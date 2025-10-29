import '../models/clouddb_model.dart'; // Use CloudDB models
import '../bg_services/clouddb_service.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';

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

  /// Get media by mediaID
  Future<List<media>> getMediaByMediaId(String mediaId) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName)
        ..equalTo('mediaID', mediaId);

      final results = await _dbService.query<media>(
        _objectTypeName,
        query: query,
        fromMap: (map) => media(
          mediaID: map['mediaID'] as String,
          order: map['order'] as int,
          mediaType: map['mediaType'] as String,
          mediaURI: map['mediaURI'] as String,
        ),
      );

      return results;
    } catch (e) {
      print('❌ Error getting media by ID: $e');
      return [];
    }
  }

  /// Delete media by mediaID
  Future<bool> deleteMediaByMediaId(String mediaId) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName)
        ..equalTo('mediaID', mediaId);

      final result = await _dbService.deleteByQuery(_objectTypeName, query);
      print('✅ Deleted media for mediaID: $mediaId');
      return result > 0;
    } catch (e) {
      print('❌ Error deleting media: $e');
      return false;
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
