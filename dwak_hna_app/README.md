# Dwak Hna - Application Mobile Patient Flutter

Ce ZIP contient une base complète et organisée de l'application mobile **Dwak Hna** : authentification, accueil, scanner ordonnance, ajout de médicaments, produits/parapharmacie, panier sans paiement, pharmacies proches, carte/liste, demandes avec suivi, notifications, profil et publicités.

## Lancer le projet

```bash
cd dwak_hna_app
flutter pub get
flutter run
```

Si les dossiers `android/`, `ios/`, `web/` ne sont pas présents sur votre machine, générez-les avec :

```bash
flutter create .
flutter pub get
flutter run
```

## Configuration importante

### Google Maps
La page Pharmacies utilise `google_maps_flutter`. Ajoutez votre clé Google Maps dans Android/iOS avant de tester sur téléphone.

### Caméra / Galerie
La page Scanner ordonnance utilise `image_picker`. Ajoutez les permissions caméra/galerie dans AndroidManifest et Info.plist si vous générez les plateformes.

### Notifications
Le projet contient un service de base pour notifications locales et Firebase Messaging. Vous devez configurer Firebase dans votre projet Flutter avec `flutterfire configure`.

## Structure

```text
lib/
 ├── main.dart
 ├── app_shell.dart
 ├── core/
 ├── data/
 └── features/
```

## Base de données
Le dossier `database/` contient :

- `dwakhna_schema_v2_2.sql` : schéma MySQL propre avec panier, commandes produits et notifications produits.
- `api_endpoints.md` : routes backend recommandées.

## À connecter au backend
Les écrans utilisent actuellement des données mockées pour que l'interface soit testable rapidement. Connectez ensuite les écrans à votre API avec `lib/data/services/api_client.dart`.
