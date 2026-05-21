import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/predefined_message_field.dart';
import '../../data/services/medicament_service.dart';
import '../../data/services/ordonnance_service.dart';
import '../../data/services/location_service.dart';

class PrescriptionScanPage extends StatefulWidget {
  const PrescriptionScanPage({super.key});

  @override
  State<PrescriptionScanPage> createState() => _PrescriptionScanPageState();
}

class _PrescriptionScanPageState extends State<PrescriptionScanPage> {
  final ImagePicker picker = ImagePicker();

  final OrdonnanceService ordonnanceService = OrdonnanceService();
  final MedicamentService medicamentService = MedicamentService();

  final TextEditingController messageController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController freeNameController = TextEditingController();

  Timer? searchDebounce;

  final List<XFile> selectedImages = [];
  final List<Map<String, dynamic>> selectedMedicaments = [];

  bool isSending = false;
  bool isLoadingMedicaments = false;
  String? medicineError;

  List<dynamic> medicaments = [];

  int rayonKm = 5;

  

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      searchDebounce?.cancel();

      final query = searchController.text.trim();

      if (query.length < 2) {
        setState(() {
          medicaments = [];
          isLoadingMedicaments = false;
          medicineError = null;
        });
        return;
      }

      setState(() {
        isLoadingMedicaments = true;
        medicineError = null;
      });

      searchDebounce = Timer(
        const Duration(milliseconds: 400),
        () {
          loadMedicaments();
        },
      );
    });
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    messageController.dispose();
    searchController.dispose();
    freeNameController.dispose();
    super.dispose();
  }

  Future<void> loadMedicaments() async {
    final query = searchController.text.trim();

    if (query.length < 2) {
      if (!mounted) return;

      setState(() {
        medicaments = [];
        isLoadingMedicaments = false;
        medicineError = null;
      });

      return;
    }

    try {
      final data = await medicamentService.getMedicaments(
        search: query,
      );

      if (!mounted) return;

      setState(() {
        medicaments = data;
        isLoadingMedicaments = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        medicineError = e.toString().replaceFirst('Exception: ', '');
        isLoadingMedicaments = false;
      });
    }
  }

  Future<void> pickFromCamera() async {
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
    );

    if (image == null) return;

    setState(() {
      selectedImages.add(image);
    });
  }

  Future<void> pickFromGallery() async {
    final images = await picker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1600,
    );

    if (images.isEmpty) return;

    setState(() {
      selectedImages.addAll(images);
    });
  }

  void removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool isMedicamentSelected(dynamic med) {
    final id = toInt(med['medicament_id']);

    if (id == null) return false;

    return selectedMedicaments.any(
      (item) => item['medicament_id'] == id,
    );
  }

  void addMedicament(dynamic med) {
    final id = toInt(med['medicament_id']);

    if (id == null) return;

    final exists = selectedMedicaments.any(
      (item) => item['medicament_id'] == id,
    );

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce médicament est déjà ajouté'),
        ),
      );
      return;
    }

    setState(() {
      selectedMedicaments.add({
        'medicament_id': id,
        'nom_libre': null,
        'nom_affichage': med['nom']?.toString() ?? 'Médicament',
        'quantite': 1,
      });
    });
  }

  void addFreeMedicament() {
    final name = freeNameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir le nom du médicament'),
        ),
      );
      return;
    }

    setState(() {
      selectedMedicaments.add({
        'medicament_id': null,
        'nom_libre': name,
        'nom_affichage': name,
        'quantite': 1,
      });

      freeNameController.clear();
    });
  }

  void updateQuantity(int index, int quantity) {
    if (quantity < 1) return;

    setState(() {
      selectedMedicaments[index]['quantite'] = quantity;
    });
  }

  void removeSelectedMedicament(int index) {
    setState(() {
      selectedMedicaments.removeAt(index);
    });
  }

  String getMedicamentSubtitle(dynamic med) {
    final parts = <String>[];

    final dci = med['denomination_commune']?.toString();
    final forme = med['forme']?.toString();
    final dosage = med['dosage']?.toString();
    final fabricant = med['fabricant']?.toString();

    if (dci != null && dci.isNotEmpty) parts.add(dci);
    if (forme != null && forme.isNotEmpty) parts.add(forme);
    if (dosage != null && dosage.isNotEmpty) parts.add(dosage);
    if (fabricant != null && fabricant.isNotEmpty) parts.add(fabricant);

    if (parts.isEmpty) {
      return 'Médicament disponible dans le catalogue';
    }

    return parts.join(' • ');
  }

  bool needsPrescription(dynamic med) {
    return med['necessite_ordonnance'] == 1 ||
        med['necessite_ordonnance'] == true;
  }

  Future<void> sendOrdonnance() async {
    if (selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins une image d’ordonnance'),
        ),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final medicamentsForApi = selectedMedicaments.map((item) {
        return {
          'medicament_id': item['medicament_id'],
          'nom_libre': item['nom_libre'],
          'quantite': item['quantite'],
        };
      }).toList();

      final location = await LocationService.getCurrentLocation();


      final success = await ordonnanceService.createOrdonnanceDemande(
        imagePaths: selectedImages.map((image) => image.path).toList(),
        latitude: location.latitude,
        longitude: location.longitude,
        rayonKm: rayonKm,
        medicaments: medicamentsForApi,
        messagePatient: messageController.text.trim().isEmpty
            ? null
            : messageController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordonnance envoyée aux pharmacies proches'),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchLength = searchController.text.trim().length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Scanner ordonnance',
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
                  const Text(
                    'Ajoutez votre ordonnance, puis indiquez les médicaments si vous le souhaitez.',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.camera_alt_outlined,
                          title: 'Caméra',
                          subtitle: 'Prendre une photo',
                          onTap: pickFromCamera,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.photo_library_outlined,
                          title: 'Galerie',
                          subtitle: 'Choisir images',
                          onTap: pickFromGallery,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Images sélectionnées',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (selectedImages.isEmpty)
                    const _EmptyImageCard()
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: selectedImages.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final image = selectedImages[index];

                        return _ImagePreviewCard(
                          image: image,
                          onRemove: () => removeImage(index),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  const Text(
                    'Médicaments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => loadMedicaments(),
                    decoration: InputDecoration(
                      hintText: 'Tapez au moins 2 lettres...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  medicaments = [];
                                  medicineError = null;
                                  isLoadingMedicaments = false;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: freeNameController,
                            decoration: const InputDecoration(
                              hintText: 'Saisie libre, ex: Doliprane',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: addFreeMedicament,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.lightGreen,
                            foregroundColor: AppColors.primaryGreen,
                          ),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (selectedMedicaments.isNotEmpty) ...[
                    const Text(
                      'Médicaments sélectionnés',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...selectedMedicaments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;

                      return _SelectedMedicineCard(
                        name: item['nom_affichage']?.toString() ?? 'Médicament',
                        quantity: item['quantite'] ?? 1,
                        onMinus: () {
                          final current = item['quantite'] ?? 1;
                          updateQuantity(index, current - 1);
                        },
                        onPlus: () {
                          final current = item['quantite'] ?? 1;
                          updateQuantity(index, current + 1);
                        },
                        onRemove: () => removeSelectedMedicament(index),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'Résultats de recherche',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (searchLength < 2)
                    const _InfoCard(
                      icon: Icons.search,
                      title: 'Rechercher un médicament',
                      message:
                          'Tapez au moins 2 caractères pour chercher dans la base.',
                      color: AppColors.primaryGreen,
                    )
                  else if (isLoadingMedicaments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (medicineError != null)
                    _InfoCard(
                      icon: Icons.error_outline,
                      title: 'Erreur',
                      message: medicineError!,
                      color: Colors.red,
                    )
                  else if (medicaments.isEmpty)
                    const _InfoCard(
                      icon: Icons.medication_outlined,
                      title: 'Aucun médicament trouvé',
                      message:
                          'Vous pouvez saisir le médicament manuellement.',
                      color: AppColors.primaryGreen,
                    )
                  else
                    ...medicaments.map(
                      (med) => _MedicineCard(
                        name: med['nom']?.toString() ?? 'Médicament',
                        subtitle: getMedicamentSubtitle(med),
                        needsPrescription: needsPrescription(med),
                        selected: isMedicamentSelected(med),
                        onTap: () => addMedicament(med),
                      ),
                    ),

                  const SizedBox(height: 24),

                  PredefinedMessageField(
                    controller: messageController,
                    type: 'patient_demande',
                  ),

                  const SizedBox(height: 18),

                  DropdownButtonFormField<int>(
                    value: rayonKm,
                    decoration: InputDecoration(
                      labelText: 'Rayon de recherche',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5 km')),
                      DropdownMenuItem(value: 10, child: Text('10 km')),
                      DropdownMenuItem(value: 20, child: Text('20 km')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          rayonKm = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primaryGreen,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Votre ordonnance sera envoyée aux pharmacies proches selon le rayon choisi.',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                  onPressed: isSending ? null : sendOrdonnance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    isSending
                        ? 'Envoi en cours...'
                        : 'Envoyer ordonnance (${selectedImages.length})',
                    style: const TextStyle(
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryGreen,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyImageCard extends StatelessWidget {
  const _EmptyImageCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            color: AppColors.primaryGreen,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'Aucune image sélectionnée',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Prenez une photo ou choisissez une image depuis la galerie.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewCard extends StatelessWidget {
  final XFile image;
  final VoidCallback onRemove;

  const _ImagePreviewCard({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.file(
              File(image.path),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton.filled(
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool needsPrescription;
  final bool selected;
  final VoidCallback onTap;

  const _MedicineCard({
    required this.name,
    required this.subtitle,
    required this.needsPrescription,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.medication_liquid_outlined,
                    color: AppColors.primaryGreen,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                      if (needsPrescription) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Ordonnance requise',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: selected ? AppColors.primaryGreen : AppColors.textGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedMedicineCard extends StatelessWidget {
  final String name;
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  const _SelectedMedicineCard({
    required this.name,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primaryGreen,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
          ),

          Text(
            quantity.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),

          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
          ),

          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.red,
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
            size: 44,
          ),
          const SizedBox(height: 12),
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
