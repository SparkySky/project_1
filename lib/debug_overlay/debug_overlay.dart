import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:huawei_location/huawei_location.dart';
import '../app_theme.dart';
import '../sensors/location_centre.dart';
import 'debug_state.dart';

class DebugOverlayWidget extends StatefulWidget {
  const DebugOverlayWidget({super.key});

  @override
  State<DebugOverlayWidget> createState() => _DebugOverlayWidgetState();
}

class _DebugOverlayWidgetState extends State<DebugOverlayWidget> {
  final DebugState _debugState = DebugState();
  final LocationServiceHelper _locationHelper = LocationServiceHelper();

  Location? _location;
  AccelerometerEvent? _accel;
  GyroscopeEvent? _gyro;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _locSub;

  @override
  void initState() {
    super.initState();
    _debugState.addListener(_onDebugStateChanged);
    _startSensorListeners();
    _startLocationUpdates();
  }

  void _onDebugStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startSensorListeners() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((event) {
      if (mounted) setState(() => _accel = event);
    }, onError: (e) {
      debugPrint('DebugOverlay Accel Error: $e');
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((event) {
      if (mounted) setState(() => _gyro = event);
    }, onError: (e) {
      debugPrint('DebugOverlay Gyro Error: $e');
    });
  }

  void _startLocationUpdates() {
    _locSub = _locationHelper.getLocationStream().listen((location) {
      if (mounted) {
        setState(() {
          _location = location;
        });
      }
    }, onError: (e) {
      debugPrint("Error in debug overlay location stream: $e");
    });
  }

  @override
  void dispose() {
    _debugState.removeListener(_onDebugStateChanged);
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _locSub?.cancel();
    super.dispose();
  }

  String _formatLocation(Location? loc) {
    if (loc == null) return "Location: Waiting...";
    String lat = loc.latitude?.toStringAsFixed(5) ?? 'N/A';
    String lon = loc.longitude?.toStringAsFixed(5) ?? 'N/A';
    String hAcc = loc.horizontalAccuracyMeters?.toStringAsFixed(1) ?? '?';
    String speed = loc.speed?.toStringAsFixed(1) ?? '?';
    return "Loc: ($lat, $lon) | Acc: ${hAcc}m | Spd: ${speed}m/s";
  }

  String _formatAccel(AccelerometerEvent? e) {
    if (e == null) return "Accel: Waiting...";
    return "Accel (x/y/z): ${e.x.toStringAsFixed(2)} / ${e.y.toStringAsFixed(2)} / ${e.z.toStringAsFixed(2)}";
  }

  String _formatGyro(GyroscopeEvent? e) {
    if (e == null) return "Gyro: Waiting...";
    return "Gyro (x/y/z): ${e.x.toStringAsFixed(2)} / ${e.y.toStringAsFixed(2)} / ${e.z.toStringAsFixed(2)}";
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 10,
      right: 10,
      child: IgnorePointer(
        ignoring: true,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DEBUG OVERLAY',
                  style: TextStyle(
                    color: AppTheme.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatLocation(_location),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  _formatAccel(_accel),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  _formatGyro(_gyro),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                // Other debug info...
              ],
            ),
          ),
        ),
      ),
    );
  }
}
