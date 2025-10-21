import 'package:flutter/material.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Make sure this is imported
import '../signup_login/auth_service.dart';
import '../signup_login/auth_page.dart';
import '../app_theme.dart';
import '../constants/provider_types.dart';
import '../util/debug_state.dart'; // Make sure this is imported

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  AGCUser? _currentUser;
  bool _isLoading = true;

  final DebugState _debugState = DebugState();
  bool _allowDiscoverable = true;
  bool _allowEmergencyAlert = false;
  bool _allowDebugOverlay = false;

  static const String _discoverableKey = 'allowDiscoverable';
  static const String _emergencyKey = 'allowEmergencyAlert';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadPreferences();
  }

  Future<void> _loadUserInfo() async {
    // ... (Keep the existing _loadUserInfo method)
    try {
      final user = await _authService.currentUser;
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    // ... (Keep the existing _loadPreferences method)
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _allowDiscoverable = prefs.getBool(_discoverableKey) ?? true;
      _allowEmergencyAlert = prefs.getBool(_emergencyKey) ?? false;
      _allowDebugOverlay = _debugState.showDebugOverlay;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    // ... (Keep the existing _savePreference method)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  String _getProviderName(int providerId) {
    // ... (Keep the existing _getProviderName method)
    debugPrint("provider ID = $providerId");
    return AuthProviderName.name(providerId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      // ... (Keep the existing placeholder widget for logged-out state)
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No user logged in'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(isLogin: true),
                    ),
                  );
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... (Keep the existing Header Section)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child:
                    _currentUser!.photoUrl != null &&
                        _currentUser!.photoUrl!.isNotEmpty
                        ? ClipOval(
                      child: Image.network(
                        _currentUser!.photoUrl!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 50,
                            color: AppTheme.primaryOrange,
                          );
                        },
                      ),
                    )
                        : const Icon(
                      Icons.person,
                      size: 50,
                      color: AppTheme.primaryOrange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUser!.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentUser!.email ??
                        _currentUser!.phone ??
                        'No contact info',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User Information Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Information',
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),

                  // ... (Keep the existing _buildInfoCard section)
                  _buildInfoCard(
                    icon: Icons.fingerprint,
                    title: 'User ID',
                    value: _currentUser!.uid!,
                  ),
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value:
                    (_currentUser!.email != null &&
                        _currentUser!.email!.isNotEmpty)
                        ? _currentUser!.email!
                        : 'unset',
                    valueColor:
                    (_currentUser!.email != null &&
                        _currentUser!.email!.isNotEmpty)
                        ? Colors.black87
                        : Colors.grey,
                  ),
                  if (_currentUser!.phone != null &&
                      _currentUser!.phone!.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: _currentUser!.phone!,
                    ),
                  _buildInfoCard(
                    icon: Icons.login,
                    title: 'Sign-in Method',
                    value: _getProviderName(_currentUser!.providerId!.index),
                  ),
                  if (_currentUser!.email != null &&
                      _currentUser!.email!.isNotEmpty)
                    _buildInfoCard(
                      icon: _currentUser!.emailVerified!
                          ? Icons.verified_user
                          : Icons.warning_amber_rounded,
                      title: 'Email Verification',
                      value: _currentUser!.emailVerified!
                          ? 'Verified'
                          : 'Not Verified',
                      valueColor: _currentUser!.emailVerified!
                          ? Colors.green
                          : Colors.orange,
                    ),

                  const SizedBox(height: 32),

                  // Preferences Section
                  const SizedBox(height: 24),
                  const Text(
                    'Preferences',
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // Allow Discoverable toggle
                  _buildToggleCard(
                    icon: Icons.visibility_outlined,
                    title: 'Allow Discoverable',
                    value: _allowDiscoverable,
                    onChanged: (value) {
                      setState(() => _allowDiscoverable = value);
                      _savePreference(_discoverableKey, value);
                    },
                  ),

                  // Allow Emergency Alert toggle
                  _buildToggleCard(
                    icon: Icons.warning_amber_outlined,
                    title: 'Allow Emergency Alerts',
                    value: _allowEmergencyAlert,
                    onChanged: (value) {
                      setState(() => _allowEmergencyAlert = value);
                      _savePreference(_emergencyKey, value);
                    },
                  ),

                  // --- HERE IS THE DEBUG OVERLAY TOGGLE ---
                  _buildToggleCard(
                    icon: Icons.bug_report_outlined,
                    title: 'Allow Debug Overlay',
                    value: _allowDebugOverlay,
                    onChanged: (value) {
                      setState(() => _allowDebugOverlay = value);
                      _debugState.setShowDebugOverlay(value);
                    },
                  ),
                  // ----------------------------------------

                  const SizedBox(height: 12),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HERE IS THE DEFINITION of _buildToggleCard ---
  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Switch(
            activeThumbColor: AppTheme.primaryOrange,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
  // ----------------------------------------------------

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    // ... (Keep the existing _buildInfoCard method)
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    // ... (Keep the existing _handleLogout method)
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _authService.signOut();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading indicator
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isLogin: true),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} // End of _ProfilePageState class

