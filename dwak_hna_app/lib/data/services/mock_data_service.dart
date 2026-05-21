import '../models/app_request.dart';
import '../models/pharmacy.dart';
import '../models/product.dart';

class MockDataService {
  static const pharmacies = [
    Pharmacy(
      id: 1,
      name: 'Pharmacie El Amel',
      address: 'Bir Khadem, Alger',
      distanceKm: 1.2,
      latitude: 36.7128,
      longitude: 3.0480,
      isOpen: true,
      isDuty: false,
      phone: '0550 00 00 01',
    ),
    Pharmacy(
      id: 2,
      name: 'Pharmacie Centrale',
      address: 'Kouba, Alger',
      distanceKm: 2.4,
      latitude: 36.7231,
      longitude: 3.0863,
      isOpen: true,
      isDuty: true,
      phone: '0550 00 00 02',
    ),
    Pharmacy(
      id: 3,
      name: 'Pharmacie Santé Plus',
      address: 'Hydra, Alger',
      distanceKm: 3.7,
      latitude: 36.7466,
      longitude: 3.0428,
      isOpen: false,
      isDuty: false,
      phone: '0550 00 00 03',
    ),
  ];

  static const products = [
    Product(
      id: 1,
      name: 'Crème hydratante visage',
      category: 'Soins du visage',
      pharmacyName: 'Pharmacie El Amel',
      pharmacyId: 1,
      price: 1450,
      distanceKm: 1.2,
      available: true,
      description: 'Crème légère pour hydratation quotidienne.',
    ),
    Product(
      id: 2,
      name: 'Gel solaire SPF 50+',
      category: 'Solaires',
      pharmacyName: 'Pharmacie Centrale',
      pharmacyId: 2,
      price: 2200,
      distanceKm: 2.4,
      available: true,
      description: 'Protection solaire haute tolérance.',
    ),
    Product(
      id: 3,
      name: 'Shampooing fortifiant',
      category: 'Capillaire',
      pharmacyName: 'Pharmacie Santé Plus',
      pharmacyId: 3,
      price: 980,
      distanceKm: 3.7,
      available: false,
      description: 'Soin capillaire pour cheveux fragiles.',
    ),
    Product(
      id: 4,
      name: 'Brosse à dents souple',
      category: 'Hygiène bucco-dentaire',
      pharmacyName: 'Pharmacie El Amel',
      pharmacyId: 1,
      price: 360,
      distanceKm: 1.2,
      available: true,
      description: 'Brosse souple pour usage quotidien.',
    ),
    Product(
      id: 5,
      name: 'Thermomètre digital',
      category: 'Matériel médical',
      pharmacyName: 'Pharmacie Centrale',
      pharmacyId: 2,
      price: 1250,
      distanceKm: 2.4,
      available: true,
      description: 'Mesure rapide de la température.',
    ),
  ];

  static final requests = [
    AppRequest(
      id: 124,
      kind: RequestKind.medicine,
      title: 'Demande ordonnance',
      pharmacyName: 'Pharmacie El Amel',
      status: RequestStatus.responseReceived,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      steps: const ['Envoyée', 'Pharmacies contactées', 'Réponse reçue', 'Pharmacie choisie', 'Terminée'],
      activeStep: 2,
    ),
    AppRequest(
      id: 125,
      kind: RequestKind.product,
      title: 'Commande produits santé',
      pharmacyName: 'Pharmacie Centrale',
      status: RequestStatus.ready,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      steps: const ['Envoyée', 'Acceptée', 'Préparation', 'Prête', 'Terminée'],
      activeStep: 3,
    ),
  ];

  static const medicines = [
    'Doliprane 500mg',
    'Paracétamol 1g',
    'Ibuprofène 400mg',
    'Vitamine C',
    'Amoxicilline 1g',
    'Smecta',
  ];
}
