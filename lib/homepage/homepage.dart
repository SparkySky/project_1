import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import '../demo/push_notification_demo.dart';
import 'map_widget.dart';
import '../app_theme.dart';
import 'chatbot_widget.dart';
import '../community/community_page.dart';
import '../lodge/lodge_incident_page.dart';
import '../lodge/incident_history_page.dart';
import '../profile/profile_page.dart';
import '../user_management.dart';
import 'package:provider/provider.dart';
import '../providers/safety_service_provider.dart';
import '../tutorial/homepage_tutorial.dart';
import '../repository/incident_repository.dart';
import '../repository/user_repository.dart';
import '../models/clouddb_model.dart';
import '../sensors/location_centre.dart';
import 'package:agconnect_auth/agconnect_auth.dart';
import 'incident_detail_page.dart';
import '../data/emergency_services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _isServiceRunning = false;
  final _backgroundService = FlutterBackgroundService();
  final GlobalKey _infoIconKey = GlobalKey();
  bool _isRefreshing = false;
  int _mapRebuildKey = 0; // Key to force map rebuild on resume
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
  String?
  _incidentTypeFilter; // null = all types, or specific type like 'threat', 'general', etc.
  String _sortBy = 'time'; // 'time' or 'distance'
  bool _sortAscending =
      false; // false = descending (newest/closest first), true = ascending
  // Status filters (checkboxes)
  bool _showActive = true;
  bool _showEndedByBtn = true;
  bool _showResolved = false;
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
  final ScrollController _incidentListScrollController = ScrollController();
  final Map<String, GlobalKey> _incidentCardKeys =
      {}; // Keys for each incident card
  String? _currentUserId;
  bool _allowDiscoverable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
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
          // Update location and timestamp
          userData.latitude = location.latitude;
          userData.longitude = location.longitude;
          userData.locUpdateTime = DateTime.now(); // Update timestamp

          await _userRepository.upsertUser(userData);
          print(
            '[Homepage] ✅ Updated user location to CloudDB: ${location.latitude}, ${location.longitude} at ${userData.locUpdateTime}',
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
        // Filter by status based on checkboxes
        bool statusMatch = false;
        if (incident.status == 'active' && _showActive) {
          if (incident.datetime.isBefore(twelveHoursAgo)) return false;
          statusMatch = true;
        } else if (incident.status == 'endedByBtn' && _showEndedByBtn) {
          if (incident.datetime.isBefore(twelveHoursAgo)) return false;
          statusMatch = true;
        } else if (incident.status == 'resolved' && _showResolved) {
          if (incident.datetime.isBefore(twelveHoursAgo)) return false;
          statusMatch = true;
        }

        if (!statusMatch) return false;

        // Filter by incident type if specified
        if (_incidentTypeFilter != null &&
            incident.incidentType != _incidentTypeFilter) {
          return false;
        }

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

      // Calculate distances for sorting
      final incidentsWithDistance = filteredIncidents.map((incident) {
        final distance = _calculateDistance(
          _userLatitude!,
          _userLongitude!,
          incident.latitude,
          incident.longitude,
        );
        return {'incident': incident, 'distance': distance};
      }).toList();

      // Sort based on user preference
      if (_sortBy == 'distance') {
        incidentsWithDistance.sort((a, b) {
          final comparison = (a['distance'] as double).compareTo(
            b['distance'] as double,
          );
          // For distance: ascending = closest first, descending = farthest first
          return _sortAscending ? comparison : -comparison;
        });
      } else {
        // Sort by time
        incidentsWithDistance.sort((a, b) {
          final comparison = (a['incident'] as incidents).datetime.compareTo(
            (b['incident'] as incidents).datetime,
          );
          // For time: ascending = oldest first, descending = newest first
          return _sortAscending ? comparison : -comparison;
        });
      }

      // Extract sorted incidents
      final sortedIncidents = incidentsWithDistance
          .map((e) => e['incident'] as incidents)
          .toList();

      // Convert to map format for UI
      final incidentMaps = await Future.wait(
        sortedIncidents.map((incident) async {
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

          // Calculate distance from user
          final distance = _calculateDistance(
            _userLatitude!,
            _userLongitude!,
            incident.latitude,
            incident.longitude,
          );

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

          // Format status label and color
          String statusLabel = '';
          Color statusColor = Colors.blue;
          IconData statusIcon = Icons.info_outline;

          switch (incident.status) {
            case 'active':
              statusLabel = 'Active';
              statusColor = Colors.red;
              statusIcon = Icons.warning_amber_rounded;
              break;
            case 'endedByBtn':
              statusLabel = 'Button Ended';
              statusColor = Colors.green;
              statusIcon = Icons.check_circle_outline;
              break;
            case 'resolved':
              statusLabel = 'Resolved';
              statusColor = Colors.grey;
              statusIcon = Icons.done_all;
              break;
            default:
              statusLabel = incident.status;
              statusColor = Colors.blue;
              statusIcon = Icons.info_outline;
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
            'statusLabel': statusLabel, // Human-readable status label
            'statusColor': statusColor, // Status tag color
            'statusIcon': statusIcon, // Status tag icon
            'distance': distance, // Distance from user in meters
          };
        }),
      );

      if (mounted) {
        setState(() {
          _rawIncidents = sortedIncidents;
          _incidents = incidentMaps;
          _isLoadingIncidents = false;

          // Create GlobalKeys for each incident card
          _incidentCardKeys.clear();
          for (var incident in incidentMaps) {
            final iid = incident['iid'] as String?;
            if (iid != null) {
              _incidentCardKeys[iid] = GlobalKey();
            }
          }
        });
        print(
          '[Homepage] Loaded ${_incidents.length} incidents within ${_radiusFilter}m (Type: ${_incidentTypeFilter ?? 'all'}, Sort: $_sortBy ${_sortAscending ? 'asc' : 'desc'})',
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

  // Format distance for display
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      final distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)}km';
    }
  }

  // Build status toggle button
  Widget _buildStatusToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryOrange
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryOrange
                : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // Show filters and sorting dialog (compact version)
  void _showFiltersDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filters & Sorting'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Toggle Buttons Section
                    const Text(
                      'Show Status',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusToggle(
                          label: 'Active',
                          isSelected: _showActive,
                          onTap: () {
                            setDialogState(() {
                              _showActive = !_showActive;
                            });
                          },
                        ),
                        _buildStatusToggle(
                          label: 'Button Ended',
                          isSelected: _showEndedByBtn,
                          onTap: () {
                            setDialogState(() {
                              _showEndedByBtn = !_showEndedByBtn;
                            });
                          },
                        ),
                        _buildStatusToggle(
                          label: 'Resolved',
                          isSelected: _showResolved,
                          onTap: () {
                            setDialogState(() {
                              _showResolved = !_showResolved;
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Distance Range (compact buttons)
                    const Text(
                      'Distance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusToggle(
                          label: '800m',
                          isSelected: _radiusFilter == 800.0,
                          onTap: () {
                            setDialogState(() {
                              _radiusFilter = 800.0;
                            });
                          },
                        ),
                        _buildStatusToggle(
                          label: '900m',
                          isSelected: _radiusFilter == 900.0,
                          onTap: () {
                            setDialogState(() {
                              _radiusFilter = 900.0;
                            });
                          },
                        ),
                        _buildStatusToggle(
                          label: '1km',
                          isSelected: _radiusFilter == 1000.0,
                          onTap: () {
                            setDialogState(() {
                              _radiusFilter = 1000.0;
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Incident Type (compact buttons)
                    const Text(
                      'Type',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusToggle(
                          label: 'All',
                          isSelected: _incidentTypeFilter == null,
                          onTap: () {
                            setDialogState(() {
                              _incidentTypeFilter = null;
                            });
                          },
                        ),
                        _buildStatusToggle(
                          label: 'Threat',
                          isSelected: _incidentTypeFilter == 'threat',
                          onTap: () {
                            setDialogState(() {
                              _incidentTypeFilter = 'threat';
                            });
                          },
                        ),
                        _buildStatusToggle(
                          label: 'General',
                          isSelected: _incidentTypeFilter == 'general',
                          onTap: () {
                            setDialogState(() {
                              _incidentTypeFilter = 'general';
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Sort (compact buttons)
                    const Text(
                      'Sort',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildStatusToggle(
                          label: 'Time',
                          isSelected: _sortBy == 'time',
                          onTap: () {
                            setDialogState(() {
                              _sortBy = 'time';
                            });
                          },
                        ),
                        _buildStatusToggle(
                          label: 'Distance',
                          isSelected: _sortBy == 'distance',
                          onTap: () {
                            setDialogState(() {
                              _sortBy = 'distance';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Sort Order Toggle
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            _sortAscending = !_sortAscending;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primaryOrange,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortAscending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 18,
                                color: AppTheme.primaryOrange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _sortBy == 'time'
                                    ? (_sortAscending
                                          ? 'Oldest First'
                                          : 'Newest First')
                                    : (_sortAscending
                                          ? 'Closest First'
                                          : 'Farthest First'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      // Trigger rebuild with new filters
                    });
                    _loadIncidents();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
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
        return ProfilePage(
          onNavigateToHomeWithTutorial: () async {
            // Switch to home tab
            setState(() {
              _selectedIndex = 0;
            });

            // Wait for the UI to update
            await Future.delayed(const Duration(milliseconds: 500));

            // Show tutorial
            if (mounted) {
              HomePageTutorialManager.showTutorial(context);
            }
          },
        );
      case 4:
        // TODO: Remove this page after testing
        return PushNotificationDemo();
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
          resizeToAvoidBottomInset:
              false, // Prevent keyboard from affecting map
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
                actions: _selectedIndex == 0
                    ? [
                        // Refresh button for Home page
                        IconButton(
                          icon: _isRefreshing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh,
                                  size: 28,
                                  color: Colors.white,
                                ),
                          padding: const EdgeInsets.only(right: 24),
                          onPressed: _isRefreshing ? null : _refreshData,
                          tooltip: 'Refresh location and incidents',
                        ),
                      ]
                    : _selectedIndex == 2
                    ? [
                        // History button for Profile page
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
                // _buildNavItem(4, Icons.person, 'Debug', appBarColor),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Manual refresh - get latest location and incidents
  Future<void> _refreshData() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() {
      _isRefreshing = true;
    });

    debugPrint('[HomePage] 🔄 Manual refresh triggered');

    try {
      // Reload location and incidents
      await Future.wait([_getUserLocation(), _loadIncidents()]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Location and incidents refreshed'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[HomePage] ❌ Refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Failed to refresh'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - reload everything
      debugPrint(
        '[HomePage] 🔄 App resumed, reloading map, location and incidents',
      );

      // Force rebuild to refresh map by changing its key
      if (mounted) {
        setState(() {
          _mapRebuildKey++; // Increment key to force new MapWidget instance
          debugPrint('[HomePage] 🗺️ Map rebuild key: $_mapRebuildKey');
        });
      }

      // Reload location and incidents
      _getUserLocation();
      _loadIncidents();

      debugPrint('[HomePage] ✅ Map and data refreshed after resume');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    _tooltipTimer?.cancel();
    _refreshTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _debounceTimer?.cancel();
    _removeTooltip();
    _incidentTypeNotifier.dispose();
    _listOverlayPosition.dispose();
    _incidentListScrollController.dispose();
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
  void _onIncidentTap(
    Map<String, dynamic> incident, {
    bool fromMarker = false,
  }) {
    debugPrint('[HomePage] 🔔 Incident tapped: ${incident['iid']}');

    // If tapped from marker, scroll to incident card and set list to middle position
    if (fromMarker) {
      _scrollToIncident(incident['iid']);
      return;
    }

    // Navigate to incident detail page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncidentDetailPage(incident: incident),
      ),
    );
  }

  // Scroll to incident card in the list
  void _scrollToIncident(String incidentId) {
    debugPrint('[HomePage] 🎯 Attempting to scroll to incident: $incidentId');

    // Find the index of the incident in the filtered list
    final index = _incidents.indexWhere(
      (incident) => incident['id'] == incidentId,
    );

    if (index == -1) {
      debugPrint('[HomePage] ❌ Cannot scroll: incident not found in list');
      debugPrint('[HomePage] Incident ID: $incidentId');
      debugPrint('[HomePage] Total incidents: ${_incidents.length}');
      return;
    }

    debugPrint('[HomePage] ✅ Found incident at index $index');

    // Set overlay to middle/default position (0) to make list visible
    _listOverlayPosition.value = 0.0;
    debugPrint('[HomePage] ✅ List position set to middle (0.0)');

    // Step 1: Reset scroll to top first to recalibrate
    if (_incidentListScrollController.hasClients) {
      _incidentListScrollController.jumpTo(0);
      debugPrint('[HomePage] ⬆️ Reset scroll to top for recalibration');
    }

    // Step 2: Wait for overlay animation, then scroll to calculated position
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || !_incidentListScrollController.hasClients) {
        debugPrint(
          '[HomePage] ⚠️ Cannot scroll - widget not mounted or no clients',
        );
        return;
      }

      // Calculate scroll position from top (0)
      // Drag handle: 30px
      // Safety trigger section: 100px (container height, padding is inside)
      // Divider: 1px
      // Top padding of list: 16px
      // Each incident card: padding(16px) + content(~180px) + margin-bottom(12px) ≈ 208px average
      const double dragHandleHeight = 30.0;
      const double safetyTriggerHeight =
          100.0; // Safety trigger container height
      const double dividerHeight = 1.0;
      const double topPadding = 16.0;
      const double cardHeight = 208.0; // More accurate average card height
      const double totalHeaderHeight =
          dragHandleHeight +
          safetyTriggerHeight +
          dividerHeight +
          topPadding; // = 147px

      final double targetPosition = (index * cardHeight) + totalHeaderHeight;

      // Ensure we don't scroll past the end
      final double maxScroll =
          _incidentListScrollController.position.maxScrollExtent;
      final double scrollTo = targetPosition > maxScroll
          ? maxScroll
          : targetPosition;

      debugPrint('[HomePage] 📍 Scroll calculation:');
      debugPrint('  - Index: $index');
      debugPrint('  - Card height: $cardHeight px');
      debugPrint('  - Header height: $totalHeaderHeight px');
      debugPrint('  - Target position: $targetPosition px');
      debugPrint('  - Max scroll: $maxScroll px');
      debugPrint('  - Final scroll to: $scrollTo px');

      try {
        _incidentListScrollController.animateTo(
          scrollTo,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        debugPrint(
          '[HomePage] ✅ Successfully scrolled to incident: $incidentId',
        );
      } catch (e) {
        debugPrint('[HomePage] ❌ Error scrolling: $e');
      }
    });
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
            child: Builder(
              builder: (context) {
                // Calculate emergency services with debug logging
                List<EmergencyService>? emergencyServices;

                print('[HomePage] 🔍 Checking emergency services...');
                print(
                  '[HomePage] User location: $_userLatitude, $_userLongitude',
                );
                print(
                  '[HomePage] Total services in DB: ${EmergencyServicesData.allServices.length}',
                );

                if (_userLatitude != null &&
                    _userLongitude != null &&
                    _userLatitude != 0.0 &&
                    _userLongitude != 0.0) {
                  print(
                    '[HomePage] ✅ Valid user location: ($_userLatitude, $_userLongitude)',
                  );

                  emergencyServices = EmergencyServicesData.getServicesWithinRadius(
                    _userLatitude!,
                    _userLongitude!,
                    50.0, // TEMP: 50km radius for testing (change back to 1.5 later)
                  );

                  print(
                    '[HomePage] 📍 Emergency services within 1.5km: ${emergencyServices.length}',
                  );

                  if (emergencyServices.isEmpty) {
                    print(
                      '[HomePage] ⚠️ No services found within 1.5km, trying 5km...',
                    );
                    final services5km =
                        EmergencyServicesData.getServicesWithinRadius(
                          _userLatitude!,
                          _userLongitude!,
                          5.0,
                        );
                    print(
                      '[HomePage] Services within 5km: ${services5km.length}',
                    );
                    if (services5km.isNotEmpty) {
                      print(
                        '[HomePage] Closest service: ${services5km.first.name}',
                      );
                    }
                  } else {
                    for (var service in emergencyServices) {
                      print('[HomePage]   - ${service.type}: ${service.name}');
                    }
                  }
                } else {
                  print('[HomePage] ❌ User location not available or invalid');
                  print('[HomePage]    _userLatitude: $_userLatitude');
                  print('[HomePage]    _userLongitude: $_userLongitude');
                }

                return MapWidget(
                  key: ValueKey(
                    _mapRebuildKey,
                  ), // Force rebuild when key changes
                  incidents: _incidents,
                  emergencyServices: emergencyServices,
                  userLatitude: _userLatitude,
                  userLongitude: _userLongitude,
                  radiusMeters: _radiusFilter,
                  onMapReady: (focusCallback) {
                    _mapFocusCallback = focusCallback;
                  },
                  onMarkerTap: (incident) {
                    _onIncidentTap(incident, fromMarker: true);
                  },
                );
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
              onVerticalDragStart: (details) {
                // Allow system gestures at the very bottom of screen
                final screenHeight = MediaQuery.of(context).size.height;
                final touchY = details.globalPosition.dy;

                // If touch is in bottom 40px, don't capture (allow system back gesture)
                if (touchY > screenHeight - 40) {
                  debugPrint(
                    '[HomePage] ⚠️ Touch at bottom edge, allowing system gesture',
                  );
                  return;
                }
              },
              onVerticalDragUpdate: (details) {
                // Allow system gestures at the very bottom of screen
                final screenHeight = MediaQuery.of(context).size.height;
                final touchY = details.globalPosition.dy;

                // If touch is in bottom 40px, don't capture the gesture
                if (touchY > screenHeight - 40) {
                  return;
                }

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
                        SizedBox(
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
                                  controller: _incidentListScrollController,
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
                  onPressed: _showFiltersDialog,
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

    // Get the GlobalKey for this incident
    final key = _incidentCardKeys[incident['iid']];

    return InkWell(
      key: key, // Assign the key here for scrolling
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
                      // Status, Distance, and AI tags row
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Status tag (always shown)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (incident['statusColor'] as Color)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (incident['statusColor'] as Color)
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  incident['statusIcon'] as IconData,
                                  size: 12,
                                  color: incident['statusColor'] as Color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  incident['statusLabel'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: incident['statusColor'] as Color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Distance tag (always shown)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location,
                                  size: 12,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDistance(
                                    incident['distance'] as double,
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // AI tag (conditional)
                          if (incident['isAIGenerated'] == true)
                            Container(
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
