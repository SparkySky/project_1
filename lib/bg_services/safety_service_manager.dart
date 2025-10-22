// lib/bg_services/safety_service_manager.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'data_collection_manager.dart';
import 'enhanced_sensor_manager.dart';
import 'gemini_analysis_manager.dart';
import 'safety_config.dart';

/// Manages the overall state of the safety monitoring service
class SafetyServiceManager {
  late final EnhancedSensorManager _sensorManager;
  late final DataCollectionManager _collectionManager;
  late final GeminiAnalysisManager _geminiManager;
  final ServiceInstance _service;

  bool _isMonitoring = true;
  bool _isCollecting = false;
  Timer? _cooldownTimer;

  SafetyServiceManager(this._service) {
    _sensorManager = EnhancedSensorManager();
    _collectionManager = DataCollectionManager(_sensorManager, _service);
    _geminiManager = GeminiAnalysisManager();
  }

  /// Starts the monitoring service
  Future<void> start() async {
    _log('Safety Service Manager starting...');
    final hasPermissions = await _sensorManager.checkPermissions();
    if (!hasPermissions) {
      _updateNotification('Permissions needed to start monitoring.');
      return;
    }
    
    await _sensorManager.initialize(onTrigger: _handleTrigger);
    _updateNotification('Monitoring for safety triggers.');
  }

  /// Stops the monitoring service completely
  void stop() {
    _log('Safety Service Manager stopping...');
    _sensorManager.destroy();
    _collectionManager.stopCollection();
    _cooldownTimer?.cancel();
    _isMonitoring = false;
  }

  /// Main trigger handler - orchestrates the mic handoff and UI navigation
  void _handleTrigger(String triggerType, Map<String, dynamic> context) {
    if (_isCollecting || _cooldownTimer?.isActive == true) {
      _log('Ignoring trigger during collection or cooldown.');
      return;
    }

    _log('Initial trigger: $triggerType. Pausing listeners and starting collection.');
    _isCollecting = true;
    _sensorManager.pauseListeners(); // Free up mic and pause sensors

    // Command UI to show the collection screen
    _service.invoke('showCollectionScreen', {'initialTrigger': triggerType});
    
    _collectionManager.startCollection(
      initialTrigger: triggerType,
      triggerContext: context,
    ).then((data) {
      if (data != null) {
        _processCollectedData(data);
      }
    });
  }

  /// Callback for when the 8-second collection is complete
  Future<void> _processCollectedData(CollectedIncidentData data) async {
    _isCollecting = false;
    _log('Data collection complete. Analyzing...');
    
    final result = await _geminiManager.analyzeIncidentData(data.formatForGemini());

    if (result.isIncident) {
      _log('GEMINI VERDICT: TRUE POSITIVE. Lodging incident.');
      await _lodgeIncident(data, result);
    } else {
      _log('GEMINI VERDICT: FALSE POSITIVE. Closing collection screen.');
      _service.invoke('closeCollectionScreen'); // Command UI to close
    }

    _startCooldown();
  }
  
  /// Handles the logic for lodging an incident
  Future<void> _lodgeIncident(CollectedIncidentData data, GeminiAnalysisResult result) async {
    _service.invoke('showLodgeScreen', {
      'incidentType': result.incidentType,
      'description': result.description,
      'audioFilePath': data.audioFilePath,
      'geminiPayload': data.formatForGemini(),
    });
  }

  /// Starts a cooldown period before resuming monitoring
  void _startCooldown() {
    _log('Starting ${SafetyConfig.cooldownPeriodSeconds}s cooldown...');
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(seconds: SafetyConfig.cooldownPeriodSeconds), () {
      _log('Cooldown complete. Resuming listeners.');
      _sensorManager.resumeListeners(); // Resume mic and sensor listeners
      _updateNotification('Monitoring for safety triggers.');
    });
  }

  void _updateNotification(String content) {
    if (Platform.isAndroid && _service is AndroidServiceInstance) {
      (_service as AndroidServiceInstance).setForegroundNotificationInfo(
        title: 'MYSafeZone Active',
        content: content,
      );
    }
  }

  void _log(String message) {
    if (SafetyConfig.enableVerboseLogging) {
      if (kDebugMode) print('[SafetyServiceManager] $message');
    }
  }
}
