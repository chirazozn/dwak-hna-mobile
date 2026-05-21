import 'package:geolocator/geolocator.dart';

class AppLocation {
  final double latitude;
  final double longitude;

  const AppLocation({
    required this.latitude,
    required this.longitude,
  });
}

class LocationService {
  static Future<AppLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Veuillez activer la localisation GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permission localisation refusée.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permission localisation refusée définitivement. Activez-la dans les paramètres.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return AppLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
