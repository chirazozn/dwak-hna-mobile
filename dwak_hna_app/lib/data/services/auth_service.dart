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
    return sendRegisterCode(email: email);
  }

  Future<bool> sendRegisterCode({
    required String email,
  }) async {
    final result = await _api.post('/auth/register/send-code', {
      'email': email,
    });

    return result['success'] == true;
  }

  Future<bool> verifyRegisterCode({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required String password,
    required String code,
  }) async {
    final result = await _api.post('/auth/register/verify', {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'mot_de_passe': password,
      'code': code,
    });

    if (result['success'] == true) {
      await saveAuthData(result);
      return true;
    }

    return false;
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
      await saveAuthData(result);
      return true;
    }

    return false;
  }

  Future<void> saveAuthData(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();
    final patient = Map<String, dynamic>.from(result['patient'] ?? {});

    await prefs.setString('token', result['token']);
    await prefs.setInt('patient_id', patient['patient_id']);
    await prefs.setString('nom', patient['nom'] ?? '');
    await prefs.setString('prenom', patient['prenom'] ?? '');
    await prefs.setString('email', patient['email'] ?? '');
    await prefs.setString('telephone', patient['telephone'] ?? '');
  }

  Future<bool> sendForgotPasswordCode({
    required String email,
  }) async {
    final result = await _api.post('/auth/forgot-password/send-code', {
      'email': email,
    });

    return result['success'] == true;
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final result = await _api.post('/auth/forgot-password/reset', {
      'email': email,
      'code': code,
      'nouveau_mot_de_passe': newPassword,
    });

    return result['success'] == true;
  }

  Future<bool> sendChangePasswordCode() async {
    final result = await _api.post('/auth/change-password/send-code', {});
    return result['success'] == true;
  }

  Future<bool> changePassword({
    required String code,
    required String newPassword,
  }) async {
    final result = await _api.post('/auth/change-password', {
      'code': code,
      'nouveau_mot_de_passe': newPassword,
    });

    return result['success'] == true;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('token');
    await prefs.remove('auth_token');
    await prefs.remove('access_token');
    await prefs.remove('patient');
    await prefs.remove('patient_id');
    await prefs.remove('nom');
    await prefs.remove('prenom');
    await prefs.remove('email');
    await prefs.remove('telephone');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return token != null && token.isNotEmpty;
  }
}
