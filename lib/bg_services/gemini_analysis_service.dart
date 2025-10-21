import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

//region Adjustable Thresholds and Configuration
// This prompt is more advanced. It asks the model to look for context
// and cancel false positives, which is key to your request.
const String GEMINI_PROMPT = """
Analyze the following data collected over a 10-second window to determine if a real safety incident occurred.

An initial trigger started this analysis. The initial triggers were: "{initialTriggers}"

During the 10-second window, the following was said:
Full Speech Transcript: "{transcript}"

Sensor Data Peaks during the window:
{
  "accelerometer": { "x": "{accelX}", "y": "{accelY}", "z": "{accelZ}" },
  "gyroscope": { "x": "{gyroX}", "y": "{gyroY}", "z": "{gyroZ}" }
}

Your task is to evaluate the full context. If the speech transcript suggests a non-emergency situation (e.g., the user is talking about a movie, telling a story, or the keywords were used in a normal conversation), you MUST classify it as a false positive.

Provide a JSON response with the following structure:
- "isIncident": boolean (true ONLY if you are confident it is a real incident, false for conversational context or false positives)
- "incidentType": string (e.g., "Fall", "Distress Call", "False Positive")
- "description": string (A concise, one-paragraph summary. If it is a false positive, briefly explain why.)
- "district": string (Infer if possible, otherwise leave empty)
- "postcode": string (Infer if possible, otherwise leave empty)
- "state": string (Infer if possible, otherwise leave empty)

Example of a false positive:
{
  "isIncident": false,
  "incidentType": "False Positive",
  "description": "The keyword 'help' was detected, but the full speech transcript indicates the user was likely discussing a movie scene. This does not appear to be a real incident.",
  "district": "", "postcode": "", "state": ""
}

Now, analyze the provided data.
""";
//endregion

class GeminiAnalysisService {
  final String apiKey;
  final String modelName;
  GenerativeModel? _model;

  GeminiAnalysisService({
    required this.apiKey,
    this.modelName = 'gemini-pro',
  }) {
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
      );
    }
  }

  Future<Map<String, dynamic>?> analyzeIncident({
    required double accelX,
    required double accelY,
    required double accelZ,
    required double gyroX,
    required double gyroY,
    required double gyroZ,
    required String initialTriggers,
    required String transcript,
  }) async {
    if (_model == null) {
      if (kDebugMode) {
        print(
            "[GeminiAnalysisService] Error: Gemini API key is not configured.");
      }
      return null;
    }

    // Replace placeholders in the prompt
    final prompt = GEMINI_PROMPT
        .replaceAll("{accelX}", accelX.toStringAsFixed(2))
        .replaceAll("{accelY}", accelY.toStringAsFixed(2))
        .replaceAll("{accelZ}", accelZ.toStringAsFixed(2))
        .replaceAll("{gyroX}", gyroX.toStringAsFixed(2))
        .replaceAll("{gyroY}", gyroY.toStringAsFixed(2))
        .replaceAll("{gyroZ}", gyroZ.toStringAsFixed(2))
        .replaceAll("{initialTriggers}", initialTriggers)
        .replaceAll("{transcript}", transcript);

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      
      String sanitizedText = response.text ?? "";
      final jsonStartIndex = sanitizedText.indexOf('{');
      final jsonEndIndex = sanitizedText.lastIndexOf('}');

      if (jsonStartIndex != -1 && jsonEndIndex != -1) {
        sanitizedText = sanitizedText.substring(jsonStartIndex, jsonEndIndex + 1);
      } else {
        return null;
      }

      final jsonResponse =
          jsonDecode(sanitizedText) as Map<String, dynamic>;
      return jsonResponse;
    } catch (e) {
      if (kDebugMode) {
        print("[GeminiAnalysisService] Error calling Gemini API: $e");
      }
      return null;
    }
  }
}
