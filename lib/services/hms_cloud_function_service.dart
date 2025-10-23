// In: lib/services/hms_cloud_function_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http; // Use http package

class HmsAudioAnalysisService {
  // Use the NEW API Gateway Path URL for sound-analysis-2
  final String _apiUrl =
      "https://injy5p4lwrvfxblw4h.api-dra.agconnect.link/sound-analysis-2"; // <-- New Authentication-free URL

  HmsAudioAnalysisService();

  Future<Map<String, dynamic>> analyzeAudio(String audioFilePath) async {
    print("HmsAudioAnalysisService: Analyzing audio via API Gateway (Auth-free) $_apiUrl");
    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        print("HmsAudioAnalysisService: Error - File does not exist: $audioFilePath");
        return {'error': 'Audio file not found'};
      }
      final audioBytes = await file.readAsBytes();
      final String audioBase64 = base64Encode(audioBytes);

      // Create the JSON payload string
      final payload = jsonEncode({
        'audio_base64': audioBase64,
      });

      // Prepare Headers (Only Content-Type needed for Auth-free)
      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        // No authentication headers needed now
      };

      print("HmsAudioAnalysisService: Calling API Gateway URL via POST...");
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: headers, // Send headers
        body: payload,    // Send JSON string body
      );

      print("HmsAudioAnalysisService: Response Status Code: ${response.statusCode}");
      print("HmsAudioAnalysisService: Response Body: ${response.body}");

      if (response.statusCode == 200) {
        // Decode the JSON response body if successful
        final resultMap = jsonDecode(response.body) as Map<String, dynamic>;
        print("HmsAudioAnalysisService: Cloud Function Result: $resultMap");
        return resultMap;
      } else {
        // Handle errors based on status code
        print("HmsAudioAnalysisService: Error - Status Code ${response.statusCode}");
        return {
          'error': 'API Gateway failed with status ${response.statusCode}',
          'body': response.body // Include body for debugging
        };
      }
    } catch (e) {
      // Handle general errors (network, file reading, JSON parsing)
      print('HmsAudioAnalysisService: General Error calling URL: $e');
      return {'error': 'Failed to analyze audio via API Gateway: $e'};
    }
  }
}