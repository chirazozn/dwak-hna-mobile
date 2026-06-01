import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DemandeService {
  static const String baseUrl = 'https://dwak-hna-mobile.onrender.com';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token') ??
        prefs.getString('auth_token') ??
        prefs.getString('access_token') ??
        '';

    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getPatientDemandes() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/demandes/patient'),
    headers: await _headers(),
  );

  print('GET DEMANDES STATUS: ${response.statusCode}');
  print('GET DEMANDES BODY: ${response.body}');

  final body = jsonDecode(response.body);

  if (response.statusCode == 200 && body['success'] == true) {
    final data = body['data'];

    if (data is List) {
      print('NB DEMANDES FLUTTER: ${data.length}');
      return data;
    }

    return [];
  }

  throw Exception(body['message'] ?? 'Erreur chargement demandes');
}

  Future<Map<String, dynamic>> getDemandeDetail({
    required int demandeId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/demandes/$demandeId'),
      headers: await _headers(),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return Map<String, dynamic>.from(body['data'] ?? {});
    }

    throw Exception(body['message'] ?? 'Erreur chargement détail demande');
  }

  Future<bool> createManualDemande({
    required List<Map<String, dynamic>> medicaments,
    required double latitude,
    required double longitude,
    required int rayonKm,
    String? messagePatient,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/demandes/manuelle'),
      headers: await _headers(),
      body: jsonEncode({
        'medicaments': medicaments,
        'message_patient': messagePatient,
        'rayon_km': rayonKm,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    final body = jsonDecode(response.body);

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        body['success'] == true) {
      return true;
    }

    throw Exception(body['message'] ?? 'Erreur création demande');
  }

  Future<bool> choisirPharmacie({
    required int demandeId,
    required int pharmacieId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/demandes/$demandeId/choisir-pharmacie'),
      headers: await _headers(),
      body: jsonEncode({
        'pharmacie_id': pharmacieId,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return true;
    }

    throw Exception(body['message'] ?? 'Erreur choix pharmacie');
  }

  Future<bool> noterDemande({
    required int demandeId,
    required int notePharmacie,
    String? commentaire,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/demandes/$demandeId/note'),
      headers: await _headers(),
      body: jsonEncode({
        'note_pharmacie': notePharmacie,
        'commentaire': commentaire,
      }),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return true;
    }

    throw Exception(body['message'] ?? 'Erreur notation demande');
  }

  Future<bool> annulerDemande({
    required int demandeId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/demandes/$demandeId/annuler'),
      headers: await _headers(),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return true;
    }

    throw Exception(body['message'] ?? 'Erreur annulation demande');
  }
  Future<void> terminerDemande({
     required int demandeId,
     required int notePharmacie,
     required String commentaire,
   }) async {
     final response = await http.post(
       Uri.parse('$baseUrl/api/demandes/$demandeId/terminer'),
       headers: await _headers(),
       body: jsonEncode({
         'note_pharmacie': notePharmacie,
         'commentaire': commentaire,
       }),
     );

     final body = jsonDecode(response.body);

     if (response.statusCode == 200 && body['success'] == true) {
       return;
     }

     throw Exception(body['message'] ?? 'Erreur terminaison demande');
   }

}