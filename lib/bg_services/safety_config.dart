/// Central configuration file for all safety trigger parameters
/// Modify these values to adjust sensitivity and behavior
import 'dart:math';

class SafetyConfig {
  // ==================== TIMING PARAMETERS ====================

  /// Duration of data collection window after initial trigger (seconds)
  static const int collectionWindowSeconds = 8;

  /// Audio recording duration for evidence (seconds)
  static const int audioRecordingDurationSeconds = 20;

  /// Cooldown period before resuming monitoring after incident (seconds)
  static const int cooldownPeriodSeconds = 30;

  /// Interval between sensor data logs during collection (seconds)
  static const double sensorLogIntervalSeconds = 0.5;

  // ==================== IMU SENSOR THRESHOLDS ====================

  /// Accelerometer threshold for high-G detection (m/s²)
  /// Typical values:
  /// - Walking: 1-2 m/s²
  /// - Running: 3-5 m/s²
  /// - Fall/Impact: 20-40 m/s²
  /// - Car crash: 50+ m/s²
  static const double accelHighGThreshold = 25.0;

  /// Accelerometer threshold during collection window (m/s²)
  /// Only log sensor data exceeding this threshold
  static const double accelCollectionThreshold = 15.0;

  /// Gyroscope threshold for violent rotation (rad/s)
  /// Typical values:
  /// - Normal head turn: 1-2 rad/s
  /// - Quick movement: 3-5 rad/s
  /// - Fall/spin: 8-15 rad/s
  /// - Violent rotation: 15+ rad/s
  static const double gyroHighRotationThreshold = 10.0;

  /// Gyroscope threshold during collection window (rad/s)
  static const double gyroCollectionThreshold = 6.0;

  /// Magnetometer threshold for unusual magnetic field changes (μT)
  /// Used to detect environmental anomalies
  /// Earth's magnetic field: ~25-65 μT
  /// Sudden changes may indicate metal objects, electrical equipment
  static const double magnetometerChangeThreshold = 20.0;

  // ==================== AUDIO DETECTION ====================

  /// Emergency keywords to detect
  static const List<String> emergencyKeywords = [
    'help',
    'tolong', // Malay
    'sakit', // Malay for "pain/hurt"
    'sos',
    'fire',
    'save me',
    'danger',
    'emergency',
    'call police',
    'ambulance',
  ];

  /// Sound level threshold for loud noise detection (dB)
  /// Typical values:
  /// - Normal conversation: 60 dB
  /// - Shouting: 80-90 dB
  /// - Scream: 100-120 dB
  static const double soundLevelThreshold = 85.0;

  /// Minimum confidence for speech recognition (0.0 - 1.0)
  static const double speechRecognitionConfidence = 0.6;

  // ==================== FALSE POSITIVE ELIMINATION ====================

  /// Minimum duration for sustained high acceleration (seconds)
  /// Helps eliminate brief hand/bag swings
  static const double minSustainedAccelDuration = 0.3;

  /// Maximum frequency for repetitive motion (Hz)
  /// Walking/swinging typically 1-2 Hz, impacts are single events
  static const double maxRepetitiveMotionFrequency = 3.0;

  /// Require multiple sensor triggers for activation
  /// E.g., require both high accel AND (gyro OR audio)
  static const bool requireMultipleTriggers = true;

  /// Time window for multiple triggers to occur (seconds)
  static const double multipleTriggerWindowSeconds = 1.0;

  // ==================== GEMINI AI PARAMETERS ====================

  /// Gemini model to use
  static const String geminiModel = 'gemini-2.0-flash-exp';

  /// Temperature for AI responses (0.0 - 1.0)
  /// Lower = more conservative, Higher = more creative
  static const double geminiTemperature = 0.3;

  /// Maximum tokens for AI response
  static const int geminiMaxTokens = 500;

  /// AI prompt template
  static const String geminiPromptTemplate = '''
Analyze this 8-second safety monitoring data to determine if a REAL emergency occurred.

INITIAL TRIGGERS: {triggers}

SENSOR DATA (high magnitude events only):
{sensorData}

AUDIO TRANSCRIPT: "{transcript}"

EMOTIONAL INDICATORS: {emotions}

CONTEXT: This is from a personal safety monitoring system in Malaysia. 

CRITICAL: You MUST identify false positives:
- Normal activities: walking, running, exercising, getting in/out of vehicles
- Conversational context: discussing events, movies, news, stories
- Routine actions: closing doors, dropping objects, sudden stops
- Phone handling: picking up, putting down, pocket movement

RESPOND ONLY with valid JSON:
{
  "isIncident": boolean,
  "confidence": 0.0-1.0,
  "incidentType": "Fall|Assault|Crash|Medical Emergency|False Positive",
  "description": "one clear paragraph explaining your decision",
  "reasoning": "why this is/isn't an emergency",
  "district": "",
  "postcode": "",
  "state": "Malaysia"
}

If ANY doubt exists, classify as false positive. Real emergencies have clear, consistent indicators.
''';

  // ==================== BACKGROUND SERVICE ====================

  /// Notification channel ID
  static const String notificationChannelId = 'mysafezone_foreground';

  /// Notification channel name
  static const String notificationChannelName = 'MYSafeZone Monitoring';

  /// Foreground service notification ID
  static const int foregroundServiceNotificationId = 888;

  // ==================== DATA STORAGE ====================

  /// Maximum number of incident logs to keep
  static const int maxIncidentLogs = 100;

  /// Auto-delete logs older than (days)
  static const int logRetentionDays = 30;

  /// Compress audio files for storage
  static const bool compressAudioFiles = true;

  // ==================== STREAM UPLOAD ====================

  /// Enable real-time streaming of incident data
  static const bool enableStreamUpload = true;

  /// Stream upload chunk size (bytes)
  static const int streamUploadChunkSize = 65536; // 64 KB

  /// Stream upload interval (seconds)
  static const double streamUploadIntervalSeconds = 2.0;

  // ==================== DEBUGGING ====================

  /// Enable verbose logging
  static const bool enableVerboseLogging = true;

  /// Log sensor data to console during collection
  static const bool logSensorDataToConsole = true;

  /// Save raw sensor data for debugging
  static const bool saveRawSensorData = false;

  // ==================== UTILITY METHODS ====================

  /// Calculate magnitude from 3D vector
  static double calculateMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Check if acceleration indicates potential incident
  static bool isHighAcceleration(double magnitude) {
    return magnitude > accelHighGThreshold;
  }

  /// Check if rotation indicates potential incident
  static bool isHighRotation(double magnitude) {
    return magnitude > gyroHighRotationThreshold;
  }

  /// Check if acceleration should be logged during collection
  static bool shouldLogAcceleration(double magnitude) {
    return magnitude > accelCollectionThreshold;
  }

  /// Check if rotation should be logged during collection
  static bool shouldLogRotation(double magnitude) {
    return magnitude > gyroCollectionThreshold;
  }

  /// Check if magnetometer change is significant
  static bool isSignificantMagnetometerChange(double change) {
    return change.abs() > magnetometerChangeThreshold;
  }

  /// Format duration for display
  static String formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    return '${seconds}s';
  }
}

/// Represents a single sensor data point logged during collection
class SensorDataPoint {
  final DateTime timestamp;
  final double accelX, accelY, accelZ;
  final double gyroX, gyroY, gyroZ;
  final double magX, magY, magZ;
  final double accelMagnitude;
  final double gyroMagnitude;
  final String triggerReason;

  SensorDataPoint({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.magX,
    required this.magY,
    required this.magZ,
    required this.accelMagnitude,
    required this.gyroMagnitude,
    required this.triggerReason,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'accel': {
      'x': accelX.toStringAsFixed(3),
      'y': accelY.toStringAsFixed(3),
      'z': accelZ.toStringAsFixed(3),
      'magnitude': accelMagnitude.toStringAsFixed(3),
    },
    'gyro': {
      'x': gyroX.toStringAsFixed(3),
      'y': gyroY.toStringAsFixed(3),
      'z': gyroZ.toStringAsFixed(3),
      'magnitude': gyroMagnitude.toStringAsFixed(3),
    },
    'magnetometer': {
      'x': magX.toStringAsFixed(3),
      'y': magY.toStringAsFixed(3),
      'z': magZ.toStringAsFixed(3),
    },
    'reason': triggerReason,
  };

  @override
  String toString() {
    return 'SensorData(${timestamp.toString().substring(11, 23)}, '
        'Accel: ${accelMagnitude.toStringAsFixed(1)} m/s², '
        'Gyro: ${gyroMagnitude.toStringAsFixed(1)} rad/s, '
        'Reason: $triggerReason)';
  }
}
