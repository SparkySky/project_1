import '../models/Users.dart';
import '../bg_services/clouddb_service.dart';
import 'package:agconnect_clouddb/agconnect_clouddb.dart';

class UserRepository {
  final _dbService = CloudDbService("dev");
  static const String _objectTypeName = 'Users';

  /// Get all users
  Future<List<Users>> getAllUsers() async {
    return await _dbService.query<Users>(
      _objectTypeName,
      fromMap: (map) => Users.fromMap(map),
    );
  }

  /// Get user by UID
  Future<Users?> getUserById(String uid) async {
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('uid', uid);
    
    final results = await _dbService.query<Users>(
      _objectTypeName,
      query: query,
      fromMap: (map) => Users.fromMap(map),
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  /// Get users by district
  Future<List<Users>> getUsersByDistrict(String district) async {
    final query = AGConnectCloudDBQuery(_objectTypeName)
      ..equalTo('district', district);
    
    return await _dbService.query<Users>(
      _objectTypeName,
      query: query,
      fromMap: (map) => Users.fromMap(map),
    );
  }

  /// Insert or update a user
  Future<bool> upsertUser(Users user) async {
    try {
      final result = await _dbService.upsert(_objectTypeName, user.toMap());
      return result > 0;
    } catch (e) {
      print('Error upserting user: $e');
      return false;
    }
  }

  /// Insert or update multiple users
  Future<bool> upsertUsers(List<Users> users) async {
    try {
      final maps = users.map((u) => u.toMap()).toList();
      final result = await _dbService.upsertBatch(_objectTypeName, maps);
      return result > 0;
    } catch (e) {
      print('Error upserting users: $e');
      return false;
    }
  }

  /// Delete a user
  Future<bool> deleteUser(Users user) async {
    try {
      final result = await _dbService.delete(_objectTypeName, user.toMap());
      return result > 0;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Delete user by UID
  Future<bool> deleteUserById(String uid) async {
    try {
      final query = AGConnectCloudDBQuery(_objectTypeName)
        ..equalTo('uid', uid);
      
      final result = await _dbService.deleteByQuery(_objectTypeName, query);
      return result > 0;
    } catch (e) {
      print('Error deleting user by id: $e');
      return false;
    }
  }

  /// Delete multiple users
  Future<bool> deleteUsers(List<Users> users) async {
    try {
      final maps = users.map((u) => u.toMap()).toList();
      final result = await _dbService.deleteBatch(_objectTypeName, maps);
      return result > 0;
    } catch (e) {
      print('Error deleting users: $e');
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