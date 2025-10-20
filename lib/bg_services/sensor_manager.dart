// lib/bg_services/sensor_manager.dart
import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:huawei_ml_language/huawei_ml_language.dart';

class SensorManager {
  // HMS Listeners
  MLSoundDetector? _soundDetector;

  // Sensor Listener Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // State
  Timer? _debugTimer;
  AccelerometerEvent? _lastAccelEvent;
  GyroscopeEvent? _lastGyroEvent;
  Function(String)? _onTrigger;

  SensorManager(); // Constructor

  void startMonitoring({required Function(String) onTrigger}) {
    print("[SENSOR_MANAGER] Starting sensor monitoring...");
    _onTrigger = onTrigger;
    _startSoundDetector();
    _startImuSensors();
    _startDebugTimer();
  }

  void _startSoundDetector() async {
     try {
      _soundDetector = MLSoundDetector();
      _soundDetector?.setSoundDetectListener(_onSoundDetect);
      await _soundDetector?.start();
      print("[SENSOR_MANAGER] SoundDetector started.");
    } catch(e) {
      print("[SENSOR_MANAGER] Error starting SoundDetector: $e");
      _soundDetector = null;
    }
  }

  void _startImuSensors() {
    try {
      _accelSubscription = accelerometerEventStream(
          samplingPeriod: SensorInterval.normalInterval
      ).listen(_onAccelEvent, onError: (e) { print("[SENSOR_MANAGER] Accel Error: $e");});

      _gyroSubscription = gyroscopeEventStream(
          samplingPeriod: SensorInterval.normalInterval
      ).listen(_onGyroEvent, onError: (e) { print("[SENSOR_MANAGER] Gyro Error: $e");});
      print("[SENSOR_MANAGER] IMU sensors started.");
    } catch (e) {
      print("[SENSOR_MANAGER] Error starting IMU sensors: $e");
    }
  }

  void _startDebugTimer() {
    _debugTimer?.cancel(); // Cancel any existing timer
    _debugTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final accel = _lastAccelEvent;
      final gyro = _lastGyroEvent;
      if (accel != null && gyro != null) {
        print("[SENSOR_DEBUG] Accel(x: ${accel.x.toStringAsFixed(2)}, y: ${accel.y.toStringAsFixed(2)}, z: ${accel.z.toStringAsFixed(2)}) | Gyro(x: ${gyro.x.toStringAsFixed(2)}, y: ${gyro.y.toStringAsFixed(2)}, z: ${gyro.z.toStringAsFixed(2)})");
      }
    });
  }

  void _onSoundDetect({int? result, int? errCode}) {
    if (errCode != null) {
      print("[SENSOR_MANAGER] SoundDetect Error Code: $errCode");
      return;
    }
    if (result != null) {
      const int soundEventScream = 12;
      print("[SENSOR_MANAGER] Sound detected: ID $result");
      if (result == soundEventScream) {
        print("[SENSOR_MANAGER] TRIGGER: Scream detected!");
        _onTrigger?.call("Scream Detected");
      }
    }
  }

  void _onAccelEvent(AccelerometerEvent event) {
    _lastAccelEvent = event;
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (magnitude > 35.0) {
      print("[SENSOR_MANAGER] TRIGGER: High-G event detected! ($magnitude m/s^2)");
      _onTrigger?.call("Impact Detected");
    }
  }

  void _onGyroEvent(GyroscopeEvent event) {
    _lastGyroEvent = event;
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    if (magnitude > 10.0) {
      print("[SENSOR_MANAGER] TRIGGER: Violent rotation detected! ($magnitude rad/s)");
      _onTrigger?.call("Violent Motion Detected");
    }
  }

  void stopAllListeners() {
    print("[SENSOR_MANAGER] Stopping all sensor listeners...");
    _debugTimer?.cancel();
    _debugTimer = null;
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;

    try {
      _soundDetector?.destroy();
    } catch (e) { print("[SENSOR_MANAGER] Error destroying SoundDetector: $e"); }
    _soundDetector = null;
    print("[SENSOR_MANAGER] Sensor listeners stopped.");
  }
}
