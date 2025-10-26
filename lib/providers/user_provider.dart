import 'package:flutter/material.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import '../bg_services/firebase_service.dart';
import '../models/users.dart';
import '../repository/user_repository.dart';
import '../signup_login/auth_service.dart';
import '../services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserRepository _userRepository = UserRepository();
  final firebase = FirebaseService();

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
  String? _pendingPushToken;

  UserProvider() {
    _initUser();
  }

  Future<void> _initUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      _agcUser = await _authService.currentUser;

      if (_agcUser != null) {
        await _loadCloudDbUser();
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCloudDbUser() async {
    if (_agcUser == null) return;

    try {
      await _userRepository.openZone();
      debugPrint('Loading CloudDB user: ${_agcUser!.uid}');
      _cloudDbUser = await _userRepository.getUserById(_agcUser!.uid!);

      // Sync language preference from SharedPreferences
      await _syncLanguageFromPreferences();

      // Process pending push token if exists
      if (_pendingPushToken != null) {
        debugPrint('📬 Processing pending push token');
        _cloudDbUser!.pushToken = _pendingPushToken;
        _pendingPushToken = null; // Clear the pending token
        debugPrint('✅ Pending push token applied: ${_cloudDbUser!.pushToken}');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading CloudDB user: $e');
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

  // Refresh user data
  Future<void> refreshUser() async {
    await _initUser();
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

    // Update push token after login
    try {
      final pushService = PushNotificationService();
      await pushService.updateTokenAfterLogin();
    } catch (e) {
      debugPrint('⚠️  Could not update push token after login: $e');
    }

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

  Future<void> updateUserPushToken(String token) async {
    try {
      final uid = _agcUser?.uid;

      if (uid == null) {
        debugPrint('⚠️  Cannot update push token: User not authenticated');
        return;
      }

      // If CloudDB user not loaded yet, store token for later
      if (_cloudDbUser == null) {
        debugPrint('⚠️  _cloudDbUser is null, queuing push token for later');
        _pendingPushToken = token;

        // Still update Firebase immediately
        await firebase.putData('users/$uid', {
          'pushToken': token,
          'lastUpdateTime': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Push token updated in Firebase (CloudDB pending)');
        return;
      }

      // Update local state
      _cloudDbUser!.pushToken = token;
      debugPrint('✅ Local state updated: ${_cloudDbUser!.pushToken}');

      // Update Firebase
      await firebase.putData('users/$uid', {
        'pushToken': token,
        'lastUpdateTime': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Push token updated: ${_cloudDbUser!.pushToken}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error updating push token: $e');
    }
  }
}
