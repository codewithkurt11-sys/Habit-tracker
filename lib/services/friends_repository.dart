import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A friend's public profile (read-only).
class FriendProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? username;

  FriendProfile(
      {required this.uid,
      required this.displayName,
      this.photoUrl,
      this.username});
}

/// Manages friend requests, friendships, and searching users by username.
///
/// Firestore collections:
///   usernames/{lowercaseName}             -> { uid }
///   users/{uid}                           -> { uid, displayName, photoUrl, username, createdAt }
///   friendRequests/{fromUid}_{toUid}      -> { fromUid, toUid, status: pending, createdAt }
///   friendships/{sortedUid1}_{sortedUid2} -> { uid1, uid2, status: accepted, createdAt }
class FriendsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Deterministic friendship doc ID (sorted UIDs).
  String friendshipId(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  // ===================== Search =====================

  /// Prefix match on the `users` collection where `username >= prefix AND
  /// username < prefix + '\uf8ff'`. Requires usernames stored lowercase.
  Future<List<FriendProfile>> searchByUsername(String prefix,
      {int limit = 10}) async {
    if (_uid == null) return [];
    final q = prefix.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final snap = await _db
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: q)
          .where('username', isLessThan: '$q\u{f8ff}')
          .limit(limit)
          .get();
      return snap.docs
          .map((doc) {
            final d = doc.data();
            return FriendProfile(
              uid: doc.id,
              displayName: (d['displayName'] as String?) ?? 'User',
              photoUrl: d['photoUrl'] as String?,
              username: d['username'] as String?,
            );
          })
          .where((p) => p.uid != _uid) // exclude self
          .toList();
    } catch (e) {
      if (kDebugMode)
        debugPrint('FriendsRepository.searchByUsername error: $e');
      return [];
    }
  }

  // ===================== Friend requests =====================

  /// Send a friend request to [toUid].
  Future<bool> sendRequest(String toUid) async {
    if (_uid == null) return false;
    try {
      final reqId = '${_uid}_$toUid';
      await _db.collection('friendRequests').doc(reqId).set({
        'fromUid': _uid,
        'toUid': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsRepository.sendRequest error: $e');
      return false;
    }
  }

  /// Accept a friend request from [fromUid].
  /// Creates the deterministic friendship doc and deletes the request.
  Future<bool> acceptRequest(String fromUid) async {
    final me = _uid;
    if (me == null) return false;
    try {
      final fid = friendshipId(fromUid, me);
      final batch = _db.batch();
      batch.set(_db.collection('friendships').doc(fid), {
        'uid1': fromUid.compareTo(me) < 0 ? fromUid : me,
        'uid2': fromUid.compareTo(me) < 0 ? me : fromUid,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.delete(_db.collection('friendRequests').doc('${fromUid}_$me'));
      await batch.commit();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsRepository.acceptRequest error: $e');
      return false;
    }
  }

  /// Decline / cancel a friend request.
  Future<bool> declineRequest(String fromUid) async {
    final me = _uid;
    if (me == null) return false;
    try {
      await _db.collection('friendRequests').doc('${fromUid}_$me').delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsRepository.declineRequest error: $e');
      return false;
    }
  }

  /// Remove an existing friendship.
  Future<bool> removeFriend(String friendUid) async {
    final me = _uid;
    if (me == null) return false;
    try {
      await _db
          .collection('friendships')
          .doc(friendshipId(me, friendUid))
          .delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('FriendsRepository.removeFriend error: $e');
      return false;
    }
  }

  // ===================== Streams =====================

  /// Incoming pending friend requests for the current user.
  Stream<List<Map<String, dynamic>>> incomingRequestsStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection('friendRequests')
        .where('toUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// My friends list — two separate queries (uid1 or uid2) merged client-side.
  /// Important: Firestore has no native OR-across-fields query; do NOT fetch
  /// the entire friendships collection and filter client-side (doesn't scale).
  Stream<List<FriendProfile>> friendsStream() {
    final me = _uid;
    if (me == null) return const Stream.empty();
    final q1 =
        _db.collection('friendships').where('uid1', isEqualTo: me).snapshots();
    final q2 =
        _db.collection('friendships').where('uid2', isEqualTo: me).snapshots();
    return q1.asyncExpand((s1) async* {
      await for (final s2 in q2) {
        final friendUids = <String>{};
        for (final doc in s1.docs) {
          final d = doc.data();
          if (d['status'] == 'accepted') {
            final other = d['uid1'] == me ? d['uid2'] : d['uid1'];
            friendUids.add(other as String);
          }
        }
        for (final doc in s2.docs) {
          final d = doc.data();
          if (d['status'] == 'accepted') {
            final other = d['uid1'] == me ? d['uid2'] : d['uid1'];
            friendUids.add(other as String);
          }
        }
        if (friendUids.isEmpty) {
          yield [];
          continue;
        }
        // Fetch user profiles for friend UIDs.
        final profiles = <FriendProfile>[];
        for (final uid in friendUids) {
          try {
            final userDoc = await _db.collection('users').doc(uid).get();
            if (userDoc.exists) {
              final d = userDoc.data()!;
              profiles.add(FriendProfile(
                uid: uid,
                displayName: (d['displayName'] as String?) ?? 'User',
                photoUrl: d['photoUrl'] as String?,
                username: d['username'] as String?,
              ));
            }
          } catch (_) {}
        }
        yield profiles;
      }
    });
  }

  // ===================== Friend's data (read-only streams) =====================

  /// Read a friend's subcollection as a stream of raw docs.
  Stream<List<Map<String, dynamic>>> friendDataStream(
      String friendUid, String type) {
    return _db
        .collection('users')
        .doc(friendUid)
        .collection(type)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }
}
