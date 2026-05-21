# Routes API recommandées - Dwak Hna

Base URL exemple : `/api/v1`

## Auth patient
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/verify-email`
- `POST /auth/resend-verification`
- `POST /auth/forgot-password`
- `GET /patients/me`
- `PUT /patients/me`

## Médicaments / Ordonnances
- `GET /medicaments?search=`
- `POST /demandes/manuelle`
- `POST /demandes/ordonnance`
- `POST /demandes/{id}/ordonnances`
- `GET /demandes/me`
- `GET /demandes/{id}`
- `POST /demandes/{id}/choisir-pharmacie`
- `POST /demandes/{id}/note`

## Pharmacies
- `GET /pharmacies/proches?lat=&lng=&rayon=&ouverte=&de_garde=`
- `GET /pharmacies/{id}`

## Produits / Panier
- `GET /categories?type_produit=parapharmacie`
- `GET /produits?category=&min_price=&max_price=&lat=&lng=&rayon=`
- `GET /panier`
- `POST /panier/items`
- `PATCH /panier/items/{id}`
- `DELETE /panier/items/{id}`
- `POST /commandes-produits`
- `GET /commandes-produits/me`
- `POST /commandes-produits/{id}/note`

## Publicités
- `GET /publicites?emplacement=patient_accueil`
- `GET /publicites?emplacement=patient_store`

## Notifications
- `GET /notifications/me`
- `PATCH /notifications/{id}/read`
- `POST /devices/firebase-token`
