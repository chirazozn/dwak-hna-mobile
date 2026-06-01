import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/demande_service.dart';

class DemandeDetailsPage extends StatefulWidget {
  final int demandeId;

  const DemandeDetailsPage({
    super.key,
    required this.demandeId,
  });

  @override
  State<DemandeDetailsPage> createState() => _DemandeDetailsPageState();
}

class _DemandeDetailsPageState extends State<DemandeDetailsPage> {
  final DemandeService demandeService = DemandeService();

  bool isLoading = true;
  bool isChoosing = false;
  bool isFinishing = false;
  bool showMap = false;

  int selectedRating = 5;
  final TextEditingController finishCommentController =
      TextEditingController();

  String? error;
  Map<String, dynamic>? data;

  String selectedStatus = 'all';
  String selectedPrice = 'all';
  String selectedDistance = 'all';
  String selectedOpenStatus = 'all';

  Map<String, dynamic>? get demande {
    final current = data?['demande'];

    if (current == null) return null;

    return Map<String, dynamic>.from(current);
  }

  List<dynamic> get medicaments {
    return data?['medicaments'] ?? [];
  }

  List<dynamic> get pharmacies {
    return data?['pharmacies'] ?? [];
  }

  Map<String, dynamic> get pharmacieStats {
    final current = data?['pharmacie_stats'];

    if (current is Map) {
      return Map<String, dynamic>.from(current);
    }

    return {};
  }

  List<dynamic> get ordonnances {
    return data?['ordonnances'] ?? [];
  }

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  @override
  void dispose() {
    finishCommentController.dispose();
    super.dispose();
  }

  Future<void> loadDetails() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final result = await demandeService.getDemandeDetail(
        demandeId: widget.demandeId,
      );

      if (!mounted) return;

      setState(() {
        data = result;
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

  int intValue(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.toInt() ??
        0;
  }

  double? doubleValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  String waitingPharmaciesMessage() {
    final total = intValue(pharmacieStats['total']);
    final pending = intValue(pharmacieStats['en_attente']);

    if (total <= 0 || pending <= 0) {
      return '';
    }

    if (pending == total) {
      if (pending == 1) {
        return '1 pharmacie a reçu votre demande. Veuillez attendre sa réponse.';
      }

      return '$pending pharmacies ont reçu votre demande. Veuillez attendre leurs réponses.';
    }

    if (pending == 1) {
      return "1 pharmacie n'a pas encore répondu. Veuillez patienter...";
    }

    return "$pending pharmacies n'ont pas encore répondu. Veuillez patienter...";
  }

  bool isPharmacyOpen(dynamic pharmacie) {
    return boolValue(pharmacie['est_ouverte']);
  }

  bool isPharmacyDuty(dynamic pharmacie) {
    return boolValue(pharmacie['est_de_garde']);
  }

  bool isPharmacyClosed(dynamic pharmacie) {
    return !isPharmacyOpen(pharmacie) && !isPharmacyDuty(pharmacie);
  }

  String priceValue(dynamic value) {
    final parsed = doubleValue(value);

    if (parsed == null) return '';

    return '${parsed.toStringAsFixed(2)} DA';
  }

  String distanceValue(dynamic value) {
    final parsed = doubleValue(value);

    if (parsed == null) return '';

    return '${parsed.toStringAsFixed(1)} km';
  }

  String statusLabel(String etat) {
    switch (etat) {
      case 'en_attente':
        return 'En attente';
      case 'reponse_recue':
        return 'Réponse reçue';
      case 'pharmacie_choisie':
        return 'Pharmacie choisie';
      case 'termine':
        return 'Terminée';
      case 'annule':
        return 'Annulée';
      default:
        return etat;
    }
  }

  int statusStep(String etat) {
    switch (etat) {
      case 'en_attente':
        return 1;
      case 'reponse_recue':
        return 2;
      case 'pharmacie_choisie':
        return 3;
      case 'termine':
        return 4;
      default:
        return 1;
    }
  }

  String pharmacieStatusLabel(String statut) {
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
        return statut;
    }
  }

  Color responseStatusColor(String statut) {
    switch (statut) {
      case 'acceptee':
        return AppColors.primaryGreen;
      case 'refusee':
        return Colors.red;
      case 'choisie':
        return Colors.blue;
      case 'en_attente':
        return Colors.orange;
      default:
        return AppColors.textGrey;
    }
  }

  String disponibiliteLabel(dynamic value) {
    final text = value?.toString() ?? '';

    switch (text) {
      case 'totale':
        return 'Disponibilité totale';
      case 'partielle':
        return 'Disponibilité partielle';
      case 'non_disponible':
        return 'Non disponible';
      default:
        return '';
    }
  }

  String statusFilterLabel() {
    switch (selectedStatus) {
      case 'en_attente':
        return 'En attente';
      case 'acceptee':
        return 'Acceptées';
      case 'refusee':
        return 'Refusées';
      case 'choisie':
        return 'Choisie';
      default:
        return 'Statut';
    }
  }

  String priceFilterLabel() {
    switch (selectedPrice) {
      case 'with_price':
        return 'Avec prix';
      case 'under_2000':
        return '< 2000 DA';
      case '2000_5000':
        return '2000-5000 DA';
      case 'over_5000':
        return '> 5000 DA';
      default:
        return 'Prix';
    }
  }

  String distanceFilterLabel() {
    switch (selectedDistance) {
      case 'under_2':
        return '≤ 2 km';
      case 'under_5':
        return '≤ 5 km';
      case 'under_10':
        return '≤ 10 km';
      default:
        return 'Distance';
    }
  }

  String openStatusFilterLabel() {
    switch (selectedOpenStatus) {
      case 'open':
        return 'Ouvertes';
      case 'closed':
        return 'Fermées';
      case 'duty':
        return 'De garde';
      default:
        return 'Ouverture';
    }
  }

  String firstOrdonnanceImageUrl() {
    if (ordonnances.isEmpty) return '';

    final first = Map<String, dynamic>.from(ordonnances.first);

    final keys = [
      'image_url_resolved',
      'image_url',
      'url',
      'fichier_url',
      'photo_url',
      'chemin',
      'chemin_image',
      'ordonnance_url',
    ];

    for (final key in keys) {
      final value = first[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  List<dynamic> pharmaciesToDisplayBase() {
    final currentDemande = demande;

    if (currentDemande == null) return pharmacies;

    final etat = currentDemande['etat']?.toString() ?? '';
    final chosenId = intValue(currentDemande['pharmacie_choisie_id']);

    if (etat == 'pharmacie_choisie' || etat == 'termine') {
      return pharmacies.where((pharmacie) {
        return intValue(pharmacie['pharmacie_id']) == chosenId ||
            pharmacie['statut'] == 'choisie';
      }).toList();
    }

    return pharmacies;
  }

  List<dynamic> get filteredPharmacies {
    final result = pharmaciesToDisplayBase().where((pharmacie) {
      final statut = pharmacie['statut']?.toString() ?? '';
      final prix = doubleValue(pharmacie['prix_estime']);
      final distance = doubleValue(pharmacie['distance_km']);

      if (selectedStatus != 'all' && statut != selectedStatus) {
        return false;
      }

      if (selectedPrice == 'with_price' && prix == null) {
        return false;
      }

      if (selectedPrice == 'under_2000' && (prix == null || prix >= 2000)) {
        return false;
      }

      if (selectedPrice == '2000_5000' &&
          (prix == null || prix < 2000 || prix > 5000)) {
        return false;
      }

      if (selectedPrice == 'over_5000' && (prix == null || prix <= 5000)) {
        return false;
      }

      if (selectedDistance == 'under_2' &&
          (distance == null || distance > 2)) {
        return false;
      }

      if (selectedDistance == 'under_5' &&
          (distance == null || distance > 5)) {
        return false;
      }

      if (selectedDistance == 'under_10' &&
          (distance == null || distance > 10)) {
        return false;
      }

      if (selectedOpenStatus == 'open' && !isPharmacyOpen(pharmacie)) {
        return false;
      }

      if (selectedOpenStatus == 'closed' && !isPharmacyClosed(pharmacie)) {
        return false;
      }

      if (selectedOpenStatus == 'duty' && !isPharmacyDuty(pharmacie)) {
        return false;
      }

      return true;
    }).toList();

    result.sort((a, b) {
      int statusRank(String s) {
        switch (s) {
          case 'choisie':
            return 0;
          case 'acceptee':
            return 1;
          case 'en_attente':
            return 2;
          case 'refusee':
            return 3;
          default:
            return 4;
        }
      }

      final statusA = a['statut']?.toString() ?? '';
      final statusB = b['statut']?.toString() ?? '';

      final byStatus = statusRank(statusA).compareTo(statusRank(statusB));

      if (byStatus != 0) return byStatus;

      final distanceA = doubleValue(a['distance_km']) ?? 999999;
      final distanceB = doubleValue(b['distance_km']) ?? 999999;

      return distanceA.compareTo(distanceB);
    });

    return result;
  }

  void clearFilters() {
    setState(() {
      selectedStatus = 'all';
      selectedPrice = 'all';
      selectedDistance = 'all';
      selectedOpenStatus = 'all';
    });
  }

  Future<void> openStatusFilter() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FilterSheet(
          title: 'Filtrer par statut',
          selectedValue: selectedStatus,
          options: const [
            _FilterOption(value: 'all', label: 'Tous les statuts'),
            _FilterOption(value: 'acceptee', label: 'Acceptées'),
            _FilterOption(value: 'refusee', label: 'Refusées'),
            _FilterOption(value: 'choisie', label: 'Choisie'),
          ],
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedStatus = value;
      });
    }
  }

  Future<void> openPriceFilter() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FilterSheet(
          title: 'Filtrer par prix',
          selectedValue: selectedPrice,
          options: const [
            _FilterOption(value: 'all', label: 'Tous les prix'),
            _FilterOption(value: 'with_price', label: 'Avec prix estimé'),
            _FilterOption(value: 'under_2000', label: 'Moins de 2000 DA'),
            _FilterOption(value: '2000_5000', label: '2000 - 5000 DA'),
            _FilterOption(value: 'over_5000', label: 'Plus de 5000 DA'),
          ],
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedPrice = value;
      });
    }
  }

  Future<void> openDistanceFilter() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FilterSheet(
          title: 'Filtrer par distance',
          selectedValue: selectedDistance,
          options: const [
            _FilterOption(value: 'all', label: 'Toutes les distances'),
            _FilterOption(value: 'under_2', label: 'Moins de 2 km'),
            _FilterOption(value: 'under_5', label: 'Moins de 5 km'),
            _FilterOption(value: 'under_10', label: 'Moins de 10 km'),
          ],
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedDistance = value;
      });
    }
  }

  Future<void> openOpenStatusFilter() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FilterSheet(
          title: 'Filtrer par ouverture',
          selectedValue: selectedOpenStatus,
          options: const [
            _FilterOption(value: 'all', label: 'Toutes'),
            _FilterOption(value: 'open', label: 'Ouvertes'),
            _FilterOption(value: 'closed', label: 'Fermées'),
            _FilterOption(value: 'duty', label: 'De garde'),
          ],
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedOpenStatus = value;
      });
    }
  }

  Future<void> choisirPharmacie(dynamic pharmacie) async {
    final currentDemande = demande;

    if (currentDemande == null) return;

    final demandeId = intValue(currentDemande['demande_id']);
    final pharmacieId = intValue(pharmacie['pharmacie_id']);

    if (demandeId == 0 || pharmacieId == 0) return;

    try {
      setState(() {
        isChoosing = true;
      });

      await demandeService.choisirPharmacie(
        demandeId: demandeId,
        pharmacieId: pharmacieId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pharmacie choisie avec succès'),
        ),
      );

      await loadDetails();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isChoosing = false;
        });
      }
    }
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
      if (!mounted) return;

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
          content: Text(
            'Erreur appel : ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> openMaps(dynamic pharmacie) async {
    final lat = doubleValue(pharmacie['pharmacie_latitude']);
    final lng = doubleValue(pharmacie['pharmacie_longitude']);
    final address = textValue(pharmacie['pharmacie_adresse'], '');
    final name = textValue(pharmacie['pharmacie_nom'], 'Pharmacie');

    String query;

    if (lat != null && lng != null) {
      query = '$lat,$lng';
    } else if (address.isNotEmpty) {
      query = '$name $address';
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
      '/maps/search/',
      {
        'api': '1',
        'query': query,
      },
    );

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir Google Maps'),
        ),
      );
    }
  }

  void showMyRequestSheet() {
    final currentDemande = demande;

    if (currentDemande == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _MyRequestSheet(
          demande: currentDemande,
          medicaments: medicaments,
          ordonnanceImageUrl: firstOrdonnanceImageUrl(),
          textValue: textValue,
        );
      },
    );
  }


  Future<void> terminerDemande() async {
    final currentDemande = demande;

    if (currentDemande == null) return;

    final demandeId = intValue(currentDemande['demande_id']);

    if (demandeId == 0) return;

    try {
      setState(() {
        isFinishing = true;
      });

      await demandeService.terminerDemande(
        demandeId: demandeId,
        notePharmacie: selectedRating,
        commentaire: finishCommentController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande terminée avec succès'),
        ),
      );

      await loadDetails();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isFinishing = false;
        });
      }
    }
  }

  Future<void> showFinishDemandeSheet() async {
    selectedRating = 5;
    finishCommentController.clear();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Terminer la demande',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Confirmez que vous avez récupéré vos médicaments, puis laissez une note et un commentaire.',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Note sur 5',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        final active = value <= selectedRating;

                        return IconButton(
                          onPressed: () {
                            setModalState(() {
                              selectedRating = value;
                            });
                          },
                          icon: Icon(
                            active
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: active ? Colors.orange : Colors.grey,
                            size: 34,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: finishCommentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Commentaire',
                        hintText: 'Votre avis sur la pharmacie...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isFinishing
                            ? null
                            : () async {
                                await terminerDemande();

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        icon: isFinishing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          isFinishing
                              ? 'Validation...'
                              : 'Confirmer la récupération',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDemande = demande;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Détail demande',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? RefreshIndicator(
                    onRefresh: loadDetails,
                    child: ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        const SizedBox(height: 100),
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                : currentDemande == null
                    ? const Center(child: Text('Demande introuvable'))
                    : RefreshIndicator(
                        onRefresh: loadDetails,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                          children: [
                            _StepCard(
                              currentStep: statusStep(
                                currentDemande['etat']?.toString() ?? '',
                              ),
                              status: statusLabel(
                                currentDemande['etat']?.toString() ?? '',
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: showMyRequestSheet,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryGreen,
                                  side: const BorderSide(
                                    color: AppColors.primaryGreen,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: const Icon(Icons.assignment_outlined),
                                label: const Text(
                                  'Voir ma demande en détail',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            if (currentDemande['etat'] == 'pharmacie_choisie') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isFinishing
                                      ? null
                                      : showFinishDemandeSheet,
                                  icon: const Icon(Icons.task_alt_rounded),
                                  label: const Text(
                                    'J’ai récupéré mes médicaments',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Pharmacies',
                                    style: TextStyle(
                                      fontSize: 22,
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
                            const SizedBox(height: 10),
                            if (waitingPharmaciesMessage().isNotEmpty) ...[
                              _WhiteCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: AppColors.lightGreen,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.hourglass_top_rounded,
                                        color: AppColors.primaryGreen,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        waitingPharmaciesMessage(),
                                        style: const TextStyle(
                                          color: AppColors.textGrey,
                                          fontWeight: FontWeight.w800,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _FilterChipButton(
                                  icon: Icons.check_circle_outline,
                                  label: statusFilterLabel(),
                                  active: selectedStatus != 'all',
                                  onTap: openStatusFilter,
                                ),
                                _FilterChipButton(
                                  icon: Icons.sell_outlined,
                                  label: priceFilterLabel(),
                                  active: selectedPrice != 'all',
                                  onTap: openPriceFilter,
                                ),
                                _FilterChipButton(
                                  icon: Icons.location_on_outlined,
                                  label: distanceFilterLabel(),
                                  active: selectedDistance != 'all',
                                  onTap: openDistanceFilter,
                                ),
                                _FilterChipButton(
                                  icon: Icons.local_pharmacy_outlined,
                                  label: openStatusFilterLabel(),
                                  active: selectedOpenStatus != 'all',
                                  onTap: openOpenStatusFilter,
                                ),
                                _FilterChipButton(
                                  icon: Icons.restart_alt_rounded,
                                  label: 'Réinitialiser',
                                  active: false,
                                  outlined: true,
                                  onTap: clearFilters,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (filteredPharmacies.isEmpty)
                              _WhiteCard(
                                child: Text(
                                  waitingPharmaciesMessage().isNotEmpty
                                      ? 'Les pharmacies en attente ne sont pas affichées. Les réponses acceptées ou refusées apparaîtront ici.'
                                      : 'Aucune pharmacie ne correspond aux filtres.',
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else if (showMap)
                              _DemandePharmaciesMapSection(
                                pharmacies: filteredPharmacies,
                                demande: currentDemande,
                                textValue: textValue,
                                doubleValue: doubleValue,
                                priceValue: priceValue,
                                statusLabel: pharmacieStatusLabel,
                                responseStatusColor: responseStatusColor,
                                disponibiliteLabel: disponibiliteLabel,
                              )
                            else
                              ...filteredPharmacies.map(
                                (pharmacie) {
                                  final canChoose =
                                      currentDemande['etat'] ==
                                              'reponse_recue' &&
                                          pharmacie['statut'] == 'acceptee';

                                  return _PharmacyCard(
                                    pharmacie: pharmacie,
                                    statusLabel: pharmacieStatusLabel,
                                    responseStatusColor: responseStatusColor,
                                    disponibiliteLabel: disponibiliteLabel,
                                    priceValue: priceValue,
                                    distanceValue: distanceValue,
                                    textValue: textValue,
                                    canChoose: canChoose,
                                    isChoosing: isChoosing,
                                    onCall: () {
                                      callPhone(
                                        textValue(
                                          pharmacie['pharmacie_telephone'],
                                          '',
                                        ),
                                      );
                                    },
                                    onMaps: () => openMaps(pharmacie),
                                    onChoose: () =>
                                        choisirPharmacie(pharmacie),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int currentStep;
  final String status;

  const _StepCard({
    required this.currentStep,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StepDot(active: currentStep >= 1, label: 'Envoyée'),
              _StepBar(active: currentStep >= 2),
              _StepDot(active: currentStep >= 2, label: 'Réponses'),
              _StepBar(active: currentStep >= 3),
              _StepDot(active: currentStep >= 3, label: 'Choisie'),
              _StepBar(active: currentStep >= 4),
              _StepDot(active: currentStep >= 4, label: 'Terminée'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final String label;

  const _StepDot({
    required this.active,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: active ? AppColors.primaryGreen : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 54,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textGrey,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  final bool active;

  const _StepBar({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 4,
        margin: const EdgeInsets.only(bottom: 24),
        color: active ? AppColors.primaryGreen : Colors.grey.shade300,
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final dynamic pharmacie;
  final String Function(String statut) statusLabel;
  final Color Function(String statut) responseStatusColor;
  final String Function(dynamic value) disponibiliteLabel;
  final String Function(dynamic value) priceValue;
  final String Function(dynamic value) distanceValue;
  final String Function(dynamic value, String fallback) textValue;
  final bool canChoose;
  final bool isChoosing;
  final VoidCallback onCall;
  final VoidCallback onMaps;
  final VoidCallback onChoose;

  const _PharmacyCard({
    required this.pharmacie,
    required this.statusLabel,
    required this.responseStatusColor,
    required this.disponibiliteLabel,
    required this.priceValue,
    required this.distanceValue,
    required this.textValue,
    required this.canChoose,
    required this.isChoosing,
    required this.onCall,
    required this.onMaps,
    required this.onChoose,
  });

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  bool isOpen(dynamic pharmacie) {
    return boolValue(pharmacie['est_ouverte']);
  }

  bool isDuty(dynamic pharmacie) {
    return boolValue(pharmacie['est_de_garde']);
  }

  Color statusColor(dynamic pharmacie) {
    if (isDuty(pharmacie)) return Colors.orange;
    if (isOpen(pharmacie)) return AppColors.primaryGreen;
    return Colors.red;
  }

  IconData statusIcon(dynamic pharmacie) {
    if (isDuty(pharmacie)) return Icons.health_and_safety_rounded;
    if (isOpen(pharmacie)) return Icons.local_pharmacy_rounded;
    return Icons.lock_outline_rounded;
  }

  String openStatus(dynamic pharmacie) {
    if (isDuty(pharmacie)) return 'De garde';
    if (isOpen(pharmacie)) return 'Ouverte';
    return 'Fermée';
  }

  @override
  Widget build(BuildContext context) {
    final statut = pharmacie['statut']?.toString() ?? '';
    final message = textValue(pharmacie['message'], '');
    final prix = priceValue(pharmacie['prix_estime']);
    final distance = distanceValue(pharmacie['distance_km']);
    final disponibilite = disponibiliteLabel(pharmacie['disponibilite']);
    final phone = textValue(pharmacie['pharmacie_telephone'], '');
    final color = statusColor(pharmacie);
    final icon = statusIcon(pharmacie);
    final responseColor = responseStatusColor(statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: _WhiteCard(
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
                    textValue(pharmacie['pharmacie_nom'], 'Pharmacie'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                _SmallStatusChip(
                  label: statusLabel(statut),
                  color: responseColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(
              icon: Icons.access_time_outlined,
              text: openStatus(pharmacie),
            ),
            if (disponibilite.isNotEmpty)
              _InfoLine(
                icon: Icons.inventory_2_outlined,
                text: disponibilite,
              ),
            _InfoLine(
              icon: Icons.location_on_outlined,
              text: textValue(
                pharmacie['pharmacie_adresse'],
                'Adresse non disponible',
              ),
            ),
            if (phone.isNotEmpty)
              _InfoLine(
                icon: Icons.phone_outlined,
                text: phone,
              ),
            if (distance.isNotEmpty)
              _InfoLine(
                icon: Icons.near_me_outlined,
                text: 'Distance : $distance',
              ),
            if (prix.isNotEmpty)
              _InfoLine(
                icon: Icons.sell_outlined,
                text: 'Prix estimé : $prix',
              ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(
                        color: AppColors.primaryGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text(
                      'Appeler',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMaps,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(
                        color: AppColors.primaryGreen,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text(
                      'Localisation',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            if (canChoose) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isChoosing ? null : onChoose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Choisir cette pharmacie',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DemandePharmaciesMapSection extends StatelessWidget {
  final List<dynamic> pharmacies;
  final Map<String, dynamic> demande;
  final String Function(dynamic value, String fallback) textValue;
  final double? Function(dynamic value) doubleValue;
  final String Function(dynamic value) priceValue;
  final String Function(String statut) statusLabel;
  final Color Function(String statut) responseStatusColor;
  final String Function(dynamic value) disponibiliteLabel;

  const _DemandePharmaciesMapSection({
    required this.pharmacies,
    required this.demande,
    required this.textValue,
    required this.doubleValue,
    required this.priceValue,
    required this.statusLabel,
    required this.responseStatusColor,
    required this.disponibiliteLabel,
  });

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  bool isOpen(dynamic pharmacie) {
    return boolValue(pharmacie['est_ouverte']);
  }

  bool isDuty(dynamic pharmacie) {
    return boolValue(pharmacie['est_de_garde']);
  }

  Color getMarkerColor(dynamic pharmacie) {
    if (isDuty(pharmacie)) return Colors.orange;
    if (isOpen(pharmacie)) return AppColors.primaryGreen;
    return Colors.red;
  }

  IconData getMarkerIcon(dynamic pharmacie) {
    if (isDuty(pharmacie)) return Icons.health_and_safety_rounded;
    if (isOpen(pharmacie)) return Icons.local_pharmacy_rounded;
    return Icons.lock_outline_rounded;
  }

  String openStatus(dynamic pharmacie) {
    if (isDuty(pharmacie)) return 'De garde';
    if (isOpen(pharmacie)) return 'Ouverte';
    return 'Fermée';
  }

  List<dynamic> get pharmaciesWithLocation {
    return pharmacies.where((pharmacie) {
      final lat = doubleValue(pharmacie['pharmacie_latitude']);
      final lng = doubleValue(pharmacie['pharmacie_longitude']);

      return lat != null && lng != null;
    }).toList();
  }

  LatLng get center {
    if (pharmaciesWithLocation.isNotEmpty) {
      final first = pharmaciesWithLocation.first;

      return LatLng(
        doubleValue(first['pharmacie_latitude'])!,
        doubleValue(first['pharmacie_longitude'])!,
      );
    }

    final demandeLat = doubleValue(demande['latitude']);
    final demandeLng = doubleValue(demande['longitude']);

    if (demandeLat != null && demandeLng != null) {
      return LatLng(demandeLat, demandeLng);
    }

    return LatLng(36.75, 3.04);
  }

  String distanceText(dynamic pharmacie) {
    final distance = doubleValue(pharmacie['distance_km']);

    if (distance == null) {
      return '';
    }

    return '${distance.toStringAsFixed(1)} km';
  }

  void showPharmacySheet(BuildContext context, dynamic pharmacie) {
    final statut = pharmacie['statut']?.toString() ?? '';
    final prix = priceValue(pharmacie['prix_estime']);
    final disponibilite = disponibiliteLabel(pharmacie['disponibilite']);
    final message = textValue(pharmacie['message'], '');
    final distance = distanceText(pharmacie);
    final color = getMarkerColor(pharmacie);
    final icon = getMarkerIcon(pharmacie);
    final responseColor = responseStatusColor(statut);

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
              _WhiteCard(
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
                            textValue(pharmacie['pharmacie_nom'], 'Pharmacie'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          openStatus(pharmacie),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          statusLabel(statut),
                          style: TextStyle(
                            color: responseColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
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
                    if (distance.isNotEmpty)
                      _InfoLine(
                        icon: Icons.near_me_outlined,
                        text: 'Distance : $distance',
                      ),
                    if (disponibilite.isNotEmpty)
                      _InfoLine(
                        icon: Icons.inventory_2_outlined,
                        text: disponibilite,
                      ),
                    if (prix.isNotEmpty)
                      _InfoLine(
                        icon: Icons.sell_outlined,
                        text: 'Prix estimé : $prix',
                      ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        message,
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
    final pharmacyMarkers = pharmaciesWithLocation.map((pharmacie) {
      final lat = doubleValue(pharmacie['pharmacie_latitude'])!;
      final lng = doubleValue(pharmacie['pharmacie_longitude'])!;
      final color = getMarkerColor(pharmacie);
      final icon = getMarkerIcon(pharmacie);

      return Marker(
        point: LatLng(lat, lng),
        width: 58,
        height: 58,
        child: GestureDetector(
          onTap: () => showPharmacySheet(context, pharmacie),
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

    final demandeLat = doubleValue(demande['latitude']);
    final demandeLng = doubleValue(demande['longitude']);

    if (demandeLat != null && demandeLng != null) {
      final patientMarker = Marker(
        point: LatLng(demandeLat, demandeLng),
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

    return pharmacyMarkers;
  }

  @override
  Widget build(BuildContext context) {
    if (pharmaciesWithLocation.isEmpty) {
      return const _WhiteCard(
        child: Text(
          'Aucune pharmacie avec localisation.',
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

class _MyRequestSheet extends StatelessWidget {
  final Map<String, dynamic> demande;
  final List<dynamic> medicaments;
  final String ordonnanceImageUrl;
  final String Function(dynamic value, String fallback) textValue;

  const _MyRequestSheet({
    required this.demande,
    required this.medicaments,
    required this.ordonnanceImageUrl,
    required this.textValue,
  });

  @override
  Widget build(BuildContext context) {
    final type = demande['type']?.toString() ?? '';
    final message = textValue(demande['message_patient'], '');

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ma demande',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                _WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == 'ordonnance'
                            ? 'Demande par ordonnance'
                            : 'Demande médicaments',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rayon : ${demande['rayon_km']} km',
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          message,
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
                if (ordonnanceImageUrl.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ordonnance',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            ordonnanceImageUrl,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                height: 130,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.lightGreen,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Text(
                                  'Image ordonnance non disponible',
                                  style: TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (medicaments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _WhiteCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Médicaments',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...medicaments.map((med) {
                          final name = textValue(
                            med['medicament_nom'] ?? med['nom_libre'],
                            'Médicament',
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.lightGreen,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.medication_liquid_outlined,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  'x${med['quantite']}',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOption {
  final String value;
  final String label;

  const _FilterOption({
    required this.value,
    required this.label,
  });
}

class _FilterSheet extends StatelessWidget {
  final String title;
  final List<_FilterOption> options;
  final String selectedValue;

  const _FilterSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = option.value == selectedValue;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(option.value),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool outlined;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = active ? AppColors.primaryGreen : AppColors.lightGreen;
    final foreground = active ? Colors.white : AppColors.primaryGreen;

    return Material(
      color: outlined ? Colors.white : background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: outlined
                ? Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.55),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: foreground,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              if (!outlined) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: foreground,
                  size: 18,
                ),
              ],
            ],
          ),
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
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallStatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
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

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}
