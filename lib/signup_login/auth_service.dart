import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:flutter/material.dart';
import 'package:huawei_account/huawei_account.dart'; // Still needed for Scope constants

class AuthService {
  final AGCAuth _auth = AGCAuth.instance;

  // Get the current user (if any)
  Future<AGCUser?> get currentUser => _auth.currentUser;

  // --- Sign-Up Step 1: Request Code ---
  // Uses the method name from your code
  Future<void> requestEmailCodeForSignUp(String email) async {
    try {
      final settings = VerifyCodeSettings(
        VerifyCodeAction.registerLogin, // Action for signing up
        sendInterval: 30, // Interval from your code
      );
      // Method name from your code
      await _auth.requestVerifyCodeWithEmail(email, settings);
    } on AGCAuthException catch (e) {
      debugPrint("AuthService requestEmailCodeForSignUp Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  // --- Sign-Up Step 2: Create User ---
  Future<AGCUser?> createEmailUser(String email, String password, String code) async {
    try {
      // Corrected: createEmailUser expects an EmailUser object.
      final EmailUser userPayload = EmailUser(email, code, password);
      final SignInResult result = await _auth.createEmailUser(userPayload);
      
      // Sign out immediately after successful sign up
      if (result.user != null) {
        await _auth.signOut();
      }
      
      return result.user;
    } on AGCAuthException catch (e) {
      debugPrint("AuthService createEmailUser Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  // --- Sign In with Email and Password ---
  // This matches your code and previous corrections.
  Future<AGCUser?> signInWithEmail(String email, String password) async {
    try {
      final AGCAuthCredential credential =
      EmailAuthProvider.credentialWithPassword(email, password); // Corrected constructor call
      final SignInResult result = await _auth.signIn(credential);
      return result.user;
    } on AGCAuthException catch (e) {
      debugPrint("AuthService SignIn Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  // --- Sign in with HUAWEI ID ---
  // Uses methods and classes from your provided code.
  Future<AGCUser?> signInWithHuaweiID() async {
    try {
      // 1. Request Auth Result using AccountAuthManager and Scope
      final AuthAccount authAccount = await AccountAuthManager.getAuthResultWithScopes([Scope.openId, Scope.email, Scope.profile]);

      // 2. Get the authorization code
      final String authCode = authAccount.authorizationCode ?? '';
      if (authCode.isEmpty) {
        throw Exception("Failed to get Huawei ID authorization code.");
      }

      // 3. Create credential using HuaweiAuthProvider
      final AGCAuthCredential credential =
      HuaweiAuthProvider.credentialWithToken(authCode);

      // 4. Sign in to ACG Auth Kit
      final SignInResult result = await _auth.signIn(credential);
      return result.user;
    } on AGCAuthException catch (e) {
      debugPrint("AuthService Huawei SignIn AGCAuthException: ${e.message}");
      throw _handleAuthException(e);
    } catch (e) {
      // Catching generic Exception for Account Kit errors
      debugPrint("AuthService Huawei SignIn Generic Error: $e");
      // Provide a slightly more specific error message if possible
      String errorMessage = "Huawei ID Sign-In Failed";
      if (e is Exception) {
        // You might parse specific error types from huawei_account if available
        errorMessage += ": An account error occurred.";
      } else {
        errorMessage += ": $e";
      }
      throw (errorMessage);
    }
  }

  // --- NEW: Password Reset Step 1: Request Code ---
  Future<void> requestPasswordResetCode(String email) async {
    try {
      final settings = VerifyCodeSettings(
        VerifyCodeAction.resetPassword, // Specific action for password reset
        sendInterval: 30,
      );
      await _auth.requestVerifyCodeWithEmail(email, settings);
    } on AGCAuthException catch (e) {
      debugPrint("AuthService requestPasswordResetCode Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }


  // --- NEW: Password Reset Step 2: Reset with Code and New Password ---
  // Uses the method signature from your code
  Future<void> resetPasswordWithCode(String email, String newPassword, String verifyCode) async {
    try {
      await _auth.resetPasswordWithEmail(email, newPassword, verifyCode);
    } on AGCAuthException catch (e) {
      debugPrint("AuthService resetPasswordWithCode Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  // Sign Out (Unchanged)
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AGCAuthException catch (e) {
      debugPrint("AuthService SignOut Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  // Helper (Using toString() for safety as per your code)
  String _handleAuthException(AGCAuthException e) {
    switch (e.code.toString()) { // Use toString()
      case "6003-8001":
      case "AUTH:3009-9004":
      case "AUTH:3013-9004": // Invalid verification code (added based on API structure)
        return "Invalid email, password, or code.";
      case "6003-8005":
      case "AUTH:3003-9004":
        return "User not found.";
      case "6003-8012":
      case "AUTH:3011-9004":
        return "Email address is already in use.";
      case "NETWORK_ERROR":
        return "Network error. Please check your connection.";
      default:
      // Include the code in the default message for easier debugging
        return e.message ?? "An unknown error occurred (Code: ${e.code})";
    }
  }
}