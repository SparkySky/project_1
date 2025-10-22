import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../signup_login/auth_page.dart';
import '../../app_theme.dart';
import '../../constants/provider_types.dart';
import '../../util/debug_state.dart';
import '../providers/user_provider.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DebugState _debugState = DebugState();
  bool _allowDebugOverlay = false;

  @override
  void initState() {
    super.initState();
  }

  String _getProviderName(int providerId) {
    return AuthProviderName.name(providerId);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final agcUser = userProvider.agcUser;
    final cloudDbUser = userProvider.cloudDbUser;
    final isLoading = userProvider.isLoading;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (agcUser == null) {
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
            // Profile header
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child:
                        agcUser.photoUrl != null && agcUser.photoUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              agcUser.photoUrl!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppTheme.primaryOrange,
                                  ),
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
                    cloudDbUser?.username ?? agcUser.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  _buildInfoCard(
                    icon: Icons.fingerprint,
                    title: 'User ID',
                    value: agcUser.uid!,
                  ),
                  _buildInfoCard(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: agcUser.email?.isNotEmpty == true
                        ? agcUser.email!
                        : 'unset',
                    valueColor: agcUser.email?.isNotEmpty == true
                        ? Colors.black87
                        : Colors.grey,
                  ),
                  if (agcUser.phone?.isNotEmpty == true)
                    _buildInfoCard(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: agcUser.phone!,
                    ),
                  _buildInfoCard(
                    icon: Icons.login,
                    title: 'Sign-in Method',
                    value: _getProviderName(agcUser.providerId!.index),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Preferences',
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),

                  // Preferences
                  _buildToggleCard(
                    icon: Icons.visibility_outlined,
                    title: 'Allow Discoverable',
                    value: cloudDbUser?.allowDiscoverable ?? true,
                    onChanged: (value) {
                      if (cloudDbUser != null) {
                        cloudDbUser.allowDiscoverable = value;
                        userProvider.updateCloudDbUser(cloudDbUser);
                      }
                    },
                  ),
                  _buildToggleCard(
                    icon: Icons.warning_amber_outlined,
                    title: 'Allow Emergency Alerts',
                    value: cloudDbUser?.allowEmergencyAlert ?? true,
                    onChanged: (value) {
                      if (cloudDbUser != null) {
                        cloudDbUser.allowEmergencyAlert = value;
                        userProvider.updateCloudDbUser(cloudDbUser);
                      }
                    },
                  ),
                  _buildToggleCard(
                    icon: Icons.bug_report_outlined,
                    title: 'Allow Debug Overlay',
                    value: _allowDebugOverlay,
                    onChanged: (value) {
                      setState(() => _allowDebugOverlay = value);
                      _debugState.setShowDebugOverlay(value);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await userProvider.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AuthScreen(isLogin: true),
                            ),
                            (route) => false,
                          );
                        }
                      },
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                child: Icon(icon, color: AppTheme.primaryOrange, size: 24),
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
            activeColor: AppTheme.primaryOrange,
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
} // End of _ProfilePageState class
