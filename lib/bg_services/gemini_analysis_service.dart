import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

//region Adjustable Thresholds and Configuration
// This prompt is more advanced. It asks the model to look for context
// and cancel false positives, which is key to your request.
const String GEMINI_PROMPT = """
Analyze the following data collected over an 8-second window to determine if a real safety incident occurred.

An initial trigger started this analysis. The initial triggers were: "{initialTriggers}"

CONTEXT AND AUDIO:
- Pre-trigger text transcript (what was said BEFORE the keyword): "{transcript}"
- An audio recording of the 8-second window AFTER the trigger is attached

CRITICAL INSTRUCTION:
The "{transcript}" contains text recognized BEFORE the trigger keyword was detected.
The attached audio file contains what was said DURING the 8-second capture window.
You MUST combine both to form the COMPLETE sentence/context.

Example: 
- Pre-trigger text: "can i get your"
- Audio contains: "help please"
- FULL SENTENCE: "Can I get your help please"

Please analyze the COMBINED context:
- Voice tone (calm vs distressed, crying, screaming, fear)
- Emotional state (panic, fear, normal conversation)
- Background sounds (crashes, breaking glass, violence, etc.)
- Whether the voice matches the complete sentence context

Sensor Data Peaks during the window:
{
  "accelerometer": { "x": "{accelX}", "y": "{accelY}", "z": "{accelZ}" },
  "gyroscope": { "x": "{gyroX}", "y": "{gyroY}", "z": "{gyroZ}" }
}

Your task is to evaluate the full context from BOTH the audio recording and the data. 

CRITICAL INSTRUCTIONS:
1. ONLY classify as a TRUE INCIDENT if there is GENUINE DANGER TO PERSONAL SAFETY.
2. Distinguish between:
   - REAL DANGER: Physical attacks, falls causing injury, medical emergencies, violent threats
   - EVERYDAY STRESS: Heavy lifting, difficult tasks, work frustration, hyperbolic expressions

3. Common FALSE POSITIVES to reject:
   - "Help me lift this!" / "This is so heavy!" → Carrying heavy objects (NOT an emergency)
   - "I can't believe this!" / "This is killing me!" → Frustration or exaggeration (NOT literal danger)
   - "Someone save me from this work!" → Metaphorical distress (NOT actual threat)
   - Testing the system with calm voice saying keywords
   - Normal conversation mentioning help/danger in non-urgent context

4. AUDIO ANALYSIS is PRIMARY:
   - If voice is calm, conversational, or laughing → FALSE POSITIVE (even with keywords)
   - If voice shows REAL panic, fear, crying, screaming → Possible true incident
   - **WHISPERED DISTRESS CALLS:** A whispered "help" or distress signal is STILL AN EMERGENCY
     → Someone whispering for help may be hiding from danger or in a hostage situation
     → DO NOT interpret whispered distress as "calm" - evaluate the CONTEXT and URGENCY
     → Consider: Is the person trying to be quiet to avoid detection? Is there fear in the whisper?
   - Background sounds matter: crashes, breaking glass, violence indicators
   
5. DO NOT infer emotions unless you HEAR them in the audio. Be factual, not speculative.
   - EXCEPTION: Whispered urgent pleas for help should be taken seriously even if not "loud"

Provide a JSON response with the following structure:
- "isIncident": boolean (true ONLY if you are confident it is a real incident based on audio + context, false otherwise)
- "incidentType": string (e.g., "Fall", "Distress Call", "False Positive")
- "transcript": string (The COMPLETE COMBINED sentence: pre-trigger text + audio transcription. Piece them together into natural, coherent sentences.)
- "description": string (A concise summary based on what you HEAR in the audio and see in the data. Be factual, not speculative.)
- "district": string (Infer if possible, otherwise leave empty)
- "postcode": string (Infer if possible, otherwise leave empty)
- "state": string (Infer if possible, otherwise leave empty)

Examples:

FALSE POSITIVE (heavy lifting):
Pre-trigger: "can i get your", Audio: "help please the file is very heavy"
{
  "isIncident": false,
  "incidentType": "False Positive - Physical Task",
  "transcript": "Can I get your help please, the file is very heavy",
  "description": "Voice tone indicates physical strain from lifting, not danger. Normal conversational volume. Keyword 'help' refers to assistance with heavy object, not emergency. No panic or distress detected.",
  "district": "", "postcode": "", "state": ""
}

FALSE POSITIVE (testing):
Pre-trigger: "", Audio: "help me help me please"
{
  "isIncident": false,
  "incidentType": "False Positive - System Test",
  "transcript": "Help me help me please",
  "description": "Calm, monotone voice speaking keywords deliberately. No emotional distress. Likely testing the safety system.",
  "district": "", "postcode": "", "state": ""
}

TRUE POSITIVE (actual danger):
Pre-trigger: "someone is following me", Audio: "help someone please help me"
{
  "isIncident": true,
  "incidentType": "Distress Call",
  "transcript": "Someone is following me, help someone please help me",
  "description": "Voice analysis indicates genuine panic and fear. Rapid breathing, elevated pitch, and trembling voice detected. Background sounds suggest struggle. IMU data shows sudden movement consistent with distress scenario.",
  "district": "", "postcode": "", "state": ""
}

TRUE POSITIVE (whispered distress):
Pre-trigger: "please", Audio: "help me quietly please someone help"
{
  "isIncident": true,
  "incidentType": "Distress Call - Whispered",
  "transcript": "Please help me quietly, please someone help",
  "description": "Whispered distress call detected with urgent tone. Voice shows fear despite low volume. Person appears to be trying to remain quiet, possibly hiding from danger or in hostage situation. Context and urgency indicate genuine emergency despite whisper.",
  "district": "", "postcode": "", "state": ""
}

Now, analyze the provided audio and data.
""";
//endregion

class GeminiAnalysisService {
  final String apiKey;
  final String modelName;
  GenerativeModel? _model;

  GeminiAnalysisService({
    required this.apiKey,
    this.modelName = 'gemini-2.0-flash',
  }) {
    if (apiKey.isNotEmpty) {
      _model = GenerativeModel(model: modelName, apiKey: apiKey);
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
    String? audioFilePath, // NEW: Optional audio file
  }) async {
    if (_model == null) {
      if (kDebugMode) {
        print(
          "[GeminiAnalysisService] Error: Gemini API key is not configured.",
        );
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
      // Build content parts
      final List<Part> parts = [];

      // Add audio file if provided
      if (audioFilePath != null && audioFilePath.isNotEmpty) {
        try {
          final audioFile = File(audioFilePath);
          if (await audioFile.exists()) {
            final audioBytes = await audioFile.readAsBytes();
            parts.add(
              DataPart('audio/m4a', audioBytes),
            ); // or 'audio/mp4', 'audio/wav'
            if (kDebugMode) {
              print(
                "[GeminiAnalysisService] Audio file attached (${audioBytes.length} bytes)",
              );
            }
          } else {
            if (kDebugMode) {
              print(
                "[GeminiAnalysisService] Audio file not found: $audioFilePath",
              );
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print("[GeminiAnalysisService] Error loading audio file: $e");
          }
        }
      }

      // Add text prompt
      parts.add(TextPart(prompt));

      final content = [Content.multi(parts)];

      // Add timeout and retry logic
      int attempt = 0;
      const maxAttempts = 2;
      const timeout = Duration(seconds: 15);

      while (attempt < maxAttempts) {
        attempt++;

        try {
          if (kDebugMode) {
            print(
              "[GeminiAnalysisService] Attempt $attempt/$maxAttempts - Calling Gemini API with ${timeout.inSeconds}s timeout...",
            );
          }

          // Call Gemini with timeout
          final response = await _model!
              .generateContent(content)
              .timeout(
                timeout,
                onTimeout: () {
                  throw TimeoutException(
                    'Gemini API call timed out after ${timeout.inSeconds} seconds',
                  );
                },
              );

          String sanitizedText = response.text ?? "";
          final jsonStartIndex = sanitizedText.indexOf('{');
          final jsonEndIndex = sanitizedText.lastIndexOf('}');

          if (jsonStartIndex != -1 && jsonEndIndex != -1) {
            sanitizedText = sanitizedText.substring(
              jsonStartIndex,
              jsonEndIndex + 1,
            );
          } else {
            if (kDebugMode) {
              print(
                "[GeminiAnalysisService] No JSON found in response, retrying...",
              );
            }
            if (attempt < maxAttempts) continue;
            return null;
          }

          final jsonResponse =
              jsonDecode(sanitizedText) as Map<String, dynamic>;

          if (kDebugMode) {
            print(
              "[GeminiAnalysisService] ✅ Successfully received response on attempt $attempt",
            );
          }

          return jsonResponse;
        } on TimeoutException catch (e) {
          if (kDebugMode) {
            print("[GeminiAnalysisService] ⏱️ Timeout on attempt $attempt: $e");
          }
          if (attempt >= maxAttempts) {
            if (kDebugMode) {
              print(
                "[GeminiAnalysisService] ❌ Max attempts reached, giving up",
              );
            }
            return null;
          }
          // Wait with countdown before retrying
          if (kDebugMode) {
            print(
              "[GeminiAnalysisService] 🔄 Retrying in 2 seconds... (Attempt ${attempt + 1}/$maxAttempts)",
            );
          }
          await Future.delayed(const Duration(milliseconds: 500));
          if (kDebugMode) print("[GeminiAnalysisService] ⏳ 1.5s...");
          await Future.delayed(const Duration(milliseconds: 500));
          if (kDebugMode) print("[GeminiAnalysisService] ⏳ 1.0s...");
          await Future.delayed(const Duration(milliseconds: 500));
          if (kDebugMode) print("[GeminiAnalysisService] ⏳ 0.5s...");
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          if (kDebugMode) {
            print("[GeminiAnalysisService] ❌ Error on attempt $attempt: $e");
          }
          if (attempt >= maxAttempts) return null;
          // Wait with countdown before retrying
          if (kDebugMode) {
            print(
              "[GeminiAnalysisService] 🔄 Retrying in 2 seconds... (Attempt ${attempt + 1}/$maxAttempts)",
            );
          }
          await Future.delayed(const Duration(milliseconds: 500));
          if (kDebugMode) print("[GeminiAnalysisService] ⏳ 1.5s...");
          await Future.delayed(const Duration(milliseconds: 500));
          if (kDebugMode) print("[GeminiAnalysisService] ⏳ 1.0s...");
          await Future.delayed(const Duration(milliseconds: 500));
          if (kDebugMode) print("[GeminiAnalysisService] ⏳ 0.5s...");
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print("[GeminiAnalysisService] ❌ Fatal error calling Gemini API: $e");
      }
      return null;
    }
  }
}
