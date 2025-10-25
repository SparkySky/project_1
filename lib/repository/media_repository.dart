import '../models/clouddb_model.dart'; // Use CloudDB models
import '../bg_services/clouddb_service.dart';

class MediaRepository {
  final CloudDbService _dbService;
  static const String _objectTypeName = 'Media';

  MediaRepository({String zoneName = "dev"}) 
      : _dbService = CloudDbService(zoneName);

  // Constructor to share CloudDB instance
  MediaRepository.withService(this._dbService);

  /// Upserts media using CloudDB model directly
  Future<bool> upsertMedia(media mediaObject) async {
    try {
      final map = mediaObject.getObjectData(); // Use CloudDB method
      
      print('=== Upserting Media to CloudDB ===');
      print('Object Type: $_objectTypeName');
      print('Map data: $map');
      
      // Detailed type logging
      print('Field types:');
      map.forEach((key, value) {
        print('  $key: ${value.runtimeType} = $value');
      });
      
      // Call CloudDB service
      final result = await _dbService.upsert(_objectTypeName, map);
      print('CloudDB media upsert result: $result');
      
      if (result <= 0) {
        throw Exception('CloudDB upsert failed with result: $result');
      }
      
      print('✅ Media upserted successfully');
      return true;
      
    } catch (e, stackTrace) {
      print('❌ Error upserting media: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> openZone() async {
    try {
      await _dbService.openZone();
      print('✅ Media zone opened successfully');
    } catch (e) {
      print('❌ Error opening Media zone: $e');
      rethrow;
    }
  }

  Future<void> closeZone() async {
    try {
      await _dbService.closeZone();
      print('✅ Media zone closed');
    } catch (e) {
      print('❌ Error closing Media zone: $e');
      rethrow;
    }
  }
}