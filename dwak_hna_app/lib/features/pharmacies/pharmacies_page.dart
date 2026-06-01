import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/location_service.dart';
import '../../data/services/pharmacie_service.dart';
import 'pharmacy_products_page.dart';

class PharmaciesPage extends StatefulWidget {
  const PharmaciesPage({super.key});

  @override
  State<PharmaciesPage> createState() => _PharmaciesPageState();
}

class _PharmaciesPageState extends State<PharmaciesPage> {
  final PharmacieService pharmacieService = PharmacieService();

  bool isLoading = true;
  bool isLocating = true;
  String? error;

  List<dynamic> pharmacies = [];

  bool showMap = false;

  String selectedStatus = 'all';
  double rayonKm = 10;

  double currentLatitude = 36.75;
  double currentLongitude = 3.04;

  StreamSubscription<Position>? positionSubscription;
  DateTime? lastRequestTime;
  double? lastRequestLatitude;
  double? lastRequestLongitude;

  @override
  void initState() {
    super.initState();
    initLocationAndLoadPharmacies();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> initLocationAndLoadPharmacies() async {
    try {
      setState(() {
        isLocating = true;
        isLoading = true;
        error = null;
      });

      final location = await LocationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        currentLatitude = location.latitude;
        currentLongitude = location.longitude;
        isLocating = false;
      });

      await loadPharmacies();

      startRealtimeLocation();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLocating = false;
        isLoading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void startRealtimeLocation() {
    positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 300,
    );

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      if (!mounted) return;

      final shouldReload = shouldReloadForPosition(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentLatitude = position.latitude;
        currentLongitude = position.longitude;
      });

      if (shouldReload) {
        await loadPharmacies();
      }
    });
  }

  bool shouldReloadForPosition(double newLatitude, double newLongitude) {
    final now = DateTime.now();

    if (lastRequestTime != null) {
      final seconds = now.difference(lastRequestTime!).inSeconds;

      if (seconds < 2) {
        return false;
      }
    }

    if (lastRequestLatitude == null || lastRequestLongitude == null) {
      lastRequestLatitude = newLatitude;
      lastRequestLongitude = newLongitude;
      lastRequestTime = now;
      return true;
    }

    final distanceMoved = Geolocator.distanceBetween(
      lastRequestLatitude!,
      lastRequestLongitude!,
      newLatitude,
      newLongitude,
    );

    if (distanceMoved >= 300) {
      lastRequestLatitude = newLatitude;
      lastRequestLongitude = newLongitude;
      lastRequestTime = now;
      return true;
    }

    return false;
  }

  Future<void> loadPharmacies() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      lastRequestLatitude = currentLatitude;
      lastRequestLongitude = currentLongitude;
      lastRequestTime = DateTime.now();

      final data = await pharmacieService.getNearbyPharmacies(
        latitude: currentLatitude,
        longitude: currentLongitude,
        rayonKm: rayonKm,
        ouverte: selectedStatus == 'open',
        deGarde: selectedStatus == 'duty',
      );

      if (!mounted) return;

      setState(() {
        pharmacies = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  String textValue(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return fallback;
    }

    return text;
  }

  double? doubleValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  int intValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  bool isOpen(dynamic pharmacy) {
    return boolValue(pharmacy['est_ouverte']);
  }

  bool isDuty(dynamic pharmacy) {
    return boolValue(pharmacy['est_de_garde']);
  }

  bool isClosed(dynamic pharmacy) {
    return !isOpen(pharmacy) && !isDuty(pharmacy);
  }

  String getOpenStatus(dynamic pharmacy) {
    return isOpen(pharmacy) ? 'Ouverte' : 'Fermée';
  }

  Color getOpenStatusColor(dynamic pharmacy) {
    return isOpen(pharmacy) ? AppColors.primaryGreen : Colors.red;
  }

  IconData getOpenStatusIcon(dynamic pharmacy) {
    return isOpen(pharmacy)
        ? Icons.local_pharmacy_rounded
        : Icons.lock_outline_rounded;
  }

  String getDutyStatus(dynamic pharmacy) {
    return isDuty(pharmacy) ? 'En garde' : 'Pas en garde';
  }

  Color getDutyStatusColor(dynamic pharmacy) {
    return isDuty(pharmacy) ? Colors.orange : Colors.grey;
  }

  IconData getDutyStatusIcon(dynamic pharmacy) {
    return isDuty(pharmacy)
        ? Icons.star_rounded
        : Icons.star_border_rounded;
  }

  List<dynamic> get visiblePharmacies {
    return pharmacies.where((pharmacy) {
      if (selectedStatus == 'open') {
        return isOpen(pharmacy);
      }

      if (selectedStatus == 'closed') {
        return isClosed(pharmacy);
      }

      if (selectedStatus == 'duty') {
        return isDuty(pharmacy);
      }

      return true;
    }).toList();
  }

  String getDistance(dynamic pharmacy) {
    final distance = pharmacy['distance_km'];

    if (distance == null) {
      return '';
    }

    final value = double.tryParse(distance.toString());

    if (value == null) {
      return '';
    }

    return '${value.toStringAsFixed(1)} km';
  }

  String getStatus(dynamic pharmacy) {
    if (isDuty(pharmacy)) return 'De garde';
    if (isOpen(pharmacy)) return 'Ouverte';
    return 'Fermée';
  }

  Color getStatusColor(dynamic pharmacy) {
    if (isDuty(pharmacy)) return Colors.orange;
    if (isOpen(pharmacy)) return AppColors.primaryGreen;
    return Colors.red;
  }

  IconData getStatusIcon(dynamic pharmacy) {
    if (isDuty(pharmacy)) return Icons.health_and_safety_rounded;
    if (isOpen(pharmacy)) return Icons.local_pharmacy_rounded;
    return Icons.lock_outline_rounded;
  }

  void changeStatus(String status) {
    setState(() {
      selectedStatus = status;
    });

    loadPharmacies();
  }

  void changeRayon(double value) {
    setState(() {
      rayonKm = value;
    });

    loadPharmacies();
  }

  Future<void> callPhone(String phone) async {
    final cleanPhone = phone
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('.', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .trim();

    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro indisponible'),
        ),
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: cleanPhone,
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d’ouvrir l’application téléphone'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur appel : ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> openLocalisation(dynamic pharmacy) async {
    final lat = doubleValue(pharmacy['latitude']);
    final lng = doubleValue(pharmacy['longitude']);
    final address = textValue(pharmacy['adresse'], '');
    final name = textValue(pharmacy['nom'], 'Pharmacie');

    String destination;

    if (lat != null && lng != null) {
      destination = '$lat,$lng';
    } else if (address.isNotEmpty) {
      destination = '$name $address';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Localisation indisponible'),
        ),
      );
      return;
    }

    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': destination,
      },
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir Google Maps'),
        ),
      );
    }
  }

  void openPharmacyProducts(dynamic pharmacy) {
    final pharmacieId = intValue(pharmacy['pharmacie_id']);
    final pharmacieName = textValue(pharmacy['nom'], 'Pharmacie');

    if (pharmacieId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pharmacie invalide'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PharmacyProductsPage(
          pharmacieId: pharmacieId,
          pharmacieName: pharmacieName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLocating || isLoading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 120),
            const Icon(
              Icons.location_off_outlined,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: initLocationAndLoadPharmacies,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text(
                'Réessayer',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadPharmacies,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pharmacies proches',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _ViewModeButton(
                        label: 'Liste',
                        icon: Icons.list_rounded,
                        active: !showMap,
                        onTap: () {
                          setState(() {
                            showMap = false;
                          });
                        },
                      ),
                      _ViewModeButton(
                        label: 'Carte',
                        icon: Icons.map_outlined,
                        active: showMap,
                        onTap: () {
                          setState(() {
                            showMap = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            const Text(
              'Liste des pharmacies autour de votre position',
              style: TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Position actuelle : ${currentLatitude.toStringAsFixed(5)}, ${currentLongitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Toutes'),
                  selected: selectedStatus == 'all',
                  onSelected: (_) => changeStatus('all'),
                ),
                ChoiceChip(
                  label: const Text('Ouvertes'),
                  selected: selectedStatus == 'open',
                  onSelected: (_) => changeStatus('open'),
                ),
                ChoiceChip(
                  label: const Text('Fermées'),
                  selected: selectedStatus == 'closed',
                  onSelected: (_) => changeStatus('closed'),
                ),
                ChoiceChip(
                  label: const Text('De garde'),
                  selected: selectedStatus == 'duty',
                  onSelected: (_) => changeStatus('duty'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('5 km'),
                  selected: rayonKm == 5,
                  onSelected: (_) => changeRayon(5),
                ),
                ChoiceChip(
                  label: const Text('10 km'),
                  selected: rayonKm == 10,
                  onSelected: (_) => changeRayon(10),
                ),
                ChoiceChip(
                  label: const Text('20 km'),
                  selected: rayonKm == 20,
                  onSelected: (_) => changeRayon(20),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (visiblePharmacies.isEmpty)
              const _EmptyPharmaciesCard()
            else if (showMap)
              _PharmaciesMapSection(
                pharmacies: visiblePharmacies,
                patientLatitude: currentLatitude,
                patientLongitude: currentLongitude,
                onCall: (pharmacy) => callPhone(
                  textValue(pharmacy['telephone'], ''),
                ),
                onLocalisation: openLocalisation,
                onProducts: openPharmacyProducts,
              )
            else
              ...visiblePharmacies.map(
                (pharmacy) => _PharmacyCard(
                  name: pharmacy['nom']?.toString() ?? 'Pharmacie',
                  address: pharmacy['adresse']?.toString() ?? '',
                  distance: getDistance(pharmacy),
                  openStatus: getOpenStatus(pharmacy),
                  openStatusColor: getOpenStatusColor(pharmacy),
                  openStatusIcon: getOpenStatusIcon(pharmacy),
                  dutyStatus: getDutyStatus(pharmacy),
                  dutyStatusColor: getDutyStatusColor(pharmacy),
                  dutyStatusIcon: getDutyStatusIcon(pharmacy),
                  commune: pharmacy['commune']?.toString() ?? '',
                  wilaya: pharmacy['wilaya']?.toString() ?? '',
                  onCall: () => callPhone(
                    textValue(pharmacy['telephone'], ''),
                  ),
                  onLocalisation: () => openLocalisation(pharmacy),
                  onProducts: () => openPharmacyProducts(pharmacy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primaryGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? Colors.white : AppColors.primaryGreen,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.primaryGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PharmaciesMapSection extends StatelessWidget {
  final List<dynamic> pharmacies;
  final double patientLatitude;
  final double patientLongitude;
  final void Function(dynamic pharmacy) onCall;
  final void Function(dynamic pharmacy) onLocalisation;
  final void Function(dynamic pharmacy) onProducts;

  const _PharmaciesMapSection({
    required this.pharmacies,
    required this.patientLatitude,
    required this.patientLongitude,
    required this.onCall,
    required this.onLocalisation,
    required this.onProducts,
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

  bool isOpen(dynamic pharmacy) {
    return boolValue(pharmacy['est_ouverte']);
  }

  bool isDuty(dynamic pharmacy) {
    return boolValue(pharmacy['est_de_garde']);
  }

  String openStatusLabel(dynamic pharmacy) {
    return isOpen(pharmacy) ? 'Ouverte' : 'Fermée';
  }

  Color openStatusColor(dynamic pharmacy) {
    return isOpen(pharmacy) ? AppColors.primaryGreen : Colors.red;
  }

  IconData openStatusIcon(dynamic pharmacy) {
    return isOpen(pharmacy)
        ? Icons.local_pharmacy_rounded
        : Icons.lock_outline_rounded;
  }

  String dutyStatusLabel(dynamic pharmacy) {
    return isDuty(pharmacy) ? 'En garde' : 'Pas en garde';
  }

  Color dutyStatusColor(dynamic pharmacy) {
    return isDuty(pharmacy) ? Colors.orange : Colors.grey;
  }

  IconData dutyStatusIcon(dynamic pharmacy) {
    return isDuty(pharmacy)
        ? Icons.star_rounded
        : Icons.star_border_rounded;
  }

  String getStatus(dynamic pharmacy) {
    if (isDuty(pharmacy)) return 'De garde';
    if (isOpen(pharmacy)) return 'Ouverte';
    return 'Fermée';
  }

  Color getMarkerColor(dynamic pharmacy) {
    if (isDuty(pharmacy)) return Colors.orange;
    if (isOpen(pharmacy)) return AppColors.primaryGreen;
    return Colors.red;
  }

  IconData getMarkerIcon(dynamic pharmacy) {
    if (isDuty(pharmacy)) return Icons.health_and_safety_rounded;
    if (isOpen(pharmacy)) return Icons.local_pharmacy_rounded;
    return Icons.lock_outline_rounded;
  }

  List<dynamic> get pharmaciesWithLocation {
    return pharmacies.where((pharmacy) {
      final lat = doubleValue(pharmacy['latitude']);
      final lng = doubleValue(pharmacy['longitude']);

      return lat != null && lng != null;
    }).toList();
  }

  String distanceText(dynamic pharmacy) {
    final distance = doubleValue(pharmacy['distance_km']);

    if (distance == null) {
      return '';
    }

    return '${distance.toStringAsFixed(1)} km';
  }

  LatLng get center {
    return LatLng(patientLatitude, patientLongitude);
  }

  void showPharmacySheet(BuildContext context, dynamic pharmacy) {
    final distance = distanceText(pharmacy);
    final color = getMarkerColor(pharmacy);
    final icon = getMarkerIcon(pharmacy);

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
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            textValue(pharmacy['nom'], 'Pharmacie'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PharmacyInfoChip(
                          icon: openStatusIcon(pharmacy),
                          label: openStatusLabel(pharmacy),
                          color: openStatusColor(pharmacy),
                        ),
                        _PharmacyInfoChip(
                          icon: dutyStatusIcon(pharmacy),
                          label: dutyStatusLabel(pharmacy),
                          color: dutyStatusColor(pharmacy),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _InfoLine(
                      icon: Icons.location_on_outlined,
                      text: textValue(
                        pharmacy['adresse'],
                        'Adresse non disponible',
                      ),
                    ),

                    _InfoLine(
                      icon: Icons.place_outlined,
                      text:
                          '${textValue(pharmacy['commune'], '')}, ${textValue(pharmacy['wilaya'], '')}',
                    ),

                    if (distance.isNotEmpty)
                      _InfoLine(
                        icon: Icons.near_me_outlined,
                        text: 'Distance : $distance',
                      ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onCall(pharmacy),
                            icon: const Icon(Icons.call_outlined, size: 18),
                            label: const Text(
                              'Appeler',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => onLocalisation(pharmacy),
                            icon: const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Localisation',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onProducts(pharmacy),
                        icon: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Voir les produits de cette pharmacie',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
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
    final pharmacyMarkers = pharmaciesWithLocation.map((pharmacy) {
      final lat = doubleValue(pharmacy['latitude'])!;
      final lng = doubleValue(pharmacy['longitude'])!;

      final color = getMarkerColor(pharmacy);
      final icon = getMarkerIcon(pharmacy);

      return Marker(
        point: LatLng(lat, lng),
        width: 58,
        height: 58,
        child: GestureDetector(
          onTap: () => showPharmacySheet(context, pharmacy),
          child: Container(
            decoration: BoxDecoration(
              color: color,
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
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
    }).toList();

    final patientMarker = Marker(
      point: LatLng(patientLatitude, patientLongitude),
      width: 48,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.person_pin_circle_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );

    return [
      patientMarker,
      ...pharmacyMarkers,
    ];
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

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendItem(color: AppColors.primaryGreen, label: 'Ouverte'),
              _LegendItem(color: Colors.red, label: 'Fermée'),
              _LegendItem(color: Colors.orange, label: 'De garde'),
              _LegendItem(color: Colors.blue, label: 'Votre position'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Container(
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
        ),
      ],
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final String name;
  final String address;
  final String distance;
  final String openStatus;
  final Color openStatusColor;
  final IconData openStatusIcon;
  final String dutyStatus;
  final Color dutyStatusColor;
  final IconData dutyStatusIcon;
  final String commune;
  final String wilaya;
  final VoidCallback onCall;
  final VoidCallback onLocalisation;
  final VoidCallback onProducts;

  const _PharmacyCard({
    required this.name,
    required this.address,
    required this.distance,
    required this.openStatus,
    required this.openStatusColor,
    required this.openStatusIcon,
    required this.dutyStatus,
    required this.dutyStatusColor,
    required this.dutyStatusIcon,
    required this.commune,
    required this.wilaya,
    required this.onCall,
    required this.onLocalisation,
    required this.onProducts,
  });

  @override
  Widget build(BuildContext context) {
    final locationLine = [
      if (distance.isNotEmpty) distance,
      if (commune.isNotEmpty || wilaya.isNotEmpty) '$commune, $wilaya',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: openStatusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  openStatusIcon,
                  color: openStatusColor,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),

                    if (locationLine.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        locationLine,
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    Text(
                      address.isEmpty ? 'Adresse non disponible' : address,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PharmacyInfoChip(
                          icon: openStatusIcon,
                          label: openStatus,
                          color: openStatusColor,
                        ),
                        _PharmacyInfoChip(
                          icon: dutyStatusIcon,
                          label: dutyStatus,
                          color: dutyStatusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text(
                    'Appeler',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onLocalisation,
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: const Text(
                    'Localisation',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onProducts,
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text(
                'Voir les produits de cette pharmacie',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PharmacyInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PharmacyInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
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
    if (text.trim().isEmpty || text.trim() == ',') {
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _EmptyPharmaciesCard extends StatelessWidget {
  const _EmptyPharmaciesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.local_pharmacy_outlined,
            color: AppColors.primaryGreen,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'Aucune pharmacie trouvée',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Vérifiez que vos pharmacies sont approuvées et possèdent latitude/longitude.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
