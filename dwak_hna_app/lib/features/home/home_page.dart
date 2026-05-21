import 'dart:convert';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/services/location_service.dart';
import '../../data/services/pharmacie_service.dart';
import '../medicines/add_medicines_page.dart';
import '../notifications/notifications_page.dart';
import '../pharmacies/pharmacies_page.dart';
import '../prescriptions/prescription_scan_page.dart';
import '../products/products_page.dart';
import '../requests/requests_page.dart';

class HomePage extends StatefulWidget {
  final void Function(int index)? onSelectTab;

  const HomePage({
    super.key,
    this.onSelectTab,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String apiBaseUrl = 'http://10.0.2.2:5001';
  static const String logoAssetPath = 'assets/images/logo.png';

  final PharmacieService pharmacieService = PharmacieService();

  bool isLoading = true;
  String? pharmacyError;

  List<dynamic> nearbyPharmacies = [];
  List<dynamic> publicites = [];

  String patientNom = '';
  String patientPrenom = '';

  @override
  void initState() {
    super.initState();
    loadHomeData();
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

  Future<void> loadHomeData() async {
    setState(() {
      isLoading = true;
      pharmacyError = null;
    });

    List<dynamic> loadedPublicites = [];
    List<dynamic> loadedPharmacies = [];
    String? loadedPharmacyError;

    await fetchPatientProfile();

    try {
      loadedPublicites = await fetchPublicitesAccueil();
    } catch (e) {
      loadedPublicites = [];
    }

    try {
      final location = await LocationService.getCurrentLocation();

      loadedPharmacies = await pharmacieService.getNearbyPharmacies(
        latitude: location.latitude,
        longitude: location.longitude,
        rayonKm: 10,
        ouverte: false,
        deGarde: false,
      );
    } catch (e) {
      loadedPharmacyError = e.toString().replaceFirst('Exception: ', '');
    }

    if (!mounted) return;

    setState(() {
      publicites = loadedPublicites;
      nearbyPharmacies = loadedPharmacies;
      pharmacyError = loadedPharmacyError;
      isLoading = false;
    });
  }

  Future<void> fetchPatientProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/patients/profile'),
        headers: await headers(),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] ?? body['patient'] ?? body;

        if (!mounted) return;

        setState(() {
          patientNom = textValue(data['nom'], '');
          patientPrenom = textValue(data['prenom'], '');
        });
      }
    } catch (_) {}
  }

  Future<List<dynamic>> fetchPublicitesAccueil() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/publicites/accueil'),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      if (body is Map && body['success'] == true) {
        return body['data'] ?? [];
      }

      if (body is List) {
        return body;
      }
    }

    return [];
  }

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  String textValue(dynamic value, String fallback) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return fallback;
    }

    return text;
  }

  String get patientFullName {
    final fullName = '$patientPrenom $patientNom'.trim();

    if (fullName.isEmpty) {
      return 'Bonjour';
    }

    return 'Bonjour $fullName';
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
    final isDuty = boolValue(pharmacy['est_de_garde']);
    final isOpen = boolValue(pharmacy['est_ouverte']);

    if (isDuty) return 'De garde';
    if (isOpen) return 'Ouverte';
    return 'Fermée';
  }

  Color getStatusColor(dynamic pharmacy) {
    final isDuty = boolValue(pharmacy['est_de_garde']);
    final isOpen = boolValue(pharmacy['est_ouverte']);

    if (isDuty) return Colors.orange;
    if (isOpen) return AppColors.primaryGreen;
    return Colors.red;
  }

  IconData getStatusIcon(dynamic pharmacy) {
    final isDuty = boolValue(pharmacy['est_de_garde']);
    final isOpen = boolValue(pharmacy['est_ouverte']);

    if (isDuty) return Icons.health_and_safety_rounded;
    if (isOpen) return Icons.local_pharmacy_rounded;
    return Icons.lock_outline_rounded;
  }

  void openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  void goToTabOrPage(int index, Widget fallbackPage) {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(index);
    } else {
      openPage(fallbackPage);
    }
  }

  void openNotificationsHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );
  }

  String resolveImageUrl(dynamic value) {
    final imageUrl = value?.toString().trim() ?? '';

    if (imageUrl.isEmpty) return '';

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    if (imageUrl.startsWith('/')) {
      return '$apiBaseUrl$imageUrl';
    }

    return '$apiBaseUrl/uploads/$imageUrl';
  }

  Future<void> openAdLink(dynamic publicite) async {
    final link = publicite['lien_cible']?.toString().trim() ?? '';

    if (link.isEmpty) return;

    final uri = Uri.tryParse(link);

    if (uri == null) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadHomeData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.asset(
                    logoAssetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.local_pharmacy_rounded,
                        color: AppColors.primaryGreen,
                        size: 28,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientFullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Trouvez vos médicaments rapidement',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filled(
                  onPressed: openNotificationsHistory,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.lightGreen,
                    foregroundColor: AppColors.primaryGreen,
                    minimumSize: const Size(42, 42),
                  ),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),

            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                _HomeActionCard(
                  icon: Icons.medication_liquid_outlined,
                  title: 'Médicaments',
                  subtitle: 'Nouvelle demande',
                  onTap: () => openPage(const AddMedicinesPage()),
                ),
                _HomeActionCard(
                  icon: Icons.document_scanner_outlined,
                  title: 'Ordonnance',
                  subtitle: 'Scanner',
                  onTap: () => openPage(const PrescriptionScanPage()),
                ),
                _HomeActionCard(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Produits',
                  subtitle: 'Parapharmacie',
                  onTap: () => goToTabOrPage(1, const ProductsPage()),
                ),
                _HomeActionCard(
                  icon: Icons.assignment_outlined,
                  title: 'Demandes',
                  subtitle: 'Suivi',
                  onTap: () => goToTabOrPage(0, const RequestsPage()),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pharmacies proches',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => goToTabOrPage(3, const PharmaciesPage()),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            if (isLoading)
              const SizedBox(
                height: 95,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (pharmacyError != null)
              _CompactInfoCard(
                icon: Icons.location_off_outlined,
                title: 'Localisation indisponible',
                message: pharmacyError!,
                color: Colors.red,
                onTap: loadHomeData,
              )
            else if (nearbyPharmacies.isEmpty)
              const _CompactInfoCard(
                icon: Icons.local_pharmacy_outlined,
                title: 'Aucune pharmacie proche',
                message: 'Aucune pharmacie trouvée.',
                color: AppColors.primaryGreen,
              )
            else
              ...nearbyPharmacies.take(2).map(
                    (pharmacy) => _NearbyPharmacyCard(
                      name: textValue(pharmacy['nom'], 'Pharmacie'),
                      address: textValue(pharmacy['adresse'], ''),
                      distance: getDistance(pharmacy),
                      status: getStatus(pharmacy),
                      color: getStatusColor(pharmacy),
                      icon: getStatusIcon(pharmacy),
                    ),
                  ),

            if (publicites.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Panneaux publicitaires',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _AdsCarousel(
                publicites: publicites,
                resolveImageUrl: resolveImageUrl,
                onTap: openAdLink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdsCarousel extends StatefulWidget {
  final List<dynamic> publicites;
  final String Function(dynamic value) resolveImageUrl;
  final Future<void> Function(dynamic publicite) onTap;

  const _AdsCarousel({
    required this.publicites,
    required this.resolveImageUrl,
    required this.onTap,
  });

  @override
  State<_AdsCarousel> createState() => _AdsCarouselState();
}

class _AdsCarouselState extends State<_AdsCarousel> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 118,
            viewportFraction: 1,
            autoPlay: widget.publicites.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            enlargeCenterPage: false,
            enableInfiniteScroll: widget.publicites.length > 1,
            onPageChanged: (index, reason) {
              setState(() {
                currentIndex = index;
              });
            },
          ),
          items: widget.publicites.map((publicite) {
            final imageUrl = widget.resolveImageUrl(
              publicite['image_url'],
            );

            final title = publicite['titre']?.toString() ?? '';

            return GestureDetector(
              onTap: () => widget.onTap(publicite),
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const _AdPlaceholder();
                        },
                      )
                    else
                      const _AdPlaceholder(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.publicites.length > 1) ...[
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.publicites.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: currentIndex == index ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: currentIndex == index
                      ? AppColors.primaryGreen
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightGreen,
      child: const Center(
        child: Icon(
          Icons.campaign_outlined,
          color: AppColors.primaryGreen,
          size: 42,
        ),
      ),
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyPharmacyCard extends StatelessWidget {
  final String name;
  final String address;
  final String distance;
  final String status;
  final Color color;
  final IconData icon;

  const _NearbyPharmacyCard({
    required this.name,
    required this.address,
    required this.distance,
    required this.status,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = distance.isEmpty ? address : '$distance • $address';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label: status),
        ],
      ),
    );
  }
}

class _CompactInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final VoidCallback? onTap;

  const _CompactInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
