# Backend recommandé

Cette application mobile attend une API REST. Vous pouvez créer le backend avec Laravel, Node.js/Express, NestJS ou Spring Boot.

Les endpoints nécessaires sont listés dans `database/api_endpoints.md`.

Points obligatoires côté backend :

1. Authentification JWT patient.
2. Vérification email.
3. Upload ordonnance vers stockage local/cloud.
4. Calcul distance pharmacie/patient.
5. Envoi FCM quand une pharmacie répond.
6. Gestion panier et commandes produits sans paiement.
7. API publicités par emplacement.
