import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiAnalysisService {
  static final AiAnalysisService _instance = AiAnalysisService._internal();
  factory AiAnalysisService() => _instance;
  AiAnalysisService._internal();

  Future<Map<String, dynamic>> analyzeIncident({
    required String trigger,
    required List<String> imuReadings,
    required String audioTranscription,
    required String audioEmotion,
  }) async {
    print("AIAnalysisService: Analyzing incident...");
    
    // Safely get the API key
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null) {
      print('GEMINI_API_KEY not found in .env file');
      // Handle the error appropriately
      return {
        "isTruePositive": false,
        "description": "API Key is missing. Could not analyze the incident.",
      };
    }
    
    // You would use the apiKey in your HTTP request to the Gemini API here
    print("Using API Key: ${apiKey.substring(0, 4)}... (for verification)");

    print({
      "trigger": trigger,
      "imuReadings": imuReadings,
      "audioTranscription": audioTranscription,
      "audioEmotion": audioEmotion,
    });

    // Simulate network delay for AI processing
    await Future.delayed(Duration(seconds: 3));

    // Mock response from Gemini
    final isTruePositive = Random().nextBool();
    
    final response = {
      "isTruePositive": isTruePositive,
      "description": isTruePositive
          ? "AI analysis indicates a high probability of a threat. A sudden high-magnitude jolt was detected, followed by sounds of distress. Keywords 'Help' and 'Tolong' were identified."
          : "AI analysis suggests this is likely a false positive. While a jolt was detected, the audio analysis did not contain significant distress signals.",
    };
    
    print("AIAnalysisService: Analysis complete. Result: $response");
    return response;
  }

  Future<Map<String, String>> processAudio(String audioPath) async {
    print("AIAnalysisService: Processing audio...");
    await Future.delayed(Duration(seconds: 2)); // Simulate audio processing
    return {
      "transcription": "Help me! Tolong!",
      "emotion": "Fear",
    };
  }
}
