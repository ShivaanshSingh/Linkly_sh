import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  GoogleSignIn? _googleSignIn;
  FirebaseFirestore? _firestore;

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  bool _isFirebaseAvailable = false;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null || (_userModel != null && !_isFirebaseAvailable);

  AuthService() {
    try {
      _auth = FirebaseAuth.instance;
      _googleSignIn = GoogleSignIn();
      _firestore = FirebaseFirestore.instance;
      _isFirebaseAvailable = true;
      _auth!.authStateChanges().listen(_onAuthStateChanged);
      debugPrint('AuthService initialized with Firebase');
    } catch (e) {
      debugPrint('AuthService initialized without Firebase: $e');
      _isFirebaseAvailable = false;
      // For demonstration purposes, auto-authenticate with mock user
      _initializeMockUser();
    }
  }

  void _initializeMockUser() {
    // Don't auto-authenticate - let user go through login flow
    _user = null;
    _userModel = null;
    debugPrint('AuthService: Ready for user authentication');
  }

  void _onAuthStateChanged(User? user) {
    _user = user;
    if (user != null) {
      _loadUserModel();
    } else {
      _userModel = null;
    }
    notifyListeners();
  }

  Future<void> _loadUserModel() async {
    if (_user == null || !_isFirebaseAvailable) return;

    try {
      final doc = await _firestore!.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      } else {
        // Create user model from Firebase Auth user
        _userModel = UserModel(
          uid: _user!.uid,
          email: _user!.email ?? '',
          fullName: _user!.displayName ?? '',
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error loading user model: $e');
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!_isFirebaseAvailable) {
      // Mock authentication for demonstration
      _setLoading(true);
      await Future.delayed(const Duration(seconds: 1));
      _user = null; // Mock user for demonstration
      _userModel = UserModel(
        uid: 'mock_user_id',
        email: email,
        fullName: 'Demo User',
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      _setLoading(false);
      notifyListeners();
      return null;
    }
    
    try {
      _setLoading(true);
      debugPrint('Signing in with email: $email');
      
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return credential;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCredential?> signUpWithEmail(String email, String password, String fullName) async {
    if (!_isFirebaseAvailable) {
      // Mock signup for demonstration
      _setLoading(true);
      await Future.delayed(const Duration(seconds: 1));
      _user = null; // Mock user for demonstration
      _userModel = UserModel(
        uid: 'mock_user_id',
        email: email,
        fullName: fullName,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      _setLoading(false);
      notifyListeners();
      return null;
    }
    
    try {
      _setLoading(true);
      debugPrint('Signing up with email: $email, name: $fullName');
      
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(fullName);
      
      // Create user document in Firestore
      await _firestore!.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email,
        'fullName': fullName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      return credential;
    } catch (e) {
      debugPrint('Sign up error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!_isFirebaseAvailable) {
      // Mock Google sign in for demonstration
      _setLoading(true);
      await Future.delayed(const Duration(seconds: 1));
      _user = null; // Mock user for demonstration
      _userModel = UserModel(
        uid: 'mock_user_id',
        email: 'demo@gmail.com',
        fullName: 'Demo User',
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      _setLoading(false);
      notifyListeners();
      return null;
    }
    
    try {
      _setLoading(true);
      debugPrint('Signing in with Google');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) return null;
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final userCredential = await _auth!.signInWithCredential(credential);
      
      // Create or update user document in Firestore
      await _firestore!.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': userCredential.user!.email,
        'fullName': userCredential.user!.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      return userCredential;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      debugPrint('Signing out');
      
      if (_isFirebaseAvailable) {
        await _auth!.signOut();
        await _googleSignIn!.signOut();
      }
      
      _user = null;
      _userModel = null;
    } catch (e) {
      debugPrint('Sign out error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    if (!_isFirebaseAvailable) {
      // Mock password reset for demonstration
      _setLoading(true);
      await Future.delayed(const Duration(seconds: 1));
      _setLoading(false);
      debugPrint('Mock password reset for: $email');
      return;
    }
    
    try {
      _setLoading(true);
      debugPrint('Resetting password for: $email');
      
      await _auth!.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUserModel(UserModel userModel) async {
    if (!_isFirebaseAvailable) {
      // Mock update for demonstration
      _setLoading(true);
      await Future.delayed(const Duration(milliseconds: 500));
      _userModel = userModel;
      _setLoading(false);
      notifyListeners();
      return;
    }
    
    try {
      _setLoading(true);
      debugPrint('Updating user model');
      
      await _firestore!.collection('users').doc(userModel.uid).update({
        'fullName': userModel.fullName,
        'email': userModel.email,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      
      _userModel = userModel;
    } catch (e) {
      debugPrint('Update user model error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}

// Mock User class for demonstration when Firebase is not available
class MockUser {
  final String? uid;
  final String? email;
  final String? displayName;

  MockUser({this.uid, this.email, this.displayName});
}
