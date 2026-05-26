import 'dart:convert';

import 'package:http/http.dart' as http;

class ProduitService {
  static const String baseUrl = 'https://dwak-hna-mobile.onrender.com';

  Future<List<dynamic>> getProduits({
    String search = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/produits/').replace(
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final response = await http.get(uri);

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return body['data'] ?? [];
    }

    throw Exception(body['message'] ?? 'Erreur chargement produits');
  }

  Future<List<dynamic>> getProduitsByPharmacie({
    required int pharmacieId,
    String search = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/produits/pharmacie/$pharmacieId')
        .replace(
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final response = await http.get(uri);

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return body['data'] ?? [];
    }

    throw Exception(
      body['message'] ?? 'Erreur chargement produits pharmacie',
    );
  }
}
