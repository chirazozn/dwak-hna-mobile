import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/predefined_message_field.dart';
import '../../data/services/demande_service.dart';
import '../../data/services/medicament_service.dart';
import '../../data/services/location_service.dart';

class AddMedicinesPage extends StatefulWidget {
  const AddMedicinesPage({super.key});

  @override
  State<AddMedicinesPage> createState() => _AddMedicinesPageState();
}

class _AddMedicinesPageState extends State<AddMedicinesPage> {
  final MedicamentService medicamentService = MedicamentService();
  final DemandeService demandeService = DemandeService();

  final TextEditingController searchController = TextEditingController();
  final TextEditingController freeNameController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  Timer? searchDebounce;

  bool isLoading = false;
  bool isSending = false;
  String? error;

  List<dynamic> medicaments = [];
  List<Map<String, dynamic>> selectedMedicaments = [];

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
          isLoading = false;
          error = null;
        });
        return;
      }

      setState(() {
        isLoading = true;
        error = null;
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
    searchController.dispose();
    freeNameController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> loadMedicaments() async {
    final query = searchController.text.trim();

    if (query.length < 2) {
      if (!mounted) return;

      setState(() {
        medicaments = [];
        isLoading = false;
        error = null;
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
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool isSelected(dynamic med) {
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

  void removeSelected(int index) {
    setState(() {
      selectedMedicaments.removeAt(index);
    });
  }

  void updateQuantity(int index, int quantity) {
    if (quantity < 1) return;

    setState(() {
      selectedMedicaments[index]['quantite'] = quantity;
    });
  }

  Future<void> sendRequest() async {
    if (selectedMedicaments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez au moins un médicament'),
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

final success = await demandeService.createManualDemande(
  medicaments: medicamentsForApi,
  latitude: location.latitude,
  longitude: location.longitude,
  rayonKm: rayonKm,
  messagePatient: messageController.text.trim().isEmpty
      ? null
      : messageController.text.trim(),
);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande envoyée aux pharmacies proches'),
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

  @override
  Widget build(BuildContext context) {
    final searchLength = searchController.text.trim().length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ajouter médicaments',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadMedicaments,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    const Text(
                      'Sélectionnez ou saisissez vos médicaments',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 16),

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
                                    error = null;
                                    isLoading = false;
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

                    const SizedBox(height: 14),

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

                    const SizedBox(height: 18),

                    if (selectedMedicaments.isNotEmpty) ...[
                      const Text(
                        'Médicaments sélectionnés',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 10),

                      ...selectedMedicaments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        return _SelectedMedicineCard(
                          name: item['nom_affichage']?.toString() ??
                              'Médicament',
                          quantity: item['quantite'] ?? 1,
                          onMinus: () {
                            final current = item['quantite'] ?? 1;
                            updateQuantity(index, current - 1);
                          },
                          onPlus: () {
                            final current = item['quantite'] ?? 1;
                            updateQuantity(index, current + 1);
                          },
                          onRemove: () => removeSelected(index),
                        );
                      }),

                      const SizedBox(height: 18),
                    ],

                    const Text(
                      'Résultats de recherche',
                      style: TextStyle(
                        fontSize: 18,
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
                    else if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (error != null)
                      _InfoCard(
                        icon: Icons.error_outline,
                        title: 'Erreur',
                        message: error!,
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
                          selected: isSelected(med),
                          onTap: () => addMedicament(med),
                        ),
                      ),

                    const SizedBox(height: 22),

                    PredefinedMessageField(
                      controller: messageController,
                      type: 'patient_demande',
                    ),

                    const SizedBox(height: 14),

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
                  ],
                ),
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
                  onPressed: isSending ? null : sendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: isSending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    isSending
                        ? 'Envoi en cours...'
                        : 'Envoyer la demande (${selectedMedicaments.length})',
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
