import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrdonnanceService {
  static const String baseUrl = 'http://10.0.2.2:5001/api';

  Future<bool> createOrdonnanceDemande({
    required List<String> imagePaths,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> medicaments,
    int rayonKm = 5,
    String? messagePatient,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token') ?? prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      throw Exception('Token introuvable. Veuillez vous reconnecter.');
    }

    final uri = Uri.parse('$baseUrl/demandes/ordonnance');

    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['rayon_km'] = rayonKm.toString();
    request.fields['medicaments'] = jsonEncode(medicaments);

    if (messagePatient != null && messagePatient.trim().isNotEmpty) {
      request.fields['message_patient'] = messagePatient.trim();
    }

    for (final path in imagePaths) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'ordonnances',
          path,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Erreur API ${response.statusCode}');
    }

    return body['success'] == true;
  }
}
