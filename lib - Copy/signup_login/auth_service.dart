import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:huawei_account/huawei_account.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repository/user_repository.dart';
import '../util/snackbar_helper.dart';
import '../models/users.dart';
import '../providers/user_provider.dart';
import '../sensors/location_centre.dart';
import '../services/push_notification_service.dart';

class AuthService {
  final AGCAuth _auth = AGCAuth.instance;
  final UserRepository _userRepository = UserRepository();

  // Get the current user (if any)
  Future<AGCUser?> get currentUser => _auth.currentUser;

  // --- Sign-Up Step 1: Request Code ---
  Future<void> requestEmailCodeForSignUp(String email) async {
    try {
      final settings = VerifyCodeSettings(
        VerifyCodeAction.registerLogin,
        sendInterval: 30,
      );
      await _auth.requestVerifyCodeWithEmail(email, settings);
    } on AGCAuthException catch (e) {

      throw _handleAuthException(e);
    }
  }

  // --- Sign-Up Step 2: Create User ---
  Future<AGCUser?> createEmailUser(
    String email,
    String password,
    String code, {
    String? username,
    String? phoneNo,
  }) async {
    try {
      final EmailUser userPayload = EmailUser(email, code, password);
      final SignInResult result = await _auth.createEmailUser(userPayload);

      // Create user in CloudDB
      if (result.user != null) {
        await _createOrUpdateUserInCloudDB(
          result.user!,
          username: username,
          email: email,
          phoneNo: phoneNo,
        );

        // Sign out immediately after successful sign up
        await _auth.signOut();
      }

      return result.user;
    } on AGCAuthException catch (e) {

      throw _handleAuthException(e);
    }
  }

  // --- Sign In with Email and Password ---
  Future<AGCUser?> signInWithEmail(
    BuildContext? context,
    String email,
    String password,
  ) async {
    try {
      final AGCAuthCredential credential =
          EmailAuthProvider.credentialWithPassword(email, password);
      final SignInResult result = await _auth.signIn(credential);

      // Update user in CloudDB if needed
      if (result.user != null) {
        await _createOrUpdateUserInCloudDB(
          result.user!,
          email: email,
          profileURL: result
              .user!
              .photoUrl, // ✅ Fetch profile picture from AGCUser (includes Huawei ID photo if linked)
        );

        if (context != null && context.mounted) {
          await context.read<UserProvider>().setUser(result.user!);
        }
      }

      return result.user;
    } on AGCAuthException catch (e) {

      throw _handleAuthException(e);
    }
  }

  // --- Link Huawei ID to existing email account ---
  Future<AGCUser?> linkHuaweiID(BuildContext? context) async {
    try {


      // Get current user
      final currentUser = await _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in. Please sign in first.');
      }



      // Step 1: Get Huawei account
      final helper = AccountAuthParamsHelper();
      helper.setAuthorizationCode();
      helper.setAccessToken();
      helper.setIdToken();
      helper.setEmail();
      helper.setProfile();
      helper.setScopeList([Scope.openId, Scope.email, Scope.profile]);

      final params = helper.createParams();
      final authService = AccountAuthManager.getService(params);

      // Step 2: Sign in to Huawei Account
      AuthAccount? authAccount;
      try {
        authAccount = await authService.silentSignIn();

      } catch (silentError) {

        authAccount = await authService.signIn();

      }



      // Step 3: Get authorization code or access token
      final String? authCode = authAccount.authorizationCode;
      final String? accessToken = authAccount.accessToken;

      if ((authCode == null || authCode.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw Exception('Failed to get Huawei ID authorization.');
      }

      // Step 4: Create AGC credential
      AGCAuthCredential credential;
      if (accessToken != null && accessToken.isNotEmpty) {
        credential = HuaweiAuthProvider.credentialWithToken(accessToken);
      } else {
        credential = HuaweiAuthProvider.credentialWithToken(authCode!);
      }

      // Step 5: Link the credential to current user

      final SignInResult result = await currentUser.link(credential);




      // Update CloudDB with Huawei info
      await _createOrUpdateUserInCloudDB(
        result.user!,
        username: authAccount.displayName,
        email: authAccount.email,
        profileURL: authAccount.avatarUri,
      );

      if (context != null && context.mounted) {
        await context.read<UserProvider>().setUser(result.user!);
        Snackbar.success('Huawei ID linked! Profile picture updated.');
      }

      return result.user;
    } on AGCAuthException catch (e) {


      // Handle specific linking errors
      if (e.code.toString().contains('205521') ||
          e.message?.toLowerCase().contains('already linked') == true) {
        throw Exception(
          'This Huawei ID is already linked to another account. '
          'Please use a different Huawei ID or sign in with that account.',
        );
      }

      if (e.code.toString().contains('205522') ||
          e.message?.toLowerCase().contains('provider user already linked') ==
              true) {
        throw Exception(
          'This Huawei account is already used by another user. '
          'Each Huawei ID can only be linked to one account.',
        );
      }

      throw _handleAuthException(e);
    } on PlatformException catch (e) {

      throw Exception('Huawei ID linking failed: ${e.message}');
    } catch (e) {


      throw Exception('Huawei ID linking failed: $e');
    }
  }

  Future<AGCUser?> signInWithHuaweiID(BuildContext? context) async {
    try {


      // Step 1: Configure AccountAuthParams
      final helper = AccountAuthParamsHelper();
      helper.setAuthorizationCode();
      helper.setAccessToken();
      helper.setIdToken();
      helper.setEmail();
      helper.setProfile();
      helper.setScopeList([Scope.openId, Scope.email, Scope.profile]);

      final params = helper.createParams();


      // Step 2: Get AuthService
      final authService = AccountAuthManager.getService(params);


      // Step 3: Attempt Silent Sign-In, fallback to interactive
      AuthAccount? authAccount;
      try {

        authAccount = await authService.silentSignIn();

      } catch (silentError) {



        try {
          authAccount = await authService.signIn();

        } catch (signInError) {

          throw Exception(
            "Huawei ID sign-in cancelled or failed: $signInError",
          );
        }
      }
      // Step 5: Get authorization code or access token
      final String? authCode = authAccount.authorizationCode;
      final String? accessToken = authAccount.accessToken;
      if ((authCode == null || authCode.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw Exception(
          "Failed to get Huawei ID authorization code or access token.",
        );
      }

      // Step 6: Create AGC credential

      AGCAuthCredential credential;

      if (accessToken != null && accessToken.isNotEmpty) {

        credential = HuaweiAuthProvider.credentialWithToken(accessToken);
      } else {

        credential = HuaweiAuthProvider.credentialWithToken(authCode!);
      }


      final SignInResult result = await _auth.signIn(credential);
      if (result.user != null) {
        await _createOrUpdateUserInCloudDB(
          result.user!,
          username: authAccount.displayName,
          email: authAccount.email,
          profileURL: authAccount.avatarUri, // ✅ Save Huawei ID profile picture
        );

        if (context != null && context.mounted) {
          await context.read<UserProvider>().setUser(result.user!);
        }
      }

      return result.user;
    } on AGCAuthException catch (e) {

      throw _handleAuthException(e);
    } on PlatformException catch (e) {


      if (e.code == '8002' || e.code == 'HMS_CORE_ERROR') {
        throw Exception(
          "HMS Core is not available. Please install or update HMS Core from AppGallery.",
        );
      }

      throw Exception("Huawei ID Sign-In Failed: ${e.message}");
    } catch (e) {


      Snackbar.error('$e');
      throw Exception("Huawei ID Sign-In Failed: $e");
    }
  }

  // --- NEW: Create or Update User in CloudDB ---
  Future<void> _createOrUpdateUserInCloudDB(
    AGCUser agcUser, {
    String? username,
    String? email,
    String? phoneNo,
    String? district,
    String? postcode,
    String? state,
    String? profileURL,
  }) async {
    try {


      // Get current location
      final locationService = LocationServiceHelper();
      final location = await locationService.getCurrentLocation(fastMode: true);
      double? latitude;
      double? longitude;

      if (location != null) {
        latitude = location.latitude;
        longitude = location.longitude;

      } else {

      }

      // Get push token from PushNotificationService or SharedPreferences
      String? pushToken;
      try {
        pushToken = PushNotificationService().currentToken;
        if (pushToken == null || pushToken.isEmpty) {
          // Try to get from SharedPreferences as fallback
          final prefs = await SharedPreferences.getInstance();
          pushToken = prefs.getString('pending_push_token');
        }
      } catch (e) {

      }


      // Check if user already exists
      await _userRepository.openZone();

      // ACCOUNT LINKING: First check if an account with this email already exists
      Users? existingUser;
      bool isAccountMigration = false;

      if (email != null && email.isNotEmpty) {
        final userByEmail = await _userRepository.getUserByEmail(email);
        if (userByEmail != null && userByEmail.uid != agcUser.uid) {
          // Found an account with same email but different UID
          // This happens when user registered with email then logged in with Huawei ID




          existingUser = userByEmail;
          isAccountMigration = true;

          // Delete the old UID entry if it exists
          try {
            await _userRepository.deleteUserById(userByEmail.uid!);

          } catch (e) {

          }
        } else {
          // Check by current UID
          existingUser = await _userRepository.getUserById(agcUser.uid!);
        }
      } else {
        existingUser = await _userRepository.getUserById(agcUser.uid!);
      }

      if (existingUser != null) {
        // User exists, update with new UID if migration, otherwise just update info
        final updatedUser = Users(
          uid: agcUser.uid, // Use new UID (important for migration)
          email: email ?? existingUser.email,
          username: username ?? existingUser.username,
          district: district ?? existingUser.district,
          postcode: postcode ?? existingUser.postcode,
          state: state ?? existingUser.state,
          phoneNo: phoneNo ?? existingUser.phoneNo,
          latitude: latitude ?? existingUser.latitude,
          longitude: longitude ?? existingUser.longitude,
          allowDiscoverable: existingUser.allowDiscoverable,
          allowEmergencyAlert: existingUser.allowEmergencyAlert,
          locUpdateTime: DateTime.now(),
          detectionLanguage: existingUser.detectionLanguage,
          profileURL: profileURL ?? existingUser.profileURL,
          pushToken: pushToken, // Add push token to update
        );

        await _userRepository.upsertUser(updatedUser);

        if (isAccountMigration) {

          Snackbar.success('Account linked! Your data has been preserved.');
        } else {

        }
      } else {
        // New user, create record


        final newUser = Users(
          uid: agcUser.uid,
          email: email,
          username: username ?? email?.split('@').first ?? 'User',
          district: district,
          postcode: postcode,
          state: state,
          phoneNo: phoneNo,
          latitude: latitude,
          longitude: longitude,
          allowDiscoverable: false, // Off by default - user must enable
          allowEmergencyAlert: false, // Off by default - requires discoverable
          profileURL: profileURL,
          pushToken: pushToken, // Add push token to new user
        );

        await _userRepository.upsertUser(newUser);

      }
    } catch (e) {

      // Don't throw - we don't want to fail auth if CloudDB fails
    }
  }

  // --- Password Reset Step 1: Request Code ---
  Future<void> requestPasswordResetCode(String email) async {
    try {
      final settings = VerifyCodeSettings(
        VerifyCodeAction.resetPassword,
        sendInterval: 30,
      );
      await _auth.requestVerifyCodeWithEmail(email, settings);
    } on AGCAuthException catch (e) {

      throw _handleAuthException(e);
    }
  }

  // --- Password Reset Step 2: Reset with Code and New Password ---
  Future<void> resetPasswordWithCode(
    String email,
    String newPassword,
    String verifyCode,
  ) async {
    try {
      await _auth.resetPasswordWithEmail(email, newPassword, verifyCode);
    } on AGCAuthException catch (e) {

      throw _handleAuthException(e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _userRepository.closeZone();
    } on AGCAuthException catch (e) {

      throw _handleAuthException(e);
    }
  }

  // Helper
  String _handleAuthException(AGCAuthException e) {
    switch (e.code.toString()) {
      case "6003-8001":
      case "AUTH:3009-9004":
      case "AUTH:3013-9004":
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
        return e.message ?? "An unknown error occurred (Code: ${e.code})";
    }
  }
}
