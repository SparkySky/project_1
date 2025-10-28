import 'package:flutter/material.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import '../models/users.dart';
import '../repository/user_repository.dart';
import '../signup_login/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();

  AGCUser? _agcUser;
  Users? _cloudDbUser;
  bool _isLoading = true;

  AGCUser? get agcUser => _agcUser;
  Users? get cloudDbUser => _cloudDbUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _agcUser != null;
  String? get uid => _agcUser?.uid;
  String? get username => _cloudDbUser?.username ?? _agcUser?.displayName;
  String? get email => _agcUser?.email;

  UserProvider() {
    _initUser();
  }

  Future<void> _initUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[UserProvider] 🔄 Initializing user...');
      _agcUser = await _authService.currentUser;

      if (_agcUser != null) {
        debugPrint('[UserProvider] ✅ AGC User found: ${_agcUser!.uid}');
        debugPrint('[UserProvider]    Email: ${_agcUser!.email}');
        debugPrint('[UserProvider]    Display Name: ${_agcUser!.displayName}');
        debugPrint('[UserProvider]    Photo URL: ${_agcUser!.photoUrl}');
        debugPrint(
          '[UserProvider]    Provider Info: ${_agcUser!.providerInfo}',
        );

        await _loadCloudDbUser();
      } else {
        debugPrint('[UserProvider] ⚠️  No AGC User found (not logged in)');
      }
    } catch (e) {
      debugPrint('[UserProvider] ❌ Error initializing user: $e');
      debugPrint('[UserProvider]    Stack trace: ${StackTrace.current}');
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint('[UserProvider] ✅ User initialization complete');
      debugPrint('[UserProvider]    AGC User: ${_agcUser?.uid}');
      debugPrint('[UserProvider]    CloudDB User: ${_cloudDbUser?.uid}');
    }
  }

  // Load CloudDB user data
  Future<void> _loadCloudDbUser() async {
    if (_agcUser == null) {
      debugPrint(
        '[UserProvider] ⚠️  Cannot load CloudDB user: AGC User is null',
      );
      return;
    }

    try {
      debugPrint('[UserProvider] 🔄 Loading CloudDB user: ${_agcUser!.uid}');
      await _userRepository.openZone();

      _cloudDbUser = await _userRepository.getUserById(_agcUser!.uid!);

      if (_cloudDbUser != null) {
        debugPrint('[UserProvider] ✅ CloudDB user loaded successfully');
        debugPrint('[UserProvider]    Username: ${_cloudDbUser!.username}');
        debugPrint('[UserProvider]    Email: ${_cloudDbUser!.email}');
        debugPrint('[UserProvider]    Phone: ${_cloudDbUser!.phoneNo}');
        debugPrint(
          '[UserProvider]    Profile URL: ${_cloudDbUser!.profileURL}',
        );
        debugPrint('[UserProvider]    District: ${_cloudDbUser!.district}');
        debugPrint('[UserProvider]    State: ${_cloudDbUser!.state}');
        debugPrint('[UserProvider]    Postcode: ${_cloudDbUser!.postcode}');

        // Immediately sync language preference from SharedPreferences
        // SharedPreferences is the single source of truth for language
        await _syncLanguageFromPreferences();
      } else {
        debugPrint(
          '[UserProvider] ⚠️  CloudDB user not found for UID: ${_agcUser!.uid}',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[UserProvider] ❌ Error loading CloudDB user: $e');
      debugPrint('[UserProvider]    Stack trace: ${StackTrace.current}');
    }
  }

  /// Sync user preferences from SharedPreferences (local storage)
  /// SharedPreferences is the single source of truth for these settings
  Future<void> _syncLanguageFromPreferences() async {
    if (_cloudDbUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load language preference
      final savedLanguage = prefs.getString('voice_detection_language');

      debugPrint(
        '[UserProvider] 📱 CloudDB loaded language: ${_cloudDbUser!.detectionLanguage}',
      );
      debugPrint(
        '[UserProvider] 💾 SharedPreferences saved language: $savedLanguage',
      );

      // Load allow discoverable preference
      final allowDiscoverable = prefs.getBool('allow_discoverable');

      // Load allow emergency alert preference
      final allowEmergencyAlert = prefs.getBool('allow_emergency_alert');

      // Sync language
      if (savedLanguage != null &&
          savedLanguage != _cloudDbUser!.detectionLanguage) {
        debugPrint(
          '[UserProvider] 🔄 Syncing language from SharedPreferences: $savedLanguage',
        );
        _cloudDbUser!.detectionLanguage = savedLanguage;
        debugPrint(
          '[UserProvider] ✅ Language updated to: ${_cloudDbUser!.detectionLanguage}',
        );
      } else if (savedLanguage != null) {
        debugPrint('[UserProvider] ✅ Language already in sync: $savedLanguage');
      } else {
        debugPrint(
          '[UserProvider] ⚠️  No saved language in SharedPreferences, keeping CloudDB value: ${_cloudDbUser!.detectionLanguage}',
        );
      }

      // Sync allow discoverable
      if (allowDiscoverable != null) {
        _cloudDbUser!.allowDiscoverable = allowDiscoverable;
        debugPrint(
          '[UserProvider] ✅ Loaded allow_discoverable: $allowDiscoverable',
        );
      }

      // Sync allow emergency alert
      if (allowEmergencyAlert != null) {
        _cloudDbUser!.allowEmergencyAlert = allowEmergencyAlert;
        debugPrint(
          '[UserProvider] ✅ Loaded allow_emergency_alert: $allowEmergencyAlert',
        );
      }

      debugPrint('[UserProvider] 💾 All preferences loaded from local storage');
      debugPrint(
        '[UserProvider] 🎯 Final language value: ${_cloudDbUser!.detectionLanguage}',
      );
    } catch (e) {
      debugPrint('[UserProvider] ❌ Error syncing preferences: $e');
    }
  }

  // Refresh user data (re-fetch AGCUser and CloudDB data)
  Future<void> refreshUser() async {
    debugPrint('[UserProvider] 🔄 Refreshing user data...');
    await _initUser();
    debugPrint('[UserProvider] ✅ User data refreshed');
    debugPrint('[UserProvider]    AGC User: ${_agcUser?.uid}');
    debugPrint('[UserProvider]    Provider Info: ${_agcUser?.providerInfo}');
    debugPrint('[UserProvider]    Photo URL: ${_agcUser?.photoUrl}');
    debugPrint(
      '[UserProvider]    CloudDB Profile URL: ${_cloudDbUser?.profileURL}',
    );
  }

  // Notify listeners when local preferences change
  // Used when profile page updates preferences locally
  void notifyPreferencesChanged() {
    notifyListeners();
  }

  // Update user after sign in
  Future<void> setUser(AGCUser user) async {
    _agcUser = user;
    _isLoading = true;
    notifyListeners();

    await _loadCloudDbUser();

    _isLoading = false;
    notifyListeners();
  }

  // Update CloudDB user data
  Future<void> updateCloudDbUser(Users user) async {
    try {
      // Ensure zone is open - if not, just update local state
      try {
        await _userRepository.openZone();
      } catch (e) {
        debugPrint('⚠️  CloudDB zone not available, updating local state only');
        _cloudDbUser = user;
        notifyListeners();
        return;
      }

      final success = await _userRepository.upsertUser(user);

      if (success) {
        _cloudDbUser = user;
        notifyListeners();
        debugPrint('✅ CloudDB user updated successfully');
      } else {
        debugPrint('⚠️  CloudDB update failed, updating local state only');
        _cloudDbUser = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating user: $e');
      // Don't rethrow - just log the error and update local state
      _cloudDbUser = user;
      notifyListeners();
    }
  }

  // Delete user
  Future<void> deleteUser(Users user) async {
    try {
      await _userRepository.openZone();
      await _userRepository.deleteUser(user);
      debugPrint('✅ User deleted from CloudDB');
    } catch (e) {
      debugPrint('❌ Error deleting user from CloudDB: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _agcUser = null;
    _cloudDbUser = null;
    await _userRepository.closeZone();
    notifyListeners();
  }

  @override
  void dispose() {
    _userRepository.closeZone();
    super.dispose();
  }
}
