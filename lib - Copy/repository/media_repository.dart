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





      // Detailed type logging

      map.forEach((key, value) {

      });

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

  Future<void> openZone() async {
    try {
      await _dbService.openZone();

    } catch (e) {

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

      return [];
    }
  }

  /// Delete media by mediaID
  Future<bool> deleteMediaByMediaId(String mediaId) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName)
        ..equalTo('mediaID', mediaId);

      final result = await _dbService.deleteByQuery(_objectTypeName, query);

      return result > 0;
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
