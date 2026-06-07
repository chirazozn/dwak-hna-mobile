import 'api_client.dart';

class CommandeService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getPatientCommandes() async {
    final result = await _api.get('/panier/historique');

    if (result['success'] == true) {
      return result['data'] ?? [];
    }

    return [];
  }

  Future<int> getActiveCommandesCount() async {
    final commandes = await getPatientCommandes();

    return commandes.where((commande) {
      final statut = commande['statut']?.toString();
      return statut == 'en_attente' || statut == 'acceptee';
    }).length;
  }
}