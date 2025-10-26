import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service to send push notifications via backend (AWS Lambda)
class BackendNotificationService {
  static String get _apiEndpoint {
    return dotenv.env['BACKEND_API_URL'] ?? '';
  }

  /// Send push notifications via backend server
  Future<bool> sendNotificationsToNearbyUsers({
    required List<String> pushTokens,
    required String title,
    required String incidentId,
    required String incidentType,
    required String description,
    required String latitude,
    required String longitude,
  }) async {
    try {
      debugPrint('[BackendService] 📤 Sending to ${pushTokens.length} devices');
      debugPrint('[BackendService] Endpoint: $_apiEndpoint');
      debugPrint('[BackendService] Title being sent: "$title"');
      debugPrint('[BackendService] Incident Type: "$incidentType"');

      if (pushTokens.isEmpty) {
        debugPrint('[BackendService] ⚠️ No push tokens to send');
        return false;
      }

      String body = jsonEncode({
        'pushTokens': pushTokens,
        'title': title,
        'incidentId': incidentId,
        'incidentType': incidentType,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        "click_action": {"type": 1},
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('[BackendService] Request Body: $body');

      final response = await http
          .post(
            Uri.parse("$_apiEndpoint/push-notification-handler"),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('[BackendService] ⏱️ Request timeout');
              throw TimeoutException('Backend request timed out');
            },
          );

      debugPrint('[BackendService] Response status: ${response.statusCode}');
      debugPrint('[BackendService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('[BackendService] ✅ Notifications sent successfully');
          return true;
        } else {
          debugPrint(
            '[BackendService] ❌ Backend returned error: ${data['error']}',
          );
          return false;
        }
      } else {
        debugPrint('[BackendService] ❌ HTTP error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[BackendService] ❌ Error: $e');
      return false;
    }
  }
}

/// Custom exception for timeouts
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
