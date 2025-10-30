import 'dart:async';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';
import 'package:flutter/material.dart';

class CloudDbService {
  static AGConnectCloudDB? _cloudDB;
  static final bool _isInitialized = false;
  AGConnectCloudDBZone? _zone;
  final String zoneName;

  CloudDbService(this.zoneName);

  /// Initialize Cloud DB (call once at app startup)
  static Future<void> initialize() async {
    debugPrint('Initializing Cloud DB...');
    if (_cloudDB == null) {
      _cloudDB = AGConnectCloudDB.getInstance();
      await _cloudDB!.initialize();
    }
  }

  /// Create object type (call before opening zone)

  static Future<void> createObjectType() async {
    debugPrint('Creating object type...');
    if (_cloudDB == null) {
      debugPrint('Cloud DB not initialized');
      throw Exception('Cloud DB not initialized');
    }

    try {
      // This method doesn't take any parameters
      // It reads the object types from your AGC configuration
      await _cloudDB!.createObjectType();
      print('[CloudDB] Object types created successfully');
    } catch (e) {
      print('[CloudDB] Error creating object type: $e');
      rethrow;
    }
  }

  /// Open a Cloud DB Zone
  Future<void> openZone({AGConnectCloudDBZoneConfig? config}) async {
    if (_cloudDB == null) {
      throw Exception('Cloud DB not initialized. Call initialize() first.');
    }

    if (_zone != null) {
      return; // Zone already open
    }

    final zoneConfig =
        config ??
        AGConnectCloudDBZoneConfig(
          zoneName: zoneName,
          syncProperty:
              AGConnectCloudDBZoneSyncProperty.CLOUDDBZONE_CLOUD_CACHE,
          accessProperty: AGConnectCloudDBZoneAccessProperty.CLOUDDBZONE_PUBLIC,
        );

    _zone = await _cloudDB!.openCloudDBZone(zoneConfig: zoneConfig);
  }

  /// Close the Cloud DB Zone
  Future<void> closeZone() async {
    if (_zone != null) {
      await _cloudDB?.closeCloudDBZone(zone: _zone!);
      _zone = null;
    }
  }

  /// Query with proper error handling and type conversion
  Future<List<T>> query<T>(
    String objectTypeName, {
    AGConnectCloudDBQuery? query,
    required T Function(Map<String, dynamic>) fromMap,
  }) async {
    try {
      await _ensureZoneOpen();
      print('Querying zone: $zoneName for type: $objectTypeName');

      final AGConnectCloudDBQuery finalQuery =
          query ?? AGConnectCloudDBQuery(objectTypeName);

      final snapshot = await _zone!.executeQuery(
        query: finalQuery,
        policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
      );

      print('Query returned ${snapshot.snapshotObjects.length} objects');

      final List<T> results = [];
      for (var obj in snapshot.snapshotObjects) {
        try {
          results.add(fromMap(obj));
        } catch (e) {
          print('Error converting object: $e');
        }
      }

      print('Converted ${results.length} objects successfully');
      return results;
    } catch (e) {
      print('Error querying Cloud DB: $e');
      rethrow;
    }
  }

  /// Upsert (Insert or Update) a single object
  Future<int> upsert(
    String objectTypeName,
    Map<String, dynamic> objectData,
  ) async {
    try {
      await _ensureZoneOpen();
      print('Upserting object: $objectData');

      final result = await _zone!.executeUpsert(
        objectTypeName: objectTypeName,
        entries: [objectData],
      );
      print('Upsert successful: $result');
      return result;
    } catch (e) {
      print('Error upserting object: $e');
      rethrow;
    }
  }

  /// Upsert multiple objects at once
  Future<int> upsertBatch(
    String objectTypeName,
    List<Map<String, dynamic>> objectDataList,
  ) async {
    try {
      await _ensureZoneOpen();
      print('Upserting ${objectDataList.length} objects');

      final result = await _zone!.executeUpsert(
        objectTypeName: objectTypeName,
        entries: objectDataList,
      );
      print('Batch upsert successful: $result');
      return result;
    } catch (e) {
      print('Error upserting batch: $e');
      rethrow;
    }
  }

  /// Delete a single object
  Future<int> delete(
    String objectTypeName,
    Map<String, dynamic> objectData,
  ) async {
    try {
      await _ensureZoneOpen();
      print('Deleting object: $objectData');

      final result = await _zone!.executeDelete(
        objectTypeName: objectTypeName,
        entries: [objectData],
      );
      print('Delete successful: $result');
      return result;
    } catch (e) {
      print('Error deleting object: $e');
      rethrow;
    }
  }

  /// Delete multiple objects at once
  Future<int> deleteBatch(
    String objectTypeName,
    List<Map<String, dynamic>> objectDataList,
  ) async {
    try {
      await _ensureZoneOpen();
      print('Deleting ${objectDataList.length} objects');

      final result = await _zone!.executeDelete(
        objectTypeName: objectTypeName,
        entries: objectDataList,
      );
      print('Batch delete successful: $result');
      return result;
    } catch (e) {
      print('Error deleting batch: $e');
      rethrow;
    }
  }

  /// Delete objects matching a query
  Future<int> deleteByQuery(
    String objectTypeName,
    AGConnectCloudDBQuery query,
  ) async {
    try {
      await _ensureZoneOpen();
      print('Deleting objects by query for type: $objectTypeName');

      // First query to get the objects to delete
      final snapshot = await _zone!.executeQuery(
        query: query,
        policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
      );

      if (snapshot.snapshotObjects.isEmpty) {
        print('No objects found matching query');
        return 0;
      }

      // Convert to list of maps
      final List<Map<String, dynamic>> entriesToDelete = [];
      for (var obj in snapshot.snapshotObjects) {
        entriesToDelete.add(obj);
      }

      // Delete the entries
      final result = await _zone!.executeDelete(
        objectTypeName: objectTypeName,
        entries: entriesToDelete,
      );

      print('Delete by query successful: $result affected');
      return result;
    } catch (e) {
      print('Error deleting by query: $e');
      rethrow;
    }
  }

  Future<void> _ensureZoneOpen() async {
    if (_zone == null) {
      await openZone();
    }
  }
}
