import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_colors.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String label;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

class PickLocationPage extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;

  const PickLocationPage({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  final TextEditingController searchController = TextEditingController();

  GoogleMapController? mapController;
  late LatLng selectedPoint;
  bool isSearching = false;
  String selectedLabel = 'Localisation sélectionnée';

  static const String googleApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  @override
  void initState() {
    super.initState();
    selectedPoint = LatLng(widget.initialLatitude, widget.initialLongitude);
    selectedLabel = '${widget.initialLatitude.toStringAsFixed(5)}, ${widget.initialLongitude.toStringAsFixed(5)}';
  }

  @override
  void dispose() {
    searchController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> searchPlace() async {
    final query = searchController.text.trim();
    if (query.isEmpty) return;

    if (googleApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clé Google Maps manquante pour la recherche texte')),
      );
      return;
    }

    setState(() => isSearching = true);

    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': query,
        'components': 'country:DZ',
        'key': googleApiKey,
      });

      final response = await http.get(uri);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List? ?? [];

      if (results.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Localisation introuvable')));
        return;
      }

      final first = Map<String, dynamic>.from(results.first);
      final geometry = Map<String, dynamic>.from(first['geometry'] ?? {});
      final location = Map<String, dynamic>.from(geometry['location'] ?? {});
      final lat = double.tryParse(location['lat'].toString());
      final lng = double.tryParse(location['lng'].toString());
      if (lat == null || lng == null) return;

      final point = LatLng(lat, lng);
      setState(() {
        selectedPoint = point;
        selectedLabel = first['formatted_address']?.toString() ?? query;
      });

      await mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 14));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur recherche : ${e.toString()}')));
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  void confirmLocation() {
    Navigator.of(context).pop(
      PickedLocation(latitude: selectedPoint.latitude, longitude: selectedPoint.longitude, label: selectedLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Choisir localisation', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => searchPlace(),
                      decoration: InputDecoration(
                        hintText: 'Rechercher ville, commune, adresse...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: isSearching ? null : searchPlace,
                    style: IconButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    icon: isSearching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: selectedPoint, zoom: 14),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) => mapController = controller,
                onTap: (point) {
                  setState(() {
                    selectedPoint = point;
                    selectedLabel = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                  });
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: selectedPoint,
                    draggable: true,
                    onDragEnd: (point) {
                      setState(() {
                        selectedPoint = point;
                        selectedLabel = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                      });
                    },
                  ),
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Localisation choisie', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(selectedLabel, style: const TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: confirmLocation,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Utiliser cette localisation', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
