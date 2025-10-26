import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../app_theme.dart';
import '../sensors/location_centre.dart';
import 'package:huawei_map/huawei_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'media_operations_widget.dart';

import '../models/clouddb_model.dart';
import '../repository/incident_repository.dart';
import '../repository/media_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:provider/provider.dart';
import '../providers/safety_service_provider.dart';
import '../bg_services/rapid_location_service.dart';
import '../widgets/rapid_location_overlay.dart';
import '../services/push_notification_service.dart';

class LodgeIncidentPage extends StatefulWidget {
  final String? incidentType;
  final String? title;
  final String? description;
  final String? district;
  final String? postcode;
  final String? state;
  final String? audioRecordingPath;
  final ValueNotifier<String>? incidentTypeNotifier;

  const LodgeIncidentPage({
    super.key,
    this.incidentType,
    this.title,
    this.description,
    this.district,
    this.postcode,
    this.state,
    this.audioRecordingPath,
    this.incidentTypeNotifier,
  });

  @override
  _LodgeIncidentPageState createState() => _LodgeIncidentPageState();
}

class _LodgeIncidentPageState extends State<LodgeIncidentPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  final FocusNode _addressFocusNode = FocusNode();
  late final TextEditingController _titleController;

  String _incidentType = 'general';
  List<File> _mediaFiles = [];

  HuaweiMapController? _mapController;
  LatLng? _selectedPosition;
  Set<Marker> _markers = {};
  bool _isLoadingLocation = true;

  final _incidentRepository = IncidentRepository();
  final _mediaRepository = MediaRepository();
  final _uuid = Uuid();
  final _pushService = PushNotificationService();
  String? _currentUserId;

  // Scroll controller for title animation
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _titleAnimationValue = ValueNotifier<double>(1.0);

  // Color animation for incident type
  Color _titleBgColor = Colors.amber[100]!;
  Color _titleTextColor = Colors.amber[900]!;
  Color _titleShadowBaseColor = Colors.amber;
  Color _accentColor = AppTheme.primaryOrange; // For icons, buttons, etc.

  // Auto-submit timer for safety trigger
  Timer? _autoSubmitTimer;
  int _countdown = 10;
  bool _isAutoSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    _addressController = TextEditingController();

    // Parse title and description if coming from Gemini (format: "Title\n---\nDescription")
    // Use provided title if available, otherwise try to parse from description
    String initialTitle = widget.title ?? '';
    String initialDescription = widget.description ?? '';

    // Fallback: Parse title from description if title not provided (legacy support)
    if (initialTitle.isEmpty &&
        widget.description != null &&
        widget.description!.contains('\n---\n')) {
      final parts = widget.description!.split('\n---\n');
      if (parts.length >= 2) {
        initialTitle = parts[0].trim();
        initialDescription = parts.sublist(1).join('\n---\n').trim();
      }
    }

    _titleController = TextEditingController(text: initialTitle);
    _descriptionController = TextEditingController(text: initialDescription);

    if (widget.incidentType != null) {
      _incidentType = widget.incidentType!;
      // Initialize title colors based on incident type
      if (_incidentType == 'threat') {
        _titleBgColor = Colors.red[100]!;
        _titleTextColor = Colors.red[900]!;
        _titleShadowBaseColor = Colors.red;
        _accentColor = Colors.red[700]!;
      }
    }

    _getCurrentUserId();

    // Auto-detect user location when page loads
    _initializeLocation();

    // Add scroll listener for title animation
    _scrollController.addListener(_onScroll);

    // Start auto-submit timer if coming from safety trigger (has audio recording)
    // Note: Audio file is automatically added by MediaOperationsWidget via initialAudioFile
    if (widget.audioRecordingPath != null) {
      _startAutoSubmitTimer();
    }
  }

  void _startAutoSubmitTimer() {
    setState(() {
      _isAutoSubmitting = true;
      _countdown = 10;
    });

    _autoSubmitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _submitIncident();
      }
    });
  }

  void _stopAutoSubmitTimer() {
    _autoSubmitTimer?.cancel();
    setState(() {
      _isAutoSubmitting = false;
    });
  }

  void _handleCancel() async {
    _stopAutoSubmitTimer();

    // Restart safety trigger service
    final safetyProvider = Provider.of<SafetyServiceProvider>(
      context,
      listen: false,
    );
    await safetyProvider.toggle(true, context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.security, color: Colors.white),
              SizedBox(width: 12),
              Text('Safety trigger reactivated'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _handleModify() {
    _stopAutoSubmitTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-submit stopped. You can now modify the incident.'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onScroll() {
    // Calculate animation value based on scroll position (0 to 100px range)
    const fadeEndOffset = 100.0;
    final scrollOffset = _scrollController.offset.clamp(0.0, fadeEndOffset);
    final newValue = 1.0 - (scrollOffset / fadeEndOffset);

    // Update only if changed significantly (reduces updates by ~90%)
    if ((newValue - _titleAnimationValue.value).abs() > 0.02) {
      _titleAnimationValue.value = newValue;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - reload map if needed
      debugPrint('[LodgeIncident] App resumed, reloading map location');
      if (_selectedPosition == null || _mapController == null) {
        _initializeLocation();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer

    // Reset to yellow/general when leaving Lodge page
    widget.incidentTypeNotifier?.value = 'general';

    _autoSubmitTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _titleAnimationValue.dispose();
    _titleController.dispose();
    _addressController.dispose();
    _addressFocusNode.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _currentUserId = user.uid;
        });
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
  }

  // Generate title from description using Gemini
  Future<void> _generateTitleFromDescription() async {
    final description = _descriptionController.text.trim();

    // Check if description has at least 3 words
    final wordCount = description
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    if (description.isEmpty || wordCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description first (at least 3 words)'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      ),
    );

    try {
      // Check for custom API key from secure storage first (AES-256-GCM encrypted)
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          resetOnError: true,
        ),
      );

      String? customApiKey = await secureStorage.read(key: 'gemini_api_key');

      // Migration: Check SharedPreferences if not in secure storage
      if (customApiKey == null) {
        final prefs = await SharedPreferences.getInstance();
        customApiKey = prefs.getString('gemini_api_key');

        if (customApiKey != null && customApiKey.isNotEmpty) {
          // Migrate to secure storage
          await secureStorage.write(key: 'gemini_api_key', value: customApiKey);
          await prefs.remove('gemini_api_key');
          debugPrint('[LodgeIncident] 🔄 Migrated API key to secure storage');
        }
      }

      // Use custom key if available, otherwise fallback to default
      final apiKey = customApiKey ?? dotenv.env['GEMINI_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API key not configured');
      }

      debugPrint(
        '[LodgeIncident] Using ${customApiKey != null ? 'custom (🔐 encrypted)' : 'default'} API key for title generation',
      );

      // Call Gemini API to generate title
      final response = await http.post(
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
                      'Generate a concise title for this incident description. The title must be STRICTLY less than 45 characters. Be brief and capture the main point. Do not include quotes or extra formatting, just the title text.\n\nDescription: $description',
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 50},
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String generatedTitle =
            data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        // Clean up the title
        generatedTitle = generatedTitle.trim();
        // Remove quotes at start and end
        if (generatedTitle.startsWith('"') || generatedTitle.startsWith("'")) {
          generatedTitle = generatedTitle.substring(1);
        }
        if (generatedTitle.endsWith('"') || generatedTitle.endsWith("'")) {
          generatedTitle = generatedTitle.substring(
            0,
            generatedTitle.length - 1,
          );
        }
        generatedTitle = generatedTitle.split('\n')[0]; // Take first line only

        // Ensure it's under 45 characters
        if (generatedTitle.length > 45) {
          generatedTitle = generatedTitle.substring(0, 42) + '...';
        }

        // Set to controller
        setState(() {
          _titleController.text = generatedTitle;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Title generated successfully by AI'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to generate title: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading if still open

      debugPrint('Error generating title: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate title: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _initializeLocation() async {
    final locationService = LocationServiceHelper();

    bool hasPermission = await locationService.hasLocationPermission();
    if (!hasPermission) {
      hasPermission = await locationService.requestLocationPermission();
    }

    if (hasPermission) {
      try {
        final location = await locationService.getLastLocation();
        if (location != null && mounted) {
          final userPosition = LatLng(location.latitude!, location.longitude!);

          setState(() {
            _selectedPosition = userPosition;
            _isLoadingLocation = false;
            _markers = {
              Marker(
                markerId: MarkerId('selected_location'),
                position: userPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
              ),
            };
          });

          await _reverseGeocodeLocation(userPosition.lat, userPosition.lng);

          _mapController?.animateCamera(CameraUpdate.newLatLng(userPosition));
        } else {
          if (mounted) {
            setState(() {
              _isLoadingLocation = false;
            });
          }
        }
      } catch (e) {
        print('Error initializing location: $e');
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is required'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _initializeLocation,
            ),
          ),
        );
      }
    }
  }

  Future<void> _reverseGeocodeLocation(
    double latitude,
    double longitude,
  ) async {
    setState(() {});

    try {
      final apiKey = dotenv.env['HUAWEI_SITE_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not found in environment variables');
      }

      final url = Uri.parse(
        'https://siteapi.cloud.huawei.com/mapApi/v1/siteService/reverseGeocode',
      );

      print('Reverse geocoding: $latitude, $longitude'); // Debug log

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'location': {'lat': latitude, 'lng': longitude},
          'language': 'en',
          'returnPoi': true,
        }),
      );

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check for API errors in response
        if (data['returnCode'] != null && data['returnCode'] != '0') {
          throw Exception(
            'API Error: ${data['returnDesc'] ?? 'Unknown error'}',
          );
        }

        if (data['sites'] != null && data['sites'].isNotEmpty) {
          final site = data['sites'][0];
          final address = site['address'];

          setState(() {
            // Combine everything into one address field
            String fullAddress = site['formatAddress'] ?? '';

            if (fullAddress.isEmpty) {
              // Fallback: build address from components
              List<String> addressParts = [];

              if (address['subLocality'] != null &&
                  address['subLocality'].isNotEmpty) {
                addressParts.add(address['subLocality']);
              }
              if (address['locality'] != null &&
                  address['locality'].isNotEmpty) {
                addressParts.add(address['locality']);
              }
              if (address['postalCode'] != null &&
                  address['postalCode'].isNotEmpty) {
                addressParts.add(address['postalCode']);
              }
              if (address['adminArea'] != null &&
                  address['adminArea'].isNotEmpty) {
                addressParts.add(address['adminArea']);
              }
              if (address['country'] != null && address['country'].isNotEmpty) {
                addressParts.add(address['country']);
              }

              fullAddress = addressParts.join(', ');
            }

            _addressController.text = fullAddress;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Address auto-filled!'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } else {
          _handleNoAddress();
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please check your API key.');
      } else if (response.statusCode == 403) {
        throw Exception('API access forbidden. Check API key permissions.');
      } else {
        throw Exception(
          'Failed to reverse geocode: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get address: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _handleNoAddress() {
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No address found at this location'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _submitIncident() async {
    if (_formKey.currentState!.validate()) {
      if (_currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User not authenticated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool dialogShown = true;

      try {
        await _incidentRepository.openZone();
        await _mediaRepository.openZone();

        final incidentId = _uuid.v4();
        String? mediaId;

        // 1. Handle multiple media uploads to AWS S3
        if (_mediaFiles.isNotEmpty) {
          // Generate ONE media ID for all files in this incident
          mediaId = _uuid.v4();

          print('Uploading ${_mediaFiles.length} media files to AWS S3...');
          print('Media ID for this incident: $mediaId');

          for (int i = 0; i < _mediaFiles.length; i++) {
            final file = _mediaFiles[i];
            final order = i + 1; // Order starts from 1

            // Get file extension
            var fileExtension = file.path.split('.').last.toLowerCase();

            print('Uploading media ${order}/${_mediaFiles.length}...');

            // Read file and convert to base64
            final bytes = await File(file.path).readAsBytes();
            final base64Content = base64Encode(bytes);

            // Prepare file name with timestamp and order
            final timestamp = DateFormat(
              'yyyyMMddHHmmss',
            ).format(DateTime.now());

            // For audio files, temporarily use .mp4 extension for AWS Lambda compatibility
            String baseFileName = file.path.split('/').last;
            if (fileExtension == 'm4a' ||
                fileExtension == 'aac' ||
                fileExtension == 'mp3' ||
                fileExtension == 'wav') {
              baseFileName = baseFileName.replaceAll('.$fileExtension', '.mp4');
              fileExtension = 'mp4';
            }

            final fileName = '${timestamp}_${order}_$baseFileName';

            // Upload to AWS S3
            final response = await http.post(
              Uri.parse(
                'https://9bgg6p599h.execute-api.ap-southeast-1.amazonaws.com/dev/media',
              ),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'file_name': fileName,
                'file_content': base64Content,
              }),
            );

            if (response.statusCode != 200) {
              throw Exception(
                'Failed to upload media ${order} to AWS S3: ${response.body}',
              );
            }

            // Parse response to get file URL
            final responseData = jsonDecode(response.body);
            final mediaURL = responseData['file_url'];

            if (mediaURL == null || mediaURL.isEmpty) {
              throw Exception(
                'Failed to get media URL from AWS S3 for file ${order}',
              );
            }

            print('✅ Media ${order} uploaded to AWS S3');
            print('✅ Media URL: $mediaURL');

            // Save media reference to CloudDB with the AWS S3 URL
            final mediaObject = media(
              mediaID: mediaId,
              order: order,
              mediaType: fileExtension,
              mediaURI: mediaURL, // AWS S3 URL
            );

            print(
              'Saving media reference to CloudDB - ID: $mediaId, Order: $order',
            );
            final success = await _mediaRepository.upsertMedia(mediaObject);

            if (!success) {
              throw Exception(
                'Failed to save media reference ${order} to CloudDB',
              );
            }

            print('✅ Media reference ${order} saved to CloudDB');
          }

          print(
            '✅ All ${_mediaFiles.length} media files processed successfully',
          );
        } else {
          print('No media files to upload');
        }

        // 2. Combine title and description with separator
        final title = _titleController.text.trim();
        final description = _descriptionController.text.trim();
        final combinedDesc = title.isNotEmpty && description.isNotEmpty
            ? '$title\n---\n$description'
            : title.isNotEmpty
            ? title
            : description;

        // 3. Create incident using CloudDB model
        // desc field is now Text type (supports up to 1MB)
        final incident = incidents(
          iid: incidentId,
          uid: _currentUserId!,
          latitude: _selectedPosition!.lat,
          longitude: _selectedPosition!.lng,
          datetime: DateTime.now().toUtc(),
          incidentType: _incidentType,
          isAIGenerated: false,
          desc: combinedDesc,
          mediaID: mediaId,
          status: 'active',
        );

        print('=== Incident Details ===');
        print('Incident ID: $incidentId');
        print('User ID: $_currentUserId');
        print('Type: $_incidentType');
        print('Media ID: $mediaId');
        print('Total Media Files: ${_mediaFiles.length}');
        print('========================');

        // 3. Upsert incident
        final success = await _incidentRepository.upsertIncident(incident);

        if (!success) {
          throw Exception('Failed to insert incident');
        }

        print('✅ Incident upserted successfully!');

        // Send push notifications to nearby users
        try {
          await _pushService.notifyNearbyUsers(
            incidentLatitude: _selectedPosition!.lat,
            incidentLongitude: _selectedPosition!.lng,
            incidentType: _incidentType,
            incidentDescription: _descriptionController.text.trim(),
            incidentId: incidentId,
            radiusKm: 5.0, // 5km radius for prototyping
          );
          print('✅ Push notifications sent to nearby users');
        } catch (e) {
          print('⚠️ Failed to send push notifications: $e');
          // Don't fail the entire incident submission if push fails
        }

        await _incidentRepository.closeZone();
        await _mediaRepository.closeZone();

        if (dialogShown && mounted) {
          Navigator.of(context).pop();
          dialogShown = false;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Incident reported successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          // Check if this was from safety trigger
          final bool fromSafetyTrigger = widget.audioRecordingPath != null;

          // Reset form
          setState(() {
            _incidentType = 'general';
            _mediaFiles.clear();
            _addressController.clear();
            _descriptionController.clear();
            _titleController.clear();
            _selectedPosition = null;
            _markers = {};
          });

          _initializeLocation();

          // If from safety trigger, start rapid location updates and show overlay
          if (fromSafetyTrigger) {
            final rapidService = Provider.of<RapidLocationService>(
              context,
              listen: false,
            );
            await rapidService.startRapidUpdates(incidentId: incidentId);

            // Navigate to overlay screen
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const RapidLocationOverlayScreen(),
                ),
              );
            }
          }
        }
      } catch (e, stackTrace) {
        if (dialogShown && mounted) {
          Navigator.of(context).pop();
          dialogShown = false;
        }

        print('❌ Error submitting incident: $e');
        print('Stack trace: $stackTrace');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit incident: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  // Helper method to build label with icon (with animated color)
  Widget _buildLabelWithIcon(IconData icon, String label) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 3000),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: _accentColor, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildMapWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelWithIcon(Icons.location_on, 'Location'),
        const SizedBox(height: 12),
        // Embedded Map
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isLoadingLocation
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: AppTheme.primaryOrange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Fetching your location...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _selectedPosition == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Location not available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _initializeLocation,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : HuaweiMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedPosition!,
                      zoom: 15,
                    ),
                    mapType: MapType.normal,
                    compassEnabled: true,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: _markers,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onClick: (LatLng position) {
                      setState(() {
                        _selectedPosition = position;
                        _markers = {
                          Marker(
                            markerId: MarkerId('selected_location'),
                            position: position,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                          ),
                        };
                      });
                      _reverseGeocodeLocation(position.lat, position.lng);
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use auto-detected location or tap on map to select location',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 20),
        Focus(
          onFocusChange: (hasFocus) {
            setState(() {}); // Rebuild to update label color
          },
          child: TextFormField(
            controller: _addressController,
            focusNode: _addressFocusNode,
            decoration: InputDecoration(
              labelText: 'Address',
              labelStyle: TextStyle(
                color: _addressFocusNode.hasFocus
                    ? (_incidentType == 'threat'
                          ? Colors.red[700]
                          : AppTheme.primaryOrange)
                    : Colors.grey[600],
              ),
              hintText: 'Full address will auto-fill or enter manually',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _incidentType == 'threat'
                      ? Colors.red
                      : AppTheme.primaryOrange,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 3,
            cursorColor: _incidentType == 'threat'
                ? Colors.red
                : AppTheme.primaryOrange,
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentTypeCard({
    required String type,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _incidentType == type;
    final isThreat = type == 'threat';

    // Define colors based on type
    Color selectedColor;
    Color selectedBgColor;
    Color unselectedColor;
    Color unselectedBgColor;
    Color borderColor;

    if (isThreat) {
      // Threat button: darker red when selected, lighter red when not
      selectedColor = Colors.red[900]!;
      selectedBgColor = Colors.red.withOpacity(0.2);
      unselectedColor = Colors.red[200]!;
      unselectedBgColor = Colors.red.withOpacity(0.05);
      borderColor = isSelected ? Colors.red[900]! : Colors.red[100]!;
    } else {
      // General button: darker yellow when selected, lighter yellow when not
      selectedColor = Colors.amber[900]!;
      selectedBgColor = Colors.amber.withOpacity(0.2);
      unselectedColor = Colors.amber[200]!;
      unselectedBgColor = Colors.amber.withOpacity(0.05);
      borderColor = isSelected ? Colors.amber[900]! : Colors.amber[100]!;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _incidentType = type;
          // Animate title and accent colors based on incident type
          if (type == 'threat') {
            _titleBgColor = Colors.red[100]!;
            _titleTextColor = Colors.red[900]!;
            _titleShadowBaseColor = Colors.red;
            _accentColor = Colors.red[700]!;
          } else {
            _titleBgColor = Colors.amber[100]!;
            _titleTextColor = Colors.amber[900]!;
            _titleShadowBaseColor = Colors.amber;
            _accentColor = AppTheme.primaryOrange;
          }
          // Update the notifier to change AppBar and navigation colors
          widget.incidentTypeNotifier?.value = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : unselectedBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              ValueListenableBuilder<double>(
                valueListenable: _titleAnimationValue,
                builder: (context, value, child) {
                  // Calculate opacity and offset from single value
                  final opacity = value;
                  final offset = -(1.0 - value) * 50.0;

                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, offset),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 3000),
                        curve: Curves.easeInOut,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: _titleBgColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _titleShadowBaseColor.withOpacity(
                                0.2 * opacity,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 3000),
                            curve: Curves.easeInOut,
                            style: Theme.of(context).textTheme.headlineMedium!
                                .copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _titleTextColor,
                                ),
                            child: const Text('Lodge Incident'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Combined white box with all content
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Map Section
                          _buildMapWidget(),
                          const SizedBox(height: 24),

                          // Incident Type
                          _buildLabelWithIcon(Icons.category, 'Incident Type'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildIncidentTypeCard(
                                  type: 'general',
                                  icon: Icons.info_outline,
                                  label: 'General',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildIncidentTypeCard(
                                  type: 'threat',
                                  icon: Icons.warning_amber_rounded,
                                  label: 'Threat',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Description
                          _buildLabelWithIcon(Icons.description, 'Description'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              hintText: 'Describe what happened in detail...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _incidentType == 'threat'
                                      ? Colors.red
                                      : AppTheme.primaryOrange,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            maxLines: 6,
                            cursorColor: _incidentType == 'threat'
                                ? Colors.red
                                : AppTheme.primaryOrange,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Incident Title with Generate Button
                          Row(
                            children: [
                              Expanded(
                                child: _buildLabelWithIcon(
                                  Icons.title,
                                  'Incident Title',
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 3000),
                                curve: Curves.easeInOut,
                                child: TextButton.icon(
                                  onPressed: _generateTitleFromDescription,
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                  ),
                                  label: const Text('Generate'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _accentColor,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: 'Enter or generate a brief title',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _incidentType == 'threat'
                                      ? Colors.red
                                      : AppTheme.primaryOrange,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            maxLines: 1,
                            maxLength: 45,
                            cursorColor: _incidentType == 'threat'
                                ? Colors.red
                                : AppTheme.primaryOrange,
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an incident title';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Media Evidence
                          MediaOperationsWidget(
                            mediaFiles: _mediaFiles,
                            onMediaFilesChanged: (files) {
                              setState(() {
                                _mediaFiles = files;
                              });
                            },
                            initialAudioFile: widget.audioRecordingPath != null
                                ? File(widget.audioRecordingPath!)
                                : null,
                            accentColor: _accentColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Submit Button with DateTime inside
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 3000),
                        curve: Curves.easeInOut,
                        child: ElevatedButton(
                          onPressed: _submitIncident,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Datetime: ${DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.now())}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Auto-submit countdown and Cancel/Modify buttons
                    if (_isAutoSubmitting) ...[
                      const SizedBox(height: 24),
                      // Countdown display
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          border: Border.all(color: Colors.orange, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timer,
                              color: Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Auto-submitting in $_countdown seconds...',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Cancel and Modify buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handleCancel,
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _handleModify,
                              icon: const Icon(Icons.edit, color: Colors.white),
                              label: const Text(
                                'Modify',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
