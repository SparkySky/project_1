// lib/lodge_incident_page.dart
import 'package:flutter/material.dart';

class LodgeIncidentPage extends StatelessWidget {
  final Map<String, dynamic>? incidentData;

  const LodgeIncidentPage({Key? key, this.incidentData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final incidentType = incidentData?['incidentType'] ?? 'Unknown';
    final description = incidentData?['description'] ?? 'No description provided.';
    final audioFilePath = incidentData?['audioFilePath'] ?? 'No audio file.';
    final geminiPayload = incidentData?['geminiPayload'] ?? 'No Gemini payload.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Lodged'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Incident Type: $incidentType',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Description:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(description),
            const SizedBox(height: 16),
            Text(
              'Audio Evidence:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(audioFilePath),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Gemini Analysis Payload'),
              children: [
                Container(
                  color: Colors.grey[200],
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    geminiPayload,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement logic to stop the stream upload
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stream upload stopped (simulation).')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Stop Stream Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
