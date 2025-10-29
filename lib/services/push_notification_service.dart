import 'package:huawei_push/huawei_push.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/users.dart';
import '../providers/user_provider.dart';
import '../repository/user_repository.dart';
import '../util/location_utils.dart';
import 'backend_notification_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final UserProvider _userProvider = UserProvider();
  final UserRepository _userRepository = UserRepository();
  final BackendNotificationService _backendService =
      BackendNotificationService();

  String? _lastToken;
  bool _isInitialized = false;

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[PushService] Already initialized');
      return;
    }

    try {
      // Check and request notification permission if needed
      final hasPermission = await Permission.notification.isGranted;
      if (!hasPermission) {
        debugPrint(
          '[PushService] Notification permission not granted, requesting...',
        );
        final status = await Permission.notification.request();
        if (status.isGranted) {
          debugPrint('[PushService] ✅ Notification permission granted');
        } else {
          debugPrint('[PushService] ❌ Notification permission denied');
          // Don't return - still try to get token as it might work on some devices
        }
      } else {
        debugPrint('[PushService] ✅ Notification permission already granted');
      }

      // Request push token
      Push.getToken('HCM');

      // Listen for token updates
      Push.getTokenStream.listen(
        (token) async {
          if (token == _lastToken) {
            debugPrint('[PushService] Token unchanged, skipping update');
            return;
          }

          debugPrint('[PushService] Token received: $token');
          _lastToken = token;

          // Save token and try to update user profile
          await _saveTokenAndUpdateUser(token);
        },
        onError: (error) {
          debugPrint('[PushService] Error receiving token: $error');
        },
      );

      // Listen for remote messages
      Push.onMessageReceivedStream.listen((RemoteMessage message) {
        debugPrint('[PushService] Remote message received: ${message.data}');
        _handleRemoteMessage(message);
      });

      _isInitialized = true;
      debugPrint('[PushService] Initialized successfully');
    } catch (e) {
      debugPrint('[PushService] Initialization error: $e');
    }
  }

  /// Get the current push token
  String? get currentToken => _lastToken;

  /// Save token and update user profile if authenticated
  Future<void> _saveTokenAndUpdateUser(String token) async {
    try {
      // Check if user is authenticated
      if (!_userProvider.isAuthenticated) {
        debugPrint(
          '[PushService] User not authenticated, saving token to SharedPreferences',
        );

        // Save token locally for later upload
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_push_token', token);
        return;
      }

      // Check if cloudDbUser is available
      final cloudDbUser = _userProvider.cloudDbUser;
      if (cloudDbUser == null) {
        debugPrint(
          '[PushService] User authenticated but cloudDbUser not loaded yet, saving token to SharedPreferences',
        );

        // Save token locally for later upload
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_push_token', token);

        // Schedule a retry after a short delay
        Future.delayed(const Duration(seconds: 2), () async {
          debugPrint('[PushService] Retrying token upload after delay');
          await uploadPendingToken();
        });
        return;
      }

      // User is authenticated and cloudDbUser is available, update both Firebase and CloudDB
      debugPrint('[PushService] User authenticated, updating token');
      cloudDbUser.pushToken = token;
      await _userProvider.updateCloudDbUser(cloudDbUser);

      // Clear pending token if upload was successful
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_push_token');
    } catch (e) {
      debugPrint('[PushService] Error saving token: $e');
    }
  }

  /// Upload pending token from SharedPreferences
  Future<void> uploadPendingToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingToken = prefs.getString('pending_push_token');

      if (pendingToken == null) {
        return;
      }

      final cloudDbUser = _userProvider.cloudDbUser;
      if (cloudDbUser == null) {
        debugPrint('[PushService] cloudDbUser still null, will retry later');
        return;
      }

      debugPrint('[PushService] Uploading pending token');
      cloudDbUser.pushToken = pendingToken;
      await _userProvider.updateCloudDbUser(cloudDbUser);
      await prefs.remove('pending_push_token');
      debugPrint('[PushService] Pending token uploaded successfully');
    } catch (e) {
      debugPrint('[PushService] Error uploading pending token: $e');
    }
  }

  /// Handle incoming remote messages
  void _handleRemoteMessage(RemoteMessage message) {
    debugPrint('[PushService] Handling remote message: ${message.data}');
    // Handle different types of messages here
  }

  /// Send push notification to nearby users when incident is lodged
  Future<void> notifyNearbyUsers({
    required String incidentTitle,
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
      debugPrint('[PushService] Received title: "$incidentTitle"');
      debugPrint('[PushService] Received incident type: "$incidentType"');

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

      // Send notifications to nearby users
      await _sendNotificationsToUsers(nearbyUsers, {
        'incidentTitle': incidentTitle,
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

  /// Fetch push tokens for a list of user IDs
  Future<List<String>> getPushTokensForUsers(List<String> userIds) async {
    // Map each userId to the Future of their user object
    final futures = userIds
        .map((id) => _userRepository.getUserById(id))
        .toList();

    // Wait for all the futures to complete
    final users = await Future.wait(futures);

    return users
        .map((user) => user?.pushToken)
        .where((token) => token != null && token.isNotEmpty)
        .cast<String>()
        .toList();
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
    final userIds = users.map((user) => user.uid).whereType<String>().toList();
    debugPrint('[PushService] Sending notifications to users: $userIds');

    final pushTokens = await getPushTokensForUsers(userIds);
    debugPrint('Push tokens: $pushTokens');

    if (pushTokens.isEmpty) {
      debugPrint('[PushService] ⚠️ No push tokens available for sending');
      return;
    }

    debugPrint(
      '[PushService] 📤 Sending to ${pushTokens.length} devices via backend',
    );

    try {
      debugPrint('[PushService] Title from data: "${data['incidentTitle']}"');
      debugPrint(
        '[PushService] Incident Type from data: "${data['incidentType']}"',
      );

      final success = await _backendService.sendNotificationsToNearbyUsers(
        pushTokens: pushTokens,
        title: data['incidentTitle']!,
        incidentId: data['incidentId']!,
        incidentType: data['incidentType']!,
        description: data['incidentDescription']!,
        latitude: data['latitude']!,
        longitude: data['longitude']!,
      );

      if (success) {
        debugPrint(
          '[PushService] ✅ Notifications sent successfully via backend',
        );
      } else {
        debugPrint('[PushService] ❌ Failed to send notifications via backend');
      }
    } catch (e) {
      debugPrint('[PushService] ❌ Error sending via backend: $e');
    }

    // Log notification details for debugging
    for (final user in users) {
      debugPrint('[PushService] 🚨 Emergency Alert for ${user.username}');
      debugPrint('[PushService] Incident Type: ${data['incidentType']}');
      debugPrint('[PushService] Description: ${data['incidentDescription']}');
      debugPrint(
        '[PushService] Location: ${data['latitude']}, ${data['longitude']}',
      );
      debugPrint('[PushService] Push Token: ${user.pushToken}');
    }
  }

  /// Send notifications to multiple push tokens via backend
  /// Call this from your backend when you want to send to multiple users
  Future<void> sendToMultipleTokens(
    List<String> pushTokens,
    Map<String, String> notificationData,
  ) async {
    // This would be called from your backend server
    // to send to multiple device tokens via Huawei Push Kit
    debugPrint('[PushService] Sending to ${pushTokens.length} tokens');
    debugPrint('[PushService] Data: $notificationData');
  }
}
