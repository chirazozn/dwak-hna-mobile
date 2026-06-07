import 'api_client.dart';

class ProduitService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getProduits({
    String search = '',
  }) async {
    final encodedSearch = Uri.encodeComponent(search.trim());
    final result = await _api.get('/produits/?search=$encodedSearch');

    if (result['success'] == true) {
      return result['data'] ?? [];
    }

    return [];
  }

  Future<List<dynamic>> getProduitsByPharmacie({
    required int pharmacieId,
    String search = '',
  }) async {
    final encodedSearch = Uri.encodeComponent(search.trim());
    final result = await _api.get(
      '/produits/pharmacie/$pharmacieId?search=$encodedSearch',
    );

    if (result['success'] == true) {
      return result['data'] ?? [];
    }

    return [];
  }
}
