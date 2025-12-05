import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instance of Firestore

  // 1. Register: Create Auth User AND Save to Firestore
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      // A. Create the User in Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );

      User? user = result.user;

      // B. Create a Document in Firestore for this user
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'username': email.split('@')[0], // Create a default username
          'created_at': FieldValue.serverTimestamp(), // Save when they joined
        });
      }

      return user;
    } catch (e) {
      print("Registration Error: $e");
      return null;
    }
  }

  // 2. Login (No changes needed here)
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // 3. Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}