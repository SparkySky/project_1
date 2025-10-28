import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

class IMUCentre {
  static final IMUCentre _instance = IMUCentre._internal();
  factory IMUCentre() => _instance;
  IMUCentre._internal();

  final StreamController<AccelerometerEvent> _accelerometerController =
      StreamController<AccelerometerEvent>.broadcast();
  final StreamController<GyroscopeEvent> _gyroscopeController =
      StreamController<GyroscopeEvent>.broadcast();
  final StreamController<MagnetometerEvent> _magnetometerController =
      StreamController<MagnetometerEvent>.broadcast();
  final StreamController<double> _magnitudeController =
      StreamController<double>.broadcast();

  Stream<AccelerometerEvent> get accelerometerStream =>
      _accelerometerController.stream;
  Stream<GyroscopeEvent> get gyroscopeStream => _gyroscopeController.stream;
  Stream<MagnetometerEvent> get magnetometerStream =>
      _magnetometerController.stream;
  Stream<double> get magnitudeStream => _magnitudeController.stream;

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetoSubscription;

  void startIMUUpdates() {
    // Use userAccelerometerEvents instead of accelerometerEvents
    // This automatically excludes gravity for motion detection
    _accelSubscription = userAccelerometerEvents.listen((
      UserAccelerometerEvent event,
    ) {
      // Convert to AccelerometerEvent for compatibility
      final accelEvent = AccelerometerEvent(event.x, event.y, event.z);
      _accelerometerController.add(accelEvent);
      _calculateAndBroadcastMagnitude(event);
    });

    _gyroSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _gyroscopeController.add(event);
    });

    _magnetoSubscription = magnetometerEvents.listen((MagnetometerEvent event) {
      _magnetometerController.add(event);
    });
  }

  void _calculateAndBroadcastMagnitude(UserAccelerometerEvent event) {
    // Calculate magnitude without gravity (already removed by userAccelerometerEvents)
    // This will be ~0 when device is at rest, and spike during actual movement
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _magnitudeController.add(magnitude);
  }

  void stopIMUUpdates() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magnetoSubscription?.cancel();
  }

  void dispose() {
    stopIMUUpdates();
    _accelerometerController.close();
    _gyroscopeController.close();
    _magnetometerController.close();
    _magnitudeController.close();
  }
}
