// lib/collection_in_progress_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'bg_services/safety_config.dart';

class CollectionInProgressPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const CollectionInProgressPage({Key? key, this.initialData}) : super(key: key);

  @override
  _CollectionInProgressPageState createState() => _CollectionInProgressPageState();
}

class _CollectionInProgressPageState extends State<CollectionInProgressPage> {
  final List<String> _triggers = [];
  final List<String> _sensorLogs = [];
  String _transcript = '';
  int _countdown = SafetyConfig.collectionWindowSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _triggers.add(widget.initialData?['initialTrigger'] ?? 'Initial Trigger');

    _startCountdown();

    // Listen for real-time updates from the background service
    FlutterBackgroundService().on('updateCollectionData').listen((event) {
      if (!mounted) return;
      setState(() {
        if (event?['sensorLog'] != null) {
          _sensorLogs.add(event!['sensorLog']);
        }
        if (event?['transcript'] != null) {
          _transcript = event!['transcript'];
        }
      });
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Incident Detected - Collecting Data ($_countdown s)'),
        backgroundColor: Colors.orange,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Initial Trigger(s)'),
            ..._triggers.map((t) => Text('• $t')),
            const Divider(height: 32),
            _buildSectionTitle(context, 'High-Magnitude Sensor Events'),
            Expanded(
              flex: 2,
              child: _sensorLogs.isEmpty
                  ? const Text('No significant sensor events detected yet...')
                  : ListView.builder(
                      itemCount: _sensorLogs.length,
                      itemBuilder: (context, index) => Text(_sensorLogs[index]),
                    ),
            ),
            const Divider(height: 32),
            _buildSectionTitle(context, 'Live Transcript'),
            Expanded(
              flex: 1,
              child: Text(
                _transcript.isEmpty ? 'Listening for speech...' : _transcript,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 10),
            const Center(child: Text('Analyzing data with AI...')),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
