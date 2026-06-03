import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/predefined_message_field.dart';
import '../../data/services/medicament_service.dart';
import '../../data/services/ordonnance_service.dart';
import '../../data/services/location_service.dart';
import '../location/pick_location_page.dart';

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
  String searchMode = 'rayon';
  PickedLocation? customLocation;
  Set<int> selectedWilayaIds = <int>{};

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
      searchDebounce = Timer(const Duration(milliseconds: 400), loadMedicaments);
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
      final data = await medicamentService.getMedicaments(search: query);
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
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1600);
    if (image == null) return;
    setState(() => selectedImages.add(image));
  }

  Future<void> pickFromGallery() async {
    final images = await picker.pickMultiImage(imageQuality: 75, maxWidth: 1600);
    if (images.isEmpty) return;
    setState(() => selectedImages.addAll(images));
  }

  void removeImage(int index) => setState(() => selectedImages.removeAt(index));

  int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool isMedicamentSelected(dynamic med) {
    final id = toInt(med['medicament_id']);
    if (id == null) return false;
    return selectedMedicaments.any((item) => item['medicament_id'] == id);
  }

  void addMedicament(dynamic med) {
    final id = toInt(med['medicament_id']);
    if (id == null) return;
    final exists = selectedMedicaments.any((item) => item['medicament_id'] == id);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce médicament est déjà ajouté')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez saisir le nom du médicament')));
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
    setState(() => selectedMedicaments[index]['quantite'] = quantity);
  }

  void removeSelectedMedicament(int index) => setState(() => selectedMedicaments.removeAt(index));


  final List<_WilayaOption> wilayaOptions = const [

    _WilayaOption(1, 'Adrar'),
    _WilayaOption(2, 'Chlef'),
    _WilayaOption(3, 'Laghouat'),
    _WilayaOption(4, 'Oum El Bouaghi'),
    _WilayaOption(5, 'Batna'),
    _WilayaOption(6, 'Béjaïa'),
    _WilayaOption(7, 'Biskra'),
    _WilayaOption(8, 'Béchar'),
    _WilayaOption(9, 'Blida'),
    _WilayaOption(10, 'Bouira'),
    _WilayaOption(11, 'Tamanrasset'),
    _WilayaOption(12, 'Tébessa'),
    _WilayaOption(13, 'Tlemcen'),
    _WilayaOption(14, 'Tiaret'),
    _WilayaOption(15, 'Tizi Ouzou'),
    _WilayaOption(16, 'Alger'),
    _WilayaOption(17, 'Djelfa'),
    _WilayaOption(18, 'Jijel'),
    _WilayaOption(19, 'Sétif'),
    _WilayaOption(20, 'Saïda'),
    _WilayaOption(21, 'Skikda'),
    _WilayaOption(22, 'Sidi Bel Abbès'),
    _WilayaOption(23, 'Annaba'),
    _WilayaOption(24, 'Guelma'),
    _WilayaOption(25, 'Constantine'),
    _WilayaOption(26, 'Médéa'),
    _WilayaOption(27, 'Mostaganem'),
    _WilayaOption(28, "M'Sila"),
    _WilayaOption(29, 'Mascara'),
    _WilayaOption(30, 'Ouargla'),
    _WilayaOption(31, 'Oran'),
    _WilayaOption(32, 'El Bayadh'),
    _WilayaOption(33, 'Illizi'),
    _WilayaOption(34, 'Bordj Bou Arréridj'),
    _WilayaOption(35, 'Boumerdès'),
    _WilayaOption(36, 'El Tarf'),
    _WilayaOption(37, 'Tindouf'),
    _WilayaOption(38, 'Tissemsilt'),
    _WilayaOption(39, 'El Oued'),
    _WilayaOption(40, 'Khenchela'),
    _WilayaOption(41, 'Souk Ahras'),
    _WilayaOption(42, 'Tipaza'),
    _WilayaOption(43, 'Mila'),
    _WilayaOption(44, 'Aïn Defla'),
    _WilayaOption(45, 'Naâma'),
    _WilayaOption(46, 'Aïn Témouchent'),
    _WilayaOption(47, 'Ghardaïa'),
    _WilayaOption(48, 'Relizane'),
    _WilayaOption(49, 'Timimoun'),
    _WilayaOption(50, 'Bordj Badji Mokhtar'),
    _WilayaOption(51, 'Ouled Djellal'),
    _WilayaOption(52, 'Béni Abbès'),
    _WilayaOption(53, 'In Salah'),
    _WilayaOption(54, 'In Guezzam'),
    _WilayaOption(55, 'Touggourt'),
    _WilayaOption(56, 'Djanet'),
    _WilayaOption(57, "El M'Ghair"),
    _WilayaOption(58, 'El Meniaa'),
  ];

  String selectedWilayasLabel() {
    if (selectedWilayaIds.isEmpty) {
      return 'Aucune wilaya sélectionnée';
    }

    final names = wilayaOptions
        .where((item) => selectedWilayaIds.contains(item.id))
        .map((item) => item.name)
        .toList();

    if (names.length <= 3) return names.join(', ');

    return '${names.take(3).join(', ')} +${names.length - 3}';
  }

  Future<void> openLocationPicker() async {
    final current = await LocationService.getCurrentLocation();

    if (!mounted) return;

    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => PickLocationPage(
          initialLatitude: customLocation?.latitude ?? current.latitude,
          initialLongitude: customLocation?.longitude ?? current.longitude,
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        customLocation = picked;
      });
    }
  }

  Future<void> openWilayaSelector() async {
    final tempSelected = Set<int>.from(selectedWilayaIds);

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          'Choisir les wilayas',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() => tempSelected.clear());
                        },
                        child: const Text('Vider'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: wilayaOptions.length,
                      itemBuilder: (context, index) {
                        final wilaya = wilayaOptions[index];
                        final selected = tempSelected.contains(wilaya.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: CheckboxListTile(
                            value: selected,
                            activeColor: AppColors.primaryGreen,
                            title: Text(
                              wilaya.name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text('Code ${wilaya.id.toString().padLeft(2, '0')}'),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  tempSelected.add(wilaya.id);
                                } else {
                                  tempSelected.remove(wilaya.id);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(tempSelected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'Valider les wilayas',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        selectedWilayaIds = result;
        if (selectedWilayaIds.isNotEmpty) searchMode = 'wilaya';
      });
    }
  }

  Widget buildLocationSection() {
    final hasCustomLocation = customLocation != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text('Localisation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasCustomLocation ? 'Localisation personnalisée sélectionnée' : 'Position actuelle utilisée par défaut',
            style: const TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w700),
          ),
          if (hasCustomLocation) ...[
            const SizedBox(height: 6),
            Text(customLocation!.label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: openLocationPicker,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Changer', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              if (hasCustomLocation) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => setState(() => customLocation = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSearchZoneSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.travel_explore_rounded, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text('Zone de recherche', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ZoneChip(label: '5 km', selected: searchMode == 'rayon' && rayonKm == 5, onTap: () => setState(() { searchMode = 'rayon'; rayonKm = 5; })),
              _ZoneChip(label: '10 km', selected: searchMode == 'rayon' && rayonKm == 10, onTap: () => setState(() { searchMode = 'rayon'; rayonKm = 10; })),
              _ZoneChip(label: '20 km', selected: searchMode == 'rayon' && rayonKm == 20, onTap: () => setState(() { searchMode = 'rayon'; rayonKm = 20; })),
              _ZoneChip(label: '50 km', selected: searchMode == 'rayon' && rayonKm == 50, onTap: () => setState(() { searchMode = 'rayon'; rayonKm = 50; })),
              _ZoneChip(label: '100 km', selected: searchMode == 'rayon' && rayonKm == 100, onTap: () => setState(() { searchMode = 'rayon'; rayonKm = 100; })),
              _ZoneChip(label: 'Par wilaya', selected: searchMode == 'wilaya', onTap: () => setState(() => searchMode = 'wilaya')),
              _ZoneChip(label: 'Toute l’Algérie', selected: searchMode == 'national', onTap: () => setState(() => searchMode = 'national')),
            ],
          ),
          if (searchMode == 'wilaya') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.location_city_outlined, color: AppColors.primaryGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedWilayasLabel(),
                      style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: openWilayaSelector,
                    child: const Text('Choisir', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
    return parts.isEmpty ? 'Médicament disponible dans le catalogue' : parts.join(' • ');
  }

  bool needsPrescription(dynamic med) {
    return med['necessite_ordonnance'] == 1 || med['necessite_ordonnance'] == true;
  }

  Future<void> sendOrdonnance() async {
    if (selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez ajouter au moins une image d’ordonnance')));
      return;
    }
    if (searchMode == 'wilaya' && selectedWilayaIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir au moins une wilaya')));
      return;
    }

    setState(() => isSending = true);

    try {
      final medicamentsForApi = selectedMedicaments.map((item) {
        return {
          'medicament_id': item['medicament_id'],
          'nom_libre': item['nom_libre'],
          'quantite': item['quantite'],
        };
      }).toList();

      final location = await LocationService.getCurrentLocation();
      final latitude = customLocation?.latitude ?? location.latitude;
      final longitude = customLocation?.longitude ?? location.longitude;

      final success = await ordonnanceService.createOrdonnanceDemande(
        imagePaths: selectedImages.map((image) => image.path).toList(),
        latitude: latitude,
        longitude: longitude,
        rayonKm: rayonKm,
        modeRecherche: searchMode,
        wilayaIds: selectedWilayaIds.toList(),
        medicaments: medicamentsForApi,
        messagePatient: messageController.text.trim().isEmpty ? null : messageController.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ordonnance envoyée aux pharmacies selon votre zone')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchLength = searchController.text.trim().length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Scanner ordonnance', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: AppColors.background, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  const Text('Ajoutez votre ordonnance, puis indiquez les médicaments si vous le souhaitez.', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _ActionButton(icon: Icons.camera_alt_outlined, title: 'Caméra', subtitle: 'Prendre une photo', onTap: pickFromCamera)),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionButton(icon: Icons.photo_library_outlined, title: 'Galerie', subtitle: 'Choisir images', onTap: pickFromGallery)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('Images sélectionnées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  if (selectedImages.isEmpty)
                    const _EmptyImageCard()
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: selectedImages.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.9),
                      itemBuilder: (context, index) => _ImagePreviewCard(image: selectedImages[index], onRemove: () => removeImage(index)),
                    ),
                  const SizedBox(height: 24),
                  const Text('Médicaments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: freeNameController, decoration: const InputDecoration(hintText: 'Saisie libre, ex: Doliprane', border: InputBorder.none))),
                        IconButton.filled(onPressed: addFreeMedicament, style: IconButton.styleFrom(backgroundColor: AppColors.lightGreen, foregroundColor: AppColors.primaryGreen), icon: const Icon(Icons.add_rounded)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedMedicaments.isNotEmpty) ...[
                    const Text('Médicaments sélectionnés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    ...selectedMedicaments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _SelectedMedicineCard(
                        name: item['nom_affichage']?.toString() ?? 'Médicament',
                        quantity: item['quantite'] ?? 1,
                        onMinus: () => updateQuantity(index, (item['quantite'] ?? 1) - 1),
                        onPlus: () => updateQuantity(index, (item['quantite'] ?? 1) + 1),
                        onRemove: () => removeSelectedMedicament(index),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  const Text('Résultats de recherche', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (searchLength < 2)
                    const _InfoCard(icon: Icons.search, title: 'Rechercher un médicament', message: 'Tapez au moins 2 caractères pour chercher dans la base.', color: AppColors.primaryGreen)
                  else if (isLoadingMedicaments)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (medicineError != null)
                    _InfoCard(icon: Icons.error_outline, title: 'Erreur', message: medicineError!, color: Colors.red)
                  else if (medicaments.isEmpty)
                    const _InfoCard(icon: Icons.medication_outlined, title: 'Aucun médicament trouvé', message: 'Vous pouvez saisir le médicament manuellement.', color: AppColors.primaryGreen)
                  else
                    ...medicaments.map((med) => _MedicineCard(
                          name: med['nom']?.toString() ?? 'Médicament',
                          subtitle: getMedicamentSubtitle(med),
                          needsPrescription: needsPrescription(med),
                          selected: isMedicamentSelected(med),
                          onTap: () => addMedicament(med),
                        )),
                  const SizedBox(height: 24),
                  PredefinedMessageField(controller: messageController, type: 'patient_demande'),
                  const SizedBox(height: 18),
                  buildLocationSection(),
                  const SizedBox(height: 14),
                  buildSearchZoneSection(),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(18)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryGreen),
                        SizedBox(width: 10),
                        Expanded(child: Text('Votre ordonnance sera envoyée selon la zone de recherche choisie.', style: TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))]),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSending ? null : sendOrdonnance,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  icon: isSending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)) : const Icon(Icons.send_rounded),
                  label: Text(isSending ? 'Envoi en cours...' : 'Envoyer ordonnance (${selectedImages.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _WilayaOption {
  final int id;
  final String name;

  const _WilayaOption(this.id, this.name);
}

class _ZoneChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ZoneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryGreen : AppColors.lightGreen,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? Colors.white : AppColors.primaryGreen,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.primaryGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
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

  const _ActionButton({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: AppColors.primaryGreen, size: 30),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: const Column(
        children: [
          Icon(Icons.document_scanner_outlined, color: AppColors.primaryGreen, size: 48),
          SizedBox(height: 12),
          Text('Aucune image sélectionnée', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          SizedBox(height: 6),
          Text('Prenez une photo ou choisissez une image depuis la galerie.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

class _ImagePreviewCard extends StatelessWidget {
  final XFile image;
  final VoidCallback onRemove;

  const _ImagePreviewCard({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.file(File(image.path), fit: BoxFit.cover))),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton.filled(
            onPressed: onRemove,
            style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
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
                  child: const Icon(Icons.medication_liquid_outlined, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                      if (needsPrescription) ...[
                        const SizedBox(height: 6),
                        const Text('Ordonnance requise', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(selected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: selected ? AppColors.primaryGreen : AppColors.textGrey),
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
      decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
          Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded, color: Colors.red)),
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

  const _InfoCard({required this.icon, required this.title, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 44),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

