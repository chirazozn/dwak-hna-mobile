import 'api_client.dart';

class PharmacieService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getNearbyPharmacies({
    required double latitude,
    required double longitude,
    double rayonKm = 5,
    bool ouverte = false,
    bool deGarde = false,
  }) async {
    final result = await _api.get(
      '/pharmacies/nearby'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&rayon_km=$rayonKm'
      '&ouverte=${ouverte ? 1 : 0}'
      '&de_garde=${deGarde ? 1 : 0}',
    );

    if (result['success'] == true) {
      return result['data'];
    }

    return [];
  }
}
