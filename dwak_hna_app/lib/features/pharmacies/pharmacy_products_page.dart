import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/produit_service.dart';

class PharmacyProductsPage extends StatefulWidget {
  final int pharmacieId;
  final String pharmacieName;

  const PharmacyProductsPage({
    super.key,
    required this.pharmacieId,
    required this.pharmacieName,
  });

  @override
  State<PharmacyProductsPage> createState() => _PharmacyProductsPageState();
}

class _PharmacyProductsPageState extends State<PharmacyProductsPage> {
  final ProduitService produitService = ProduitService();
  final TextEditingController searchController = TextEditingController();

  Timer? debounce;

  bool isLoading = true;
  String? error;
  List<dynamic> produits = [];

  @override
  void initState() {
    super.initState();
    loadProduits();

    searchController.addListener(() {
      debounce?.cancel();
      debounce = Timer(
        const Duration(milliseconds: 450),
        loadProduits,
      );
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadProduits() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final data = await produitService.getProduitsByPharmacie(
        pharmacieId: widget.pharmacieId,
        search: searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        produits = data;
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

  String priceValue(dynamic value) {
    final price = doubleValue(value);

    if (price == null) {
      return 'Prix non défini';
    }

    return '${price.toStringAsFixed(2)} DA';
  }

  void addToCart(dynamic produit) {
    final name = textValue(produit['produit_nom'], 'Produit');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name ajouté au panier'),
      ),
    );
  }

  void openProductDetails(dynamic produit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _ProductDetailsSheet(
          produit: produit,
          textValue: textValue,
          priceValue: priceValue,
          onAddToCart: () {
            Navigator.of(context).pop();
            addToCart(produit);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Produits pharmacie',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadProduits,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Text(
                widget.pharmacieName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Produits disponibles dans cette pharmacie',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            searchController.clear();
                            loadProduits();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
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
                )
              else if (produits.isEmpty)
                const _InfoCard(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Aucun produit',
                  message: 'Cette pharmacie n’a pas encore de produits disponibles.',
                  color: AppColors.primaryGreen,
                )
              else
                GridView.builder(
                  itemCount: produits.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.68,
                  ),
                  itemBuilder: (context, index) {
                    final produit = produits[index];

                    return _ProductCard(
                      name: textValue(produit['produit_nom'], 'Produit'),
                      category: textValue(
                        produit['categories'] ?? produit['type_produit'],
                        'Catégorie non définie',
                      ),
                      price: priceValue(produit['prix']),
                      imageUrl: textValue(
                        produit['image_url_resolved'] ?? produit['image_url'],
                        '',
                      ),
                      onTap: () => openProductDetails(produit),
                      onAddToCart: () => addToCart(produit),
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

class _ProductCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: _ProductImage(
                    imageUrl: imageUrl,
                    size: 105,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: IconButton.filled(
                      onPressed: onAddToCart,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductDetailsSheet extends StatelessWidget {
  final dynamic produit;
  final String Function(dynamic value, String fallback) textValue;
  final String Function(dynamic value) priceValue;
  final VoidCallback onAddToCart;

  const _ProductDetailsSheet({
    required this.produit,
    required this.textValue,
    required this.priceValue,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final name = textValue(produit['produit_nom'], 'Produit');
    final description = textValue(
      produit['description_perso'] ?? produit['produit_description'],
      'Aucune description disponible.',
    );
    final category = textValue(
      produit['categories'] ?? produit['type_produit'],
      'Catégorie non définie',
    );
    final price = priceValue(produit['prix']);
    final imageUrl = textValue(
      produit['image_url_resolved'] ?? produit['image_url'],
      '',
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.76,
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

          Expanded(
            child: ListView(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      _ProductImage(
                        imageUrl: imageUrl,
                        size: 145,
                      ),

                      const SizedBox(height: 18),

                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        category,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        price,
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: onAddToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text(
                'Ajouter au panier',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _ProductImage({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _ImagePlaceholder(size: size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return _ImagePlaceholder(size: size);
        },
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final double size;

  const _ImagePlaceholder({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.shopping_bag_outlined,
        color: AppColors.primaryGreen,
        size: size * 0.42,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
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
        ],
      ),
    );
  }
}
