import 'api_client.dart';

class MessagePredefiniService {
  final ApiClient _api = ApiClient();

  Future<List<dynamic>> getMessages({
    String type = 'patient_demande',
  }) async {
    final result = await _api.get(
      '/messages-predefinis/?type=${Uri.encodeComponent(type)}',
    );

    if (result['success'] == true) {
      return result['data'];
    }

    return [];
  }
}
