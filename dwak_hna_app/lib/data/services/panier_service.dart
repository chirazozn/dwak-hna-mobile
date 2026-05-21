import 'api_client.dart';

class PanierService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>?> getPanier() async {
    final result = await _api.get('/panier/');

    if (result['success'] == true) {
      final data = result['data'];

      if (data == null) {
        return null;
      }

      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  Future<Map<String, dynamic>?> addItem({
    required int pharmacieProduitId,
    int quantite = 1,
  }) async {
    final result = await _api.post('/panier/items', {
      'pharmacie_produit_id': pharmacieProduitId,
      'quantite': quantite,
    });

    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }

    throw Exception(result['message'] ?? 'Erreur panier');
  }

  Future<Map<String, dynamic>?> updateQuantity({
    required int ligneId,
    required int quantite,
  }) async {
    final result = await _api.post('/panier/items/$ligneId/quantite', {
      'quantite': quantite,
    });

    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }

    throw Exception(result['message'] ?? 'Erreur panier');
  }

  Future<Map<String, dynamic>?> removeItem({
    required int ligneId,
  }) async {
    final result = await _api.post('/panier/items/$ligneId/supprimer', {});

    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }

    throw Exception(result['message'] ?? 'Erreur panier');
  }

  Future<Map<String, dynamic>?> validerPanier({
    String? messagePatient,
  }) async {
    final result = await _api.post('/panier/valider', {
      'message_patient': messagePatient,
    });

    if (result['success'] == true) {
      return Map<String, dynamic>.from(result['data']);
    }

    throw Exception(result['message'] ?? 'Erreur validation panier');
  }
}
