import 'dart:async';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';

class CloudDbService {
  static AGConnectCloudDB? _cloudDB;
  static final bool _isInitialized = false;
  AGConnectCloudDBZone? _zone;
  final String zoneName;

  CloudDbService(this.zoneName);

  /// Initialize Cloud DB (call once at app startup)
  static Future<void> initialize() async {

    if (_cloudDB == null) {
      _cloudDB = AGConnectCloudDB.getInstance();
      await _cloudDB!.initialize();
    }
  }

  /// Create object type (call before opening zone)

  static Future<void> createObjectType() async {

    if (_cloudDB == null) {

      throw Exception('Cloud DB not initialized');
    }

    try {
      // This method doesn't take any parameters
      // It reads the object types from your AGC configuration
      await _cloudDB!.createObjectType();

    } catch (e) {

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


      final AGConnectCloudDBQuery finalQuery =
          query ?? AGConnectCloudDBQuery(objectTypeName);

      final snapshot = await _zone!.executeQuery(
        query: finalQuery,
        policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
      );



      final List<T> results = [];
      for (var obj in snapshot.snapshotObjects) {
        try {
          results.add(fromMap(obj));
        } catch (e) {

        }
      }


      return results;
    } catch (e) {

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


      final result = await _zone!.executeUpsert(
        objectTypeName: objectTypeName,
        entries: [objectData],
      );

      return result;
    } catch (e) {

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


      final result = await _zone!.executeUpsert(
        objectTypeName: objectTypeName,
        entries: objectDataList,
      );

      return result;
    } catch (e) {

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


      final result = await _zone!.executeDelete(
        objectTypeName: objectTypeName,
        entries: [objectData],
      );

      return result;
    } catch (e) {

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


      final result = await _zone!.executeDelete(
        objectTypeName: objectTypeName,
        entries: objectDataList,
      );

      return result;
    } catch (e) {

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


      // First query to get the objects to delete
      final snapshot = await _zone!.executeQuery(
        query: query,
        policy: AGConnectCloudDBZoneQueryPolicy.POLICY_QUERY_FROM_CLOUD_ONLY,
      );

      if (snapshot.snapshotObjects.isEmpty) {

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


      return result;
    } catch (e) {

      rethrow;
    }
  }

  Future<void> _ensureZoneOpen() async {
    if (_zone == null) {
      await openZone();
    }
  }
}
