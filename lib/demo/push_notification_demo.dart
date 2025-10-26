import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/push_notification_service.dart';
import '../repository/user_repository.dart';
import '../models/users.dart';

class PushNotificationDemo extends StatefulWidget {
  const PushNotificationDemo({super.key});

  @override
  State<PushNotificationDemo> createState() => _PushNotificationDemoState();
}

class _PushNotificationDemoState extends State<PushNotificationDemo> {
  final PushNotificationService _pushService = PushNotificationService();
  final UserRepository _userRepository = UserRepository();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  List<Users> _users = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _initializeLocalNotifications();
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(initializationSettings);
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      await _userRepository.openZone();
      final users = await _userRepository.getAllUsers();
      setState(() => _users = users);
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      await _userRepository.closeZone();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotification() async {
    try {
      await _pushService.notifyNearbyUsers(
        incidentLatitude: 3.1390, // Kuala Lumpur coordinates
        incidentLongitude: 101.6869,
        incidentType: 'emergency',
        incidentDescription: 'Test emergency incident for demonstration',
        incidentId: 'test-${DateTime.now().millisecondsSinceEpoch}',
        radiusKm: 10.0, // 10km radius for testing
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent! Check console logs.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error testing notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _testOwnDeviceNotification() async {
    try {
      // Show local notification immediately
      await _localNotifications.show(
        1,
        '🚨 Emergency Alert',
        'Test emergency incident reported nearby',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'emergency_alerts',
            'Emergency Alerts',
            channelDescription: 'Notifications for emergency incidents',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );

      // Also subscribe to topic for future notifications
      await _pushService.subscribeToEmergencyAlerts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Emergency alert notification sent! Check your notification panel.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notification Demo'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Push Notification System Demo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'This demo shows how the push notification system works:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('1. Retrieves all users from CloudDB'),
            const Text('2. Filters users within 10km of test location'),
            const Text('3. Sends notifications to filtered users'),
            const Text('4. Logs notification details to console'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _testNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test Push Notification'),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: _testOwnDeviceNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Test Emergency Alert on Device'),
            ),
            const SizedBox(height: 24),
            Text(
              'Total Users: ${_users.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Users with Location: ${_users.where((u) => u.latitude != null && u.longitude != null).length}',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Users allowing Emergency Alerts: ${_users.where((u) => u.allowEmergencyAlert == true).length}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    child: ListTile(
                      title: Text(user.username ?? 'Unknown User'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UID: ${user.uid}'),
                          Text(
                            'Location: ${user.latitude?.toStringAsFixed(4)}, ${user.longitude?.toStringAsFixed(4)}',
                          ),
                          Text(
                            'Emergency Alerts: ${user.allowEmergencyAlert == true ? 'Enabled' : 'Disabled'}',
                          ),
                        ],
                      ),
                      trailing: user.latitude != null && user.longitude != null
                          ? const Icon(Icons.location_on, color: Colors.green)
                          : const Icon(Icons.location_off, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
