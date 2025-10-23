import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'map_widget.dart';
import '../app_theme.dart';
import 'chatbot_widget.dart';
import '../community/community_page.dart';
import '../lodge/lodge_incident_page.dart';
import '../lodge/incident_history_page.dart';
import '../notification_page.dart';
import '../profile/profile_page.dart';
import '../user_management.dart';

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

  List<Map<String, dynamic>> _incidents = [
    {
      'id': 1,
      'title': 'Suspicious Person Spotted',
      'timestamp': '3 min ago',
      'location': 'Loading address...',
      'severity': 'high',
      'latitude': 5.3654,
      'longitude': 100.4632,
    },
    {
      'id': 2,
      'title': 'Vehicle Break-in Reported',
      'timestamp': '15 min ago',
      'location': 'Loading address...',
      'severity': 'medium',
      'latitude': 5.3601,
      'longitude': 100.4589,
    },
    {
      'id': 3,
      'title': 'Theft Attempt',
      'timestamp': '1 hour ago',
      'location': 'Loading address...',
      'severity': 'high',
      'latitude': 5.3638,
      'longitude': 100.4605,
    },
    {
      'id': 4,
      'title': 'Vandalism Spotted',
      'timestamp': '2 hours ago',
      'location': 'Loading address...',
      'severity': 'low',
      'latitude': 5.3569,
      'longitude': 100.4667,
    },
    {
      'id': 5,
      'title': 'Assault Reported',
      'timestamp': '3 hours ago',
      'location': 'Loading address...',
      'severity': 'high',
      'latitude': 5.4294,
      'longitude': 100.3832,
    },
    {
      'id': 6,
      'title': 'Assault Reported',
      'timestamp': '2 hours ago',
      'location': 'Loading address...',
      'severity': 'high',
      'latitude': 4.6133,
      'longitude': 101.1044,
    },
  ];

  @override
  void initState() {
    super.initState();
    _backgroundService.isRunning().then((value) {
      if (mounted) {
        setState(() {
          _isServiceRunning = value;
        });
      }
    });
    _getAddressesForIncidents();
  }

  void _toggleService(bool value) async {
    if (value) {
      await _backgroundService.startService();
    } else {
      _backgroundService.invoke("stopService");
    }
    setState(() {
      _isServiceRunning = value;
    });
  }

  Future<void> _getAddressesForIncidents() async {
    print('[Geocoding] Starting geocoding process...');
    List<Map<String, dynamic>> updatedIncidents = List.from(_incidents);

    for (int i = 0; i < updatedIncidents.length; i++) {
      final incident = updatedIncidents[i];
      print(
        '[Geocoding] Attempting to geocode for incident ${incident['id']} at latitude: ${incident['latitude']}, longitude: ${incident['longitude']}',
      );
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          incident['latitude'],
          incident['longitude'],
        );

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks[0];
          final String address = [
            place.street,
            place.thoroughfare,
            place.subLocality,
            place.locality,
            place.postalCode,
            place.administrativeArea,
            place.country,
          ].where((element) => element != null && element.isNotEmpty).join(', ');
          updatedIncidents[i]['location'] = address;
          print('[Geocoding] Incident ${incident['id']} location updated to: $address');
        } else {
          updatedIncidents[i]['location'] = 'Address not found';
          print('[Geocoding] No placemarks found for incident ${incident['id']}.');
        }
      } catch (e) {
        print('[Geocoding] Error during geocoding for incident ${incident['id']}: $e');
        updatedIncidents[i]['location'] = 'Geocoding error';
      }
    }

    if (mounted) {
      setState(() {
        _incidents = updatedIncidents;
        print('[Geocoding] State updated with new incident locations. Total incidents: ${_incidents.length}');
      });
    }
    print('[Geocoding] Geocoding process finished.');
  }

  void _showTooltipOverlay() {
    _removeTooltip();

    final RenderBox? renderBox = _infoIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + size.height + 4,
        right: MediaQuery.of(context).size.width - position.dx - size.width,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
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
              "Actively listens to sounds around you to detect potential threats or incidents nearby",
              style: TextStyle(fontSize: 10, color: Colors.white),
              maxLines: 2,
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
        return LodgeIncidentPage();
      case 3:
        return ProfilePage();
      case 4:
        return UserManagementScreen();
      default:
        return _buildHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    print('HomePage building, selectedIndex: $_selectedIndex');

    return Scaffold(
      appBar: AppBar(
        title: const Text('MYSafeZone'),
        scrolledUnderElevation: 0,
        actions: _selectedIndex == 2 ? [
          IconButton(
            icon: const Icon(Icons.history, size: 28, color: Colors.white),
            padding: const EdgeInsets.only(right: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IncidentHistoryPage(),
                ),
              );
            },
          ),
        ] : null,
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.group, 'Community'),
            _buildNavItem(2, Icons.add_box, 'Lodge'),
            _buildNavItem(3, Icons.person, 'Profile'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    _removeTooltip();
    super.dispose();
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('Navigation tapped: $index');
          setState(() {
            _selectedIndex = index;
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
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryOrange : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppTheme.primaryOrange : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    print('Building HomePage content');
    return Stack(
      children: [
        Column(
          key: const PageStorageKey<String>('homePage'),
          children: [
            SizedBox(height: 250, child: MapWidget(incidents: _incidents)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nearby Incidents',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: GestureDetector(
                                key: _infoIconKey,
                                onTap: _showTooltipOverlay,
                                child: Icon(
                                  Icons.info_outline,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: _isServiceRunning,
                                  onChanged: _toggleService,
                                  activeColor: Colors.orange,
                                  activeTrackColor: Colors.orange.withOpacity(0.5),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const Text(
                                  "Sound Detector",
                                  style: TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _incidents.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        return _buildIncidentCard(_incidents[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const ChatbotWidget(),
      ],
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

    return Container(
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
                          child: Text(
                            incident['title'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
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
    );
  }
}