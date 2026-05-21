import 'package:flutter/material.dart';

import 'features/home/home_page.dart';
import 'features/products/products_page.dart';
import 'features/pharmacies/pharmacies_page.dart';
import 'features/requests/requests_page.dart';
import 'features/profile/profile_page.dart';
import 'features/notifications/notification_watcher.dart';
import 'data/services/firebase_push_service.dart';

class AppShell extends StatefulWidget {
  static const routeName = '/app';

  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 2; // Accueil au milieu par défaut
  int _requestsRefreshCounter = 0;

  @override
  void initState() {
    super.initState();
    initFirebasePush();
  }

  Future<void> initFirebasePush() async {
    try {
      await FirebasePushService().init();
    } catch (e) {
      debugPrint('Firebase push init error: $e');
    }
  }

  void selectTab(int index) {
    setState(() {
      _index = index;

      // Recharge l’onglet Demandes à chaque ouverture
      if (index == 0) {
        _requestsRefreshCounter++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RequestsPage(
        key: ValueKey('requests_$_requestsRefreshCounter'),
      ),
      const ProductsPage(),
      HomePage(onSelectTab: selectTab),
      const PharmaciesPage(),
      const ProfilePage(),
    ];

    return NotificationWatcher(
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'Demandes',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag_rounded),
              label: 'Produits',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on_rounded),
              label: 'Pharmacies',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
