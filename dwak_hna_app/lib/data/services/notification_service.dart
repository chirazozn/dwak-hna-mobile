import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppNotif {
  final String source;
  final int id;
  final String titre;
  final String corps;
  final String typeNotif;
  final int? demandeId;
  final bool estLue;
  final String envoyeLe;

  const AppNotif({
    required this.source,
    required this.id,
    required this.titre,
    required this.corps,
    required this.typeNotif,
    required this.demandeId,
    required this.estLue,
    required this.envoyeLe,
  });

  String get key => '$source-$id';

  factory AppNotif.fromJson(Map<String, dynamic> json) {
    return AppNotif(
      source: json['source']?.toString() ?? '',
      id: int.tryParse(json['notification_id'].toString()) ?? 0,
      titre: json['titre']?.toString() ?? '',
      corps: json['corps']?.toString() ?? '',
      typeNotif: json['type_notif']?.toString() ?? '',
      demandeId: json['demande_id'] == null
          ? null
          : int.tryParse(json['demande_id'].toString()),
      estLue: json['est_lue'] == 1 ||
          json['est_lue'] == true ||
          json['est_lue'] == '1',
      envoyeLe: json['envoye_le']?.toString() ?? '',
    );
  }
}

class NotificationService {
  static const String baseUrl = 'https://dwak-hna-mobile.onrender.com';

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token') ??
        prefs.getString('auth_token') ??
        prefs.getString('access_token') ??
        '';

    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<({List<AppNotif> notifications, int unreadCount})>
      getPatientNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/notifications/patient').replace(
      queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      final list = body['data'] as List? ?? [];

      return (
        notifications: list
            .map((item) => AppNotif.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        unreadCount: int.tryParse(body['unread_count'].toString()) ?? 0,
      );
    }

    throw Exception(body['message'] ?? 'Erreur chargement notifications');
  }

  Future<List<AppNotif>> getUnreadNotifications({
    int limit = 5,
  }) async {
    final uri = Uri.parse('$baseUrl/api/notifications/patient/unread').replace(
      queryParameters: {
        'limit': limit.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      final list = body['data'] as List? ?? [];

      return list
          .map((item) => AppNotif.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    throw Exception(body['message'] ?? 'Erreur chargement notifications');
  }
Future<int> getUnreadCount() async {
  final response = await http.get(
    Uri.parse('$baseUrl/api/notifications/patient/count'),
    headers: await _headers(),
  );

  final body = jsonDecode(response.body);

  if (response.statusCode == 200 && body['success'] == true) {
    return int.tryParse(body['unread_count'].toString()) ?? 0;
  }

  throw Exception(body['message'] ?? 'Erreur compteur notifications');
}
  Future<void> markAsRead(AppNotif notif) async {
    final endpoint = notif.source == 'admin'
        ? '$baseUrl/api/notifications/admin/${notif.id}/lu'
        : '$baseUrl/api/notifications/systeme/${notif.id}/lu';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: await _headers(),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Erreur mise à jour notification');
    }
  }

  Future<void> markAllAsRead() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/notifications/tout-lu'),
      headers: await _headers(),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Erreur mise à jour notifications');
    }
  }
}
