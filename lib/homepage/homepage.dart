import 'package:flutter/material.dart';
import 'post_model.dart';
import 'post_card.dart';
import 'map_widget.dart';
import '../app_theme.dart';
import '../community_page.dart';
import '../notification_page.dart';
import '../profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  
  final List<Post> incidents = [
    Post(
      id: 1,
      author: 'Sarah Chen',
      district: 'Bukit Mertajam',
      postcode: '14000',
      time: '2 hours ago',
      type: 'discuss',
      title: 'Street lighting improvement needed',
      content: 'The street lights along Jalan Besar are not working properly at night.',
      likes: 24,
      comments: 8,
      avatar: '👩‍🦰',
    ),
    Post(
      id: 2,
      author: 'Ahmad Rashid',
      district: 'Bukit Mertajam',
      postcode: '14000',
      time: '4 hours ago',
      type: 'alert',
      title: '🚨 Traffic accident on Jalan Raja',
      content: 'Accident between Jalan Raja and Jalan Dato - expect delays.',
      likes: 45,
      comments: 12,
      avatar: '👨‍💼',
    ),
    Post(
      id: 3,
      author: 'Mei Ling Wong',
      district: 'Bukit Mertajam',
      postcode: '14000',
      time: '6 hours ago',
      type: 'discuss',
      title: 'Community watch group forming',
      content: 'Interested in joining a neighborhood watch? We are organizing regular patrols.',
      likes: 67,
      comments: 31,
      avatar: '👩‍🦱',
    ),
    Post(
      id: 4,
      author: 'Ravi Kumar',
      district: 'Bukit Mertajam',
      postcode: '14000',
      time: '8 hours ago',
      type: 'alert',
      title: '🚨 Suspicious activity reported',
      content: 'Multiple reports of loitering near the market area. Police notified.',
      likes: 38,
      comments: 15,
      avatar: '👨‍🦱',
    ),
    Post(
      id: 5,
      author: 'Priya Sharma',
      district: 'Bukit Mertajam',
      postcode: '14000',
      time: '10 hours ago',
      type: 'discuss',
      title: 'Health and safety at the community center',
      content: 'Planning a first aid training workshop. Anyone interested?',
      likes: 22,
      comments: 9,
      avatar: '👩‍⚕️',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MYSafeZone'),
      ),
      body: _buildPage(_selectedIndex),
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

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _buildHomePage();
      case 1:
        return const CommunityPage();
      case 2:
        return const NotificationPage();
      case 3:
        return const ProfilePage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return Column(
      children: [
        // Map Section - 1/3 of screen
        MapWidget(
          height: MediaQuery.of(context).size.height * 0.30,
        ),
        // Nearby Incidents Section - 2/3 of screen
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
              Expanded(
                child: ListView.builder(
                  itemCount: incidents.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    return PostCard(post: incidents[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}