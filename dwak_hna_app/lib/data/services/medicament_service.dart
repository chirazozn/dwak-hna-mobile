import 'api_client.dart';

class MedicamentService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getMedicaments({
    String? search,
  }) async {
    final query = search != null && search.trim().isNotEmpty
        ? '?search=${Uri.encodeComponent(search.trim())}'
        : '';

    final result = await _api.get('/medicaments$query');

    if (result['success'] == true) {
      return result['data'];
    }

    return [];
  }
}
