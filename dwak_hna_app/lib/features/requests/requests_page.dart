import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/demande_service.dart';
import 'demande_details_page.dart';
import '../medicines/add_medicines_page.dart';
import '../prescriptions/prescription_scan_page.dart';
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final DemandeService demandeService = DemandeService();

  bool isLoading = true;
  bool isSilentRefreshing = false;
  String? error;

  List<dynamic> demandes = [];

  Timer? demandesRefreshTimer;
  DateTime? lastRefreshTime;
void openCreatePage(Widget page) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => page),
  );

  refreshDemandesSilently();
}
  @override
  void initState() {
    super.initState();

    loadDemandes();

    demandesRefreshTimer = Timer.periodic(
     const Duration(seconds: 2),
     (_) => refreshDemandesSilently(),
    );
  }

  @override
  void dispose() {
    demandesRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadDemandes() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final data = await demandeService.getPatientDemandes();

      if (!mounted) return;

      setState(() {
        demandes = data;
        isLoading = false;
        lastRefreshTime = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

Future<void> refreshDemandesSilently() async {
  if (isSilentRefreshing || isLoading) return;

  try {
    isSilentRefreshing = true;

    final data = await demandeService.getPatientDemandes();

    if (!mounted) return;

    setState(() {
      // Important :
      // si le backend retourne vide par erreur, on ne supprime pas l’ancienne liste.
      if (data.isNotEmpty || demandes.isEmpty) {
        demandes = data;
      }

      error = null;
      lastRefreshTime = DateTime.now();
    });
  } catch (e) {
    // On ignore l'erreur pendant le refresh automatique
    // pour ne pas bloquer l'écran Demandes.
  } finally {
    isSilentRefreshing = false;
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

    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }

  String typeLabel(dynamic type) {
    final value = textValue(type, '');

    switch (value) {
      case 'manuelle':
        return 'Demande manuelle';
      case 'ordonnance':
        return 'Ordonnance';
      default:
        return 'Demande';
    }
  }

  String etatLabel(dynamic etat) {
    final value = textValue(etat, '');

    switch (value) {
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
        return 'En attente';
    }
  }

  Color etatColor(dynamic etat) {
    final value = textValue(etat, '');

    switch (value) {
      case 'en_attente':
        return Colors.orange;
      case 'reponse_recue':
        return AppColors.primaryGreen;
      case 'pharmacie_choisie':
        return Colors.blue;
      case 'termine':
        return AppColors.primaryGreen;
      case 'annule':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData etatIcon(dynamic etat) {
    final value = textValue(etat, '');

    switch (value) {
      case 'en_attente':
        return Icons.hourglass_empty_rounded;
      case 'reponse_recue':
        return Icons.mark_email_read_outlined;
      case 'pharmacie_choisie':
        return Icons.local_pharmacy_outlined;
      case 'termine':
        return Icons.check_circle_outline_rounded;
      case 'annule':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  int stepIndex(dynamic etat) {
    final value = textValue(etat, '');

    switch (value) {
      case 'en_attente':
        return 0;
      case 'reponse_recue':
        return 1;
      case 'pharmacie_choisie':
        return 2;
      case 'termine':
        return 3;
      case 'annule':
        return -1;
      default:
        return 0;
    }
  }

  String dateLabel(dynamic value) {
    final text = textValue(value, '');

    if (text.isEmpty) {
      return '';
    }

    return text;
  }

  void openDemandeDetails(dynamic demande) async {
    final demandeId = intValue(demande['demande_id']);

    if (demandeId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande invalide'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DemandeDetailsPage(
          demandeId: demandeId,
        ),
      ),
    );

    refreshDemandesSilently();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadDemandes,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mes demandes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Suivez les réponses des pharmacies',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isSilentRefreshing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),

            if (lastRefreshTime != null) ...[
              const SizedBox(height: 6),
              Text(
                'Mise à jour automatique active',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 18),
             Row(
               children: [
                 Expanded(
                   child: _CreateRequestButton(
                     icon: Icons.edit_note_rounded,
                     title: 'Saisie manuelle',
                     subtitle: 'Ajouter médicaments',
                     onTap: () => openCreatePage(const AddMedicinesPage()),
                   ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: _CreateRequestButton(
                     icon: Icons.document_scanner_outlined,
                     title: 'Scanner ordonnance',
                     subtitle: 'Photo ordonnance',
                     onTap: () => openCreatePage(const PrescriptionScanPage()),
                   ),
                 ),
               ],
             ),

             const SizedBox(height: 18),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 90),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              _InfoCard(
                icon: Icons.error_outline,
                title: 'Erreur',
                message: error!,
                color: Colors.red,
                actionText: 'Réessayer',
                onAction: loadDemandes,
              )
            else if (demandes.isEmpty)
              const _InfoCard(
                icon: Icons.assignment_outlined,
                title: 'Aucune demande',
                message:
                    'Vos demandes de médicaments et ordonnances apparaîtront ici.',
                color: AppColors.primaryGreen,
              )
            else
              ...demandes.map(
                (demande) => _DemandeCard(
                  demande: demande,
                  typeLabel: typeLabel(demande['type']),
                  etatLabel: etatLabel(demande['etat']),
                  etatColor: etatColor(demande['etat']),
                  etatIcon: etatIcon(demande['etat']),
                  stepIndex: stepIndex(demande['etat']),
                  dateLabel: dateLabel(demande['cree_le']),
                  pharmacieChoisie: textValue(
                    demande['pharmacie_choisie'],
                    '',
                  ),
                  message: textValue(
                    demande['message_patient'],
                    '',
                  ),
                  rayonKm: textValue(
                    demande['rayon_km'],
                    '5',
                  ),
                  onTap: () => openDemandeDetails(demande),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
class _CreateRequestButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateRequestButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _DemandeCard extends StatelessWidget {
  final dynamic demande;
  final String typeLabel;
  final String etatLabel;
  final Color etatColor;
  final IconData etatIcon;
  final int stepIndex;
  final String dateLabel;
  final String pharmacieChoisie;
  final String message;
  final String rayonKm;
  final VoidCallback onTap;

  const _DemandeCard({
    required this.demande,
    required this.typeLabel,
    required this.etatLabel,
    required this.etatColor,
    required this.etatIcon,
    required this.stepIndex,
    required this.dateLabel,
    required this.pharmacieChoisie,
    required this.message,
    required this.rayonKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = stepIndex == -1;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: etatColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        etatIcon,
                        color: etatColor,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: etatColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        etatLabel,
                        style: TextStyle(
                          color: etatColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (!isCancelled)
                  _StepsLine(
                    activeStep: stepIndex,
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Cette demande a été annulée.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                if (message.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),

                if (message.isNotEmpty)
                  const SizedBox(height: 12),

                Row(
                  children: [
                    _SmallInfo(
                      icon: Icons.radar_rounded,
                      label: '$rayonKm km',
                    ),
                    const SizedBox(width: 8),
                    if (pharmacieChoisie.isNotEmpty)
                      Expanded(
                        child: _SmallInfo(
                          icon: Icons.local_pharmacy_outlined,
                          label: pharmacieChoisie,
                        ),
                      )
                    else
                      const Expanded(
                        child: _SmallInfo(
                          icon: Icons.local_pharmacy_outlined,
                          label: 'Aucune pharmacie choisie',
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Voir les détails',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.primaryGreen,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepsLine extends StatelessWidget {
  final int activeStep;

  const _StepsLine({
    required this.activeStep,
  });

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Envoyée',
      'Réponse',
      'Choisie',
      'Terminée',
    ];

    return Column(
      children: [
        Row(
          children: List.generate(labels.length, (index) {
            final isDone = index <= activeStep;

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.primaryGreen
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDone
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      color: isDone ? Colors.white : Colors.grey.shade600,
                      size: 15,
                    ),
                  ),
                  if (index < labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: index < activeStep
                            ? AppColors.primaryGreen
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 7),
        Row(
          children: List.generate(labels.length, (index) {
            final isDone = index <= activeStep;

            return Expanded(
              child: Text(
                labels[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: index == 0
                    ? TextAlign.left
                    : index == labels.length - 1
                        ? TextAlign.right
                        : TextAlign.center,
                style: TextStyle(
                  color: isDone ? AppColors.primaryGreen : AppColors.textGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SmallInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallInfo({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 36,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.primaryGreen,
            size: 17,
          ),
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final String? actionText;
  final VoidCallback? onAction;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textGrey,
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(
                actionText!,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
