import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/commande_service.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final CommandeService commandeService = CommandeService();

  bool isLoading = true;
  String? error;
  List<dynamic> commandes = [];

  @override
  void initState() {
    super.initState();
    loadCommandes();
  }

  Future<void> loadCommandes() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final data = await commandeService.getPatientCommandes();

      if (!mounted) return;

      setState(() {
        commandes = data;
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

  String priceValue(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '');
    if (price == null) return '0.00 DA';
    return '${price.toStringAsFixed(2)} DA';
  }

  Color statusColor(String statut) {
    switch (statut) {
      case 'acceptee':
        return AppColors.primaryGreen;
      case 'refusee':
      case 'annulee':
        return Colors.red;
      case 'terminee':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String statusLabel(String statut) {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'acceptee':
        return 'Acceptée';
      case 'refusee':
        return 'Refusée';
      case 'terminee':
        return 'Terminée';
      case 'annulee':
        return 'Annulée';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mes commandes',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadCommandes,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        const SizedBox(height: 120),
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
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
                    )
                  : commandes.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(22),
                          children: const [
                            SizedBox(height: 120),
                            Icon(
                              Icons.receipt_long_outlined,
                              color: AppColors.primaryGreen,
                              size: 56,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Aucune commande',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Vos commandes validées apparaîtront ici.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                          children: commandes.map((commande) {
                            final statut = commande['statut']?.toString() ?? 'en_attente';
                            final color = statusColor(statut);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
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
                                          Icons.receipt_long_rounded,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Commande #${commande['commande_id']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              commande['pharmacie_nom']?.toString() ?? 'Pharmacie',
                                              style: const TextStyle(
                                                color: AppColors.textGrey,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                        child: Text(
                                          statusLabel(statut),
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Total',
                                          style: TextStyle(
                                            color: AppColors.textGrey,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        priceValue(commande['total']),
                                        style: const TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (commande['cree_le'] != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      commande['cree_le'].toString(),
                                      style: const TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
        ),
      ),
    );
  }
}