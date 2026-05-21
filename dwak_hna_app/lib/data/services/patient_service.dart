import 'api_client.dart';

class PatientService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>?> getProfile() async {
    final result = await _api.get('/patients/profile');

    if (result['success'] == true) {
      return result['data'];
    }

    return null;
  }

  Future<bool> updateProfile({
    required String nom,
    required String prenom,
    required String telephone,
    String? image,
  }) async {
    final result = await _api.put('/patients/profile', {
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'image': image,
    });

    return result['success'] == true;
  }
}
