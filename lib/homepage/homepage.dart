import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'map_widget.dart';
import '../app_theme.dart';
import 'chatbot_widget.dart';
import '../community/community_page.dart';
import '../lodge/lodge_incident_page.dart';
import '../lodge/incident_history_page.dart';
import '../profile/profile_page.dart';
import 'package:provider/provider.dart';
import '../providers/safety_service_provider.dart';
import '../tutorial/homepage_tutorial.dart';
import '../repository/incident_repository.dart';
import '../repository/user_repository.dart';
import '../models/clouddb_model.dart';
import '../sensors/location_centre.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'incident_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isServiceRunning = false;
  final _backgroundService = FlutterBackgroundService();
  final GlobalKey _infoIconKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _tooltipTimer;

  int _selectedIndex = 0;
  final ValueNotifier<String> _incidentTypeNotifier = ValueNotifier<String>(
    'general',
  );

  List<Map<String, dynamic>> _incidents = [];
  List<incidents> _rawIncidents = [];
  bool _isLoadingIncidents = true;
  double _radiusFilter = 800.0; // Default 800m
  double? _userLatitude;
  double? _userLongitude;
  final _incidentRepository = IncidentRepository();
  final _userRepository = UserRepository();
  Timer? _refreshTimer;
  Timer? _locationUpdateTimer;
  Timer? _debounceTimer;
  Function(Map<String, dynamic>)? _mapFocusCallback;
  final ValueNotifier<double> _listOverlayPosition = ValueNotifier<double>(
    0.0,
  ); // Position of incident list overlay (0 = default, negative = expanded)
  String? _currentUserId;
  bool _allowDiscoverable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final safetyProvider = Provider.of<SafetyServiceProvider>(
        context,
        listen: false,
      );
      setState(() {
        _isServiceRunning = safetyProvider.isEnabled;
      });

      // Load user ID and settings
      await _loadUserSettings();

      // Load user location and incidents
      await _getUserLocation();
      await _loadIncidents();

      // Refresh incidents every 30 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _loadIncidents();
      });

      // Update user location to CloudDB every 3 minutes if allowDiscoverable
      _locationUpdateTimer = Timer.periodic(const Duration(minutes: 3), (_) {
        _updateUserLocationToCloudDB();
      });

      // Show tutorial after small delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        HomePageTutorialManager.showTutorialIfNeeded(context);
      }
    });
  }

  void _toggleService(bool value) async {
    final safetyProvider = Provider.of<SafetyServiceProvider>(
      context,
      listen: false,
    );
    await safetyProvider.toggle(value, context);

    setState(() {
      _isServiceRunning = value;
    });
  }

  // Load user settings from CloudDB
  Future<void> _loadUserSettings() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      if (user != null && user.uid != null) {
        _currentUserId = user.uid;

        await _userRepository.openZone();
        final userData = await _userRepository.getUserById(user.uid!);
        await _userRepository.closeZone();

        if (userData != null && mounted) {
          setState(() {
            _allowDiscoverable = userData.allowDiscoverable ?? false;
          });
          print('[Homepage] User allowDiscoverable: $_allowDiscoverable');
        }
      }
    } catch (e) {
      print('[Homepage] Error loading user settings: $e');
    }
  }

  // Get user's current location
  Future<void> _getUserLocation() async {
    try {
      final locationService = LocationServiceHelper();
      final hasPermission = await locationService.hasLocationPermission();

      if (hasPermission) {
        final location = await locationService.getLastLocation();
        if (location != null && mounted) {
          setState(() {
            _userLatitude = location.latitude;
            _userLongitude = location.longitude;
          });
          print('[Homepage] User location: $_userLatitude, $_userLongitude');
        }
      }
    } catch (e) {
      print('[Homepage] Error getting user location: $e');
    }
  }

  // Update user location to CloudDB if allowDiscoverable is enabled
  Future<void> _updateUserLocationToCloudDB() async {
    if (!mounted) return;

    if (!_allowDiscoverable || _currentUserId == null) {
      print(
        '[Homepage] Location update skipped - allowDiscoverable: $_allowDiscoverable',
      );
      return;
    }

    try {
      // Get fresh location
      final locationService = LocationServiceHelper();
      final location = await locationService.getLastLocation();

      if (location != null &&
          location.latitude != null &&
          location.longitude != null) {
        await _userRepository.openZone();

        // Get current user data
        final userData = await _userRepository.getUserById(_currentUserId!);

        if (userData != null) {
          // Update location
          userData.latitude = location.latitude;
          userData.longitude = location.longitude;

          await _userRepository.upsertUser(userData);
          print(
            '[Homepage] ✅ Updated user location to CloudDB: ${location.latitude}, ${location.longitude}',
          );
        }

        await _userRepository.closeZone();

        // Update local state
        if (mounted) {
          setState(() {
            _userLatitude = location.latitude;
            _userLongitude = location.longitude;
          });
        }
      }
    } catch (e) {
      print('[Homepage] ❌ Error updating location to CloudDB: $e');
    }
  }

  // Calculate distance between two points in meters using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 *
        asin(sqrt(a)); // 2 * R * asin, R = 6371 km, result in meters
  }

  // Load incidents from CloudDB with filtering
  Future<void> _loadIncidents() async {
    if (!mounted) return;

    if (_userLatitude == null || _userLongitude == null) {
      print('[Homepage] User location not available, skipping incident load');
      return;
    }

    try {
      if (!mounted) return;
      setState(() {
        _isLoadingIncidents = true;
      });

      await _incidentRepository.openZone();

      // Get all incidents
      final allIncidents = await _incidentRepository.getAllIncidents();

      // Filter incidents
      final now = DateTime.now();
      final twelveHoursAgo = now.subtract(const Duration(hours: 12));

      final filteredIncidents = allIncidents.where((incident) {
        // Filter by status: only "active"
        if (incident.status != 'active') return false;

        // Filter by time: within last 12 hours
        if (incident.datetime.isBefore(twelveHoursAgo)) return false;

        // Filter by distance: within radius
        final distance = _calculateDistance(
          _userLatitude!,
          _userLongitude!,
          incident.latitude,
          incident.longitude,
        );

        if (distance > _radiusFilter) return false;

        return true;
      }).toList();

      // Sort by datetime (most recent first)
      filteredIncidents.sort((a, b) => b.datetime.compareTo(a.datetime));

      // Convert to map format for UI
      final incidentMaps = await Future.wait(
        filteredIncidents.map((incident) async {
          // Parse title and description
          String title = incident.desc;
          String description = '';

          if (incident.desc.contains('\n---\n')) {
            final parts = incident.desc.split('\n---\n');
            if (parts.length >= 2) {
              title = parts[0].trim();
              description = parts.sublist(1).join('\n---\n').trim();
            }
          }

          // Calculate time ago
          final timeDiff = now.difference(incident.datetime);
          String timeAgo;
          if (timeDiff.inMinutes < 1) {
            timeAgo = 'Just now';
          } else if (timeDiff.inMinutes < 60) {
            timeAgo = '${timeDiff.inMinutes} min ago';
          } else if (timeDiff.inHours < 24) {
            timeAgo =
                '${timeDiff.inHours} hour${timeDiff.inHours > 1 ? 's' : ''} ago';
          } else {
            timeAgo =
                '${timeDiff.inDays} day${timeDiff.inDays > 1 ? 's' : ''} ago';
          }

          // Get location address
          String location = 'Loading address...';
          try {
            final placemarks = await placemarkFromCoordinates(
              incident.latitude,
              incident.longitude,
            );
            if (placemarks.isNotEmpty) {
              final place = placemarks[0];
              location = [
                place.street,
                place.thoroughfare,
                place.subLocality,
                place.locality,
              ].where((e) => e != null && e.isNotEmpty).join(', ');
            }
          } catch (e) {
            print('[Homepage] Geocoding error: $e');
          }

          return {
            'id': incident.iid,
            'iid': incident.iid, // For detail page
            'title': title,
            'description': description,
            'desc': incident.desc, // Full raw description for detail page
            'timestamp': timeAgo,
            'datetime': incident.datetime
                .toIso8601String(), // Full datetime for detail page
            'location': location,
            'severity': incident.incidentType == 'threat' ? 'high' : 'medium',
            'latitude': incident.latitude,
            'longitude': incident.longitude,
            'isAIGenerated':
                incident.isAIGenerated == 'true' ||
                incident.isAIGenerated == true,
            'incidentType': incident.incidentType,
            'mediaID': incident.mediaID, // For media fetching
            'uid': incident.uid, // For victim location tracking
            'status': incident.status, // For status display
          };
        }),
      );

      if (mounted) {
        setState(() {
          _rawIncidents = filteredIncidents;
          _incidents = incidentMaps;
          _isLoadingIncidents = false;
        });
        print(
          '[Homepage] Loaded ${_incidents.length} incidents within ${_radiusFilter}m',
        );
      }

      await _incidentRepository.closeZone();
    } catch (e) {
      print('[Homepage] Error loading incidents: $e');
      if (mounted) {
        setState(() {
          _isLoadingIncidents = false;
        });
      }
    }
  }

  // Show radius filter dialog
  void _showRadiusFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter Radius'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<double>(
                title: const Text('800 meters'),
                value: 800.0,
                groupValue: _radiusFilter,
                activeColor: AppTheme.primaryOrange,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _radiusFilter = value!;
                  });
                  _loadIncidents();
                },
              ),
              RadioListTile<double>(
                title: const Text('900 meters'),
                value: 900.0,
                groupValue: _radiusFilter,
                activeColor: AppTheme.primaryOrange,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _radiusFilter = value!;
                  });
                  _loadIncidents();
                },
              ),
              RadioListTile<double>(
                title: const Text('1000 meters'),
                value: 1000.0,
                groupValue: _radiusFilter,
                activeColor: AppTheme.primaryOrange,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() {
                    _radiusFilter = value!;
                  });
                  _loadIncidents();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTooltipOverlay() {
    _removeTooltip();

    final RenderBox? renderBox =
        _infoIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate tooltip position with screen boundary check
    const tooltipWidth = 280.0;
    const rightMargin = 16.0;
    double leftPosition = position.dx + size.width + 4;

    // If tooltip would go off screen, position it to the left of icon instead
    if (leftPosition + tooltipWidth + rightMargin > screenWidth) {
      leftPosition = position.dx - tooltipWidth - 4;
      // If still off screen on left, clamp to screen with margin
      if (leftPosition < rightMargin) {
        leftPosition = rightMargin;
      }
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + size.height + 4, // Below the icon
        left: leftPosition,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: tooltipWidth,
            constraints: BoxConstraints(
              maxWidth: screenWidth - (rightMargin * 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              "Continuously records IMU sensors and sound data to detect potential dangers or incidents happening around you in real-time",
              style: TextStyle(fontSize: 11, color: Colors.white, height: 1.4),
              softWrap: true,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(const Duration(seconds: 5), () {
      _removeTooltip();
    });
  }

  void _removeTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return const CommunityPage();
      case 2:
        return LodgeIncidentPage(incidentTypeNotifier: _incidentTypeNotifier);
      case 3:
        return ProfilePage();
      default:
        return _buildHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    print('HomePage building, selectedIndex: $_selectedIndex');

    return ValueListenableBuilder<String>(
      valueListenable: _incidentTypeNotifier,
      builder: (context, incidentType, child) {
        final isThreat = incidentType == 'threat';
        final appBarColor = isThreat
            ? Colors.red[700]!
            : AppTheme.primaryOrange;

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 3000),
              curve: Curves.easeInOut,
              color: appBarColor,
              child: AppBar(
                title: const Text('MYSafeZone'),
                scrolledUnderElevation: 0,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: _selectedIndex == 2
                    ? [
                        IconButton(
                          icon: const Icon(
                            Icons.history,
                            size: 28,
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.only(right: 24),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const IncidentHistoryPage(),
                              ),
                            );
                          },
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          body: _buildCurrentPage(),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home, 'Home', appBarColor),
                _buildNavItem(1, Icons.group, 'Community', appBarColor),
                _buildNavItem(2, Icons.add_box, 'Lodge', appBarColor),
                _buildNavItem(3, Icons.person, 'Profile', appBarColor),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    _refreshTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _debounceTimer?.cancel();
    _removeTooltip();
    _incidentTypeNotifier.dispose();
    _listOverlayPosition.dispose();
    _incidentRepository.closeZone();
    _userRepository.closeZone();
    super.dispose();
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color activeColor,
  ) {
    bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('Navigation tapped: $index');
          setState(() {
            _selectedIndex = index;
            // Reset to yellow/general when leaving Lodge page
            if (index != 2) {
              _incidentTypeNotifier.value = 'general';
            }
          });
        },
        borderRadius: BorderRadius.circular(50),
        highlightColor: Colors.grey.withOpacity(0.3),
        splashColor: Colors.grey.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 3000),
                curve: Curves.easeInOut,
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 3000),
                curve: Curves.easeInOut,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? activeColor : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle incident card tap - navigate to detail page
  void _onIncidentTap(Map<String, dynamic> incident) {
    debugPrint('[HomePage] 🔔 Incident tapped: ${incident['iid']}');

    // Navigate to incident detail page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentDetailPage(incident: incident),
      ),
    );
  }

  Widget _buildHomePage() {
    print('Building HomePage content');
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.7;
    final defaultListPosition = mapHeight - 250; // Start 250px visible map

    // Max collapse position - when dragged up, show only drag handle + safety trigger + divider
    // Drag handle (30px) + Safety trigger (100px) + Divider (1px) = ~131px
    final maxCollapsePosition = 200.0; // Adjusted for button with label

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Map at full 70% height (always loaded)
          SizedBox(
            height: mapHeight,
            child: MapWidget(
              incidents: _incidents,
              userLatitude: _userLatitude,
              userLongitude: _userLongitude,
              radiusMeters: _radiusFilter,
              onMapReady: (focusCallback) {
                _mapFocusCallback = focusCallback;
              },
              onMarkerTap: (incident) {
                _onIncidentTap(incident);
              },
            ),
          ),

          // Draggable Incident List Overlay (extends beyond body to cover nav bar)
          ValueListenableBuilder<double>(
            valueListenable: _listOverlayPosition,
            builder: (context, position, child) {
              return Positioned(
                top: defaultListPosition + position,
                left: 0,
                right: 0,
                bottom:
                    -80, // Extend below screen to cover nav bar and eliminate gap
                child: child!,
              );
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                // Drag down to reveal more map (negative position)
                // Drag up to collapse to divider line (positive position)
                double newPosition =
                    _listOverlayPosition.value + details.delta.dy;

                // Limit: -defaultListPosition+50 (full map) to maxCollapsePosition (divider line)
                if (newPosition < -defaultListPosition + 50) {
                  newPosition = -defaultListPosition + 50;
                } else if (newPosition > maxCollapsePosition) {
                  newPosition = maxCollapsePosition; // Stop at divider line
                }

                // Update position (direct update for smooth dragging)
                _listOverlayPosition.value = newPosition;
              },
              onVerticalDragEnd: (details) {
                // Snap to nearest position with smooth animation
                double targetPosition;
                final currentPosition = _listOverlayPosition.value;

                if (currentPosition < -defaultListPosition / 3) {
                  // Snap to expanded (show full map - 70% screen)
                  targetPosition = -defaultListPosition + 50;
                } else if (currentPosition > maxCollapsePosition / 2) {
                  // Snap to collapsed (show only up to divider line)
                  targetPosition = maxCollapsePosition;
                } else {
                  // Snap to default (250px map visible)
                  targetPosition = 0.0;
                }

                // Animate to target position smoothly
                final start = currentPosition;
                const duration = 200;
                const steps = 10;
                const stepDuration = duration ~/ steps;

                for (int i = 1; i <= steps; i++) {
                  Future.delayed(Duration(milliseconds: stepDuration * i), () {
                    if (mounted) {
                      _listOverlayPosition.value =
                          start + (targetPosition - start) * (i / steps);
                    }
                  });
                }
              },
              child: Container(
                // No animation during drag for better performance
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Drag handle
                        Container(
                          height: 30,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(top: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        // Safety Trigger Section (below drag handle)
                        Container(
                          height: 100,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Consumer<SafetyServiceProvider>(
                            builder: (context, safetyProvider, child) {
                              return Stack(
                                children: [
                                  // Centered column with label and button
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Safety Trigger label with info icon on the left
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              key: _infoIconKey,
                                              onTap: _showTooltipOverlay,
                                              child: Icon(
                                                Icons.info_outline,
                                                color: Colors.grey[600],
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Safety Trigger',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // Activated/Deactivated button
                                        ElevatedButton(
                                          onPressed: () {
                                            _toggleService(
                                              !safetyProvider.isEnabled,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                safetyProvider.isEnabled
                                                ? Colors.green
                                                : Colors.grey[400],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            elevation: 3,
                                            minimumSize: const Size(160, 52),
                                            maximumSize: const Size(200, 52),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              safetyProvider.isEnabled
                                                  ? 'ACTIVATED'
                                                  : 'DEACTIVATED',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Test trigger link to the right
                                  if (safetyProvider.isEnabled)
                                    Positioned(
                                      left:
                                          MediaQuery.of(context).size.width /
                                              2 +
                                          100, // Adjusted for button width
                                      right:
                                          8, // Add right constraint to prevent overflow
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: TextButton(
                                          onPressed: () {
                                            debugPrint(
                                              '[HomePage] 🧪 TEST BUTTON PRESSED',
                                            );
                                            safetyProvider.manualTrigger(
                                              'TEST TRIGGER',
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Test Trigger',
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.visible,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Divider
                        Divider(height: 1, color: Colors.grey[300]),
                        // Nearby Incidents Header
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Nearby Incidents',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: _isLoadingIncidents
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryOrange,
                                  ),
                                )
                              : _incidents.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.location_searching,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No incidents found nearby',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Within ${_radiusFilter.toInt()}m radius',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _incidents.length,
                                  shrinkWrap: false,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 8,
                                    bottom: 100, // Padding for bottom nav bar
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildIncidentCard(
                                      _incidents[index],
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _listOverlayPosition,
            builder: (context, position, _) {
              final isCollapsed = position > maxCollapsePosition / 2;
              return ChatbotWidget(isCollapsed: isCollapsed);
            },
          ),
          // Filter button - bottom right when expanded/default, top right when collapsed
          ValueListenableBuilder<double>(
            valueListenable: _listOverlayPosition,
            builder: (context, position, _) {
              final isCollapsed = position > maxCollapsePosition / 2;
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: isCollapsed
                    ? null // Move to top when collapsed
                    : 92, // Stay at bottom when expanded/default (above chatbot)
                top: isCollapsed
                    ? 16 // Top position when collapsed
                    : null,
                right: 16,
                child: FloatingActionButton(
                  heroTag: "filter_fab",
                  onPressed: _showRadiusFilterDialog,
                  backgroundColor: AppTheme.primaryOrange,
                  child: const Icon(Icons.filter_list, color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    Color borderColor;
    switch (incident['severity']) {
      case 'high':
        borderColor = Colors.red;
        break;
      case 'medium':
        borderColor = Colors.orange;
        break;
      case 'low':
        borderColor = Colors.yellow;
        break;
      default:
        borderColor = Colors.grey;
    }

    return InkWell(
      onTap: () => _onIncidentTap(incident),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    incident['title'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                if (incident['isAIGenerated'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.purple.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 12,
                                          color: Colors.purple[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'AI',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            incident['timestamp'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              incident['location'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
