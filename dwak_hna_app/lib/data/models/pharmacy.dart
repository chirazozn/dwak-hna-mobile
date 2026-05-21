class Pharmacy {
  final int id;
  final String name;
  final String address;
  final double distanceKm;
  final double latitude;
  final double longitude;
  final bool isOpen;
  final bool isDuty;
  final String phone;

  const Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
    required this.isOpen,
    required this.isDuty,
    required this.phone,
  });
}
