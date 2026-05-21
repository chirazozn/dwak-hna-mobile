import 'api_client.dart';

class PubliciteService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getHomeAds() async {
    final result = await _api.get('/publicites/accueil');

    if (result['success'] == true) {
      return result['data'];
    }

    return [];
  }

  Future<List<dynamic>> getStoreAds() async {
    final result = await _api.get('/publicites/store');

    if (result['success'] == true) {
      return result['data'];
    }

    return [];
  }
}
