import 'package:huawei_push/huawei_push.dart';
import 'package:flutter/foundation.dart';
import '../models/users.dart';
import '../repository/user_repository.dart';
import '../util/location_utils.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final UserRepository _userRepository = UserRepository();

  /// Initialize push notification service
  Future<void> initialize() async {
    try {
      // Request push token
      Push.getToken('HCM');

      // Listen for token updates
      Push.getTokenStream.listen((token) {
        debugPrint('[PushService] Token received: $token');
      });

      // Listen for remote messages
      Push.onMessageReceivedStream.listen((RemoteMessage message) {
        debugPrint('[PushService] Remote message received: ${message.data}');
        _handleRemoteMessage(message);
      });

      debugPrint('[PushService] Initialized successfully');
    } catch (e) {
      debugPrint('[PushService] Initialization error: $e');
    }
  }

  /// Handle incoming remote messages
  void _handleRemoteMessage(RemoteMessage message) {
    debugPrint('[PushService] Handling remote message: ${message.data}');
    // Handle different types of messages here
  }

  /// Send push notification to nearby users when incident is lodged
  Future<void> notifyNearbyUsers({
    required double incidentLatitude,
    required double incidentLongitude,
    required String incidentType,
    required String incidentDescription,
    required String incidentId,
    double radiusKm = 5.0, // Default 5km radius
  }) async {
    try {
      debugPrint(
        '[PushService] Starting notification process for incident: $incidentId',
      );

      // Get all users
      await _userRepository.openZone();
      final allUsers = await _userRepository.getAllUsers();

      // Filter nearby users
      final nearbyUsers = _filterNearbyUsers(
        allUsers,
        incidentLatitude,
        incidentLongitude,
        radiusKm,
      );

      debugPrint(
        '[PushService] Found ${nearbyUsers.length} nearby users out of ${allUsers.length} total users',
      );

      if (nearbyUsers.isEmpty) {
        debugPrint('[PushService] No nearby users found');
        return;
      }

      // Send notifications to nearby users
      await _sendNotificationsToUsers(nearbyUsers, {
        'incidentId': incidentId,
        'incidentType': incidentType,
        'incidentDescription': incidentDescription,
        'latitude': incidentLatitude.toString(),
        'longitude': incidentLongitude.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[PushService] Error notifying nearby users: $e');
    } finally {
      await _userRepository.closeZone();
    }
  }

  /// Filter users within specified radius of incident location
  List<Users> _filterNearbyUsers(
    List<Users> allUsers,
    double incidentLatitude,
    double incidentLongitude,
    double radiusKm,
  ) {
    return allUsers.where((user) {
      // Skip users without location data
      if (user.latitude == null || user.longitude == null) {
        return false;
      }

      // Skip users who don't allow emergency alerts
      if (user.allowEmergencyAlert == false) {
        return false;
      }

      // Check if user is within radius
      return LocationUtils.isWithinRadius(
        incidentLatitude,
        incidentLongitude,
        user.latitude!,
        user.longitude!,
        radiusKm,
      );
    }).toList();
  }

  /// Send push notifications to a list of users
  Future<void> _sendNotificationsToUsers(
    List<Users> users,
    Map<String, String> data,
  ) async {
    for (final user in users) {
      try {
        // For prototyping, we'll send to all users
        // In production, you would need to store push tokens for each user
        await _sendNotificationToUser(user, data);
      } catch (e) {
        debugPrint(
          '[PushService] Error sending notification to user ${user.uid}: $e',
        );
      }
    }
  }

  /// Send notification to a specific user
  Future<void> _sendNotificationToUser(
    Users user,
    Map<String, String> data,
  ) async {
    try {
      // local notifications for prototyping
      // In production, send to specific device tokens via Huawei Push Kit server
      debugPrint(
        '[PushService] Would send notification to user: ${user.username}',
      );
      debugPrint('[PushService] Notification data: $data');

      // Log the notification details for debugging
      debugPrint('[PushService] 🚨 Emergency Alert for ${user.username}');
      debugPrint('[PushService] Incident Type: ${data['incidentType']}');
      debugPrint('[PushService] Description: ${data['incidentDescription']}');
      debugPrint(
        '[PushService] Location: ${data['latitude']}, ${data['longitude']}',
      );
    } catch (e) {
      debugPrint('[PushService] Error sending notification: $e');
    }
  }

  /// Subscribe user to emergency alerts topic
  Future<void> subscribeToEmergencyAlerts() async {
    try {
      await Push.subscribe('emergency_alerts');
      debugPrint('[PushService] Subscribed to emergency_alerts topic');
    } catch (e) {
      debugPrint('[PushService] Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe user from emergency alerts topic
  Future<void> unsubscribeFromEmergencyAlerts() async {
    try {
      await Push.unsubscribe('emergency_alerts');
      debugPrint('[PushService] Unsubscribed from emergency_alerts topic');
    } catch (e) {
      debugPrint('[PushService] Error unsubscribing from topic: $e');
    }
  }
}
