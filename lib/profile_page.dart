import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import '../signup_login/auth_service.dart';
import '../signup_login/auth_page.dart';
import '../app_theme.dart';
import '../constants/provider_types.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  AGCUser? _currentUser;
  bool _isLoading = true;
  bool _allowDiscoverable = true;
  bool _allowEmergencyAlert = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
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

  String _getProviderName(int providerId) {
    debugPrint("provider ID = $providerId");
    return AuthProviderName.name(providerId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
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
            // Header Section with Avatar
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
                  // Avatar
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
                  // Display Name
                  Text(
                    _currentUser!.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email or Phone
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

                  // User ID Card
                  _buildInfoCard(
                    icon: Icons.fingerprint,
                    title: 'User ID',
                    value: _currentUser!.uid!,
                  ),

                  // Email Card
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

                  // Phone Card
                  if (_currentUser!.phone != null &&
                      _currentUser!.phone!.isNotEmpty)
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: _currentUser!.phone!,
                    ),

                  // Provider Card
                  _buildInfoCard(
                    icon: Icons.login,
                    title: 'Sign-in Method',
                    value: _getProviderName(_currentUser!.providerId!.index),
                  ),

                  // Email Verified Status
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

                  // Discoverability and Alerts Toggles
                  const SizedBox(height: 24),
                  const Text(
                    'Preferences',
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // Allow Discoverable toggle
                  Container(
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
                              child: const Icon(
                                Icons.visibility_outlined,
                                color: AppTheme.primaryOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Allow Discoverable',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          activeColor: AppTheme.primaryOrange,
                          value: _allowDiscoverable,
                          onChanged: (value) {
                            setState(() {
                              _allowDiscoverable = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Allow Emergency Alert toggle
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
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
                              child: const Icon(
                                Icons.warning_amber_outlined,
                                color: AppTheme.primaryOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Allow Emergency Alerts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          activeColor: AppTheme.primaryOrange,
                          value: _allowEmergencyAlert,
                          onChanged: (value) {
                            setState(() {
                              _allowEmergencyAlert = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
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
    // Show confirmation dialog
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
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await _authService.signOut();

      if (!mounted) return;

      // Close loading indicator
      Navigator.of(context).pop();

      // Navigate to login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isLogin: true),
        ),
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      if (!mounted) return;

      // Close loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
