import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

class IMUCentre {
  static final IMUCentre _instance = IMUCentre._internal();
  factory IMUCentre() => _instance;
  IMUCentre._internal();

  final StreamController<AccelerometerEvent> _accelerometerController = StreamController<AccelerometerEvent>.broadcast();
  final StreamController<GyroscopeEvent> _gyroscopeController = StreamController<GyroscopeEvent>.broadcast();
  final StreamController<MagnetometerEvent> _magnetometerController = StreamController<MagnetometerEvent>.broadcast();
  final StreamController<double> _magnitudeController = StreamController<double>.broadcast();

  Stream<AccelerometerEvent> get accelerometerStream => _accelerometerController.stream;
  Stream<GyroscopeEvent> get gyroscopeStream => _gyroscopeController.stream;
  Stream<MagnetometerEvent> get magnetometerStream => _magnetometerController.stream;
  Stream<double> get magnitudeStream => _magnitudeController.stream;
  
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _gyroscopeSubscription;
  StreamSubscription? _magnetometerSubscription;

  void startIMUUpdates() {
    _accelerometerSubscription ??= accelerometerEvents.listen((event) {
      _accelerometerController.add(event);
      _calculateMagnitude(event);
    });

    _gyroscopeSubscription ??= gyroscopeEvents.listen((event) {
      _gyroscopeController.add(event);
    });
    
    _magnetometerSubscription ??= magnetometerEvents.listen((event) {
        _magnetometerController.add(event);
    });
  }

  void _calculateMagnitude(AccelerometerEvent event) {
    final magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
    _magnitudeController.add(magnitude);
  }

  void stopIMUUpdates() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
  }
  
  void dispose() {
    stopIMUUpdates();
    _accelerometerController.close();
    _gyroscopeController.close();
    _magnetometerController.close();
    _magnitudeController.close();
  }
}
