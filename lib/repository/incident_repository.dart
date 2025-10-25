import '../models/clouddb_model.dart';
import '../bg_services/clouddb_service.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';

class IncidentRepository {
  final _dbService = CloudDbService("dev");
  static const String _objectTypeName = 'Incidents';

  /// Get all incidents
  Future<List<incidents>> getAllIncidents() async {
    return await _dbService.query<incidents>(
      _objectTypeName,
      fromMap: (map) => incidents.fromMap(map),
    );
  }

  /// Get incident by ID
  Future<incidents?> getIncidentById(String iid) async {
    final query = AGConnectCloudDBQuery(_objectTypeName)..equalTo('iid', iid);

    final results = await _dbService.query<incidents>(
      _objectTypeName,
      query: query,
      fromMap: (map) => incidents.fromMap(map),
    );

    return results.isNotEmpty ? results.first : null;
  }

  /// Get incidents by user ID
  Future<List<incidents>> getIncidentsByUserId(String uid) async {
    final query = AGConnectCloudDBQuery(_objectTypeName)..equalTo('uid', uid);

    return await _dbService.query<incidents>(
      _objectTypeName,
      query: query,
      fromMap: (map) => incidents.fromMap(map),
    );
  }

  /// Get active incidents
  Future<List<incidents>> getActiveIncidents() async {
    final query = AGConnectCloudDBQuery(_objectTypeName)..equalTo('status', 1);

    return await _dbService.query<incidents>(
      _objectTypeName,
      query: query,
      fromMap: (map) => incidents.fromMap(map),
    );
  }

  /// Insert or update an incident
  Future<bool> upsertIncident(incidents incident) async {
    try {
      final result = await _dbService.upsert(
        _objectTypeName,
        incident.getObjectData(),
      );
      return result > 0;
    } catch (e) {
      print('Error upserting incident: $e');
      return false;
    }
  }

  /// Insert or update multiple incidents
  Future<bool> upsertIncidents(List<incidents> incidents) async {
    try {
      final maps = incidents.map((i) => i.getObjectData()).toList();
      final result = await _dbService.upsertBatch(_objectTypeName, maps);
      return result > 0;
    } catch (e) {
      print('Error upserting incidents: $e');
      return false;
    }
  }

  /// Delete an incident
  Future<bool> deleteIncident(incidents incident) async {
    try {
      final result = await _dbService.delete(
        _objectTypeName,
        incident.getObjectData(),
      );
      return result > 0;
    } catch (e) {
      print('Error deleting incident: $e');
      return false;
    }
  }

  /// Delete incident by ID
  Future<bool> deleteIncidentById(String iid) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName)..equalTo('iid', iid);

      final result = await _dbService.deleteByQuery(_objectTypeName, query);
      return result > 0;
    } catch (e) {
      print('Error deleting incident by id: $e');
      return false;
    }
  }

  Future<void> openZone() async {
    await _dbService.openZone();
  }

  Future<void> closeZone() async {
    await _dbService.closeZone();
  }
}
