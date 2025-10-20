// lib/background_service.dart
import 'dart:async';
import 'dart:convert'; // For JSON encoding sensor data
import 'dart:math';
import 'dart:ui';
import 'dart:io'; // For File path manipulation if needed by Drive
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Needed for WidgetsFlutterBinding, but avoid UI code
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart'; // For AndroidServiceInstance
import 'package:flutter_sound/flutter_sound.dart' as flutterSound;
import 'package:permission_handler/permission_handler.dart'; // Might need for checks inside service
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:huawei_location/huawei_location.dart';
import 'package:huawei_drive/huawei_drive.dart';
import 'package:huawei_account/huawei_account.dart'; // Needed for Drive credentials

// Import your generated CloudDB model file
import '../models/clouddb_model.dart' as db;
import 'sensor_manager.dart';

// --- Service Initialization (Called from main.dart) ---
Future<void> initializeBackgroundService() async {
  if (kDebugMode) {
    print("Initializing Background Service - Emergency Response Module");
  }
  final service = FlutterBackgroundService();

  await service.configure(
    // Android Configuration
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true, // Run as foreground service
      autoStart: false, // Don't start automatically on boot/app start
      notificationChannelId: 'mysafezone_foreground', // Match channel id
      initialNotificationTitle: "MYSafeZone Active",
      initialNotificationContent: "Monitoring for safety.",
      foregroundServiceNotificationId: 888, // Unique ID for the notification
    ),
    // iOS Configuration (Basic placeholder)
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart, // Same entry point for foreground
      // onBackground: onIosBackground, // Optional separate handler for iOS background fetch
    ),
  );
}

// --- Main Background Entry Point (Android onStart) ---
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure plugins are registered in this isolate
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Add a small delay to allow native initialization to complete
  await Future.delayed(const Duration(seconds: 2));

  // --- Get Pre-Initialized CloudDB Instance ---
  // Initialization is now handled in main.dart to avoid isolate issues.
  AGConnectCloudDB? cloudDB;
  try {
    if (kDebugMode) print("[BG_SERVICE] Getting CloudDB instance...");
    cloudDB = AGConnectCloudDB.getInstance();
    // We assume initialize() and createObjectType() have been called in main.dart
    if (kDebugMode) print("[BG_SERVICE] CloudDB instance retrieved.");
  } catch (e) {
    if (kDebugMode) print("[BG_SERVICE] CRITICAL CloudDB getInstance error: $e");
    service.stopSelf();
    return;
  }


  // --- Service State ---
  bool isMonitoring = true; // Flag to control monitoring loops/listeners
  bool isTriggering = false; // Debounce flag to prevent multiple triggers
  final SafetyTriggerManager manager = SafetyTriggerManager(cloudDB);

  print("[BG_SERVICE] Service started. Monitoring...");

  // Update notification if needed (optional)
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService(); // Ensure it stays foreground
    service.setForegroundNotificationInfo( // Set initial content again
      title: "MYSafeZone Active",
      content: "Monitoring for safety.",
    );
  }

  // --- Service Control Listener (from UI) ---
  service.on('stopService').listen((event) {
    print("[BG_SERVICE] Stop event received.");
    isMonitoring = false; // Signal loops/listeners to stop
    manager.stopAllListeners(); // Clean up HMS/Sensor listeners
    service.stopSelf(); // Stop the foreground service
  });

  // --- Start Monitoring Logic ---
  manager.startMonitoring(onTrigger: (triggerType) async {
    if (!isMonitoring || isTriggering) return; // Ignore if stopped or already processing

    isTriggering = true;
    print("[BG_SERVICE] !!!!!!! TRIGGER DETECTED: $triggerType !!!!!!!");

    // 1. Update notification
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "MYSafeZone: INCIDENT DETECTED",
        content: "Analyzing & recording data...",
      );
    }

    // 2. Stop monitoring listeners temporarily to process/record
    await manager.stopAllListeners(); // Stop sensors and audio analysis

    // 3. Handle the incident (get location, record audio, save to DB)
    bool incidentHandledSuccessfully = await manager.handleIncidentTrigger(triggerType, service); // Pass service instance

    // 4. Initiate Emergency Response Module (if handling was successful)
    if (incidentHandledSuccessfully) {
      print("[BG_SERVICE] ===> Initiating Emergency Response Module <===");
    } else {
      print("[BG_SERVICE] Incident handling failed. Not initiating Emergency Response.");
    }

    // 5. Cooldown and Reset
    print("[BG_SERVICE] Cooldown period...");
    await Future.delayed(const Duration(seconds: 30)); // Wait 30 seconds

    isTriggering = false; // Reset debounce flag

    if (isMonitoring) { // Only restart if the service wasn't stopped during handling
      print("[BG_SERVICE] Resetting to monitoring state...");
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "MYSafeZone Active",
          content: "Monitoring for safety.",
        );
      }
      // Restart monitoring (pass the callback handler again)
      manager.startMonitoring(onTrigger: (newTriggerType) async {
        if (!isMonitoring || isTriggering) return;
        isTriggering = true;
        print("[BG_SERVICE] !!!!!!! TRIGGER DETECTED: $newTriggerType !!!!!!!");
        if (service is AndroidServiceInstance) { service.setForegroundNotificationInfo(title: "MYSafeZone: INCIDENT DETECTED", content: "Analyzing & recording data..."); }
        await manager.stopAllListeners();
        bool success = await manager.handleIncidentTrigger(newTriggerType, service);
        if (success) { print("[BG_SERVICE] ===> Initiating Emergency Response Module <==="); } else { print("[BG_SERVICE] Incident handling failed."); }
        await Future.delayed(const Duration(seconds: 30));
        isTriggering = false;
        if (isMonitoring) { /* Recursive restart logic simplified, ensure onTrigger is rebound */ }
      });
    } else {
      print("[BG_SERVICE] Service was stopped during incident handling. Not restarting monitoring.");
      service.stopSelf(); // Ensure service stops if isMonitoring became false
    }
  });
} // End of onStart

// --- Main Logic Class ---
class SafetyTriggerManager {
  final AGConnectCloudDB _cloudDB;
  final SensorManager _sensorManager;

  // HMS Listeners
  FusedLocationProviderClient? _locationProvider;

  // Audio Recorder
  flutterSound.FlutterSoundRecorder? _audioRecorder;
  String? _audioPath;
  bool _isRecording = false;

  // State
  Function(String)? _onTrigger;
  int? _locationRequestCode;
  String? lastIncidentId;

  SafetyTriggerManager(this._cloudDB) : _sensorManager = SensorManager() {
    _locationProvider = FusedLocationProviderClient();
    _audioRecorder = flutterSound.FlutterSoundRecorder();
  }

  void startMonitoring({required Function(String) onTrigger}) async {
    print("[BG_SERVICE_MANAGER] Starting monitoring...");
    _onTrigger = onTrigger;

    var micStatus = await Permission.microphone.status;
    var locStatus = await Permission.locationAlways.status;
    if (!micStatus.isGranted || !locStatus.isGranted) {
      print("[BG_SERVICE_MANAGER] ERROR: Required permissions (Mic/LocationAlways) not granted.");
      return;
    }

    await _startAudioRecording();
    _sensorManager.startMonitoring(onTrigger: onTrigger);
  }

  Future<void> _startAudioRecording() async {
    if (_isRecording) {
      await _audioRecorder?.stopRecorder();
    }
    try {
      final directory = await getTemporaryDirectory();
      _audioPath = '${directory.path}/safety_trigger_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _audioRecorder?.openRecorder();
      await _audioRecorder?.startRecorder(
        toFile: _audioPath,
        codec: flutterSound.Codec.aacADTS,
      );
      _isRecording = true;
      print("[BG_SERVICE_MANAGER] Audio recording started to $_audioPath");
    } catch (e) {
      print("[BG_SERVICE_MANAGER] Error starting audio recording: $e");
      _audioPath = null;
      _isRecording = false;
    }
  }

  Future<bool> handleIncidentTrigger(String triggerType, ServiceInstance service) async {
    print("[BG_SERVICE_MANAGER] Handling trigger: $triggerType");
    String? finalizedAudioPath = _audioPath;
    if (_isRecording) {
      try {
        await _audioRecorder?.stopRecorder();
        _isRecording = false;
        print("[BG_SERVICE_MANAGER] Audio recording stopped. File: $finalizedAudioPath");
      } catch (e) {
        print("[BG_SERVICE_MANAGER] Error stopping recorder: $e");
        finalizedAudioPath = null;
      }
    } else {
      finalizedAudioPath = null;
    }

    Location? location;
    try {
      location = await _locationProvider?.getLastLocation();
      if (location == null) {
        print("[BG_SERVICE_MANAGER] getLastLocation failed, requesting updates...");
        final Completer<Location> locationCompleter = Completer<Location>();

        void onLocationUpdateResult(LocationResult locationResult) {
          Location? newLocation = locationResult.lastLocation ?? (locationResult.locations!.isNotEmpty ? locationResult.locations!.last : null);
          if (newLocation != null && !locationCompleter.isCompleted) {
            locationCompleter.complete(newLocation);
            if (_locationRequestCode != null) { _locationProvider?.removeLocationUpdates(_locationRequestCode!); _locationRequestCode = null; }
          }
        }
        void onLocationAvailability(LocationAvailability availability) {}

        final LocationCallback locationCallback = LocationCallback(onLocationResult: onLocationUpdateResult, onLocationAvailability: onLocationAvailability);
        LocationRequest locationRequest = LocationRequest()..priority = LocationRequest.PRIORITY_HIGH_ACCURACY;

        _locationRequestCode = await _locationProvider?.requestLocationUpdatesCb(locationRequest, locationCallback);

        location = await locationCompleter.future.timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            if (_locationRequestCode != null) { _locationProvider?.removeLocationUpdates(_locationRequestCode!); _locationRequestCode = null; }
            return Future.value(null);
          },
        );
      }
    } catch (e) {
      print("[BG_SERVICE_MANAGER] Error getting location: $e");
      if (_locationRequestCode != null) { try { await _locationProvider?.removeLocationUpdates(_locationRequestCode!); _locationRequestCode = null; } catch (_) {} }
    }

    if (location == null) {
      print("[BG_SERVICE_MANAGER] CRITICAL: Failed to get location.");
      return false;
    }
    print("[BG_SERVICE_MANAGER] Location acquired: ${location.latitude}, ${location.longitude}");

    String? mediaUri;
    if (finalizedAudioPath != null) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(title: "MYSafeZone: Incident Detected", content: "Uploading audio evidence...");
      }
      mediaUri = await _uploadAudioToDrive(finalizedAudioPath);
      if (mediaUri == null) {
        print("[BG_SERVICE_MANAGER] WARNING: Failed to upload audio to Drive.");
      }
    }

    String uid = await _getOrCreateDeviceUID();
    String mediaId = Uuid().v4();
    db.media mediaObj = db.media(
      mediaID: mediaId,
      order: 1,
      forLog: 1,
      mediaType: "aac",
      mediaURI: mediaUri ?? "UPLOAD_FAILED",
    );

    lastIncidentId = Uuid().v4();
    db.incidents incidentObj = db.incidents(
      iid: lastIncidentId,
      uid: uid,
      latitude: location.latitude,
      longitude: location.longitude,
      datetime: DateTime.now(),
      incidentType: triggerType,
      isAIGenerated: 1,
      desc: "AI/Sensor detected '$triggerType'. Location: ${location.latitude?.toStringAsFixed(5)}, ${location.longitude?.toStringAsFixed(5)}",
      mediaID: mediaId,
      status: 1,
    );

    try {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(title: "MYSafeZone: Incident Detected", content: "Saving incident details...");
      }
      final zoneConfig = AGConnectCloudDBZoneConfig(zoneName: "MYSafeZone");
      final cloudDBZone = await _cloudDB.openCloudDBZone(zoneConfig: zoneConfig);
      await cloudDBZone.executeUpsert(objectTypeName: "media", entries: [mediaObj.getObjectData()]);
      await cloudDBZone.executeUpsert(objectTypeName: "incidents", entries: [incidentObj.getObjectData()]);
      print("[BG_SERVICE_MANAGER] Incident saved to CloudDB. IID: $lastIncidentId");
      return true;
    } catch (e) {
      print("[BG_SERVICE_MANAGER] CloudDB write failed: $e");
      return false;
    }
  }

  Future<String?> _uploadAudioToDrive(String filePath) async {
    AuthAccount? account = await AccountAuthManager.getAuthResult();
    String? accessToken = account?.accessToken;
    if (accessToken == null) {
      return "AUTH_FAILED";
    }
    final DriveCredentials credentials = DriveCredentials(accessToken: accessToken);
    try {
      final Drive drive = await Drive.init(credentials);
      final DriveFile driveMetadata = DriveFile(fileName: filePath.split('/').last, mimeType: "audio/aac");
      final DriveFile? driveFile = await drive.files.create(
          FilesRequest.create(driveMetadata, fileContent: DriveFileContent(path: filePath), fields: '*')
      );
      return driveFile?.id;
    } catch (e) {
      return "UPLOAD_EXCEPTION";
    }
  }

  Future<String> _getOrCreateDeviceUID() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('device_uid');
    if (uid == null) {
      uid = Uuid().v4();
      await prefs.setString('device_uid', uid);
      db.users placeholderUser = db.users(
          uid: uid,
          username: "Device-$uid",
          allowDiscoverable: false,
          allowEmergencyAlert: true,
          postcode: "UNKNOWN",
          state: "UNKNOWN"
      );
      try {
        final zoneConfig = AGConnectCloudDBZoneConfig(zoneName: "MYSafeZone");
        final zone = await _cloudDB.openCloudDBZone(zoneConfig: zoneConfig);
        await zone.executeUpsert(objectTypeName: "users", entries: [placeholderUser.getObjectData()]);
      } catch (e) {
        print("[BG_SERVICE_MANAGER] Failed to create placeholder user: $e");
      }
    }
    return uid;
  }

  Future<void> stopAllListeners() async {
    print("[BG_SERVICE_MANAGER] Stopping all listeners...");
    _sensorManager.stopAllListeners();

    if (_locationRequestCode != null) {
      try {
        await _locationProvider?.removeLocationUpdates(_locationRequestCode!);
      } catch (e) {print("[BG_SERVICE_MANAGER] Error removing location updates: $e");}
      _locationRequestCode = null;
    }

    if (_isRecording) {
      try {
        await _audioRecorder?.stopRecorder();
        _isRecording = false;
      } catch (e) { print("[BG_SERVICE_MANAGER] Error stopping dangling recording: $e");}
    }
    print("[BG_SERVICE_MANAGER] Listeners stopped.");
  }

}