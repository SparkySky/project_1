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
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sound/flutter_sound.dart' as flutterSound;
import 'package:permission_handler/permission_handler.dart'; // Might need for checks inside service
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// --- HMS / AGConnect Imports (using package: imports as they resolve to local paths) ---
// If these cause errors, ensure the paths in pubspec.yaml are correct
import 'package:agconnect_core/agconnect_core.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:huawei_location/huawei_location.dart';
import 'package:huawei_map/huawei_map.dart' as huaweiMap; // Use prefix
// Important: Use ML Language for SoundDetector and ASR
import 'package:huawei_ml_language/huawei_ml_language.dart';
import 'package:huawei_drive/huawei_drive.dart';
import 'package:huawei_account/huawei_account.dart'; // Needed for Drive credentials


// Import your generated CloudDB model file
import '/models/clouddb_model.dart' as db;

// --- Service Initialization (Called from main.dart) ---
Future<void> initializeBackgroundService() async {
  if (kDebugMode) {
    print("Initializing Background Service - Emergency Response Module");
  }
  final service = FlutterBackgroundService();

  // Basic notification channel setup (optional, can be expanded)
  // const AndroidNotificationChannel channel = AndroidNotificationChannel(
  //   'mysafezone_foreground', // id
  //   'MYSafeZone Monitoring', // title
  //   description: 'Background service for safety monitoring.', // description
  //   importance: Importance.low, // Low importance to be less intrusive
  // );

  // If using flutter_local_notifications for channel creation
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  //    FlutterLocalNotificationsPlugin();
  // await flutterLocalNotificationsPlugin
  //    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
  //    ?.createNotificationChannel(channel);

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

// --- iOS Background Entry Point (Optional Placeholder) ---
// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async {
//   WidgetsFlutterBinding.ensureInitialized();
//   DartPluginRegistrant.ensureInitialized();
//   print('FLUTTER BACKGROUND FETCH');
//   // Add iOS specific background task handling if needed
//   return true;
// }


// --- Main Background Entry Point (Android onStart, iOS onForeground) ---
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure plugins are registered in this isolate
  WidgetsFlutterBinding.ensureInitialized(); // Needed for path_provider, etc.
  DartPluginRegistrant.ensureInitialized();

  // --- Initialize CloudDB (MUST be done inside the isolate) ---
  AGConnectCloudDB? cloudDB;
  try {
    // AGConnect core initializes natively via agconnect-services.json
    print("[BG_SERVICE] Initializing CloudDB...");
    cloudDB = await AGConnectCloudDB.getInstance();
    await cloudDB.initialize();
    await cloudDB.createObjectType(); // Uses Java models from plugin path
    print("[BG_SERVICE] CloudDB Initialized and ObjectType created.");
  } catch (e) {
    print("[BG_SERVICE] CRITICAL CloudDB init error: $e");
    // Consider stopping if CloudDB fails, as we can't save incidents
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
      // Placeholder: This is where you would invoke the next module/process
      // service.invoke("startEmergencyResponse", {"incidentId": manager.lastIncidentId});
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

  // HMS Listeners
  MLSoundDetector? _soundDetector; // Make nullable
  // MLAsrRecognizer? _asrRecognizer; // ASR setup is complex, maybe add later
  FusedLocationProviderClient? _locationProvider;

  // Sensor Listener Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  // Add magnetometer if needed: StreamSubscription<MagnetometerEvent>? _magSubscription;

  // Audio Recorder
  flutterSound.FlutterSoundRecorder? _audioRecorder;
  String? _audioPath;
  bool _isRecording = false;

  // State
  Function(String)? _onTrigger; // Callback function for trigger events
  int? _locationRequestCode; // ID for location update requests
  String? lastIncidentId; // To potentially pass to Emergency Response

  SafetyTriggerManager(this._cloudDB) {
    // Initialize non-nullable ones here or make them nullable
    _locationProvider = FusedLocationProviderClient();
    _audioRecorder = flutterSound.FlutterSoundRecorder();
  }

  void startMonitoring({required Function(String) onTrigger}) async {
    print("[BG_SERVICE_MANAGER] Starting monitoring...");
    _onTrigger = onTrigger;

    // --- Ensure Permissions ---
    // Although requested in main, double-check essential ones if possible
    var micStatus = await Permission.microphone.status;
    var locStatus = await Permission.locationAlways.status;
    if (!micStatus.isGranted || !locStatus.isGranted) {
      print("[BG_SERVICE_MANAGER] ERROR: Required permissions (Mic/LocationAlways) not granted. Monitoring cannot start effectively.");
      // We can't request permissions from background, user needs to grant them.
      // Service should probably stop or notify user via foreground notification?
      return; // Stop starting the monitoring
    }

    // 1. Initialize & Start Audio Recording (Circular Buffer - Simple Approach)
    // FlutterSound manages file size implicitly to some extent, but not truly circular.
    // We restart recording periodically or when triggered.
    await _startAudioRecording();

    // 2. Start HMS Sound Detector
    try {
      _soundDetector = MLSoundDetector(); // Initialize here
      _soundDetector?.setSoundDetectListener(_onSoundDetect);
      await _soundDetector?.start();
      print("[BG_SERVICE_MANAGER] SoundDetector started.");
    } catch(e) {
      print("[BG_SERVICE_MANAGER] Error starting SoundDetector: $e");
      _soundDetector = null; // Ensure it's null if init fails
    }


    // 3. Start HMS ASR (Keywords - Optional, Complex)
    // Continuous ASR is resource-intensive. Triggering ASR *after* sound detect
    // or impact might be more efficient. Skipping continuous ASR for now.


    // 4. Start IMU Sensors
    try {
      _accelSubscription = accelerometerEventStream(
          samplingPeriod: SensorInterval.normalInterval // Adjust interval if needed
      ).listen(_onAccelEvent, onError: (e) { print("[BG_SERVICE_MANAGER] Accel Error: $e");});

      _gyroSubscription = gyroscopeEventStream(
          samplingPeriod: SensorInterval.normalInterval
      ).listen(_onGyroEvent, onError: (e) { print("[BG_SERVICE_MANAGER] Gyro Error: $e");});
      print("[BG_SERVICE_MANAGER] IMU sensors started.");
    } catch (e) {
      print("[BG_SERVICE_MANAGER] Error starting IMU sensors: $e");
    }

  }

  Future<void> _startAudioRecording() async {
    if (_isRecording) {
      await _audioRecorder?.stopRecorder(); // Stop previous if any
    }
    try {
      final directory = await getTemporaryDirectory(); // Use temp dir
      _audioPath = '${directory.path}/safety_trigger_${DateTime.now().millisecondsSinceEpoch}.aac'; // Unique name

      await _audioRecorder?.openRecorder();
      await _audioRecorder?.startRecorder(
        toFile: _audioPath,
        codec: flutterSound.Codec.aacADTS, // AAC is widely compatible
      );
      _isRecording = true;
      print("[BG_SERVICE_MANAGER] Audio recording started to $_audioPath");
    } catch (e) {
      print("[BG_SERVICE_MANAGER] Error starting audio recording: $e");
      _audioPath = null;
      _isRecording = false;
    }
  }

  // --- Listener Callbacks ---

  // Sound Detector Callback
  void _onSoundDetect({int? result, int? errCode}) {
    if (errCode != null) {
      print("[BG_SERVICE_MANAGER] SoundDetect Error Code: $errCode");
      return;
    }
    if (result != null) {
      // ***** VERIFY CONSTANT VALUE FOR SCREAM from HMS Docs *****
      const int soundEventScream = 12; // Placeholder - MUST VERIFY
      print("[BG_SERVICE_MANAGER] Sound detected: ID $result");
      if (result == soundEventScream) {
        print("[BG_SERVICE_MANAGER] TRIGGER: Scream detected!");
        _onTrigger?.call("Scream Detected");
      }
      // Add other relevant sound IDs here (e.g., glass breaking, car alarm if supported)
    }
  }

  // Accelerometer Callback
  void _onAccelEvent(AccelerometerEvent event) {
    // Simple fall/impact detection (High-G event) - Tune threshold carefully!
    // Using magnitude of acceleration vector sqrt(x^2 + y^2 + z^2)
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    // Threshold needs tuning based on testing. Should be significantly > 9.8 (gravity)
    // Maybe > 30 or 40 for impacts?
    if (magnitude > 35.0) {
      print("[BG_SERVICE_MANAGER] TRIGGER: High-G event detected! ($magnitude m/s^2)");
      _onTrigger?.call("Impact Detected");
    }
  }

  // Gyroscope Callback
  void _onGyroEvent(GyroscopeEvent event) {
    // Detect sudden, violent rotation (High angular velocity) - Tune threshold!
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    // Threshold in radians per second. Needs testing.
    if (magnitude > 10.0) { // Example threshold for rapid spin/fall
      print("[BG_SERVICE_MANAGER] TRIGGER: Violent rotation detected! ($magnitude rad/s)");
      _onTrigger?.call("Violent Motion Detected");
    }
  }


  // --- Trigger Handling Flow ---
  Future<bool> handleIncidentTrigger(String triggerType, ServiceInstance service) async {
    print("[BG_SERVICE_MANAGER] Handling trigger: $triggerType");
    // 1. Stop audio recording to finalize the current file
    String? finalizedAudioPath = _audioPath; // Store current path
    if (_isRecording) {
      try {
        await _audioRecorder?.stopRecorder();
        _isRecording = false;
        print("[BG_SERVICE_MANAGER] Audio recording stopped. File: $finalizedAudioPath");
      } catch (e) {
        print("[BG_SERVICE_MANAGER] Error stopping recorder: $e");
        finalizedAudioPath = null; // Don't try to upload if stop failed
      }
    } else {
      finalizedAudioPath = null; // No active recording to upload
    }

    // 2. Get current location (with fallback to requesting updates)
    Location? location;
    try {
      location = await _locationProvider?.getLastLocation();

      if (location == null) {
        print("[BG_SERVICE_MANAGER] getLastLocation failed, requesting updates...");
        final Completer<Location> locationCompleter = Completer<Location>();

        void _onLocationUpdateResult(LocationResult locationResult) {
          Location? newLocation = locationResult.lastLocation ?? (locationResult.locations!.isNotEmpty ? locationResult.locations!.last : null);
          if (newLocation != null && !locationCompleter.isCompleted) {
            print("[BG_SERVICE_MANAGER] Received location update: ${newLocation.latitude}, ${newLocation.longitude}");
            locationCompleter.complete(newLocation);
            if (_locationRequestCode != null) { _locationProvider?.removeLocationUpdates(_locationRequestCode!); _locationRequestCode = null; }
          }
        }
        void _onLocationAvailability(LocationAvailability availability) { print("[BG_SERVICE_MANAGER] Loc Avail: ${availability.isLocationAvailable}"); }

        final LocationCallback locationCallback = LocationCallback(onLocationResult: _onLocationUpdateResult, onLocationAvailability: _onLocationAvailability);
        LocationRequest locationRequest = LocationRequest();
        locationRequest.priority = LocationRequest.PRIORITY_HIGH_ACCURACY;

        _locationRequestCode = await _locationProvider?.requestLocationUpdatesCb(locationRequest, locationCallback);
        print("[BG_SERVICE_MANAGER] Waiting for location update callback (Code: $_locationRequestCode)...");

        location = await locationCompleter.future.timeout(
          const Duration(seconds: 20), // Increased timeout slightly
          onTimeout: () {
            print("[BG_SERVICE_MANAGER] Timeout waiting for location update.");
            if (_locationRequestCode != null) { _locationProvider?.removeLocationUpdates(_locationRequestCode!); _locationRequestCode = null; }
            return Future.value(null);
          },
        );
      }
    } catch (e) {
      print("[BG_SERVICE_MANAGER] Error getting location: $e");
      location = null; // Ensure location is null on error
      // Clean up listener if it was registered
      if (_locationRequestCode != null) { try { _locationProvider?.removeLocationUpdates(_locationRequestCode!); _locationRequestCode = null; } catch (_) {} }
    }

    // FINAL LOCATION CHECK
    if (location == null) {
      print("[BG_SERVICE_MANAGER] CRITICAL: Failed to get location.");
      // Can't proceed without location, report failure
      return false;
    }
    print("[BG_SERVICE_MANAGER] Location acquired: ${location.latitude}, ${location.longitude}");


    // 3. Upload audio log to Drive Kit (if audio was recorded)
    String? mediaUri; // Keep track of Drive File ID
    if (finalizedAudioPath != null) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "MYSafeZone: Incident Detected", // Add the title back
          content: "Uploading audio evidence...",
        );
      }      mediaUri = await _uploadAudioToDrive(finalizedAudioPath);
      if (mediaUri == null) {
        print("[BG_SERVICE_MANAGER] WARNING: Failed to upload audio to Drive.");
        // Decide if this is critical. Maybe proceed without mediaURI?
      } else {
        print("[BG_SERVICE_MANAGER] Audio uploaded. Drive ID: $mediaUri");
        // Optionally delete local audio file after successful upload
        // try { File(finalizedAudioPath).delete(); } catch (_) {}
      }
    } else {
      print("[BG_SERVICE_MANAGER] No finalized audio path to upload.");
    }


    // 4. Get placeholder UID (or real UID if login is implemented)
    String uid = await _getOrCreateDeviceUID();

    // 5. Create media object in CloudDB (even if upload failed, record the attempt)
    String mediaId = Uuid().v4();
    db.media mediaObj = db.media(
      mediaID: mediaId,
      order: 1,
      forLog: 1, // 1 indicates it's a log file
      mediaType: "aac", // Match the recording codec
      mediaURI: mediaUri ?? "UPLOAD_FAILED", // Store ID or failure status
    );

    // 6. Create incident object in CloudDB
    lastIncidentId = Uuid().v4(); // Store for potential use by Emergency Response
    db.incidents incidentObj = db.incidents(
      iid: lastIncidentId,
      uid: uid,
      latitude: location.latitude,
      longitude: location.longitude,
      datetime: DateTime.now(), // Use current time
      incidentType: triggerType, // What triggered the event
      isAIGenerated: 1, // Flagged as AI/Sensor generated
      desc: "AI/Sensor detected '$triggerType'. Location: ${location.latitude?.toStringAsFixed(5)}, ${location.longitude?.toStringAsFixed(5)}", // Basic description
      mediaID: mediaId, // Link to the media object
      status: 1, // 1 = active/unresolved
    );

    // 7. Write to CloudDB
    try {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "MYSafeZone: Incident Detected",
          content: "Saving incident details...",
        );
      }

      final zoneConfig = AGConnectCloudDBZoneConfig(zoneName: "MYSafeZone"); // Use your actual Zone name
      final cloudDBZone = await _cloudDB.openCloudDBZone(zoneConfig: zoneConfig);

      // Upsert media object
      final mediaData = mediaObj.getObjectData();
      await cloudDBZone.executeUpsert(
        objectTypeName: "media",
        entries: [mediaData],
      );
      print("[BG_SERVICE_MANAGER] Media object saved to CloudDB.");

      // Upsert incident object
      final incidentData = incidentObj.getObjectData();
      await cloudDBZone.executeUpsert(
        objectTypeName: "incidents",
        entries: [incidentData],
      );
      print("[BG_SERVICE_MANAGER] Incident object saved to CloudDB. IID: $lastIncidentId");

      // Close the zone after use? Check documentation for best practice.
      // await _cloudDB.closeCloudDBZone(zone: cloudDBZone);

      return true; // Indicate success

    } catch (e) {
      print("[BG_SERVICE_MANAGER] CloudDB write failed: $e");
      // Optionally try to delete the uploaded Drive file if DB write fails? Complex.
      return false; // Indicate failure
    }
  } // End of handleIncidentTrigger


  // --- Helper Functions ---

  Future<String?> _uploadAudioToDrive(String filePath) async {
    print("[BG_SERVICE_MANAGER] Attempting to upload audio: $filePath");
    // --- Placeholder for Credentials ---
    // TODO: Replace with actual credential retrieval after login
    // This will likely involve getting the signed-in HuaweiIdAuthAccount
    AuthAccount? account = await AccountAuthManager.getAuthResult(); // Example
    String? accessToken = account?.accessToken; // Example: Get token

    if (accessToken == null) {
      print("[BG_SERVICE_MANAGER] Drive Upload Error: No Access Token found. User likely not logged in.");
      return "AUTH_FAILED"; // Indicate auth failure
    }

    final DriveCredentials credentials = DriveCredentials(
      accessToken: accessToken,
      // unionID: account?.unionId, // Add if needed by Drive init
    );
    // --- End Placeholder ---

    try {
      final Drive drive = await Drive.init(credentials);

      final DriveFile driveMetadata = DriveFile(
        fileName: filePath.split('/').last,
        mimeType: "audio/aac", // Match codec
      );

      // Use the correct FilesRequest constructor
      final DriveFile? driveFile = await drive.files.create(
          FilesRequest.create(
              driveMetadata,
              fileContent: DriveFileContent(path: filePath),
              // Optional: Set fields like '*' to get full file info back
              fields: '*'
          )
      );

      if (driveFile != null && driveFile.id != null) {
        print("[BG_SERVICE_MANAGER] Audio upload successful. Drive ID: ${driveFile.id}");
        return driveFile.id;
      } else {
        print("[BG_SERVICE_MANAGER] Drive upload returned null or no file ID.");
        return "UPLOAD_RETURNED_NULL";
      }
    } catch (e) {
      print("[BG_SERVICE_MANAGER] Drive upload exception: $e");
      return "UPLOAD_EXCEPTION";
    }
  }


  Future<String> _getOrCreateDeviceUID() async {
    // Uses SharedPreferences as a temporary substitute for user login UID
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('device_uid');

    if (uid == null) {
      uid = Uuid().v4();
      await prefs.setString('device_uid', uid);
      print("[BG_SERVICE_MANAGER] Generated new device UID: $uid");

      // Optional: Create a placeholder user entry in CloudDB
      db.users placeholderUser = db.users(
          uid: uid,
          username: "Device-$uid", // Simple username
          allowDiscoverable: false, // Default preferences
          allowEmergencyAlert: true,
          // Add default location fields if required by schema (might be null initially)
          postcode: "UNKNOWN",
          state: "UNKNOWN"
      );
      try {
        final zoneConfig = AGConnectCloudDBZoneConfig(zoneName: "MYSafeZone");
        final zone = await _cloudDB.openCloudDBZone(zoneConfig: zoneConfig);
        final userDataMap = placeholderUser.getObjectData();
        await zone.executeUpsert(
            objectTypeName: "users",
            entries: [userDataMap]
        );
        print("[BG_SERVICE_MANAGER] Created placeholder user in CloudDB.");
        // await _cloudDB.closeCloudDBZone(zone: zone);
      } catch (e) {
        print("[BG_SERVICE_MANAGER] Failed to create placeholder user: $e");
      }
    }
    return uid;
  }

  Future<void> stopAllListeners() async {
    print("[BG_SERVICE_MANAGER] Stopping all listeners...");
    // Stop Sensors
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;

    // Stop Sound Detector
    try {
      _soundDetector?.destroy(); // Use destroy if available
    } catch (e) { print("[BG_SERVICE_MANAGER] Error destroying SoundDetector: $e"); }
    _soundDetector = null;

    // Stop ASR if implemented
    // _asrRecognizer?.destroy();

    // Stop Location Updates if active
    if (_locationRequestCode != null) {
      try {
        await _locationProvider?.removeLocationUpdates(_locationRequestCode!);
      } catch (e) {print("[BG_SERVICE_MANAGER] Error removing location updates: $e");}
      _locationRequestCode = null;
    }

    // Don't stop audio recorder here, handleIncidentTrigger stops it to finalize file.
    // Ensure recorder is closed if service stops abruptly?
    if (_isRecording) { // If stopped outside of trigger sequence
      try {
        await _audioRecorder?.stopRecorder();
        _isRecording = false;
        print("[BG_SERVICE_MANAGER] Stopped dangling recording.");
      } catch (e) { print("[BG_SERVICE_MANAGER] Error stopping dangling recording: $e");}
    }
    // Close recorder only when completely stopping? Maybe not here.
    // await _audioRecorder?.closeRecorder();

    print("[BG_SERVICE_MANAGER] Listeners stopped.");
  }

} // End of SafetyTriggerManager