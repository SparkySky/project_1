import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../util/snackbar_helper.dart';
import '../app_theme.dart';
import '../models/users.dart';
import '../repository/incident_repository.dart';
import '../repository/media_repository.dart';
import '../signup_login/auth_page.dart';
import '../signup_login/auth_service.dart';
import '../signup_login/terms_conditions_page.dart';
import '../signup_login/privacy_policy_page.dart';
import '../tutorial/homepage_tutorial.dart';
import '../tutorial/lodge_tutorial.dart';
import '../tutorial/profile_tutorial.dart';
import '../tutorial/chatbot_tutorial.dart';
import '../../constants/provider_types.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/info_card.dart';
import '../widgets/common/toggle_card.dart';
import '../widgets/common/custom_text_field.dart';
import '../widgets/common/action_card.dart';
import '../debug_overlay/debug_state.dart';
import '../providers/safety_service_provider.dart';
import '../providers/user_provider.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onNavigateToHomeWithTutorial;

  const ProfilePage({super.key, this.onNavigateToHomeWithTutorial});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DebugState _debugState = DebugState();
  bool _allowDebugOverlay = false;
  bool _hasLoadedLanguagePreference = false;

  // Local preferences (loaded from SharedPreferences)
  String _selectedLanguage = 'en';
  bool _allowDiscoverable = false; // Off by default
  bool _allowEmergencyAlert = false; // Off by default (requires discoverable)

  // Developer settings
  bool _isApiKeySet = false;

  UserProvider? _userProvider;
  AGCUser? _agcUser;
  Users? _cloudDbUser;

  // User information fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();

  // Track if email has been set before (can only be set once)
  bool _emailHasBeenSet = false;

  // Track if controllers have been initialized
  bool _controllersInitialized = false;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Scroll controller for profile page (for tutorial scrolling)
  final ScrollController _scrollController = ScrollController();

  // Secure storage with AES-256-GCM encryption and hardware-backed keys
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _loadDebugOverlayState();
    _loadLocalPreferences();
    _loadDeveloperSettings();
    _debugState.addListener(_onDebugStateChanged);

    // Show tutorial on first app use (continuous flow from lodge)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        // Check if this is first app use - lodge completed but profile not completed
        final prefs = await SharedPreferences.getInstance();
        final lodgeCompleted =
            prefs.getBool('lodge_tutorial_completed') ?? false;
        final profileCompleted =
            prefs.getBool('profile_tutorial_completed') ?? false;

        // Show if lodge completed (user came from lodge tutorial) and profile not completed
        if (lodgeCompleted && !profileCompleted) {
          ProfileTutorialManager.showTutorial(
            context,
            pageScrollController: _scrollController,
            onCustomKeywordsTap: () {
              print('[ProfilePage] onCustomKeywordsTap callback triggered');
              _showCombinedCustomKeywordsDialog();
            },
          );
        }
      }
    });
  }

  /// Load developer settings (API key status)
  Future<void> _loadDeveloperSettings() async {
    // Try to read from secure storage first
    String? apiKey = await _secureStorage.read(key: 'gemini_api_key');

    // Migration: If not in secure storage, check SharedPreferences (old storage)
    if (apiKey == null) {
      final prefs = await SharedPreferences.getInstance();
      final oldApiKey = prefs.getString('gemini_api_key');

      if (oldApiKey != null && oldApiKey.isNotEmpty) {
        // Migrate to secure storage
        await _secureStorage.write(key: 'gemini_api_key', value: oldApiKey);
        // Remove from old storage
        await prefs.remove('gemini_api_key');
        apiKey = oldApiKey;
        debugPrint('[ProfilePage] 🔄 Migrated API key to secure storage');
      }
    }

    if (!mounted) return;
    setState(() {
      _isApiKeySet = apiKey != null && apiKey.isNotEmpty;
    });
  }

  /// Load all preferences from SharedPreferences (local storage only)
  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if widget is still mounted before calling setState
    if (!mounted) return;

    setState(() {
      _selectedLanguage = prefs.getString('voice_detection_language') ?? 'en';
      _allowDiscoverable =
          prefs.getBool('allow_discoverable') ?? false; // Off by default
      _allowEmergencyAlert =
          prefs.getBool('allow_emergency_alert') ?? false; // Off by default
    });

    debugPrint('[ProfilePage] ✅ Loaded local preferences:');
    debugPrint('[ProfilePage]    Language: $_selectedLanguage');
    debugPrint('[ProfilePage]    Allow Discoverable: $_allowDiscoverable');
    debugPrint('[ProfilePage]    Allow Emergency Alert: $_allowEmergencyAlert');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load language preference when dependencies change (i.e., when user data is loaded)
    if (!_hasLoadedLanguagePreference) {
      _loadLanguagePreference();
    }
  }

  void _onDebugStateChanged() {
    if (mounted) {
      setState(() {
        _allowDebugOverlay = _debugState.showDebugOverlay;
      });
    }
  }

  Future<void> _loadDebugOverlayState() async {
    await _debugState.loadState();
    if (mounted) {
      setState(() {
        _allowDebugOverlay = _debugState.showDebugOverlay;
      });
    }
  }

  /// Load preferences (no longer needed since UserProvider handles this)
  /// Kept for backwards compatibility - just sets the flag
  Future<void> _loadLanguagePreference() async {
    // UserProvider now handles loading preferences from SharedPreferences
    // This just sets the flag to prevent repeated calls
    if (!_hasLoadedLanguagePreference) {
      _hasLoadedLanguagePreference = true;
    }
  }

  /// Calculate minutes ago from a given DateTime (always display in minutes, never convert to hours)
  int _getMinutesAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    return difference.inMinutes;
  }

  @override
  void dispose() {
    _debugState.removeListener(_onDebugStateChanged);
    _scrollController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _postcodeController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceDialog() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Profile Picture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.camera_alt, color: AppTheme.primaryOrange),
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });

        final bytes = await pickedFile.readAsBytes();
        final base64Content = base64Encode(bytes);

        final fileName = pickedFile.path.split('/').last;

        // Load environment variable
        final awsApiUrl = dotenv.env['AWS_API_URL'];
        if (awsApiUrl == null || awsApiUrl.isEmpty) {
          throw Exception('Missing environment variable: AWS_API_URL');
        }

        // Upload to AWS S3
        final response = await http.post(
          Uri.parse('$awsApiUrl/media'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'file_name': fileName,
            'file_content': base64Content,
          }),
        );

        if (response.statusCode != 200) {
          Snackbar.error(
            'Failed to upload media $fileName to AWS S3: ${response.body}',
          );
          return;
        }

        // Parse response to get file URL
        final responseData = jsonDecode(response.body);
        final mediaURL = responseData['file_url'];

        if (mediaURL == null || mediaURL.isEmpty) {
          Snackbar.error(
            'Failed to get media URL from AWS S3 for file $fileName',
          );
          return;
        }

        // Optionally handle success
        print('Uploaded successfully: $mediaURL');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile image uploaded'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          debugPrint('Media URL: $mediaURL');
          _cloudDbUser!.profileURL = mediaURL;
          _userProvider!.updateCloudDbUser(_cloudDbUser!);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveUserInfo(
    String phone,
    String district,
    String postcode,
    String state,
    String email,
  ) async {
    if (mounted) {
      setState(() {
        _cloudDbUser?.phoneNo = phone;
        _cloudDbUser?.district = district;
        _cloudDbUser?.postcode = postcode;
        _cloudDbUser?.state = state;

        // Only update email if it hasn't been set before
        if (!_emailHasBeenSet && email.isNotEmpty) {
          _cloudDbUser?.email = email;
          _emailHasBeenSet = true;
        }

        _userProvider!.updateCloudDbUser(_cloudDbUser!);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User information saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  String _getProviderName(int providerId) {
    debugPrint("provider ID = $providerId");
    return AuthProviderName.name(providerId);
  }

  // Check if Huawei ID is linked to the account
  bool _isHuaweiIdLinked() {
    if (_agcUser?.providerInfo == null) return false;

    // Check if any provider is Huawei ID (provider index 10)
    for (final provider in _agcUser!.providerInfo!) {
      final providerId = int.tryParse(provider['providerId'] ?? '0') ?? 0;
      if (providerId == 10) {
        // ✅ Fixed: Compare as integer, not string
        return true;
      }
    }
    return false;
  }

  // Build card showing all linked providers
  Widget _buildLinkedProvidersCard() {
    final providers = _agcUser!.providerInfo!;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Sign-in Methods',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You can sign in with any of these',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: providers.map((provider) {
              final providerId =
                  int.tryParse(provider['providerId'] ?? '0') ?? 0;
              final providerName = _getProviderName(providerId);
              final providerIcon = _getProviderIcon(providerId);
              final providerColor = _getProviderColor(providerId);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: providerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: providerColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(providerIcon, size: 16, color: providerColor),
                    const SizedBox(width: 6),
                    Text(
                      providerName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: providerColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Get icon for provider
  IconData _getProviderIcon(int providerId) {
    switch (providerId) {
      case 10: // Huawei ID
        return Icons.account_circle;
      case 12: // Email
        return Icons.email;
      case 11: // Phone
        return Icons.phone;
      case 0: // Anonymous
        return Icons.person_outline;
      default:
        return Icons.login;
    }
  }

  // Get color for provider
  Color _getProviderColor(int providerId) {
    switch (providerId) {
      case 10: // Huawei ID
        return Colors.red;
      case 12: // Email
        return AppTheme.primaryOrange;
      case 11: // Phone
        return Colors.green;
      case 0: // Anonymous
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  // Build action card (for Terms, Privacy, etc.)

  // Build delete account card with warning
  Widget _buildDeleteAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Permanently delete your account',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.2), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Warning',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This action cannot be undone. Your profile and user-uploaded media will be deleted. Incidents will be disabled (not deleted) and trigger evidence will be preserved.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[900],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleDeleteAccount,
              icon: const Icon(Icons.delete_forever, size: 20),
              label: const Text(
                'Delete My Account',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Handle delete account
  Future<void> _handleDeleteAccount() async {
    // First confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Account?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('This will:', style: TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.delete_forever, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('• DELETE: Profile information')),
              ],
            ),
            Row(
              children: [
                Icon(Icons.delete_forever, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('• DELETE: User-uploaded media')),
              ],
            ),
            Row(
              children: [
                Icon(Icons.block, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('• DISABLE: All incident reports')),
              ],
            ),
            Row(
              children: [
                Icon(Icons.save, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('• PRESERVE: Trigger evidence')),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Second confirmation - type to confirm
    final textController = TextEditingController();
    final confirmed2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To confirm deletion, please type:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'DELETE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Type DELETE to confirm',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().toUpperCase() == 'DELETE') {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please type DELETE to confirm'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed2 != true) return;

    // Perform deletion
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final uid = _agcUser?.uid;
      if (uid != null) {
        // Import repositories
        final incidentRepo = IncidentRepository();
        final mediaRepo = MediaRepository();

        try {
          // Open zones
          await incidentRepo.openZone();
          await mediaRepo.openZone();

          // Get all user incidents
          final userIncidents = await incidentRepo.getIncidentsByUserId(uid);

          // Delete media from non-AI-generated incidents only
          // Keep evidence from trigger events (AI-generated)
          for (var incident in userIncidents) {
            if (incident.mediaID != null && incident.mediaID!.isNotEmpty) {
              if (!incident.isAIGenerated) {
                // Not AI-generated = user uploaded = can be deleted
                await mediaRepo.deleteMediaByMediaId(incident.mediaID!);
                debugPrint('✅ Deleted media for incident ${incident.iid}');
              } else {
                // AI-generated = trigger evidence = keep it
                debugPrint(
                  '⚠️ Preserved evidence media for incident ${incident.iid}',
                );
              }
            }
          }

          // Disable all incidents (don't delete them)
          await incidentRepo.disableIncidentsByUserId(uid);

          // Close zones
          await incidentRepo.closeZone();
          await mediaRepo.closeZone();
        } catch (e) {
          debugPrint('❌ Error during incident/media cleanup: $e');
          // Continue with user deletion even if this fails
        }
      }

      // Delete user from CloudDB
      if (_cloudDbUser != null) {
        await _userProvider?.deleteUser(_cloudDbUser!);
      }

      // Delete AGConnect Auth user (commented out - implement if needed)
      // await _agcUser?.delete();

      // Sign out
      await _userProvider?.signOut();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      // Navigate to auth screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isLogin: true),
        ),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account deleted successfully. Incidents preserved with disabled status.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Build card prompting user to link Huawei ID
  Widget _buildLinkHuaweiIdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryOrange.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryOrange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.link,
                  color: AppTheme.primaryOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link Huawei ID',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get your profile picture & easier sign-in',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleLinkHuaweiId,
              icon: const Icon(Icons.account_circle, size: 20),
              label: const Text(
                'Link Huawei Account',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Huawei ID already linked card
  Widget _buildHuaweiIdLinkedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Huawei ID Linked',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You can sign in with your Huawei ID',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Handle linking Huawei ID
  Future<void> _handleLinkHuaweiId() async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Import auth service
      final authService = AuthService();
      await authService.linkHuaweiID(context);

      // Refresh user data to get updated AGCUser with providerInfo
      await _userProvider?.refreshUser();

      // Reset controllers to reload data (including profile picture)
      _controllersInitialized = false;

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Force rebuild to show updated Huawei ID linked status
      if (!mounted) return;
      setState(() {});

      debugPrint('[ProfilePage] ✅ Huawei ID linked and data refreshed');
      debugPrint('[ProfilePage]    Provider Info: ${_agcUser?.providerInfo}');
      debugPrint('[ProfilePage]    Is Huawei Linked: ${_isHuaweiIdLinked()}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Huawei ID linked successfully! 🎉')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Check if error is "already linked" - this means Huawei ID is linked
      final errorMessage = e.toString();
      if (errorMessage.contains('Provider user hava been linked') ||
          errorMessage.contains('already linked')) {
        // This is not an error - Huawei ID is already linked!
        // Refresh user data to show linked status
        await _userProvider?.refreshUser();
        _controllersInitialized = false;

        if (!mounted) return;
        setState(() {});

        debugPrint(
          '[ProfilePage] ℹ️ Huawei ID already linked, showing linked status',
        );

        // Show info message instead of error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your Huawei ID is already linked to this account',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      // Show actual error for other cases
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to link Huawei ID: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Capture previous UID before updating from provider
    final previousUserId = _cloudDbUser?.uid;

    _userProvider = Provider.of<UserProvider>(context);
    final newAgcUser = _userProvider!.agcUser;
    final newCloudDbUser = _userProvider!.cloudDbUser;
    final isLoading = _userProvider!.isLoading;

    // Detect if user data changed (user switch or initial load after app restart)
    final currentUserId = newCloudDbUser?.uid;
    final userChanged = previousUserId != currentUserId;

    // Update instance variables
    _agcUser = newAgcUser;
    _cloudDbUser = newCloudDbUser;

    // Reset controllers if user changed or if data just loaded for first time
    if (userChanged && currentUserId != null) {
      _controllersInitialized = false;
      debugPrint('[ProfilePage] 🔄 User data changed, resetting controllers');
      debugPrint('[ProfilePage]    Previous UID: $previousUserId');
      debugPrint('[ProfilePage]    Current UID: $currentUserId');
    }

    // Only populate controllers once when data is first loaded OR when user changes
    // This prevents clearing user input while they're typing
    if (!_controllersInitialized && _cloudDbUser != null) {
      // Email: prefer AGCUser email, fallback to CloudDB email
      _emailController.text = _agcUser?.email ?? _cloudDbUser?.email ?? '';
      _phoneController.text = _cloudDbUser?.phoneNo ?? '';
      _districtController.text = _cloudDbUser?.district ?? '';
      _postcodeController.text = _cloudDbUser?.postcode ?? '';
      _stateController.text = _cloudDbUser?.state ?? '';
      _controllersInitialized = true;

      debugPrint('[ProfilePage] ✅ Controllers initialized with user data');
      debugPrint('[ProfilePage]    User ID: ${_cloudDbUser?.uid}');
      debugPrint('[ProfilePage]    Email: ${_emailController.text}');
      debugPrint('[ProfilePage]    Phone: ${_phoneController.text}');
      debugPrint('[ProfilePage]    District: ${_districtController.text}');
      debugPrint('[ProfilePage]    Profile URL: ${_cloudDbUser?.profileURL}');
    }

    // Check if email has been set
    _emailHasBeenSet =
        _cloudDbUser?.email != null && _cloudDbUser!.email!.isNotEmpty;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_agcUser == null) {
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
      backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 24),
              child: Column(
                children: [
                  // Profile Avatar with Edit Button
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: _profileImage != null
                            // default avatar
                            ? ClipOval(
                                child: Image.file(
                                  _profileImage!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              )
                            // user avatar
                            : (_cloudDbUser != null &&
                                      _cloudDbUser!.profileURL != null &&
                                      _cloudDbUser!.profileURL!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        _cloudDbUser!.profileURL!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Icon(
                                                Icons.person,
                                                size: 50,
                                                color: AppTheme.primaryOrange,
                                              );
                                            },
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 50,
                                      color: AppTheme.primaryOrange,
                                    )),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    _cloudDbUser?.username ?? _agcUser?.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Email and Phone - show only if at least one has data
                  if (((_agcUser?.email?.isNotEmpty ?? false) ||
                          (_cloudDbUser?.email?.isNotEmpty ?? false)) ||
                      (_cloudDbUser?.phoneNo?.isNotEmpty ?? false))
                    Column(
                      children: [
                        // Email (from AGCUser or CloudDB)
                        if ((_agcUser?.email?.isNotEmpty ?? false) ||
                            (_cloudDbUser?.email?.isNotEmpty ?? false))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 16,
                                  color: AppTheme.primaryOrange,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _agcUser?.email ?? _cloudDbUser?.email ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primaryOrange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Phone
                        if (_cloudDbUser?.phoneNo?.isNotEmpty ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 16,
                                  color: AppTheme.primaryOrange,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _cloudDbUser!.phoneNo!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primaryOrange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'No contact info',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Information Section
                  SectionHeader(
                    title: 'Account Information',
                    icon: Icons.info_outline,
                  ),
                  const SizedBox(height: 16),
                  InfoCard(
                    icon: Icons.fingerprint,
                    title: 'User ID',
                    value: _agcUser!.uid!,
                  ),
                  InfoCard(
                    icon: Icons.login,
                    title: 'Primary Sign-in Method',
                    value: _getProviderName(_agcUser!.providerId!.index),
                  ),

                  // Display all linked providers
                  if (_agcUser!.providerInfo != null &&
                      _agcUser!.providerInfo!.length > 1)
                    _buildLinkedProvidersCard(),

                  // Link Huawei ID button OR Linked status (only for email users)
                  if (_agcUser!.providerId?.index == 12) // Email provider
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      child: _isHuaweiIdLinked()
                          ? _buildHuaweiIdLinkedCard() // ✅ Show linked status
                          : _buildLinkHuaweiIdCard(), // Show link button
                    ),
                  if (_agcUser!.email != null && _agcUser!.email!.isNotEmpty)
                    InfoCard(
                      icon: _agcUser!.emailVerified!
                          ? Icons.verified_user
                          : Icons.warning_amber_rounded,
                      title: 'Email Verification',
                      value: _agcUser!.emailVerified!
                          ? 'Verified'
                          : 'Not Verified',
                      valueColor: _agcUser!.emailVerified!
                          ? Colors.green
                          : Colors.orange,
                    ),

                  const SizedBox(height: 32),

                  // User Information Section
                  SectionHeader(
                    title: 'User Information',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),

                  _buildUserInfoForm(),

                  const SizedBox(height: 45),

                  // Preferences Section
                  SectionHeader(title: 'Preferences', icon: Icons.tune),
                  const SizedBox(height: 16),

                  // Combined Voice Detection Language Card with toggles
                  _buildLanguageSelectionCard(),

                  const SizedBox(height: 32),

                  // Developer Section
                  SectionHeader(title: 'Developer', icon: Icons.code),
                  const SizedBox(height: 16),

                  // Debug Overlay Toggle
                  ToggleCard(
                    icon: Icons.bug_report_outlined,
                    title: 'Debug Overlay',
                    subtitle: 'Show developer diagnostics',
                    value: _allowDebugOverlay,
                    onChanged: (value) {
                      setState(() => _allowDebugOverlay = value);
                      _debugState.setShowDebugOverlay(value);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Gemini API Key Card
                  _buildApiKeyCard(),

                  const SizedBox(height: 12),

                  // TEMPORARY: Emergency Clear Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'TEMPORARY: Emergency API Key Reset',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If you cannot access your API key due to authentication issues, use this button to clear it. This button will be removed in future updates.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text('Clear API Key?'),
                                    ],
                                  ),
                                  content: const Text(
                                    'This will delete your custom API key from secure storage. You will need to set it up again.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Clear Key'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  await _secureStorage.delete(
                                    key: 'gemini_api_key',
                                  );
                                  // Also check old storage
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.remove('gemini_api_key');

                                  setState(() {
                                    _isApiKeySet = false;
                                  });

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '✅ API key cleared successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                  debugPrint(
                                    '[ProfilePage] 🗑️ Emergency cleared API key',
                                  );
                                } catch (e) {
                                  debugPrint(
                                    '[ProfilePage] ❌ Error clearing API key: $e',
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error clearing key: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Emergency Clear API Key'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Tutorial Section
                  SectionHeader(title: 'Tutorial', icon: Icons.help_outline),
                  const SizedBox(height: 16),

                  // Tutorial Replay Card
                  ActionCard(
                    icon: Icons.play_circle_outline,
                    title: 'View Tutorial',
                    subtitle: 'Replay the interactive walkthrough',
                    color: Colors.blue,
                    onTap: () async {
                      // Reset all tutorials for complete replay
                      await HomePageTutorialManager.resetTutorial();
                      await LodgeTutorialManager.resetTutorial();
                      await ProfileTutorialManager.resetTutorial();
                      await ChatbotTutorialManager.resetTutorial();

                      if (mounted &&
                          widget.onNavigateToHomeWithTutorial != null) {
                        widget.onNavigateToHomeWithTutorial!();
                      }
                    },
                  ),

                  const SizedBox(height: 32),

                  // Legal Section
                  SectionHeader(
                    title: 'Legal',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Terms & Conditions Button
                  ActionCard(
                    icon: Icons.article_outlined,
                    title: 'Terms & Conditions',
                    subtitle: 'View our terms of service',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsConditionsPage(),
                        ),
                      );
                    },
                  ),

                  // Privacy Policy Button
                  ActionCard(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'View our privacy policy',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Delete Account Section
                  SectionHeader(
                    title: 'Danger Zone',
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Delete Account Button
                  _buildDeleteAccountCard(),

                  const SizedBox(height: 32),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red[400]!, Colors.red[600]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _handleLogout(_userProvider!);
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
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          CustomTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            readOnly: true, // Email from auth provider is read-only
            helperText: _agcUser?.email != null
                ? 'Email from ${_getProviderName(_agcUser!.providerId!.index)}'
                : null,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _districtController,
            label: 'District',
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _postcodeController,
            label: 'Postcode',
            icon: Icons.pin_drop_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _stateController,
            label: 'State',
            icon: Icons.map_outlined,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                _saveUserInfo(
                  _phoneController.text,
                  _districtController.text,
                  _postcodeController.text,
                  _stateController.text,
                  _emailController.text,
                );
              },
              icon: const Icon(Icons.save_outlined, size: 20),
              label: const Text(
                'Save',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build API Key Card for Gemini configuration
  Widget _buildApiKeyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.key, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gemini API Key',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isApiKeySet
                          ? 'Custom key configured'
                          : 'Using default key',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isApiKeySet ? Colors.green : Colors.grey[600],
                        fontWeight: _isApiKeySet
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Use your own Google API key for Gemini to reduce downtime and improve reliability. Your key is encrypted with AES-256-GCM and stored in Android Keystore (hardware-backed).',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Require authentication before accessing API key
                final authenticated = await _authenticateUser();
                if (authenticated && mounted) {
                  _showApiKeyDialog();
                } else if (!authenticated && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Authentication required to access API key settings',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: Icon(_isApiKeySet ? Icons.edit : Icons.add, size: 18),
              label: Text(_isApiKeySet ? 'Manage API Key' : 'Set API Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.withOpacity(0.1),
                foregroundColor: Colors.purple,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.purple.withOpacity(0.3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Authenticate user before accessing API key
  Future<bool> _authenticateUser() async {
    try {
      // Check if device supports authentication
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      debugPrint('[ProfilePage] Can check biometrics: $canCheckBiometrics');
      debugPrint('[ProfilePage] Is device supported: $isDeviceSupported');

      if (!isDeviceSupported) {
        // Device doesn't support any authentication, allow access
        debugPrint(
          '[ProfilePage] Device does not support authentication - allowing access',
        );
        return true;
      }

      // Check if device has any authentication methods enrolled
      List<BiometricType> availableBiometrics = [];
      try {
        availableBiometrics = await _localAuth.getAvailableBiometrics();
        debugPrint('[ProfilePage] Available biometrics: $availableBiometrics');
      } catch (e) {
        debugPrint('[ProfilePage] Error checking biometrics: $e');
      }

      if (!canCheckBiometrics && availableBiometrics.isEmpty) {
        // No security set up - show warning but allow access
        debugPrint(
          '[ProfilePage] No device security enrolled - showing warning',
        );
        if (mounted) {
          final shouldProceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(child: Text('No Device Security')),
                ],
              ),
              content: const Text(
                'Your device does not have a screen lock (PIN, password, pattern, or biometric) set up.\n\n'
                'For security, it is recommended to set up device security before managing API keys.\n\n'
                'Do you want to proceed anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Proceed Anyway'),
                ),
              ],
            ),
          );
          return shouldProceed ?? false;
        }
        return false;
      }

      // Try to authenticate
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Gemini API key settings',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/password/pattern as fallback
        ),
      );

      debugPrint('[ProfilePage] Authentication result: $authenticated');
      return authenticated;
    } catch (e) {
      debugPrint('[ProfilePage] Authentication error: $e');

      // Show error dialog with option to proceed
      if (mounted) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 12),
                Expanded(child: Text('Authentication Error')),
              ],
            ),
            content: Text(
              'Failed to authenticate: $e\n\n'
              'This might happen if:\n'
              '• No screen lock is set up\n'
              '• Authentication was cancelled\n'
              '• Biometric sensor failed\n\n'
              'Do you want to proceed without authentication?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        );
        return shouldProceed ?? false;
      }
      return false;
    }
  }

  /// Test Gemini API key
  Future<bool> _testApiKey(String apiKey) async {
    try {
      debugPrint('[ProfilePage] 🧪 Testing API key...');
      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {
                      'text':
                          'Respond with only the word "OK" if you can read this.',
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Check if we got a valid response
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          debugPrint('[ProfilePage] ✅ API key test successful');
          return true;
        }
      }

      debugPrint('[ProfilePage] ❌ API key test failed: ${response.statusCode}');
      debugPrint('[ProfilePage] Response: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[ProfilePage] ❌ API key test error: $e');
      return false;
    }
  }

  /// Show API Key management dialog
  Future<void> _showApiKeyDialog() async {
    final TextEditingController apiKeyController = TextEditingController();
    final existingKey = await _secureStorage.read(key: 'gemini_api_key') ?? '';
    bool isTestPassed =
        existingKey.isNotEmpty; // Existing key is already validated
    bool isTesting = false;
    String? testMessage;
    String? saveError;

    if (existingKey.isNotEmpty) {
      // Show masked version
      apiKeyController.text =
          '••••••••${existingKey.substring(existingKey.length - 4)}';
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.key, color: Colors.purple),
              const SizedBox(width: 12),
              const Text('Gemini API Key'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Security Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Key is Secure',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your API key never leaves your device and is encrypted with AES-256-GCM in Android Keystore (hardware-backed keys).',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[800],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Important Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google API Key Only',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use only official Google Gemini API keys. Benefits: Lower downtime, better reliability.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[800],
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'AIzaSy...',
                    prefixIcon: const Icon(Icons.vpn_key),
                    suffixIcon: existingKey.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setDialogState(() {
                                apiKeyController.clear();
                                isTestPassed = false;
                                testMessage = null;
                                saveError = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Leave empty to use default key',
                    helperMaxLines: 2,
                  ),
                  maxLines: 2,
                  onChanged: (value) {
                    // Reset test status and save error when user types
                    setDialogState(() {
                      isTestPassed = false;
                      testMessage = null;
                      saveError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Test button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () async {
                            final apiKey = apiKeyController.text.trim();

                            // If field is masked and unchanged, don't test
                            if (apiKey.startsWith('••••••••')) {
                              setDialogState(() {
                                isTestPassed = true;
                                testMessage = 'Using existing validated key';
                              });
                              return;
                            }

                            if (apiKey.isEmpty) {
                              setDialogState(() {
                                testMessage = 'Please enter an API key to test';
                              });
                              return;
                            }

                            // Basic format validation
                            if (!apiKey.startsWith('AIzaSy') ||
                                apiKey.length < 30) {
                              setDialogState(() {
                                testMessage =
                                    '❌ Invalid format. Key should start with "AIzaSy"';
                              });
                              return;
                            }

                            // Test the API key
                            setDialogState(() {
                              isTesting = true;
                              testMessage = 'Testing API key...';
                            });

                            final testResult = await _testApiKey(apiKey);

                            setDialogState(() {
                              isTesting = false;
                              isTestPassed = testResult;
                              testMessage = testResult
                                  ? '✅ API key works! You can save it now.'
                                  : '❌ Test failed. Please check your API key.';
                            });
                          },
                    icon: isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.flash_on, size: 18),
                    label: Text(isTesting ? 'Testing...' : 'Test API Key'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Test status message
                if (testMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isTestPassed
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isTestPassed
                              ? Colors.green.withOpacity(0.3)
                              : Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isTestPassed ? Icons.check_circle : Icons.error,
                            color: isTestPassed ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isTestPassed
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Save error message
                if (saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              saveError!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (_isApiKeySet)
              TextButton(
                onPressed: () async {
                  await _secureStorage.delete(key: 'gemini_api_key');
                  setState(() {
                    _isApiKeySet = false;
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('API key removed. Using default key.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text('Remove Key'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final apiKey = apiKeyController.text.trim();

                // If field is masked and unchanged, don't update
                if (apiKey.startsWith('••••••••')) {
                  Navigator.of(context).pop();
                  return;
                }

                if (apiKey.isEmpty) {
                  // Remove key, use default
                  await _secureStorage.delete(key: 'gemini_api_key');
                  setState(() {
                    _isApiKeySet = false;
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Using default API key'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                } else {
                  // Must pass test before saving
                  if (!isTestPassed) {
                    setDialogState(() {
                      saveError =
                          '⚠️ Please test the API key first before saving';
                    });
                    return;
                  }

                  // Save key to secure storage with AES-256-GCM encryption
                  await _secureStorage.write(
                    key: 'gemini_api_key',
                    value: apiKey,
                  );
                  debugPrint(
                    '[ProfilePage] 🔐 API key saved to secure storage (AES-256-GCM encrypted)',
                  );
                  setState(() {
                    _isApiKeySet = true;
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build inline toggle (without separate container, for use inside cards)
  Widget _buildInlineToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: value
                ? AppTheme.primaryOrange.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: value ? AppTheme.primaryOrange : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Switch(
          activeThumbColor: AppTheme.primaryOrange,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _handleLogout(UserProvider userProvider) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

      await userProvider.signOut();

      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isLogin: true),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Build language selection card with combined custom keywords button
  Widget _buildLanguageSelectionCard() {
    // Use local state (loaded from SharedPreferences)
    final currentLanguage = _selectedLanguage;

    debugPrint(
      '[ProfilePage] 🎨 Building language card with: $currentLanguage',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.mic_outlined,
                  color: AppTheme.primaryOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Voice Detection Language',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Language Grid (3 options)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _buildLanguageOption(
                language: 'en',
                label: 'English',
                subtitle: 'English only',
                isSelected: currentLanguage == 'en',
                onTap: () => _selectLanguage('en', 'English'),
              ),
              _buildLanguageOption(
                language: 'zh',
                label: 'Mandarin',
                subtitle: 'Mandarin/English',
                isSelected: currentLanguage == 'zh',
                onTap: () => _selectLanguage('zh', 'Mandarin'),
              ),
              _buildLanguageOption(
                language: 'ms',
                label: 'Malay',
                subtitle: 'Bahasa Melayu/English',
                isSelected: currentLanguage == 'ms',
                onTap: () => _selectLanguage('ms', 'Malay'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Combined Custom Keywords Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showCombinedCustomKeywordsDialog,
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text(
                'Edit All Custom Keywords',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                foregroundColor: AppTheme.primaryOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppTheme.primaryOrange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Allow Discoverable Toggle
              _buildInlineToggle(
                icon: Icons.visibility_outlined,
                title: 'Allow Discoverable',
                subtitle: 'Others can find you in the app',
                value: _allowDiscoverable,
                onChanged: (value) async {
                  setState(() {
                    _allowDiscoverable = value;
                    // If turning off discoverable, also turn off emergency alerts
                    if (!value && _allowEmergencyAlert) {
                      _allowEmergencyAlert = false;
                      _cloudDbUser?.allowEmergencyAlert = false;
                      debugPrint(
                        '[ProfilePage] ⚠️ Auto-disabled emergency alerts because discoverable was turned off',
                      );
                    }
                  });
                  _cloudDbUser?.allowDiscoverable = value;
                  await _userProvider!.updateCloudDbUser(_cloudDbUser!);

                  debugPrint(
                    '[ProfilePage] 💾 Saved allow_discoverable: $value',
                  );

                  // Show warning if turning off discoverable
                  if (!value && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Discoverable disabled. Emergency alerts also disabled.',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              // Show last location update time when toggle is ON
              if (_allowDiscoverable && _cloudDbUser?.locUpdateTime != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Last location update: ${_getMinutesAgo(_cloudDbUser!.locUpdateTime!)} minutes ago',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Allow Emergency Alerts Toggle (requires discoverable to be on)
          _buildInlineToggle(
            icon: Icons.warning_amber_outlined,
            title: 'Allow Emergency Alerts',
            subtitle: _allowDiscoverable
                ? 'Receive emergency notifications'
                : 'Requires "Allow Discoverable" to be enabled',
            value:
                _allowEmergencyAlert &&
                _allowDiscoverable, // Only true if both are on
            onChanged: (value) async {
              // If trying to enable emergency alerts, check if discoverable is on
              if (value && !_allowDiscoverable) {
                // Show explanation dialog
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Enable Discoverable First'),
                      ],
                    ),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency alerts require you to be discoverable.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        Text('Why?'),
                        SizedBox(height: 8),
                        Text(
                          '• Emergency responders need to find your location',
                        ),
                        Text(
                          '• Nearby users can see and respond to your alerts',
                        ),
                        Text(
                          '• Your safety depends on others knowing where you are',
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Please enable "Allow Discoverable" first.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                return; // Don't enable emergency alerts
              }

              setState(() {
                _allowEmergencyAlert = value;
              });
              _cloudDbUser?.allowEmergencyAlert = value;
              await _userProvider!.updateCloudDbUser(_cloudDbUser!);

              if (!mounted) return;

              debugPrint(
                '[ProfilePage] 💾 Saved allow_emergency_alert: $value',
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build individual language option
  Widget _buildLanguageOption({
    required String language,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryOrange : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? AppTheme.primaryOrange : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppTheme.primaryOrange : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Handle language selection
  Future<void> _selectLanguage(String languageCode, String languageName) async {
    debugPrint('[ProfilePage] 🔘 Language selected: $languageCode');

    // Show confirmation dialog for non-English languages
    if (languageCode != 'en') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.language, color: AppTheme.primaryOrange, size: 28),
              const SizedBox(width: 12),
              Text('$languageName Mode'),
            ],
          ),
          content: languageCode == 'zh'
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This mode uses Mandarin Chinese speech recognition. It can detect both Mandarin and English keywords.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'English keyword sensitivity will be reduced in this mode.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : FutureBuilder<String>(
                  future: _getSystemLanguage(),
                  builder: (context, snapshot) {
                    final isInMalay = snapshot.data == 'ms';
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'To use Malay voice detection:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. Go to Settings → System → Languages\n'
                          '2. Set "Bahasa Melayu" as your phone language\n'
                          '3. Restart this app\n'
                          '4. Return here and select Malay mode',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isInMalay
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isInMalay ? Icons.check_circle : Icons.info,
                                color: isInMalay ? Colors.green : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isInMalay
                                      ? 'Your phone is currently in Malay language. ✓'
                                      : 'Your phone is NOT in Malay language.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'English keyword sensitivity will be reduced in this mode.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                languageCode == 'zh' ? 'Use Mandarin' : 'My Phone is in Malay',
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // Save to SharedPreferences for local persistence (after confirmation)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voice_detection_language', languageCode);
    debugPrint(
      '[ProfilePage] 💾 Saved language to SharedPreferences: $languageCode',
    );

    // Update local state
    if (!mounted) return;
    setState(() {
      _selectedLanguage = languageCode;
    });

    debugPrint('[ProfilePage] ✅ Language updated to: $languageCode');

    // Update running safety trigger
    final safetyProvider = Provider.of<SafetyServiceProvider>(
      context,
      listen: false,
    );
    if (safetyProvider.isEnabled) {
      await safetyProvider.updateLanguage(languageCode);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language set to $languageName'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Get system language to check if phone is in Malay
  Future<String> _getSystemLanguage() async {
    try {
      final safetyProvider = Provider.of<SafetyServiceProvider>(
        context,
        listen: false,
      );
      // Use the microphone service to check available locales
      final locales = await safetyProvider.getAvailableLocales();

      // Check if Malay is the primary locale
      if (locales.isNotEmpty) {
        final firstLocale = locales.first.localeId.toLowerCase();
        if (firstLocale.startsWith('ms')) {
          return 'ms';
        }
      }

      return 'en'; // Default to English
    } catch (e) {
      debugPrint('[ProfilePage] Error detecting system language: $e');
      return 'en';
    }
  }

  /// Default keywords for each language
  static const Map<String, List<String>> _defaultKeywords = {
    'en': [
      'ah'
          'ahh'
          'help',
      'someone please',
      'please',
      'emergency',
      'danger',
      'sos',
      'stop',
      'fire',
      'police',
      'ambulance',
      'hurt',
      'pain',
      'scared',
      'i am scared'
          'attack',
    ],
    'ms': [
      'tolong',
      'bantu',
      'selamatkan',
      'bahaya',
      'api',
      'polis',
      'ambulan',
      'sakit',
      'takut',
      'jangan',
    ],
    'zh': [
      '救',
      '帮',
      '痛',
      '怕',
      '火',
      '停',
      '别',
      '疼',
      '急',
      '救命',
      '求救',
      '救救',
      '帮我',
      '帮忙',
      '不要',
      '放手',
      '住手',
      '报警',
    ],
  };

  /// Load custom keywords from SharedPreferences
  Future<List<String>> _loadCustomKeywords(String language) async {
    final prefs = await SharedPreferences.getInstance();
    var keywords = prefs.getStringList('custom_keywords_$language') ?? [];

    if (keywords.isEmpty && _defaultKeywords.containsKey(language)) {
      keywords = List<String>.from(_defaultKeywords[language]!);
      await prefs.setStringList('custom_keywords_$language', keywords);
    }

    return keywords;
  }

  /// Save custom keywords to SharedPreferences
  Future<void> _saveCustomKeywords(
    String language,
    List<String> keywords,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_keywords_$language', keywords);
  }

  /// Show combined custom keywords dialog
  Future<void> _showCombinedCustomKeywordsDialog({
    String? newlyAddedKeyword,
  }) async {
    final enKeywords = await _loadCustomKeywords('en');
    final msKeywords = await _loadCustomKeywords('ms');
    final zhKeywords = await _loadCustomKeywords('zh');

    final allKeywords = <String>[...enKeywords, ...msKeywords, ...zhKeywords];

    // If there's a newly added keyword, put it at the top temporarily
    // Otherwise, sort normally: English/Malay A-Z first, then Chinese
    if (newlyAddedKeyword != null && allKeywords.contains(newlyAddedKeyword)) {
      allKeywords.remove(newlyAddedKeyword);
      allKeywords.insert(0, newlyAddedKeyword);
    } else {
      allKeywords.sort((a, b) {
        final aIsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(a);
        final bIsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(b);

        if (aIsChinese && !bIsChinese) return 1;
        if (!aIsChinese && bIsChinese) return -1;
        return a.compareTo(b);
      });
    }

    final controller = TextEditingController();
    String selectedFilter =
        'All'; // All, EN, CN, BM, Phonetic (always "All" if new keyword)
    final ScrollController scrollController = ScrollController();

    // If there's a newly added keyword, ensure we start with "All" filter and scroll to top
    if (newlyAddedKeyword != null) {
      selectedFilter = 'All';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(0);
        }
      });
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_note, color: AppTheme.primaryOrange, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'All Custom Keywords',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width:
                MediaQuery.of(context).size.width * 0.95, // Even wider dialog
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', selectedFilter, (filter) {
                          setDialogState(() => selectedFilter = filter);
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('EN', selectedFilter, (filter) {
                          setDialogState(() => selectedFilter = filter);
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('CN', selectedFilter, (filter) {
                          setDialogState(() => selectedFilter = filter);
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('BM', selectedFilter, (filter) {
                          setDialogState(() => selectedFilter = filter);
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Phonetic', selectedFilter, (filter) {
                          setDialogState(() => selectedFilter = filter);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Keyword count display
                  Text(
                    'Total: ${_getFilteredKeywords(allKeywords, selectedFilter).length} keywords',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Keywords list with constrained height
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                      minHeight: 200,
                    ),
                    child: () {
                      final filteredKeywords = _getFilteredKeywords(
                        allKeywords,
                        selectedFilter,
                      );
                      return filteredKeywords.isEmpty
                          ? Center(
                              child: Text(
                                selectedFilter == 'All'
                                    ? 'No custom keywords yet'
                                    : 'No $selectedFilter keywords',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filteredKeywords.length,
                              itemBuilder: (context, index) {
                                final keyword = filteredKeywords[index];
                                final keywordType = _getKeywordType(keyword);
                                final isNewlyAdded =
                                    keyword == newlyAddedKeyword;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      _getKeywordIcon(keywordType),
                                      size: 20,
                                      color: _getKeywordColor(keywordType),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            keyword,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (isNewlyAdded)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'NEW',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      keywordType,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, size: 20),
                                      color: Colors.red,
                                      onPressed: () {
                                        setDialogState(
                                          () => allKeywords.remove(keyword),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Keyword removed'),
                                            backgroundColor: Colors.orange,
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                    }(),
                  ),

                  const SizedBox(height: 16),

                  // Add Keyword Button (below the list)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _showAddKeywordDialog(
                          allKeywords,
                          setDialogState,
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text(
                        'Add Keyword',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _resetToDefaults(allKeywords, setDialogState),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset to Default'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
            TextButton(
              onPressed: () async {
                // Split keywords back into their respective languages before saving
                final enList = <String>[];
                final msList = <String>[];
                final zhList = <String>[];

                for (final keyword in allKeywords) {
                  final type = _getKeywordType(keyword);
                  if (type == 'Chinese') {
                    zhList.add(keyword);
                  } else if (type == 'Malay') {
                    msList.add(keyword);
                  } else {
                    // English and Phonetic go to English
                    enList.add(keyword);
                  }
                }

                // Save to respective categories
                await _saveCustomKeywords('en', enList);
                await _saveCustomKeywords('ms', msList);
                await _saveCustomKeywords('zh', zhList);

                if (mounted) Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _addKeywords(
    String value,
    List<String> allKeywords,
    TextEditingController controller,
    StateSetter setDialogState,
  ) {
    if (value.trim().isEmpty) return;

    final newKeywords = value
        .split(',')
        .map((k) {
          final trimmed = k.trim();
          // Only lowercase non-Chinese keywords
          final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed);
          return isChinese ? trimmed : trimmed.toLowerCase();
        })
        .where((k) => k.isNotEmpty && !allKeywords.contains(k))
        .toList();

    if (newKeywords.isNotEmpty) {
      setDialogState(() {
        allKeywords.addAll(newKeywords);
        allKeywords.sort((a, b) {
          final aIsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(a);
          final bIsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(b);
          if (aIsChinese && !bIsChinese) return 1;
          if (!aIsChinese && bIsChinese) return -1;
          return a.compareTo(b);
        });
      });
      controller.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${newKeywords.length} keyword(s)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _resetToDefaults(List<String> allKeywords, StateSetter setDialogState) {
    setDialogState(() {
      allKeywords.clear();
      allKeywords.addAll(_defaultKeywords['en']!);
      allKeywords.addAll(_defaultKeywords['ms']!);
      allKeywords.addAll(_defaultKeywords['zh']!);
      allKeywords.addAll(_phoneticKeywords); // Add phonetics
      allKeywords.sort((a, b) {
        final aIsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(a);
        final bIsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(b);
        if (aIsChinese && !bIsChinese) return 1;
        if (!aIsChinese && bIsChinese) return -1;
        return a.compareTo(b);
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reset to ${allKeywords.length} default keywords'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Phonetic keywords (approximate pronunciations)
  static const List<String> _phoneticKeywords = [
    // English phonetics
    'sauce', // SOS
    'essay', // SOS
    'so so', // SOS
    'soss', // SOS
    's.o.s', // SOS
    // Chinese phonetics (Mandarin)
    'jiu ming', // 救命 (save life)
    'chiu ming', // 救命 (alternate)
    'bang wo', // 帮我 (help me)
    'pang wo', // 帮我 (alternate)
    'qiu jiu', // 求救 (seek rescue)
    'chiu jiu', // 求救 (alternate)
    'jiu jiu', // 救救 (save save)
    // Malay phonetics
    'to long', // tolong (help)
    'ban too', // bantu (help)
    'ba ha ya', // bahaya (danger)
    'po lis', // polis (police)
  ];

  /// Build filter chip
  Widget _buildFilterChip(
    String label,
    String selectedFilter,
    Function(String) onSelected,
  ) {
    final isSelected = selectedFilter == label;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) => onSelected(label),
      selectedColor: AppTheme.primaryOrange,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  /// Get filtered keywords based on selected filter
  List<String> _getFilteredKeywords(List<String> allKeywords, String filter) {
    if (filter == 'All') return allKeywords;

    return allKeywords.where((keyword) {
      final type = _getKeywordType(keyword);
      switch (filter) {
        case 'EN':
          return type == 'English';
        case 'CN':
          return type == 'Chinese';
        case 'BM':
          return type == 'Malay';
        case 'Phonetic':
          return type == 'Phonetic';
        default:
          return true;
      }
    }).toList();
  }

  /// Determine keyword type
  String _getKeywordType(String keyword) {
    // Check if Chinese
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(keyword)) {
      return 'Chinese';
    }

    // Check if phonetic
    if (_phoneticKeywords.contains(keyword.toLowerCase())) {
      return 'Phonetic';
    }

    // Check if Malay
    final malayKeywords = _defaultKeywords['ms'] ?? [];
    if (malayKeywords.contains(keyword.toLowerCase())) {
      return 'Malay';
    }

    // Default to English
    return 'English';
  }

  /// Get icon for keyword type
  IconData _getKeywordIcon(String type) {
    switch (type) {
      case 'Chinese':
        return Icons.translate;
      case 'Malay':
        return Icons.language;
      case 'Phonetic':
        return Icons.hearing;
      default:
        return Icons.label;
    }
  }

  /// Get color for keyword type
  Color _getKeywordColor(String type) {
    switch (type) {
      case 'Chinese':
        return Colors.red;
      case 'Malay':
        return Colors.green;
      case 'Phonetic':
        return Colors.purple;
      default:
        return AppTheme.primaryOrange;
    }
  }

  /// Show dialog to add a keyword with category selection
  Future<void> _showAddKeywordDialog(
    List<String> allKeywords,
    StateSetter parentSetState,
  ) async {
    final keywordController = TextEditingController();
    String selectedCategory = 'EN'; // Default to English
    String errorMessage = ''; // Error message to display

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.add_circle, color: AppTheme.primaryOrange, size: 28),
              const SizedBox(width: 12),
              const Text('Add New Keyword'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tips
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 20,
                        color: AppTheme.primaryOrange,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add keywords in any language. Phonetic = approximate sounds (e.g., "sauce" for "SOS")',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Keyword input
                TextField(
                  controller: keywordController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Keyword',
                    hintText: 'e.g., help, tolong, 救命, sauce',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.label),
                  ),
                  onChanged: (value) {
                    // Clear error when user types
                    if (errorMessage.isNotEmpty) {
                      setDialogState(() => errorMessage = '');
                    }
                  },
                ),

                // Error message
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Category selection
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Category chips (wrap to prevent overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryChip(
                      'EN',
                      'English',
                      Icons.label,
                      AppTheme.primaryOrange,
                      selectedCategory,
                      (category) {
                        setDialogState(() => selectedCategory = category);
                      },
                    ),
                    _buildCategoryChip(
                      'CN',
                      'Chinese',
                      Icons.translate,
                      Colors.red,
                      selectedCategory,
                      (category) {
                        setDialogState(() => selectedCategory = category);
                      },
                    ),
                    _buildCategoryChip(
                      'BM',
                      'Malay',
                      Icons.language,
                      Colors.green,
                      selectedCategory,
                      (category) {
                        setDialogState(() => selectedCategory = category);
                      },
                    ),
                    _buildCategoryChip(
                      'Phonetic',
                      'Phonetic',
                      Icons.hearing,
                      Colors.purple,
                      selectedCategory,
                      (category) {
                        setDialogState(() => selectedCategory = category);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final trimmed = keywordController.text.trim();
                // Only lowercase non-Chinese keywords
                final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(trimmed);
                final keyword = isChinese ? trimmed : trimmed.toLowerCase();

                // Validation
                if (keyword.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Please enter a keyword';
                  });
                  return;
                }

                if (allKeywords.contains(keyword)) {
                  setDialogState(() {
                    errorMessage = 'This keyword already exists';
                  });
                  return;
                }

                // Save to appropriate category
                final categoryKey = selectedCategory == 'EN'
                    ? 'en'
                    : selectedCategory == 'CN'
                    ? 'zh'
                    : selectedCategory == 'BM'
                    ? 'ms'
                    : 'en'; // Phonetic goes to English

                // Load, add, and save
                final keywords = await _loadCustomKeywords(categoryKey);
                keywords.add(keyword);
                await _saveCustomKeywords(categoryKey, keywords);

                // Close both dialogs
                if (mounted) {
                  Navigator.of(context).pop(); // Close add keyword dialog
                }
                if (mounted) {
                  Navigator.of(context).pop(); // Close all keywords dialog
                }

                // Reopen the all keywords dialog with the new keyword highlighted
                if (mounted) {
                  _showCombinedCustomKeywordsDialog(newlyAddedKeyword: keyword);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build category selection chip
  Widget _buildCategoryChip(
    String value,
    String label,
    IconData icon,
    Color color,
    String selectedCategory,
    Function(String) onSelected,
  ) {
    final isSelected = selectedCategory == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) => onSelected(value),
      selectedColor: color,
      checkmarkColor: Colors.white,
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }
}
