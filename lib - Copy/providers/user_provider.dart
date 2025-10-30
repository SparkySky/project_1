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

      _agcUser = await _authService.currentUser;

      if (_agcUser != null) {
        await _loadCloudDbUser();
      } else {
      }
    } finally {
      _isLoading = false;
      notifyListeners();



    }
  }

  // Load CloudDB user data
  Future<void> _loadCloudDbUser() async {
    if (_agcUser == null) {
      return;
    }

    try {

      await _userRepository.openZone();

      _cloudDbUser = await _userRepository.getUserById(_agcUser!.uid!);

      if (_cloudDbUser != null) {
        // Immediately sync language preference from SharedPreferences
        // SharedPreferences is the single source of truth for language
        await _syncLanguageFromPreferences();

      } else {
      }
      notifyListeners();
    } catch (e) {


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
      // Load allow discoverable preference
      final allowDiscoverable = prefs.getBool('allow_discoverable');

      // Load allow emergency alert preference
      final allowEmergencyAlert = prefs.getBool('allow_emergency_alert');

      // Sync language
      if (savedLanguage != null &&
          savedLanguage != _cloudDbUser!.detectionLanguage) {
        _cloudDbUser!.detectionLanguage = savedLanguage;
      } else if (savedLanguage != null) {

      } else {
      }

      // Sync allow discoverable
      if (allowDiscoverable != null) {
        _cloudDbUser!.allowDiscoverable = allowDiscoverable;
      }

      // Sync allow emergency alert
      if (allowEmergencyAlert != null) {
        _cloudDbUser!.allowEmergencyAlert = allowEmergencyAlert;
      }
    } catch (e) {

    }
  }

  // Refresh user data (re-fetch AGCUser and CloudDB data)
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

    // If CloudDB user is still null after loading, try again with a short delay
    // This handles race conditions where CloudDB sync hasn't completed yet
    if (_cloudDbUser == null) {
      await Future.delayed(const Duration(milliseconds: 1500));
      await _loadCloudDbUser();

      if (_cloudDbUser != null) {

      } else {
      }
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

        _cloudDbUser = user;
        notifyListeners();
        return;
      }

      final success = await _userRepository.upsertUser(user);

      if (success) {
        _cloudDbUser = user;
        notifyListeners();

      } else {

        _cloudDbUser = user;
        notifyListeners();
      }
    } catch (e) {

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

    } catch (e) {

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
      _cloudDbUser?.pushToken = token;
      await updateCloudDbUser(_cloudDbUser!);


      notifyListeners();
    } catch (e) {

    }
  }
}
