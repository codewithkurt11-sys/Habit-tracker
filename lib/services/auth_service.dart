import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Result of an auth operation.
enum AuthResult { success, cancelled, error, offline }

/// Wraps Google Sign-In + Firebase Auth + the optional username system.
///
/// **Fully optional** — every other feature in the app works with no sign-in.
/// Treat "signed out" as a normal state, not an error state.
/// Every public method catches its own errors and never throws into UI code;
/// expose failures via [lastError].
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  String? get displayName => _auth.currentUser?.displayName;
  String? get photoUrl => _auth.currentUser?.photoURL;
  bool get isSignedIn => _auth.currentUser != null;

  /// Last human-readable error message, or null.
  String? lastError;

  String? _username;
  String? get username => _username;

  StreamSubscription<DocumentSnapshot>? _userDocSub;

  AuthService() {
    // Listen to auth state changes so the UI rebuilds on sign-in/out.
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _userDocSub?.cancel();
    _userDocSub = null;
    _username = null;
    if (user != null) {
      // Subscribe to the user doc to keep the local username in sync.
      _userDocSub = _db.collection('users').doc(user.uid).snapshots().listen(
        (doc) {
          if (doc.exists) {
            _username = doc.data()?['username'] as String?;
          }
          notifyListeners();
        },
        onError: (e) {
          // Cloud read failures must never crash the app.
          if (kDebugMode) debugPrint('AuthService user doc stream error: $e');
        },
      );
      // Ensure a user doc exists on first sign-in.
      _ensureUserDoc(user);
    }
    notifyListeners();
  }

  Future<void> _ensureUserDoc(User user) async {
    try {
      final ref = _db.collection('users').doc(user.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'uid': user.uid,
          'displayName': user.displayName ?? '',
          'photoUrl': user.photoURL ?? '',
          'username': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AuthService _ensureUserDoc error: $e');
      // Non-fatal — app remains usable offline.
    }
  }

  /// Sign in with Google. Returns [AuthResult.success] on success.
  Future<AuthResult> signInWithGoogle() async {
    lastError = null;
    try {
      final googleAccount = await _googleSignIn.signIn();
      if (googleAccount == null) return AuthResult.cancelled;
      final googleAuth = await googleAccount.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return AuthResult.success;
    } catch (e) {
      lastError = 'Google sign-in failed: $e';
      if (kDebugMode) debugPrint('AuthService signInWithGoogle error: $e');
      return AuthResult.error;
    }
  }

  /// Sign out. Does NOT delete local Hive data.
  Future<void> signOut() async {
    lastError = null;
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      lastError = 'Sign-out failed: $e';
      if (kDebugMode) debugPrint('AuthService signOut error: $e');
    }
  }

  /// Claim a username via a Firestore transaction (atomic, race-free).
  /// Format enforced: lowercase, [a-z0-9_]{3,20}.
  Future<bool> claimUsername(String desired) async {
    lastError = null;
    final name = desired.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(name)) {
      lastError =
          'Username must be 3-20 chars: lowercase letters, numbers, underscore.';
      return false;
    }
    if (uid == null) {
      lastError = 'You must be signed in to claim a username.';
      return false;
    }
    try {
      final result = await _db.runTransaction((tx) async {
        final nameRef = _db.collection('usernames').doc(name);
        final nameSnap = await tx.get(nameRef);
        if (nameSnap.exists) {
          // Already claimed by someone else?
          final owner = nameSnap.data()?['uid'] as String?;
          if (owner == uid) return true; // same user re-claiming
          return false; // taken by another user
        }
        tx.set(
            nameRef, {'uid': uid, 'claimedAt': FieldValue.serverTimestamp()});
        // Also set username on the user doc.
        final userRef = _db.collection('users').doc(uid);
        final userSnap = await tx.get(userRef);
        if (userSnap.exists) {
          // If this user had an old username, release it.
          final oldName = userSnap.data()?['username'] as String?;
          if (oldName != null && oldName != name) {
            tx.delete(_db.collection('usernames').doc(oldName));
          }
        }
        tx.update(userRef, {'username': name});
        return true;
      });
      if (result == true) {
        return true;
      } else {
        lastError = 'That username is already taken.';
        return false;
      }
    } catch (e) {
      lastError = 'Failed to claim username: $e';
      if (kDebugMode) debugPrint('AuthService claimUsername error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    super.dispose();
  }
}
