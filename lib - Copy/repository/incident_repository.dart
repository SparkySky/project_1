import '../models/clouddb_model.dart';
import '../bg_services/clouddb_service.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';

class IncidentRepository {
  final CloudDbService _dbService;
  static const String _objectTypeName = 'Incidents';

  IncidentRepository({String zoneName = "dev"})
    : _dbService = CloudDbService(zoneName);

  IncidentRepository.withService(this._dbService);

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
      final map = incident.getObjectData(); // Use CloudDB method





      // Call CloudDB service
      final result = await _dbService.upsert(_objectTypeName, map);


      if (result <= 0) {
        throw Exception('CloudDB upsert failed with result: $result');
      }


      return true;
    } catch (e) {


      rethrow;
    }
  }

  /// Insert or update multiple incidents
  Future<bool> upsertIncidents(List<incidents> incidents) async {
    try {
      final maps = incidents.map((i) => i.getObjectData()).toList();
      final result = await _dbService.upsertBatch(_objectTypeName, maps);
      return result > 0;
    } catch (e) {

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

      return false;
    }
  }

  Future<void> openZone() async {
    try {
      await _dbService.openZone();

    } catch (e) {

      rethrow;
    }
  }

  /// Disable incidents by user ID (set status to 'disabled')
  Future<bool> disableIncidentsByUserId(String uid) async {
    try {
      // Get all user incidents
      final userIncidents = await getIncidentsByUserId(uid);

      if (userIncidents.isEmpty) {

        return true;
      }

      // Update each incident status to 'disabled'
      for (var incident in userIncidents) {
        incident.status = 'disabled';
        await upsertIncident(incident);
      }


      return true;
    } catch (e) {

      return false;
    }
  }

  Future<void> closeZone() async {
    try {
      await _dbService.closeZone();

    } catch (e) {

      rethrow;
    }
  }
}
