import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class IMUService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  void start() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      // Handle accelerometer data
    });
    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      // Handle gyroscope data
    });
    _magnetometerSubscription = magnetometerEvents.listen((event) {
      // Handle magnetometer data
    });
  }

  void stop() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
  }
}
