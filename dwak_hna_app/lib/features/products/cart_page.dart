import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/services/cart_store.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CartStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            if (store.items.isEmpty) {
              return const EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Panier vide',
                subtitle: 'Ajoutez des produits parapharmacie ou cosmétique.',
              );
            }

            final pharmacies = {for (final item in store.items) item.product.pharmacyName}.toList();

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: pharmacies.map((pharmacy) {
                      final items = store.items.where((item) => item.product.pharmacyName == pharmacy).toList();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_pharmacy_rounded, color: AppColors.primaryGreen),
                                const SizedBox(width: 8),
                                Text(pharmacy, style: const TextStyle(fontWeight: FontWeight.w900)),
                              ],
                            ),
                            const Divider(height: 22),
                            ...items.map((item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${item.product.price.toStringAsFixed(0)} DA • Qté ${item.quantity}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(onPressed: () => store.decrement(item.product), icon: const Icon(Icons.remove_circle_outline)),
                                      IconButton(onPressed: () => store.add(item.product), icon: const Icon(Icons.add_circle_outline)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Total estimé', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                          Text('${store.total.toStringAsFixed(0)} DA', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.darkGreen)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Commande envoyée'),
                              content: const Text('Votre panier a été envoyé aux pharmacies concernées. Vous recevrez une notification sonore quand une pharmacie répond.'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    store.clear();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Envoyer aux pharmacies'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
