import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FirebasePushService {
  static const String baseUrl = 'https://dwak-hna-mobile.onrender.com';

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await requestPermission();

    final token = await messaging.getToken();

    if (token != null && token.isNotEmpty) {
      await sendTokenToBackend(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await sendTokenToBackend(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Quand l'app est ouverte, ton NotificationWatcher gère déjà les popups.
      // Ici on garde juste le listener pour debug.
      print('FCM FOREGROUND: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('FCM OPENED APP: ${message.data}');
    });
  }

  Future<void> requestPermission() async {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<Map<String, String>> headers() async {
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

  Future<void> sendTokenToBackend(String firebaseToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/notifications/firebase-token'),
      headers: await headers(),
      body: jsonEncode({
        'token': firebaseToken,
      }),
    );

    if (response.statusCode != 200) {
      print('SAVE FCM TOKEN ERROR: ${response.body}');
    } else {
      print('FCM TOKEN SAVED');
    }
  }
}
