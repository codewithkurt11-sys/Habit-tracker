import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of an auth operation.
enum AuthResult { success, cancelled, error, offline }

/// Wraps Google Sign-In + Firebase Auth + the optional username system.
///
/// **Fully optional** — every other feature in the app works with no sign-in.
/// Treat "signed out" as a normal state, not an error state.
/// Every public method catches its own errors and never throws into UI code;
/// expose failures via [lastError].
class AuthService extends ChangeNotifier {
  static const _webClientId =
      '687760012800-njf7ak1fsip6mruit05i7pqb0r9jjdd9.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: kIsWeb ? null : _webClientId,
  );

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
  StreamSubscription<User?>? _authSub;

  AuthService() {
    // Listen to auth state changes so the UI rebuilds on sign-in/out.
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
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
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed' && e.message?.contains('10') == true) {
        lastError =
            'Google Sign-In is not authorized for this app certificate. '
            'Add this build\'s SHA-1 and SHA-256 to the com.yourself.habits '
            'Android app in Firebase, then download google-services.json again.';
      } else if (e.code == 'network_error') {
        lastError = 'Google Sign-In needs an internet connection.';
      } else {
        lastError = 'Google Sign-In failed (${e.code}). Please try again.';
      }
      if (kDebugMode) debugPrint('AuthService Google platform error: $e');
      notifyListeners();
      return AuthResult.error;
    } on FirebaseAuthException catch (e) {
      lastError = e.code == 'account-exists-with-different-credential'
          ? 'An account already exists with this email using another sign-in method.'
          : 'Firebase authentication failed (${e.code}). Please try again.';
      if (kDebugMode) debugPrint('AuthService Firebase auth error: $e');
      notifyListeners();
      return AuthResult.error;
    } catch (e) {
      lastError = 'Google Sign-In failed. Please try again.';
      if (kDebugMode) debugPrint('AuthService signInWithGoogle error: $e');
      notifyListeners();
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
    final currentUid = uid;
    if (currentUid == null) {
      lastError = 'You must be signed in to claim a username.';
      return false;
    }
    try {
      final userRef = _db.collection('users').doc(currentUid);
      final userSnapshot = await userRef.get();
      final existingUsername = userSnapshot.data()?['username'] as String?;
      if (existingUsername != null && existingUsername.isNotEmpty) {
        lastError = 'You already have a username and cannot change it.';
        return false;
      }

      final result = await _db.runTransaction((tx) async {
        final nameRef = _db.collection('usernames').doc(name);
        final nameSnap = await tx.get(nameRef);
        if (nameSnap.exists) {
          // Already claimed by someone else?
          final owner = nameSnap.data()?['uid'] as String?;
          if (owner == currentUid) return true; // same user re-claiming
          return false; // taken by another user
        }
        tx.set(nameRef, {
          'uid': currentUid,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        // Usernames are permanent: rules intentionally forbid update/delete.
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
    _authSub?.cancel();
    super.dispose();
  }
}
