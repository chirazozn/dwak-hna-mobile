import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';

class PharmaciesMapPage extends StatelessWidget {
  final List<dynamic> pharmacies;

  const PharmaciesMapPage({
    super.key,
    required this.pharmacies,
  });

  double? doubleValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  String textValue(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return fallback;
    }

    return text;
  }

  List<dynamic> get pharmaciesWithLocation {
    return pharmacies.where((pharmacie) {
      final lat = doubleValue(pharmacie['pharmacie_latitude']);
      final lng = doubleValue(pharmacie['pharmacie_longitude']);

      return lat != null && lng != null;
    }).toList();
  }

  LatLng get initialCenter {
    if (pharmaciesWithLocation.isNotEmpty) {
      final first = pharmaciesWithLocation.first;

      return LatLng(
        doubleValue(first['pharmacie_latitude'])!,
        doubleValue(first['pharmacie_longitude'])!,
      );
    }

    return const LatLng(36.75, 3.04);
  }

  String statusLabel(dynamic value) {
    final statut = value?.toString() ?? '';

    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'acceptee':
        return 'Acceptée';
      case 'refusee':
        return 'Refusée';
      case 'choisie':
        return 'Choisie';
      default:
        return statut.isEmpty ? 'Statut inconnu' : statut;
    }
  }

  String priceValue(dynamic value) {
    final price = doubleValue(value);

    if (price == null) return 'Prix non défini';

    return '${price.toStringAsFixed(2)} DA';
  }

  void showPharmacySheet(BuildContext context, dynamic pharmacie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textValue(pharmacie['pharmacie_nom'], 'Pharmacie'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      statusLabel(pharmacie['statut']),
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _InfoLine(
                      icon: Icons.location_on_outlined,
                      text: textValue(
                        pharmacie['pharmacie_adresse'],
                        'Adresse non disponible',
                      ),
                    ),

                    _InfoLine(
                      icon: Icons.phone_outlined,
                      text: textValue(
                        pharmacie['pharmacie_telephone'],
                        'Téléphone non disponible',
                      ),
                    ),

                    _InfoLine(
                      icon: Icons.sell_outlined,
                      text: priceValue(pharmacie['prix_estime']),
                    ),

                    if (pharmacie['message'] != null &&
                        pharmacie['message'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        pharmacie['message'].toString(),
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Marker> buildMarkers(BuildContext context) {
    return pharmaciesWithLocation.map((pharmacie) {
      final lat = doubleValue(pharmacie['pharmacie_latitude'])!;
      final lng = doubleValue(pharmacie['pharmacie_longitude'])!;

      return Marker(
        point: LatLng(lat, lng),
        width: 52,
        height: 52,
        child: GestureDetector(
          onTap: () => showPharmacySheet(context, pharmacie),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_pharmacy_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final markers = buildMarkers(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Carte pharmacies',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: pharmaciesWithLocation.isEmpty
          ? const Center(
              child: Text(
                'Aucune pharmacie avec localisation.',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : FlutterMap(
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.dwakhna.dwak_hna_app',
                ),
                MarkerLayer(
                  markers: markers,
                ),
              ],
            ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
