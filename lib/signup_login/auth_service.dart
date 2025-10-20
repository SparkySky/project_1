import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:huawei_account/huawei_account.dart';
import '../util/snackbar_helper.dart';

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
  Future<AGCUser?> createEmailUser(
    String email,
    String password,
    String code,
  ) async {
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
          EmailAuthProvider.credentialWithPassword(
            email,
            password,
          ); // Corrected constructor call
      final SignInResult result = await _auth.signIn(credential);
      return result.user;
    } on AGCAuthException catch (e) {
      debugPrint("AuthService SignIn Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  Future<AGCUser?> signInWithHuaweiID() async {
    try {
      debugPrint('[HuaweiSignIn] Starting Huawei ID sign-in');

      // Step 1: Configure AccountAuthParams with proper scopes
      final helper = AccountAuthParamsHelper();
      helper.setAuthorizationCode();
      helper.setAccessToken();
      helper.setIdToken();
      helper.setEmail();
      helper.setProfile();

      helper.setScopeList([Scope.openId, Scope.email, Scope.profile]);

      final params = helper.createParams();
      debugPrint('[HuaweiSignIn] Auth params created');

      // Step 2: Get AuthService
      final authService = AccountAuthManager.getService(params);
      debugPrint('[HuaweiSignIn] Auth service obtained');

      // Step 3: Attempt Silent Sign-In, fallback to interactive
      AuthAccount? authAccount;
      try {
        debugPrint('[HuaweiSignIn] Attempting silent sign-in');
        authAccount = await authService.silentSignIn();
        debugPrint('[HuaweiSignIn] Silent sign-in successful');
      } catch (silentError) {
        debugPrint('[HuaweiSignIn] Silent sign-in failed: $silentError');
        debugPrint('[HuaweiSignIn] Attempting interactive sign-in');

        try {
          authAccount = await authService.signIn();
          debugPrint('[HuaweiSignIn] Interactive sign-in successful');
        } catch (signInError) {
          debugPrint('[HuaweiSignIn] Interactive sign-in failed: $signInError');
          throw Exception(
            "Huawei ID sign-in cancelled or failed: $signInError",
          );
        }
      }

      // Log account details for debugging
      debugPrint(
        '[HuaweiSignIn] Account display name: ${authAccount.displayName}',
      );
      debugPrint('[HuaweiSignIn] Account email: ${authAccount.email}');
      debugPrint('[HuaweiSignIn] Account unionId: ${authAccount.unionId}');
      debugPrint('[HuaweiSignIn] Account openId: ${authAccount.openId}');

      // Step 5: Get authorization code or access token
      final String? authCode = authAccount.authorizationCode;
      final String? accessToken = authAccount.accessToken;

      debugPrint(
        '[HuaweiSignIn] Auth code obtained: ${authCode?.isNotEmpty ?? false}',
      );
      debugPrint(
        '[HuaweiSignIn] Access token obtained: ${accessToken?.isNotEmpty ?? false}',
      );

      if ((authCode == null || authCode.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw Exception(
          "Failed to get Huawei ID authorization code or access token.",
        );
      }

      // Step 6: Create AGC credential - try access token first, fallback to auth code
      debugPrint('[HuaweiSignIn] Creating AGC credential');
      AGCAuthCredential credential;

      if (accessToken != null && accessToken.isNotEmpty) {
        debugPrint('[HuaweiSignIn] Using access token for credential');
        credential = HuaweiAuthProvider.credentialWithToken(accessToken);
      } else {
        debugPrint('[HuaweiSignIn] Using authorization code for credential');
        credential = HuaweiAuthProvider.credentialWithToken(authCode!);
      }

      debugPrint('[HuaweiSignIn] Signing in to AGC');
      final SignInResult result = await _auth.signIn(credential);

      debugPrint(
        '[HuaweiSignIn] AGC sign-in complete. User: ${result.user.toString()}',
      );
      debugPrint(
        '[HuaweiSignIn] AGC sign-in complete. User: ${result.user?.uid}',
      );
      return result.user;
    } on AGCAuthException catch (e) {
      debugPrint('[HuaweiSignIn] AGCAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } on PlatformException catch (e) {
      debugPrint('[HuaweiSignIn] PlatformException: ${e.code} - ${e.message}');

      // Handle HMS Core errors
      if (e.code == '8002' || e.code == 'HMS_CORE_ERROR') {
        throw Exception(
          "HMS Core is not available. Please install or update HMS Core from AppGallery.",
        );
      }

      throw Exception("Huawei ID Sign-In Failed: ${e.message}");
    } catch (e, stackTrace) {
      debugPrint('[HuaweiSignIn] Unexpected error: $e');
      debugPrint('[HuaweiSignIn] Stack trace: $stackTrace');
      Snackbar.error('$e');
      throw Exception("Huawei ID Sign-In Failed: $e");
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
  Future<void> resetPasswordWithCode(
    String email,
    String newPassword,
    String verifyCode,
  ) async {
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
    switch (e.code.toString()) {
      // Use toString()
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