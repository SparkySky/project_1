import '../models/clouddb_model.dart'; // Use CloudDB models
import '../bg_services/clouddb_service.dart';

class IncidentRepository {
  final CloudDbService _dbService;
  static const String _objectTypeName = 'Incidents';

  IncidentRepository({String zoneName = "dev"}) 
      : _dbService = CloudDbService(zoneName);

  IncidentRepository.withService(this._dbService);

  Future<void> openZone() async {
    try {
      await _dbService.openZone();
      print('✅ Incidents zone opened successfully');
    } catch (e) {
      print('❌ Error opening Incidents zone: $e');
      rethrow;
    }
  }

  Future<void> closeZone() async {
    try {
      await _dbService.closeZone();
      print('✅ Incidents zone closed');
    } catch (e) {
      print('❌ Error closing Incidents zone: $e');
      rethrow;
    }
  }

  /// Upserts incident using CloudDB model
  Future<bool> upsertIncident(incidents incident) async {
    try {
      final map = incident.getObjectData(); // Use CloudDB method
      
      print('=== Upserting Incident to CloudDB ===');
      print('Object Type: $_objectTypeName');
      print('Map data: $map');
      
      // Call CloudDB service
      final result = await _dbService.upsert(_objectTypeName, map);
      print('CloudDB upsert result: $result');
      
      if (result <= 0) {
        throw Exception('CloudDB upsert failed with result: $result');
      }
      
      print('✅ Incident upserted successfully');
      return true;
      
    } catch (e, stackTrace) {
      print('❌ Error upserting incident: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}