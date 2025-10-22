import 'package:flutter/material.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import '../models/users.dart';
import '../repository/user_repository.dart';
import '../signup_login/auth_service.dart';

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
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load CloudDB user data
  Future<void> _loadCloudDbUser() async {
    if (_agcUser == null) return;

    try {
      await _userRepository.openZone();
      _cloudDbUser = await _userRepository.getUserById(_agcUser!.uid!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading CloudDB user: $e');
    }
  }

  // Refresh user data
  Future<void> refreshUser() async {
    await _initUser();
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
      await _userRepository.openZone();
      final success = await _userRepository.upsertUser(user);
      
      if (success) {
        _cloudDbUser = user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating user: $e');
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