import 'dart:convert';
import 'package:http/http.dart' as http;
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





      if (pushTokens.isEmpty) {

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



      final response = await http
          .post(
            Uri.parse("$_apiEndpoint/push-notification-handler"),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {

              throw TimeoutException('Backend request timed out');
            },
          );




      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {

          return true;
        } else {
          return false;
        }
      } else {

        return false;
      }
    } catch (e) {

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
