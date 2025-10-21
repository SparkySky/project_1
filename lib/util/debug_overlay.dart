import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:huawei_location/huawei_location.dart';
import '../app_theme.dart'; // Using AppTheme for colors
import 'package:permission_handler/permission_handler.dart';

class DebugOverlayWidget extends StatefulWidget {
  const DebugOverlayWidget({super.key});

  @override
  State<DebugOverlayWidget> createState() => _DebugOverlayWidgetState();
}

class _DebugOverlayWidgetState extends State<DebugOverlayWidget> {
  Location? _location;
  AccelerometerEvent? _accel;
  GyroscopeEvent? _gyro;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  int? _locCallbackId;
  final FusedLocationProviderClient _locationService = FusedLocationProviderClient();

  LocationCallback? _locationCallback;

  @override
  void initState() {
    super.initState();
    _startSensorListeners();
    _startLocationUpdates();
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

  Future<void> _startLocationUpdates() async {
    try {
      // Check for location permissions using permission_handler
      var statusWhenInUse = await Permission.locationWhenInUse.status;
      var statusAlways = await Permission.locationAlways.status;

      // Check if either 'When In Use' or 'Always' is granted
      if (!statusWhenInUse.isGranted && !statusAlways.isGranted) {
        debugPrint("DebugOverlay: Location permission not granted.");
        return; // Don't try to get location if not granted
      }

      LocationRequest request = LocationRequest()
        ..priority = LocationRequest.PRIORITY_HIGH_ACCURACY
        ..interval = 2000; // Update every 2 seconds

      // 1. Define the callback handlers
      void onLocationUpdateResult(LocationResult locationResult) {
        if (locationResult.lastLocation != null && mounted) {
          setState(() {
            _location = locationResult.lastLocation;
          });
        }
      }
      void onLocationAvailability(LocationAvailability availability) {
        // You can add debug prints here if needed
      }

      // 2. Create the LocationCallback object
      _locationCallback = LocationCallback(
        onLocationResult: onLocationUpdateResult,
        onLocationAvailability: onLocationAvailability,
      );

      // 3. Use the correct method name: 'requestLocationUpdatesCb'
      _locCallbackId = await _locationService.requestLocationUpdatesCb(
        request,
        _locationCallback!, // Pass the callback object
      );
    } catch (e) {
      debugPrint("Error starting location updates for overlay: $e");
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    if (_locCallbackId != null) {
      try {
        _locationService.removeLocationUpdates(_locCallbackId!);
      } catch (e) {
        debugPrint("Error removing location updates from overlay: $e");
      }
    }
    super.dispose();
  }

  // --- MODIFIED: This method includes more accuracy details ---
  String _formatLocation(Location? loc) {
    if (loc == null) return "Location: Waiting...";
    String lat = loc.latitude?.toStringAsFixed(5) ?? 'N/A';
    String lon = loc.longitude?.toStringAsFixed(5) ?? 'N/A';
    String hAcc = loc.horizontalAccuracyMeters?.toStringAsFixed(1) ?? '?';
    String vAcc = loc.verticalAccuracyMeters?.toStringAsFixed(1) ?? '?';
    String sAcc = loc.speedAccuracyMetersPerSecond?.toStringAsFixed(1) ?? '?';
    String speed = loc.speed?.toStringAsFixed(1) ?? '?';

    // Format string to include more details concisely
    return "Loc: ($lat, $lon) | Acc(H/V/S): ${hAcc}m/${vAcc}m/${sAcc}m/s | Spd: ${speed}m/s";
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
    // Positioned at the bottom, above any bottom nav bar (adjust `bottom` as needed)
    return Positioned(
      bottom: 80, // Adjust this value if it overlaps with your BottomNavBar
      left: 10,
      right: 10,
      child: IgnorePointer(
        // Prevent the overlay from capturing touch events
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}