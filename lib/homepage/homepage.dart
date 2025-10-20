import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'map_widget.dart';
import '../app_theme.dart';
import 'chatbot_widget.dart';
import '../community/community_page.dart';
import '../notification_page.dart';
import '../profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // states for service status - Safety Trigger
  bool _isServiceRunning = false;
  final _backgroundService = FlutterBackgroundService();

  int _selectedIndex = 0;

  // Init Safety Trigger BG process
  @override
  void initState() {
    super.initState();
    // Check initial service status when the widget loads
    _backgroundService.isRunning().then((value) {
      if (mounted) {
        setState(() {
          _isServiceRunning = value;
        });
      }
    });
  }

  // Start/Stop Safety Trigger BG process
  void _toggleService(bool value) async {
    if (value) {
      // Start the service configured in main.dart
      await _backgroundService.startService();
    } else {
      // Invoke the 'stopService' command defined in background_service.dart
      _backgroundService.invoke("stopService");
    }
    setState(() {
      _isServiceRunning = value;
    });
  }


  // Dummy incident data - will be replaced with cloud DB
  final List<Map<String, dynamic>> incidents = [
    {
      'id': 1,
      'title': 'Suspicious Person Spotted',
      'timestamp': '3 min ago',
      'location': 'Jalan Pasar, Bukit Mertajam, 14000',
      'severity': 'high',
    },
    {
      'id': 2,
      'title': 'Vehicle Break-in Reported',
      'timestamp': '15 min ago',
      'location': 'Persiaran Bukit Mertajam, 14000',
      'severity': 'medium',
    },
    {
      'id': 3,
      'title': 'Theft Attempt',
      'timestamp': '1 hour ago',
      'location': 'Jalan Besar, Bukit Mertajam, 14000',
      'severity': 'high',
    },
    {
      'id': 4,
      'title': 'Vandalism Spotted',
      'timestamp': '2 hours ago',
      'location': 'Taman Bukit Mertajam, 14000',
      'severity': 'low',
    },
    {
      'id': 5,
      'title': 'Assault Reported',
      'timestamp': '3 hours ago',
      'location': 'Jalan Raja Uda, Bukit Mertajam, 14000',
      'severity': 'high',
    },
  ];

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return const CommunityPage();
      case 2:
        return const NotificationPage();
      case 3:
        return ProfilePage();
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
        // Add the toggle switch to the AppBar actions
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_isServiceRunning ? "ON" : "OFF", style: TextStyle(fontSize: 10)),
                Switch(
                  value: _isServiceRunning,
                  onChanged: _toggleService,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          _buildCurrentPage(),
          const ChatbotWidget(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.group_outlined, 'Community'),
            _buildNavItem(2, Icons.notifications_outlined, 'Notification'),
            _buildNavItem(3, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
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
    return Column(
      key: const PageStorageKey<String>('homePage'),
      children: [
        // Map Section - Fixed height
        SizedBox( // Apply fixed height here
          height: 250, // Or whatever height you want for the map
          child: MapWidget(incidents: incidents), // ONLY ONE MapWidget here
        ),

        // Nearby Incidents Section - Takes remaining space
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Nearby Incidents',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded( // This Expanded fills the space within the inner Column
                child: ListView.builder(
                  // Assuming 'incidents' is defined elsewhere in your state
                  itemCount: incidents.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    // Assuming '_buildIncidentCard' is defined elsewhere
                    return _buildIncidentCard(incidents[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncidentCard(Map<String, dynamic> incident) {
    // Determine border color based on severity
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
            // Left colored border
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
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and timestamp row
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
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.grey[600],
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