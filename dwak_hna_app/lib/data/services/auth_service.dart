import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<bool> register({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required String password,
  }) async {
    final result = await _api.post('/auth/register', {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'mot_de_passe': password,
    });

    return result['success'] == true;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final result = await _api.post('/auth/login', {
      'email': email,
      'mot_de_passe': password,
    });

    if (result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', result['token']);
      await prefs.setInt('patient_id', result['patient']['patient_id']);
      await prefs.setString('nom', result['patient']['nom'] ?? '');
      await prefs.setString('prenom', result['patient']['prenom'] ?? '');
      await prefs.setString('email', result['patient']['email'] ?? '');
      await prefs.setString('telephone', result['patient']['telephone'] ?? '');

      return true;
    }

    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return token != null && token.isNotEmpty;
  }
}
