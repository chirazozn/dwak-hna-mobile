class Product {
  final int id;
  final String name;
  final String category;
  final String pharmacyName;
  final int pharmacyId;
  final double price;
  final double distanceKm;
  final bool available;
  final String description;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.pharmacyName,
    required this.pharmacyId,
    required this.price,
    required this.distanceKm,
    required this.available,
    required this.description,
  });
}
