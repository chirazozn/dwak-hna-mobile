import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/panier_service.dart';
import '../../data/services/produit_service.dart';
import '../cart/cart_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ProduitService produitService = ProduitService();
  final PanierService panierService = PanierService();
  final TextEditingController searchController = TextEditingController();

  Timer? searchDebounce;

  bool isLoading = true;
  String? error;
  List<dynamic> produits = [];

  String selectedDistance = 'all';
  String selectedPrice = 'all';
  String selectedSort = 'default';

  final Set<String> selectedCategories = {};

  @override
  void initState() {
    super.initState();
    loadProduits();

    searchController.addListener(() {
      searchDebounce?.cancel();
      searchDebounce = Timer(
        const Duration(milliseconds: 450),
        loadProduits,
      );
    });
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadProduits() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final data = await produitService.getProduits(
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

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  String priceValue(dynamic value) {
    final price = doubleValue(value);

    if (price == null) {
      return 'Prix non défini';
    }

    return '${price.toStringAsFixed(2)} DA';
  }

  bool isAvailable(dynamic produit) {
    return boolValue(produit['est_disponible']);
  }

  bool isOpen(dynamic produit) {
    return boolValue(produit['est_ouverte']);
  }

  bool isDuty(dynamic produit) {
    return boolValue(produit['est_de_garde']);
  }

  String categoryValue(dynamic produit) {
    return textValue(
      produit['categories'] ?? produit['type_produit'],
      'Catégorie non définie',
    );
  }

  double? distanceValue(dynamic produit) {
    return doubleValue(produit['distance_km']);
  }

  List<String> categoriesOfProduct(dynamic produit) {
    final raw = categoryValue(produit);

    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && item != 'Catégorie non définie')
        .toList();
  }

  List<String> get categoryOptions {
    final categories = <String>{};

    for (final produit in produits) {
      for (final category in categoriesOfProduct(produit)) {
        categories.add(category);
      }
    }

    final list = categories.toList()..sort();

    return list;
  }

  bool productMatchesSelectedCategories(dynamic produit) {
    if (selectedCategories.isEmpty) {
      return true;
    }

    final productCategories = categoriesOfProduct(produit)
        .map((category) => category.toLowerCase())
        .toList();

    for (final selected in selectedCategories) {
      final selectedLower = selected.toLowerCase();

      final exists = productCategories.any(
        (category) =>
            category == selectedLower || category.contains(selectedLower),
      );

      if (exists) {
        return true;
      }
    }

    return false;
  }

  List<dynamic> get filteredProduits {
    final result = produits.where((produit) {
      final price = doubleValue(produit['prix']) ?? 0;
      final distance = distanceValue(produit);

      if (selectedPrice == 'under_1000' && price >= 1000) {
        return false;
      }

      if (selectedPrice == '1000_2000' && (price < 1000 || price > 2000)) {
        return false;
      }

      if (selectedPrice == 'over_2000' && price <= 2000) {
        return false;
      }

      if (!productMatchesSelectedCategories(produit)) {
        return false;
      }

      if (selectedDistance != 'all' && distance != null) {
        final maxDistance = double.tryParse(selectedDistance);

        if (maxDistance != null && distance > maxDistance) {
          return false;
        }
      }

      return true;
    }).toList();

    if (selectedSort == 'price_asc') {
      result.sort((a, b) {
        final priceA = doubleValue(a['prix']) ?? 999999999;
        final priceB = doubleValue(b['prix']) ?? 999999999;

        return priceA.compareTo(priceB);
      });
    } else if (selectedSort == 'price_desc') {
      result.sort((a, b) {
        final priceA = doubleValue(a['prix']) ?? 0;
        final priceB = doubleValue(b['prix']) ?? 0;

        return priceB.compareTo(priceA);
      });
    } else if (selectedSort == 'name') {
      result.sort((a, b) {
        final nameA = textValue(a['produit_nom'], '');
        final nameB = textValue(b['produit_nom'], '');

        return nameA.compareTo(nameB);
      });
    } else if (selectedSort == 'distance') {
      result.sort((a, b) {
        final distanceA = distanceValue(a) ?? 999999;
        final distanceB = distanceValue(b) ?? 999999;

        return distanceA.compareTo(distanceB);
      });
    }

    return result;
  }

  String distanceLabel() {
    switch (selectedDistance) {
      case '2':
        return '≤ 2 km';
      case '5':
        return '≤ 5 km';
      case '10':
        return '≤ 10 km';
      default:
        return 'Distance';
    }
  }

  String priceLabel() {
    switch (selectedPrice) {
      case 'under_1000':
        return '< 1000 DA';
      case '1000_2000':
        return '1000-2000 DA';
      case 'over_2000':
        return '> 2000 DA';
      default:
        return 'Prix';
    }
  }

  String categoryLabel() {
    if (selectedCategories.isEmpty) {
      return 'Catégorie';
    }

    if (selectedCategories.length == 1) {
      return selectedCategories.first;
    }

    return '${selectedCategories.length} catégories';
  }

  String sortLabel() {
    switch (selectedSort) {
      case 'price_asc':
        return 'Prix ↑';
      case 'price_desc':
        return 'Prix ↓';
      case 'name':
        return 'Nom A-Z';
      case 'distance':
        return 'Distance';
      default:
        return 'Trier';
    }
  }

  void clearFilters() {
    setState(() {
      selectedDistance = 'all';
      selectedPrice = 'all';
      selectedSort = 'default';
      selectedCategories.clear();
    });
  }

  Future<void> addToCart(dynamic produit) async {
    final name = textValue(produit['produit_nom'], 'Produit');
    final pharmacieProduitId = produit['pharmacie_produit_id'];

    if (pharmacieProduitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produit invalide'),
        ),
      );
      return;
    }

    try {
      await panierService.addItem(
        pharmacieProduitId: int.parse(pharmacieProduitId.toString()),
        quantite: 1,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name ajouté au panier'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void openProductDetails(dynamic produit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          produit: produit,
          onAddToCart: () {
            addToCart(produit);
          },
        ),
      ),
    );
  }

  Future<void> openDistanceFilter() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FilterSheet(
          title: 'Filtrer par distance',
          options: const [
            _FilterOption(value: 'all', label: 'Toutes les distances'),
            _FilterOption(value: '2', label: 'Moins de 2 km'),
            _FilterOption(value: '5', label: 'Moins de 5 km'),
            _FilterOption(value: '10', label: 'Moins de 10 km'),
          ],
          selectedValue: selectedDistance,
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedDistance = value;
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
          options: const [
            _FilterOption(value: 'all', label: 'Tous les prix'),
            _FilterOption(value: 'under_1000', label: 'Moins de 1000 DA'),
            _FilterOption(value: '1000_2000', label: '1000 - 2000 DA'),
            _FilterOption(value: 'over_2000', label: 'Plus de 2000 DA'),
          ],
          selectedValue: selectedPrice,
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedPrice = value;
      });
    }
  }

  Future<void> openCategoryFilter() async {
    final value = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _CategoryFilterSheet(
          categories: categoryOptions,
          selectedCategories: selectedCategories,
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedCategories
          ..clear()
          ..addAll(value);
      });
    }
  }

  Future<void> openSortFilter() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FilterSheet(
          title: 'Trier les produits',
          options: const [
            _FilterOption(value: 'default', label: 'Par défaut'),
            _FilterOption(value: 'price_asc', label: 'Prix croissant'),
            _FilterOption(value: 'price_desc', label: 'Prix décroissant'),
            _FilterOption(value: 'name', label: 'Nom A-Z'),
            _FilterOption(value: 'distance', label: 'Distance'),
          ],
          selectedValue: selectedSort,
        );
      },
    );

    if (value != null) {
      setState(() {
        selectedSort = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleProducts = filteredProduits;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadProduits,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeLikeHeader(
                      onCartTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CartPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher des produits',
                        prefixIcon: const Icon(Icons.search),
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

                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _FilterChipButton(
                          icon: Icons.location_on_outlined,
                          label: distanceLabel(),
                          active: selectedDistance != 'all',
                          onTap: openDistanceFilter,
                        ),
                        _FilterChipButton(
                          icon: Icons.sell_outlined,
                          label: priceLabel(),
                          active: selectedPrice != 'all',
                          onTap: openPriceFilter,
                        ),
                        _FilterChipButton(
                          icon: Icons.grid_view_rounded,
                          label: categoryLabel(),
                          active: selectedCategories.isNotEmpty,
                          onTap: openCategoryFilter,
                        ),
                        _FilterChipButton(
                          icon: Icons.swap_vert_rounded,
                          label: sortLabel(),
                          active: selectedSort != 'default',
                          onTap: openSortFilter,
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

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Produits recommandés',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${visibleProducts.length} produit(s)',
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            if (isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: _InfoCard(
                    icon: Icons.error_outline,
                    title: 'Erreur',
                    message: error!,
                    color: Colors.red,
                  ),
                ),
              )
            else if (visibleProducts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: _InfoCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Aucun produit trouvé',
                    message:
                        'Aucun produit ne correspond à votre recherche ou vos filtres.',
                    color: AppColors.primaryGreen,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final produit = visibleProducts[index];

                      final name = textValue(
                        produit['produit_nom'],
                        'Produit',
                      );

                      final price = priceValue(produit['prix']);

                      final imageUrl = textValue(
                        produit['image_url'],
                        '',
                      );

                      final pharmacyName = textValue(
                        produit['pharmacie_nom'],
                        'Pharmacie',
                      );

                      return _ProductGridCard(
                        name: name,
                        pharmacyName: pharmacyName,
                        price: price,
                        imageUrl: imageUrl,
                        isAvailable: isAvailable(produit),
                        onTap: () => openProductDetails(produit),
                        onAddToCart: () => addToCart(produit),
                      );
                    },
                    childCount: visibleProducts.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.69,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeLikeHeader extends StatelessWidget {
  final VoidCallback onCartTap;

  const _HomeLikeHeader({
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.local_pharmacy_rounded,
            color: AppColors.primaryGreen,
            size: 28,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dwak Hna',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryGreen,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Produits santé disponibles',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        IconButton.filled(
          onPressed: onCartTap,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.lightGreen,
            foregroundColor: AppColors.primaryGreen,
          ),
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
      ],
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 115),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
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

class _ProductGridCard extends StatelessWidget {
  final String name;
  final String pharmacyName;
  final String price;
  final String imageUrl;
  final bool isAvailable;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductGridCard({
    required this.name,
    required this.pharmacyName,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
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
                child: Stack(
                  children: [
                    Center(
                      child: _ProductImage(
                        imageUrl: imageUrl,
                        size: 105,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Icon(
                          Icons.favorite_border_rounded,
                          color: AppColors.primaryGreen,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
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

              const SizedBox(height: 6),

              Text(
                pharmacyName,
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
                      onPressed: isAvailable ? onAddToCart : null,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
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

class ProductDetailsPage extends StatelessWidget {
  final dynamic produit;
  final VoidCallback onAddToCart;

  const ProductDetailsPage({
    super.key,
    required this.produit,
    required this.onAddToCart,
  });

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

  bool boolValue(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  @override
  Widget build(BuildContext context) {
    final name = textValue(produit['produit_nom'], 'Produit');

    final category = textValue(
      produit['categories'] ?? produit['type_produit'],
      'Catégorie non définie',
    );

    final description = textValue(
      produit['description_perso'] ?? produit['produit_description'],
      'Aucune description disponible.',
    );

    final price = priceValue(produit['prix']);

    final imageUrl = textValue(produit['image_url'], '');

    final pharmacyName = textValue(
      produit['pharmacie_nom'],
      'Pharmacie',
    );

    final pharmacyAddress = textValue(
      produit['pharmacie_adresse'],
      'Adresse non disponible',
    );

    final pharmacyPhone = textValue(
      produit['pharmacie_telephone'],
      'Téléphone non disponible',
    );

    final isAvailable = boolValue(produit['est_disponible']);
    final isOpen = boolValue(produit['est_ouverte']);
    final isDuty = boolValue(produit['est_de_garde']);

    final pharmacyStatus = isDuty
        ? 'Pharmacie de garde'
        : isOpen
            ? 'Pharmacie ouverte'
            : 'Pharmacie fermée';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Détails produit',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
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
                          size: 140,
                        ),

                        const SizedBox(height: 18),

                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          category,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontWeight: FontWeight.w600,
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

                        const SizedBox(height: 12),

                        _StatusChip(
                          label: isAvailable ? 'Disponible' : 'Indisponible',
                          icon: isAvailable
                              ? Icons.check_circle_outline_rounded
                              : Icons.cancel_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Description',
                    icon: Icons.description_outlined,
                    child: Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  _SectionCard(
                    title: 'Pharmacie',
                    icon: Icons.local_pharmacy_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pharmacyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 10),

                        _DetailLine(
                          icon: Icons.location_on_outlined,
                          text: pharmacyAddress,
                        ),

                        const SizedBox(height: 8),

                        _DetailLine(
                          icon: Icons.phone_outlined,
                          text: pharmacyPhone,
                        ),

                        const SizedBox(height: 12),

                        _StatusChip(
                          label: pharmacyStatus,
                          icon: Icons.access_time_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isAvailable ? onAddToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
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
            ),
          ],
        ),
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
        errorBuilder: (context, error, stackTrace) {
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
      height: MediaQuery.of(context).size.height * 0.58,
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
                final isSelected = option.value == selectedValue;

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
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : AppColors.lightGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_rounded
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primaryGreen,
                                size: 18,
                              ),
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

class _CategoryFilterSheet extends StatefulWidget {
  final List<String> categories;
  final Set<String> selectedCategories;

  const _CategoryFilterSheet({
    required this.categories,
    required this.selectedCategories,
  });

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  late Set<String> tempSelected;

  @override
  void initState() {
    super.initState();
    tempSelected = {...widget.selectedCategories};
  }

  void toggleCategory(String category) {
    setState(() {
      if (tempSelected.contains(category)) {
        tempSelected.remove(category);
      } else {
        tempSelected.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
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
                  'Choisir les catégories',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    tempSelected.clear();
                  });
                },
                child: const Text('Tout effacer'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (widget.categories.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Aucune catégorie disponible.',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final category = widget.categories[index];
                  final isSelected = tempSelected.contains(category);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => toggleCategory(category),
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : AppColors.lightGreen,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primaryGreen,
                                  size: 20,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  category,
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

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(tempSelected);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                tempSelected.isEmpty
                    ? 'Afficher toutes les catégories'
                    : 'Appliquer (${tempSelected.length})',
                style: const TextStyle(
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.primaryGreen,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
