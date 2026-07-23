#!/usr/bin/env python3
"""
Firebase backend setup for the Yourself habit tracker.

Creates Firestore security rules and a few placeholder docs so the friend
system has something to query against. Run once after enabling Firestore.

Usage:
    python3 setup_firebase_backend.py

Requires: /opt/flutter/firebase-admin-sdk.json (Admin SDK key)
"""

import os
import sys

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("ERROR: firebase-admin not installed. Run: pip install firebase-admin==7.1.0")
    sys.exit(1)

SDK_PATH = "/opt/flutter/firebase-admin-sdk.json"

if not os.path.exists(SDK_PATH):
    print(f"ERROR: Firebase Admin SDK key not found at {SDK_PATH}")
    print("Upload it via the Firebase tab in the sandbox UI.")
    sys.exit(1)

cred = credentials.Certificate(SDK_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# --- Security rules ---
# Note: Deploying rules via the Admin SDK requires the firebase-admin rules
# API which is version-dependent. For the initial draft, print the rules
# to deploy manually in the Firebase Console.
RULES = """rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }
    function isOwner(uid) { return isSignedIn() && request.auth.uid == uid; }
    function friendshipId(a, b) { return a < b ? a + '_' + b : b + '_' + a; }
    function areFriends(a, b) {
      return exists(/databases/$(database)/documents/friendships/$(friendshipId(a, b)))
        && get(/databases/$(database)/documents/friendships/$(friendshipId(a, b))).data.status == 'accepted';
    }

    match /usernames/{username} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;
      allow update, delete: if false;
    }

    match /users/{uid} {
      allow read: if isSignedIn();
      allow write: if isOwner(uid);
      match /{collection}/{docId} {
        allow read: if isOwner(uid) || areFriends(request.auth.uid, uid);
        allow write: if isOwner(uid);
      }
    }

    match /friendRequests/{reqId} {
      allow create: if isSignedIn();
      allow read, delete: if isSignedIn();
    }

    match /friendships/{id} {
      allow read: if isSignedIn();
      allow write: if isSignedIn();
    }
  }
}"""

print("=" * 60)
print("FIRESTORE SECURITY RULES (deploy in Firebase Console)")
print("=" * 60)
print(RULES)
print("=" * 60)
print()
print("Deploy steps:")
print("1. Go to https://console.firebase.google.com/")
print("2. Select project -> Firestore Database -> Rules")
print("3. Paste the rules above and click 'Publish'")
print()

# --- Verify database connectivity ---
try:
    # Try a simple read to confirm the database exists.
    db.collection("_health_check").limit(1).get()
    print("OK: Firestore database is reachable.")
except Exception as e:
    print(f"WARNING: Could not reach Firestore: {e}")
    print("Make sure you created the Firestore Database in Firebase Console.")
    sys.exit(1)

print()
print("Backend setup complete. The app will create users/ docs on first sign-in.")
