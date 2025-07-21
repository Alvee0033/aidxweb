import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aidx/services/database_init.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Configure GoogleSignIn with the correct client ID from google-services.json
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  
  final DatabaseService _databaseService = DatabaseService();
  
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  
  Stream<User?> get userStream => _auth.authStateChanges();
  
  // Enhanced Google Sign-In method
  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('🔄 Starting Google Sign-In flow...');
      
      // Attempt to sign out previous session to prevent token conflicts
      await _googleSignIn.signOut();
      await _auth.signOut();
      
      // Trigger the Google Sign-In flow with additional error handling
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏰ Google Sign-In timed out');
          return null;
        },
      );
      
      if (googleUser == null) {
        debugPrint('ℹ️ Google sign-in was cancelled or timed out');
        return null;
      }
      
      debugPrint('✅ Google account selected: ${googleUser.email}');
      
      // Obtain the auth details from the request with retry mechanism
      GoogleSignInAuthentication? googleAuth;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          googleAuth = await googleUser.authentication;
          break;
        } catch (e) {
          debugPrint('⚠️ Token retrieval attempt $attempt failed: $e');
          if (attempt == 3) rethrow;
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
      
      if (googleAuth == null || googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Invalid Google authentication tokens');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      debugPrint('✅ Created Firebase credential with tokens');
      
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      
      debugPrint('✅ Firebase sign-in successful: ${user?.email}');
      
      // Create or update user profile with enhanced error handling
      if (user != null) {
        try {
          await _databaseService.createUserProfile(user.uid, {
            'name': user.displayName ?? 'Google User',
            'email': user.email ?? '',
            'photo': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
            'loginMethod': 'google',
            'isVerified': user.emailVerified,
          });
          debugPrint('✅ User profile created in Firestore');
        } catch (e) {
          debugPrint('⚠️ Error creating user profile: $e');
          // Log error but continue execution
        }
        
        notifyListeners();
      }
      
      return user;
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      
      // Comprehensive error handling
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'network-request-failed':
            debugPrint('🌐 Network error during authentication');
            break;
          case 'invalid-credential':
            debugPrint('🔑 Invalid authentication credentials');
            break;
          default:
            debugPrint('🚨 Unhandled Firebase Auth Error: ${e.code}');
        }
      }
      
      throw Exception(_getReadableAuthError(e));
    }
  }

  // Enhanced error handling for sign-in methods
  String _getReadableAuthError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-email':
          return 'Invalid email address format.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        case 'too-many-requests':
          return 'Too many login attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'operation-not-allowed':
          return 'This sign-in method is not allowed.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with a different sign-in method.';
        default:
          return 'Authentication error: ${error.message ?? 'Unknown error'}';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
  
  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      debugPrint('🔄 Signing in with email: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      debugPrint('✅ Sign in successful for: ${user?.email}');
 
      // Create or update user profile in Firestore to store last login timestamp
      if (user != null) {
        try {
          await _databaseService.createUserProfile(user.uid, {
            'name': user.displayName ?? '',
            'email': user.email,
            'lastLogin': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ User profile created/updated after login');
        } catch (e) {
          debugPrint('⚠️ Failed to create/update profile after login: $e');
          // Not critical – continue
        }
      }
 
      notifyListeners();
      return user;
    } catch (e) {
      debugPrint('❌ Login error: $e');
      throw Exception(_getReadableAuthError(e));
    }
  }
  
  // Register with email and password
  Future<User?> registerWithEmailAndPassword(String email, String password, String name) async {
    try {
      debugPrint('🔄 Registering new user: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      debugPrint('✅ User registration successful: ${user?.email}');
      
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);
        debugPrint('✅ Display name updated: $name');
        
        // Create user profile in Firestore
        try {
          await _databaseService.createUserProfile(user.uid, {
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ User profile created in Firestore');
        } catch (e) {
          debugPrint('⚠️ Failed to create user profile in Firestore: $e');
          // Continue even if profile creation fails
        }
      }
      
      notifyListeners();
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error registering with email and password: $e');
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('🔄 Signing out user...');
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint('✅ User signed out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error signing out: $e');
      rethrow;
    }
  }
  
  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('🔄 Getting profile for user: ${user.uid}');
        final profile = await _databaseService.getUserProfile(user.uid);
        if (profile != null) {
          debugPrint('✅ User profile retrieved successfully');
        } else {
          debugPrint('ℹ️ No profile found for user');
        }
        return profile;
      }
      debugPrint('ℹ️ No current user to get profile for');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      return null;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('🔄 Updating profile for user: ${user.uid}');
        await _databaseService.updateUserProfile(user.uid, data);
        debugPrint('✅ User profile updated successfully');
        notifyListeners();
      } else {
        debugPrint('⚠️ Cannot update profile: No current user');
      }
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      rethrow;
    }
  }
  
  // Create a test user for development/testing
  Future<User?> createTestUser() async {
    try {
      debugPrint('🔄 Creating test user...');
      
      // Check if test user already exists
      try {
        final testUser = await signInWithEmailAndPassword(
          'test@medigay.com', 
          'test123456'
        );
        
        if (testUser != null) {
          debugPrint('✅ Existing test user found and logged in');
          return testUser;
        }
      } catch (e) {
        // User doesn't exist, continue with creation
        debugPrint('ℹ️ No existing test user found');
      }
      
      // Create test user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: 'test@medigay.com', 
        password: 'test123456'
      );
      
      final user = userCredential.user;
      
      if (user != null) {
        // Update display name
        await user.updateDisplayName('Test User');
        
        // Create user profile in Firestore
        await _databaseService.createUserProfile(user.uid, {
          'name': 'Test User',
          'email': 'test@medigay.com',
          'createdAt': FieldValue.serverTimestamp(),
          'isTestUser': true,
        });
        
        debugPrint('✅ Test user created successfully');
        return user;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error creating test user: $e');
      throw Exception(_getReadableAuthError(e));
    }
  }
 
  // Update user email
  Future<void> updateEmail(String newEmail) async {
    try {
      if (currentUser == null) {
        debugPrint('⚠️ Cannot update email: No current user');
        throw Exception('No user logged in');
      }
      
      debugPrint('🔄 Updating email to: $newEmail');
      await currentUser!.updateEmail(newEmail);
      
      try {
        await _firestore.collection('users').doc(currentUser!.uid).update({'profile.email': newEmail});
        debugPrint('✅ Email updated in Firestore');
      } catch (e) {
        debugPrint('⚠️ Failed to update email in Firestore: $e');
        // Continue even if Firestore update fails
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating email: $e');
      rethrow;
    }
  }
 
  // Update user phone (Firestore only, as Firebase Auth phone update is more complex)
  Future<void> updatePhone(String newPhone) async {
    try {
      if (currentUser == null) {
        debugPrint('⚠️ Cannot update phone: No current user');
        throw Exception('No user logged in');
      }
      
      debugPrint('🔄 Updating phone to: $newPhone');
      await _firestore.collection('users').doc(currentUser!.uid).update({'profile.phone': newPhone});
      debugPrint('✅ Phone updated in Firestore');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating phone: $e');
      rethrow;
    }
  }
 
  // Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      if (currentUser == null) {
        debugPrint('⚠️ Cannot update password: No current user');
        throw Exception('No user logged in');
      }
      
      debugPrint('🔄 Updating password');
      await currentUser!.updatePassword(newPassword);
      debugPrint('✅ Password updated successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating password: $e');
      rethrow;
    }
  }
}