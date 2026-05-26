import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    this.token,
  }) : baseUrl = baseUrl ?? 'https://dwak-hna-mobile.onrender.com/api';

  final String baseUrl;
  final String? token;

  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = token ?? prefs.getString('token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (savedToken != null && savedToken.isNotEmpty)
        'Authorization': 'Bearer $savedToken',
    };
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers,
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers,
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers,
      body: jsonEncode(body),
    );

    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final json = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw Exception(json['message'] ?? 'Erreur API ${response.statusCode}');
    }

    return json;
  }
}
