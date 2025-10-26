import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseService {
  final String _baseUrl = dotenv.env['FIREBASE_DB_URL']!;

  /// Writes (replaces) data at a specific path
  Future<bool> putData(String path, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/$path.json');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  /// Updates (merges) fields at a path (PATCH)
  Future<bool> patchData(String path, Map<String, dynamic> data) async {
    final url = Uri.parse('$_baseUrl/$path.json');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return response.statusCode == 200;
  }

  /// Reads data at a given path
  Future<dynamic> getData(String path) async {
    final url = Uri.parse('$_baseUrl/$path.json');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  /// Deletes data at a given path
  Future<bool> deleteData(String path) async {
    final url = Uri.parse('$_baseUrl/$path.json');
    final response = await http.delete(url);
    return response.statusCode == 200;
  }

  Future<String?> getUserTokenByID(String userId) async {
    try {
      final data = await getData('users/$userId');
      if (data != null && data['pushToken'] != null) {
        return data['pushToken'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user push token: $e');
      return null;
    }
  }
}
