import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

// Configurable base URL for your backend. Change to your dev machine IP or
// to 10.0.2.2 when running on Android emulator.
const String backendBaseUrl = 'http://192.168.43.254:8081';

/// Backend Service class for all API calls
class BackendService {
  
  // Fungsi yang dipanggil dari SignupPage untuk sinkronisasi ke MySQL/Spring Boot
  static Future<bool> createUserOnServer(BuildContext context, Map<String, dynamic> userPayload) async {
    final url = Uri.parse('$backendBaseUrl/api/users');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userPayload),
      );

      // Log status untuk debugging
      debugPrint('createUser response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 201) {
        // 201 Created: User berhasil dibuat di MySQL
        return true; 
      } else if (response.statusCode == 409) {
        // 409 Conflict: User ID (UID) sudah ada di MySQL, anggap sukses sinkron
        return true; 
      } else {
        // Gagal (misalnya error 500, atau 400 Bad Request)
        final serverMsg = response.body.isNotEmpty ? jsonDecode(response.body)['message'] : 'Server error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat pengguna: ${response.statusCode} - $serverMsg')));
        return false;
      }
    } catch (e) {
      debugPrint('createUser exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error koneksi server')));
      return false;
    }
  }

  /// Send a run and its waypoints to the backend.
  static Future<http.Response?> sendRun(Map<String, dynamic> run, List<Map<String, dynamic>> waypoints) async {
    final url = Uri.parse('$backendBaseUrl/api/runs');
    final body = jsonEncode({
      'run': run,
      'waypoints': waypoints,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('sendRun status: ${response.statusCode}');
      print('sendRun body: ${response.body}');

      return response;
    } catch (e) {
      print('Error sending run: $e');
      return null;
    }
  }

  /// Post waypoints array to a given runId
  static Future<http.Response?> postWaypoints(String runId, List<Map<String, dynamic>> waypoints) async {
    final url = Uri.parse('$backendBaseUrl/api/runs/$runId/waypoints');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(waypoints),
      );

      debugPrint('postWaypoints status: ${response.statusCode}');
      debugPrint('postWaypoints body: ${response.body}');
      return response;
    } catch (e) {
      debugPrint('Error posting waypoints: $e');
      return null;
    }
  }

  /// Send user's goals to backend.
  static Future<http.Response?> sendGoals(Map<String, dynamic> goals) async {
    final url = Uri.parse('$backendBaseUrl/api/goals');
    final body = jsonEncode(goals);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('sendGoals status: ${response.statusCode}');
      print('sendGoals body: ${response.body}');
      return response;
    } catch (e) {
      print('Error sending goals: $e');
      return null;
    }
  }

  /// Create or update a user profile on the backend.
  static Future<http.Response?> sendUser(Map<String, dynamic> userPayload) async {
    final url = Uri.parse('$backendBaseUrl/api/users');
    final body = jsonEncode(userPayload);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('sendUser status: ${response.statusCode}');
      print('sendUser body: ${response.body}');
      return response;
    } catch (e) {
      print('Error sending user profile: $e');
      return null;
    }
  }

  /// Fetch a user by UID from the backend. Returns decoded JSON map or null on not found/error.
  static Future<Map<String, dynamic>?> getUserFromServer(String uid) async {
    final url = Uri.parse('$backendBaseUrl/api/users/$uid');
    try {
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      debugPrint('getUserFromServer status: ${response.statusCode} body: ${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null; // user not found
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('getUserFromServer error: $e');
      return null;
    }
  }

  /// Update an existing user on the server. Returns true when update succeeded.
  static Future<bool> updateUserOnServer(BuildContext context, String uid, Map<String, dynamic> userPayload) async {
    final url = Uri.parse('$backendBaseUrl/api/users/$uid');
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userPayload),
      );
      debugPrint('updateUser response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil disimpan dan disinkronkan.')));
        return true;
      } else {
        final serverMsg = response.body.isNotEmpty ? response.body : 'Server error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal update profil: ${response.statusCode} - $serverMsg')));
        return false;
      }
    } catch (e) {
      debugPrint('updateUser exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error koneksi server')));
      return false;
    }
  }
}