import 'dart:async';
import 'package:flutter/material.dart';
import 'package:project_1/util/imu_centre.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class IncidentCollectionPage extends StatefulWidget {
  final String initialTrigger;

  const IncidentCollectionPage({Key? key, required this.initialTrigger}) : super(key: key);

  @override
  _IncidentCollectionPageState createState() => _IncidentCollectionPageState();
}

class _IncidentCollectionPageState extends State<IncidentCollectionPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final IMUCentre _imuCentre = IMUCentre();

  String _transcript = "Listening...";
  final List<String> _imuReadings = [];
  int _countdown = 8;
  Timer? _countdownTimer;
  Timer? _imuTimer;

  @override
  void initState() {
    super.initState();
    _startCollection();
  }

  void _startCollection() {
    // Start speech-to-text
    _speech.initialize().then((isInitialized) {
      if (isInitialized) {
        _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _transcript = result.recognizedWords;
              });
            }
          },
          listenFor: const Duration(seconds: 8),
        );
      }
    });

    // Start IMU logging (10 readings over 8 seconds)
    _imuTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (_imuReadings.length >= 10) {
        timer.cancel();
        return;
      }
      // For simplicity, we just grab the latest accelerometer event here.
      // A more robust solution might buffer events.
      _imuCentre.accelerometerStream.first.then((event) {
        if (mounted) {
          final timestamp = TimeOfDay.now().format(context);
          final reading =
              "[$timestamp] Accel: X:${event.x.toStringAsFixed(2)}, Y:${event.y.toStringAsFixed(2)}, Z:${event.z.toStringAsFixed(2)}";
          setState(() {
            _imuReadings.add(reading);
          });
        }
      });
    });

    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 1) {
        timer.cancel();
        _finishCollection();
      } else {
        if (mounted) {
          setState(() {
            _countdown--;
          });
        }
      }
    });
  }

  void _finishCollection() {
    _imuTimer?.cancel();
    _speech.stop();
    
    final result = {
      'transcript': _transcript,
      'imuReadings': _imuReadings,
    };
    
    // Return the collected data to the previous screen
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _imuTimer?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Potential Incident Detected",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Initial Trigger: ${widget.initialTrigger}",
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Countdown Timer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 4),
                ),
                child: Text(
                  _countdown.toString(),
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Live Transcript
              _buildDataBox(
                title: "Live Transcript",
                icon: Icons.mic,
                content: _transcript,
              ),
              const SizedBox(height: 20),
              // IMU Logs
              _buildDataBox(
                title: "IMU Log",
                icon: Icons.sensors,
                content: _imuReadings.join('\n'),
                isScrollable: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataBox({
    required String title,
    required IconData icon,
    required String content,
    bool isScrollable = false,
  }) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: isScrollable
                ? SingleChildScrollView(
                    child: Text(
                      content.isEmpty ? "Waiting for data..." : content,
                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                    ),
                  )
                : Text(
                    content.isEmpty ? "Waiting for data..." : content,
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
          ),
        ],
      ),
    );
  }
}
