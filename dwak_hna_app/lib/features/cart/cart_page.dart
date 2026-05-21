import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/panier_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final PanierService panierService = PanierService();
  final TextEditingController messageController = TextEditingController();

  bool isLoading = true;
  bool isUpdating = false;
  bool isValidating = false;
  String? error;

  Map<String, dynamic>? panierData;

  @override
  void initState() {
    super.initState();
    loadPanier();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  List<dynamic> get lignes {
    final data = panierData;

    if (data == null) {
      return [];
    }

    return data['lignes'] ?? [];
  }

  Map<String, dynamic>? get panier {
    final data = panierData;

    if (data == null) {
      return null;
    }

    final panier = data['panier'];

    if (panier == null) {
      return null;
    }

    return Map<String, dynamic>.from(panier);
  }

  Future<void> loadPanier() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final data = await panierService.getPanier();

      if (!mounted) return;

      setState(() {
        panierData = data;
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
    if (value == null) {
      return '0.00 DA';
    }

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      return '${value.toString()} DA';
    }

    return '${parsed.toStringAsFixed(2)} DA';
  }

  int intValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;

    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> updateQuantity(dynamic ligne, int quantity) async {
    final ligneId = intValue(ligne['panier_ligne_id']);

    if (ligneId == 0) return;

    try {
      setState(() {
        isUpdating = true;
      });

      final data = await panierService.updateQuantity(
        ligneId: ligneId,
        quantite: quantity,
      );

      if (!mounted) return;

      setState(() {
        panierData = data;
      });
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
          isUpdating = false;
        });
      }
    }
  }

  Future<void> removeItem(dynamic ligne) async {
    final ligneId = intValue(ligne['panier_ligne_id']);

    if (ligneId == 0) return;

    try {
      setState(() {
        isUpdating = true;
      });

      final data = await panierService.removeItem(
        ligneId: ligneId,
      );

      if (!mounted) return;

      setState(() {
        panierData = data;
      });
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
          isUpdating = false;
        });
      }
    }
  }

  Future<void> validateCart() async {
    if (lignes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre panier est vide'),
        ),
      );
      return;
    }

    try {
      setState(() {
        isValidating = true;
      });

      await panierService.validerPanier(
        messagePatient: messageController.text.trim().isEmpty
            ? null
            : messageController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande envoyée à la pharmacie'),
        ),
      );

      Navigator.of(context).pop();
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
          isValidating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPanier = panier;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mon panier',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : error != null
                ? RefreshIndicator(
                    onRefresh: loadPanier,
                    child: ListView(
                      padding: const EdgeInsets.all(22),
                      children: [
                        const SizedBox(height: 120),
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
                : currentPanier == null || lignes.isEmpty
                    ? RefreshIndicator(
                        onRefresh: loadPanier,
                        child: ListView(
                          padding: const EdgeInsets.all(22),
                          children: const [
                            SizedBox(height: 120),
                            Icon(
                              Icons.shopping_cart_outlined,
                              color: AppColors.primaryGreen,
                              size: 56,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Votre panier est vide',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Ajoutez des produits depuis la page Produits.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: loadPanier,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  12,
                                  18,
                                  24,
                                ),
                                children: [
                                  _PharmacyCard(
                                    name: currentPanier['pharmacie_nom']
                                            ?.toString() ??
                                        'Pharmacie',
                                    address: currentPanier['pharmacie_adresse']
                                            ?.toString() ??
                                        '',
                                    phone: currentPanier['pharmacie_telephone']
                                            ?.toString() ??
                                        '',
                                  ),

                                  const SizedBox(height: 16),

                                  const Text(
                                    'Produits',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  ...lignes.map(
                                    (ligne) {
                                      final quantity =
                                          intValue(ligne['quantite']);

                                      return _CartLineCard(
                                        name: ligne[
                                                    'nom_produit_snapshot']
                                                ?.toString() ??
                                            ligne['produit_nom']?.toString() ??
                                            'Produit',
                                        price: priceValue(
                                          ligne['prix_unitaire'],
                                        ),
                                        totalLine: priceValue(
                                          ligne['total_ligne'],
                                        ),
                                        quantity: quantity,
                                        isUpdating: isUpdating,
                                        onMinus: () {
                                          updateQuantity(
                                            ligne,
                                            quantity - 1,
                                          );
                                        },
                                        onPlus: () {
                                          updateQuantity(
                                            ligne,
                                            quantity + 1,
                                          );
                                        },
                                        onRemove: () => removeItem(ligne),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  TextField(
                                    controller: messageController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: 'Message à la pharmacie',
                                      hintText:
                                          'Ex: Je passerai récupérer la commande aujourd’hui...',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.fromLTRB(
                              18,
                              12,
                              18,
                              18,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 12,
                                  offset: Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      priceValue(currentPanier['total']),
                                      style: const TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        isValidating ? null : validateCart,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: isValidating
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                                CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.4,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                    label: Text(
                                      isValidating
                                          ? 'Validation...'
                                          : 'Valider la commande',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
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

class _PharmacyCard extends StatelessWidget {
  final String name;
  final String address;
  final String phone;

  const _PharmacyCard({
    required this.name,
    required this.address,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_pharmacy_outlined,
              color: AppColors.primaryGreen,
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
                if (address.isNotEmpty)
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  final String name;
  final String price;
  final String totalLine;
  final int quantity;
  final bool isUpdating;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  const _CartLineCard({
    required this.name,
    required this.price,
    required this.totalLine,
    required this.quantity,
    required this.isUpdating,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.primaryGreen,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$price / unité',
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalLine,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: isUpdating ? null : onMinus,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    quantity.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: isUpdating ? null : onPlus,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              TextButton(
                onPressed: isUpdating ? null : onRemove,
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
