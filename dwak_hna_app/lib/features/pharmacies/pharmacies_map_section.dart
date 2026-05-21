import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';

class PharmaciesMapSection extends StatelessWidget {
  final List<dynamic> pharmacies;

  const PharmaciesMapSection({
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

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  List<dynamic> get pharmaciesWithLocation {
    return pharmacies.where((pharmacie) {
      final lat = doubleValue(pharmacie['latitude']);
      final lng = doubleValue(pharmacie['longitude']);

      return lat != null && lng != null;
    }).toList();
  }

  LatLng get center {
    if (pharmaciesWithLocation.isNotEmpty) {
      final first = pharmaciesWithLocation.first;

      return LatLng(
        doubleValue(first['latitude'])!,
        doubleValue(first['longitude'])!,
      );
    }

    return const LatLng(36.75, 3.04);
  }

  String distanceText(dynamic pharmacie) {
    final distance = doubleValue(pharmacie['distance_km']);

    if (distance == null) {
      return '';
    }

    return '${distance.toStringAsFixed(2)} km';
  }

  String openStatus(dynamic pharmacie) {
    final isOpen = boolValue(pharmacie['est_ouverte']);
    final isDuty = boolValue(pharmacie['est_de_garde']);

    if (isDuty) {
      return 'De garde';
    }

    if (isOpen) {
      return 'Ouverte';
    }

    return 'Fermée';
  }

  void showPharmacySheet(BuildContext context, dynamic pharmacie) {
    final distance = distanceText(pharmacie);

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
                      textValue(pharmacie['nom'], 'Pharmacie'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      openStatus(pharmacie),
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _InfoLine(
                      icon: Icons.location_on_outlined,
                      text: textValue(
                        pharmacie['adresse'],
                        'Adresse non disponible',
                      ),
                    ),

                    _InfoLine(
                      icon: Icons.phone_outlined,
                      text: textValue(
                        pharmacie['telephone'],
                        'Téléphone non disponible',
                      ),
                    ),

                    if (distance.isNotEmpty)
                      _InfoLine(
                        icon: Icons.near_me_outlined,
                        text: 'Distance : $distance',
                      ),
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
      final lat = doubleValue(pharmacie['latitude'])!;
      final lng = doubleValue(pharmacie['longitude'])!;

      return Marker(
        point: LatLng(lat, lng),
        width: 54,
        height: 54,
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
              size: 29,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (pharmaciesWithLocation.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Text(
          'Aucune pharmacie avec localisation.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textGrey,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      height: 520,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dwakhna.dwak_hna_app',
          ),
          MarkerLayer(
            markers: buildMarkers(context),
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
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

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
