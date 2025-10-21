import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

//region Adjustable Thresholds and Configuration
// TODO: Replace with your actual Gemini API key.
const String GEMINI_API_KEY = "YOUR_GEMINI_API_KEY";

// Tweak this prompt to get the best results from the Gemini model.
const String GEMINI_PROMPT = """
Analyze the following sensor data and recognized speech to determine if a safety incident has occurred.
The data includes accelerometer and gyroscope readings, along with any spoken words that were detected.

Data:
{
  "accelerometer": {
    "x": "{accelX}",
    "y": "{accelY}",
    "z": "{accelZ}"
  },
  "gyroscope": {
    "x": "{gyroX}",
    "y": "{gyroY}",
    "z": "{gyroZ}"
  },
  "speech": "{speech}"
}

Based on this data, provide a JSON response with the following structure:
- "isIncident": boolean (true if an incident is likely, false otherwise)
- "incidentType": string (e.g., "Fall", "Car Crash", "Argument", "General Alert")
- "description": string (A concise, one-paragraph summary of what likely happened, suitable for a report.)
- "district": string (Infer the district from the context if possible, otherwise leave empty)
- "postcode": string (Infer the postcode from the context if possible, otherwise leave empty)
- "state": string (Infer the state from the context if possible, otherwise leave empty)

Example of a high-motion event with the word "help":
{
  "isIncident": true,
  "incidentType": "General Alert",
  "description": "A potential emergency has been detected. The user's device registered a significant impact or fall, and the word 'help' was spoken. Immediate attention may be required.",
  "district": "",
  "postcode": "",
  "state": ""
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
    if (apiKey.isNotEmpty && apiKey != "YOUR_GEMINI_API_KEY") {
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
    required String speech,
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
        .replaceAll("{speech}", speech);

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      // Sanitize the response to remove Markdown formatting.
      String sanitizedText = response.text ?? "";
      final jsonStartIndex = sanitizedText.indexOf('{');
      final jsonEndIndex = sanitizedText.lastIndexOf('}');

      if (jsonStartIndex != -1 && jsonEndIndex != -1) {
        sanitizedText =
            sanitizedText.substring(jsonStartIndex, jsonEndIndex + 1);
      } else {
        // If we can't find a JSON object, return null
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
