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

  // Getters
  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  bool get isAuthenticated => _user != null || (_userModel != null && !_isFirebaseAvailable);

  AuthService({bool firebaseInitialized = true}) {
    if (firebaseInitialized) {
      try {
        _auth = FirebaseAuth.instance;
        _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
        _firestore = FirebaseFirestore.instance;
        _isFirebaseAvailable = true;
        _auth!.authStateChanges().listen(_onAuthStateChanged);
        debugPrint('✅ AuthService initialized with REAL Firebase authentication');
        debugPrint('✅ Users will be created in Firebase Console');
        debugPrint('✅ Only registered users can sign in');
      } catch (e) {
        debugPrint('❌ AuthService initialized without Firebase: $e');
        _isFirebaseAvailable = false;
        _initializeMockUser();
      }
    } else {
      debugPrint('❌ AuthService initialized without Firebase (disabled)');
      _isFirebaseAvailable = false;
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
    debugPrint('🔄 Auth state changed: user=${user?.uid}');
    _user = user;
    
    if (user != null) {
      // User is signed in, load their data from Firestore
      loadUserData();
    } else {
      // User is signed out, clear user data
      _userModel = null;
    }
    
    notifyListeners();
  }


  void _setLoading(bool loading) {
    debugPrint('🔄 AuthService loading state changed: $loading');
    _isLoading = loading;
    notifyListeners();
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not available. Please check your internet connection.');
    }
    
    try {
      _setLoading(true);
      debugPrint('Signing in with email: $email');
      
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }
      
      if (!email.contains('@')) {
        throw Exception('Please enter a valid email address');
      }
      
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      debugPrint('Sign in successful for: $email');
      return credential;
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (e.toString().contains('user-not-found')) {
        throw Exception('No account found with this email address. Please sign up first.');
      } else if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Please enter a valid email address');
      } else if (e.toString().contains('user-disabled')) {
        throw Exception('This account has been disabled. Please contact support.');
      } else if (e.toString().contains('too-many-requests')) {
        throw Exception('Too many failed attempts. Please try again later.');
      } else {
        rethrow;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCredential?> signUpWithEmail(String email, String password, String fullName, {String? username, String? phoneNumber, String? company, String? accountType}) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not available. Please check your internet connection.');
    }
    
    try {
      _setLoading(true);
      debugPrint('Signing up with email: $email, name: $fullName');
      
      if (email.isEmpty || password.isEmpty || fullName.isEmpty || username == null || username.isEmpty) {
        throw Exception('All fields are required');
      }
      
      if (username.length < 3) {
        throw Exception('Username must be at least 3 characters');
      }
      
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        throw Exception('Username can only contain letters, numbers, and underscores');
      }
      
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }
      
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (credential.user != null) {
        await credential.user!.updateDisplayName(fullName.trim());
        
        await _firestore!.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email.trim(),
          'fullName': fullName.trim(),
          'username': username.trim(),
          'phoneNumber': phoneNumber?.trim() ?? '',
          'company': company?.trim() ?? '',
          'accountType': accountType ?? 'Public',
          'socialLinks': {},
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });
        
        // Immediately load user data after signup
        await loadUserData();
      }
      
      debugPrint('Sign up successful for: $email');
      return credential;
    } catch (e) {
      debugPrint('Sign up error: $e');
      if (e.toString().contains('email-already-in-use')) {
        throw Exception('An account with this email already exists');
      } else if (e.toString().contains('weak-password')) {
        throw Exception('Password is too weak. Please choose a stronger password');
      } else if (e.toString().contains('invalid-email')) {
        throw Exception('Please enter a valid email address');
      } else if (e.toString().contains('PigeonUserDetails')) {
        throw Exception('Authentication service error. Please try again');
      } else {
        rethrow;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCredential?> signInWithUsernameOrEmail(String usernameOrEmail, String password) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not available. Please check your internet connection.');
    }
    
    try {
      _setLoading(true);
      debugPrint('Signing in with username/email: $usernameOrEmail');
      
      if (usernameOrEmail.isEmpty || password.isEmpty) {
        throw Exception('Username/Email and password are required');
      }

      String email = usernameOrEmail.trim();
      
      // Check if it's a username (not an email format)
      if (!email.contains('@')) {
        // It's a username, find the corresponding email
        final userQuery = await _firestore!.collection('users')
            .where('username', isEqualTo: email)
            .limit(1)
            .get();
        
        if (userQuery.docs.isEmpty) {
          throw Exception('No account found with this username. Please sign up first.');
        }
        
        email = userQuery.docs.first.data()['email'];
        debugPrint('Found email for username: $email');
      }

      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      debugPrint('Sign in successful for: $usernameOrEmail');
      return credential;
    } catch (e) {
      debugPrint('Sign in error: $e');
      if (e.toString().contains('user-not-found')) {
        throw Exception('No account found with this username/email. Please sign up first.');
      } else if (e.toString().contains('wrong-password')) {
        throw Exception('Incorrect password. Please try again.');
      } else if (e.toString().contains('too-many-requests')) {
        throw Exception('Too many failed attempts. Please try again later.');
      } else if (e.toString().contains('user-disabled')) {
        throw Exception('This account has been disabled. Please contact support.');
      } else {
        rethrow;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not available. Please check your internet connection.');
    }
    
    try {
      _setLoading(true);
      debugPrint('Signing in with Google');
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        debugPrint('Google sign-in was cancelled by user');
        return null;
      }
      
      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Check if we have the required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get authentication tokens from Google');
      }
      
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken!,
        idToken: googleAuth.idToken!,
      );
      
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth!.signInWithCredential(credential);
      
      // Create or update user document in Firestore
      if (userCredential.user != null) {
        await _firestore!.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email ?? '',
          'fullName': userCredential.user!.displayName ?? 'Google User',
          'profileImageUrl': userCredential.user!.photoURL,
          'socialLinks': {},
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        }, SetOptions(merge: true));
        
        // Immediately load user data after Google sign-in
        await loadUserData();
      }
      
      debugPrint('Google sign in successful for: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      if (e.toString().contains('network_error')) {
        throw Exception('Network error. Please check your internet connection');
      } else if (e.toString().contains('sign_in_failed')) {
        throw Exception('Google sign-in failed. Please try again');
      } else if (e.toString().contains('PigeonUserDetails')) {
        throw Exception('Authentication service error. Please try again');
      } else {
        rethrow;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      debugPrint('Signing out');
      
      if (_isFirebaseAvailable) {
        try {
          // Sign out from Firebase Auth
          await _auth!.signOut();
          debugPrint('✅ Firebase Auth sign out successful');
        } catch (e) {
          debugPrint('⚠️ Firebase Auth sign out error: $e');
          // Continue with sign out even if Firebase fails
        }
        
        try {
          // Sign out from Google Sign-In
          await _googleSignIn!.signOut();
          debugPrint('✅ Google Sign-In sign out successful');
        } catch (e) {
          debugPrint('⚠️ Google Sign-In sign out error: $e');
          // Continue with sign out even if Google fails
        }
      } else {
        debugPrint('✅ Local authentication sign out');
      }
      
      // Clear user data (always do this)
      _user = null;
      _userModel = null;
      
      // Notify listeners
      notifyListeners();
      
      debugPrint('✅ Sign out completed successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      // Even if there's an error, clear the user data
      _user = null;
      _userModel = null;
      notifyListeners();
    } finally {
      // Always reset loading state
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not available. Please check your internet connection.');
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

  Future<void> loadUserData() async {
    if (!_isFirebaseAvailable || _user == null) {
      debugPrint('Firebase not available or no user, cannot load user data');
      return;
    }
    
    try {
      debugPrint('Loading user data from Firestore for: ${_user!.uid}');
      
      final userDoc = await _firestore!.collection('users').doc(_user!.uid).get();
      
      if (userDoc.exists) {
        _userModel = UserModel.fromFirestore(userDoc);
        debugPrint('✅ User data loaded successfully: ${_userModel!.fullName}');
        debugPrint('✅ User email: ${_userModel!.email}');
        debugPrint('✅ User company: ${_userModel!.company}');
        debugPrint('✅ User phone: ${_userModel!.phoneNumber}');
        notifyListeners();
        
        // Initialize notifications for the user
        await _initializeNotifications();
      } else {
        debugPrint('❌ User document not found in Firestore for UID: ${_user!.uid}');
        debugPrint('❌ This might be why the name shows as "User"');
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      // This would be called from the UI layer where NotificationService is available
      debugPrint('🔔 User authenticated, notifications should be initialized');
      // The actual initialization will be done in the UI layer
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  // Force refresh user data - useful for debugging
  Future<void> refreshUserData() async {
    debugPrint('🔄 Force refreshing user data...');
    await loadUserData();
  }

  Future<void> updateUserModel(UserModel userModel) async {
    if (!_isFirebaseAvailable) {
      debugPrint('Firebase not available, cannot update user model');
      return;
    }
    
    try {
      _setLoading(true);
      debugPrint('Updating user model for: ${userModel.email}');
      
      await _firestore!.collection('users').doc(userModel.uid).update({
        'fullName': userModel.fullName,
        'profileImageUrl': userModel.profileImageUrl,
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': userModel.isOnline,
      });
      
      _userModel = userModel;
      notifyListeners();
      
      debugPrint('User model updated successfully');
    } catch (e) {
      debugPrint('Error updating user model: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUserProfile({
    required String fullName,
    String? bio,
    String? company,
    String? position,
    String? phoneNumber,
    String? profileImageUrl,
    Map<String, String>? socialLinks,
  }) async {
    if (!_isFirebaseAvailable) {
      debugPrint('Firebase not available, cannot update user profile');
      return;
    }
    
    try {
      _setLoading(true);
      final userId = _user?.uid ?? _userModel?.uid;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      debugPrint('Updating user profile for: $fullName');
      
      // Update Firebase Auth display name
      if (_user != null) {
        await _user!.updateDisplayName(fullName);
        if (profileImageUrl != null) {
          await _user!.updatePhotoURL(profileImageUrl);
        }
      }
      
      // Update Firestore user document
      final updateData = {
        'fullName': fullName,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (bio != null && bio.isNotEmpty) updateData['bio'] = bio;
      if (company != null && company.isNotEmpty) updateData['company'] = company;
      if (position != null && position.isNotEmpty) updateData['position'] = position;
      if (phoneNumber != null && phoneNumber.isNotEmpty) updateData['phoneNumber'] = phoneNumber;
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        updateData['profileImageUrl'] = profileImageUrl;
      }
      if (socialLinks != null) {
        updateData['socialLinks'] = socialLinks;
      }
      
      await _firestore!.collection('users').doc(userId).update(updateData);
      
      // Update local user model
      if (_userModel != null) {
        _userModel = _userModel!.copyWith(
          fullName: fullName,
          phoneNumber: phoneNumber ?? _userModel!.phoneNumber,
          profileImageUrl: profileImageUrl ?? _userModel!.profileImageUrl,
          socialLinks: socialLinks ?? _userModel!.socialLinks,
        );
      }
      
      notifyListeners();
      debugPrint('User profile updated successfully');
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}