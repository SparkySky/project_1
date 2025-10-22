// lib/bg_services/gemini_analysis_manager.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'safety_config.dart';
import 'package:project_1/api_keys.dart';

class GeminiAnalysisResult {
  final bool isIncident;
  final double confidence;
  final String incidentType;
  final String description;

  GeminiAnalysisResult({
    required this.isIncident,
    required this.confidence,
    required this.incidentType,
    required this.description,
  });

  factory GeminiAnalysisResult.fromJson(Map<String, dynamic> json) {
    return GeminiAnalysisResult(
      isIncident: json['isIncident'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      incidentType: json['incidentType'] ?? 'False Positive',
      description: json['description'] ?? 'No analysis provided.',
    );
  }
}

class GeminiAnalysisManager {
  // IMPORTANT: Replace with your actual Gemini API key
  final String _apiKey = GEMINI_API_KEY;
  
  // Using the newer, faster, and more available Flash model
  final String _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  Future<GeminiAnalysisResult> analyzeIncidentData(String payload) async {
    _log('Starting Gemini analysis...');

    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      _log('WARNING: No Gemini API key provided. Using simulated analysis.');
      return _getSimulatedResponse(payload);
    }

    int maxRetries = 3;
    int currentTry = 0;

    while (currentTry < maxRetries) {
      currentTry++;
      try {
        final response = await http.post(
          Uri.parse('$_endpoint?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [{'parts': [{'text': payload}]}]
          }),
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          String rawText = body['candidates'][0]['content']['parts'][0]['text'];
          
          final RegExp jsonRegex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
          final match = jsonRegex.firstMatch(rawText);
          
          if (match != null) {
            rawText = match.group(1)!;
          } else {
            rawText = rawText.trim();
          }

          final jsonResult = jsonDecode(rawText);
          _log('Successfully received and parsed Gemini analysis.');
          return GeminiAnalysisResult.fromJson(jsonResult);

        } else if (response.statusCode == 503 && currentTry < maxRetries) {
          // If model is overloaded, wait and retry
          _log('WARNING: Gemini API returned 503 (UNAVAILABLE). Retrying in 2 seconds... (Attempt $currentTry/$maxRetries)');
          await Future.delayed(const Duration(seconds: 2));
          
        } else {
          _log('ERROR: Gemini API request failed with status code ${response.statusCode}');
          _log('Response body: ${response.body}');
          return GeminiAnalysisResult.fromJson({'isIncident': false});
        }
      } catch (e) {
        _log('ERROR: Exception during Gemini API call: $e');
        return GeminiAnalysisResult.fromJson({'isIncident': false});
      }
    }
    
    _log('ERROR: Gemini analysis failed after $maxRetries retries.');
    return GeminiAnalysisResult.fromJson({'isIncident': false});
  }

  /// Provides a simulated response for testing without an API key
  Future<GeminiAnalysisResult> _getSimulatedResponse(String payload) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate network latency
    
    _log('Simulation complete. Returning TRUE POSITIVE.');
    return GeminiAnalysisResult.fromJson({
      "isIncident": true,
      "confidence": 0.85,
      "incidentType": "Suspected Fall",
      "description": "The combination of a high-impact accelerometer reading followed by a period of no significant movement, along with the spoken phrase 'Oh, I fell,' strongly indicates a fall has occurred."
    });
  }

  void _log(String message) {
    if (SafetyConfig.enableVerboseLogging) {
      if (kDebugMode) {
        print('[GeminiAnalysisManager] $message');
      }
    }
  }
}
