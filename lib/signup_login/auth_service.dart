import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:huawei_account/huawei_account.dart';
import 'package:provider/provider.dart';
import '../repository/user_repository.dart';
import '../util/snackbar_helper.dart';
import '../models/users.dart';
import '../providers/user_provider.dart';
import '../sensors/location_centre.dart';

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
      debugPrint("AuthService requestEmailCodeForSignUp Error: ${e.message}");
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
      debugPrint("AuthService createEmailUser Error: ${e.message}");
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
        await _createOrUpdateUserInCloudDB(result.user!, email: email);

        if (context != null && context.mounted) {
          await context.read<UserProvider>().setUser(result.user!);
        }
      }

      return result.user;
    } on AGCAuthException catch (e) {
      debugPrint("AuthService SignIn Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  // --- Link Huawei ID to existing email account ---
  Future<AGCUser?> linkHuaweiID(BuildContext? context) async {
    try {
      debugPrint('[HuaweiLink] Starting Huawei ID linking');

      // Get current user
      final currentUser = await _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in. Please sign in first.');
      }

      debugPrint('[HuaweiLink] Current user: ${currentUser.uid}');

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
        debugPrint('[HuaweiLink] Silent sign-in successful');
      } catch (silentError) {
        debugPrint('[HuaweiLink] Silent sign-in failed, trying interactive');
        authAccount = await authService.signIn();
        debugPrint('[HuaweiLink] Interactive sign-in successful');
      }

      debugPrint('[HuaweiLink] Account email: ${authAccount.email}');

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
      debugPrint('[HuaweiLink] Linking Huawei ID to current account');
      final SignInResult result = await currentUser.link(credential);

      debugPrint('[HuaweiLink] 🎉 Successfully linked Huawei ID!');
      debugPrint('[HuaweiLink] Photo URL: ${result.user?.photoUrl}');

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
      debugPrint('[HuaweiLink] AGCAuthException: ${e.code} - ${e.message}');

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
      debugPrint('[HuaweiLink] PlatformException: ${e.code} - ${e.message}');
      throw Exception('Huawei ID linking failed: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('[HuaweiLink] Unexpected error: $e');
      debugPrint('[HuaweiLink] Stack trace: $stackTrace');
      throw Exception('Huawei ID linking failed: $e');
    }
  }

  Future<AGCUser?> signInWithHuaweiID(BuildContext? context) async {
    try {
      debugPrint('[HuaweiSignIn] Starting Huawei ID sign-in');

      // Step 1: Configure AccountAuthParams
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

      // Step 6: Create AGC credential
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
        '[HuaweiSignIn] AGC sign-in complete. User: ${result.user?.uid}',
      );

      if (result.user != null) {
        await _createOrUpdateUserInCloudDB(
          result.user!,
          username: authAccount.displayName,
          email: authAccount.email,
        );

        if (context != null && context.mounted) {
          await context.read<UserProvider>().setUser(result.user!);
        }
      }

      return result.user;
    } on AGCAuthException catch (e) {
      debugPrint('[HuaweiSignIn] AGCAuthException: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } on PlatformException catch (e) {
      debugPrint('[HuaweiSignIn] PlatformException: ${e.code} - ${e.message}');

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
      debugPrint('[CloudDB] Creating/updating user: ${agcUser.uid}');

      // Get current location
      final locationService = LocationServiceHelper();
      final location = await locationService.getCurrentLocation(fastMode: true);
      double? latitude;
      double? longitude;

      if (location != null) {
        latitude = location.latitude;
        longitude = location.longitude;
        debugPrint('[CloudDB] Got location: $latitude, $longitude');
      } else {
        debugPrint('[CloudDB] Could not get current location');
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
          debugPrint('[CloudDB] 🔗 Account linking detected!');
          debugPrint('[CloudDB] 📧 Email account UID: ${userByEmail.uid}');
          debugPrint('[CloudDB] 🆔 Current Huawei ID UID: ${agcUser.uid}');

          existingUser = userByEmail;
          isAccountMigration = true;

          // Delete the old UID entry if it exists
          try {
            await _userRepository.deleteUserById(userByEmail.uid!);
            debugPrint('[CloudDB] ✅ Old account deleted: ${userByEmail.uid}');
          } catch (e) {
            debugPrint('[CloudDB] ⚠️  Could not delete old account: $e');
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
        debugPrint(
          '[CloudDB] ${isAccountMigration ? "Migrating" : "Updating"} user...',
        );

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
        );

        await _userRepository.upsertUser(updatedUser);

        if (isAccountMigration) {
          debugPrint('[CloudDB] 🎉 Account successfully linked and migrated!');
          Snackbar.success('Account linked! Your data has been preserved.');
        } else {
          debugPrint('[CloudDB] User updated successfully');
        }
      } else {
        // New user, create record
        debugPrint('[CloudDB] Creating new user...');

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
          allowDiscoverable: true,
          allowEmergencyAlert: true,
          profileURL: profileURL,
        );

        await _userRepository.upsertUser(newUser);
        debugPrint('[CloudDB] User created successfully');
      }
    } catch (e) {
      debugPrint('[CloudDB] Error creating/updating user: $e');
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
      debugPrint("AuthService requestPasswordResetCode Error: ${e.message}");
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
      debugPrint("AuthService resetPasswordWithCode Error: ${e.message}");
      throw _handleAuthException(e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _userRepository.closeZone();
    } on AGCAuthException catch (e) {
      debugPrint("AuthService SignOut Error: ${e.message}");
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
