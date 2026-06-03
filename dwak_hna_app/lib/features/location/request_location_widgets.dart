import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class WilayaOption {
  final int id;
  final String code;
  final String name;

  const WilayaOption({
    required this.id,
    required this.code,
    required this.name,
  });
}

const List<WilayaOption> algeriaWilayas = [
  WilayaOption(id: 1, code: '01', name: 'Adrar'),
  WilayaOption(id: 2, code: '02', name: 'Chlef'),
  WilayaOption(id: 3, code: '03', name: 'Laghouat'),
  WilayaOption(id: 4, code: '04', name: 'Oum El Bouaghi'),
  WilayaOption(id: 5, code: '05', name: 'Batna'),
  WilayaOption(id: 6, code: '06', name: 'Béjaïa'),
  WilayaOption(id: 7, code: '07', name: 'Biskra'),
  WilayaOption(id: 8, code: '08', name: 'Béchar'),
  WilayaOption(id: 9, code: '09', name: 'Blida'),
  WilayaOption(id: 10, code: '10', name: 'Bouira'),
  WilayaOption(id: 11, code: '11', name: 'Tamanrasset'),
  WilayaOption(id: 12, code: '12', name: 'Tébessa'),
  WilayaOption(id: 13, code: '13', name: 'Tlemcen'),
  WilayaOption(id: 14, code: '14', name: 'Tiaret'),
  WilayaOption(id: 15, code: '15', name: 'Tizi Ouzou'),
  WilayaOption(id: 16, code: '16', name: 'Alger'),
  WilayaOption(id: 17, code: '17', name: 'Djelfa'),
  WilayaOption(id: 18, code: '18', name: 'Jijel'),
  WilayaOption(id: 19, code: '19', name: 'Sétif'),
  WilayaOption(id: 20, code: '20', name: 'Saïda'),
  WilayaOption(id: 21, code: '21', name: 'Skikda'),
  WilayaOption(id: 22, code: '22', name: 'Sidi Bel Abbès'),
  WilayaOption(id: 23, code: '23', name: 'Annaba'),
  WilayaOption(id: 24, code: '24', name: 'Guelma'),
  WilayaOption(id: 25, code: '25', name: 'Constantine'),
  WilayaOption(id: 26, code: '26', name: 'Médéa'),
  WilayaOption(id: 27, code: '27', name: 'Mostaganem'),
  WilayaOption(id: 28, code: '28', name: 'M’Sila'),
  WilayaOption(id: 29, code: '29', name: 'Mascara'),
  WilayaOption(id: 30, code: '30', name: 'Ouargla'),
  WilayaOption(id: 31, code: '31', name: 'Oran'),
  WilayaOption(id: 32, code: '32', name: 'El Bayadh'),
  WilayaOption(id: 33, code: '33', name: 'Illizi'),
  WilayaOption(id: 34, code: '34', name: 'Bordj Bou Arréridj'),
  WilayaOption(id: 35, code: '35', name: 'Boumerdès'),
  WilayaOption(id: 36, code: '36', name: 'El Tarf'),
  WilayaOption(id: 37, code: '37', name: 'Tindouf'),
  WilayaOption(id: 38, code: '38', name: 'Tissemsilt'),
  WilayaOption(id: 39, code: '39', name: 'El Oued'),
  WilayaOption(id: 40, code: '40', name: 'Khenchela'),
  WilayaOption(id: 41, code: '41', name: 'Souk Ahras'),
  WilayaOption(id: 42, code: '42', name: 'Tipaza'),
  WilayaOption(id: 43, code: '43', name: 'Mila'),
  WilayaOption(id: 44, code: '44', name: 'Aïn Defla'),
  WilayaOption(id: 45, code: '45', name: 'Naâma'),
  WilayaOption(id: 46, code: '46', name: 'Aïn Témouchent'),
  WilayaOption(id: 47, code: '47', name: 'Ghardaïa'),
  WilayaOption(id: 48, code: '48', name: 'Relizane'),
  WilayaOption(id: 49, code: '49', name: 'Timimoun'),
  WilayaOption(id: 50, code: '50', name: 'Bordj Badji Mokhtar'),
  WilayaOption(id: 51, code: '51', name: 'Ouled Djellal'),
  WilayaOption(id: 52, code: '52', name: 'Béni Abbès'),
  WilayaOption(id: 53, code: '53', name: 'In Salah'),
  WilayaOption(id: 54, code: '54', name: 'In Guezzam'),
  WilayaOption(id: 55, code: '55', name: 'Touggourt'),
  WilayaOption(id: 56, code: '56', name: 'Djanet'),
  WilayaOption(id: 57, code: '57', name: 'El M’Ghair'),
  WilayaOption(id: 58, code: '58', name: 'El Meniaa'),
];

String wilayaNames(List<int> selectedIds) {
  if (selectedIds.isEmpty) return 'Aucune wilaya sélectionnée';

  return algeriaWilayas
      .where((wilaya) => selectedIds.contains(wilaya.id))
      .map((wilaya) => wilaya.name)
      .join(', ');
}

class RequestLocationSection extends StatelessWidget {
  final bool hasCustomLocation;
  final String locationLabel;
  final double? latitude;
  final double? longitude;
  final VoidCallback onChangeLocation;
  final VoidCallback onUseCurrentLocation;

  const RequestLocationSection({
    super.key,
    required this.hasCustomLocation,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
    required this.onChangeLocation,
    required this.onUseCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasCustomLocation
                      ? 'Localisation personnalisée'
                      : 'Position actuelle utilisée',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            locationLabel,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (latitude != null && longitude != null) ...[
            const SizedBox(height: 4),
            Text(
              '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChangeLocation,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text(
                    'Changer',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (hasCustomLocation) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUseCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text(
                      'Position actuelle',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class RequestSearchZoneSection extends StatelessWidget {
  final String searchMode;
  final int rayonKm;
  final List<int> selectedWilayaIds;
  final ValueChanged<String> onSearchModeChanged;
  final ValueChanged<int> onRayonChanged;
  final VoidCallback onChooseWilayas;

  const RequestSearchZoneSection({
    super.key,
    required this.searchMode,
    required this.rayonKm,
    required this.selectedWilayaIds,
    required this.onSearchModeChanged,
    required this.onRayonChanged,
    required this.onChooseWilayas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.public_rounded,
                color: AppColors.primaryGreen,
              ),
              SizedBox(width: 8),
              Text(
                'Zone de recherche',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final km in [5, 10, 20, 50, 100])
                ChoiceChip(
                  label: Text('$km km'),
                  selected: searchMode == 'rayon' && rayonKm == km,
                  onSelected: (_) {
                    onSearchModeChanged('rayon');
                    onRayonChanged(km);
                  },
                ),
              ChoiceChip(
                label: const Text('Par wilaya'),
                selected: searchMode == 'wilaya',
                onSelected: (_) => onSearchModeChanged('wilaya'),
              ),
              ChoiceChip(
                label: const Text('Toute l’Algérie'),
                selected: searchMode == 'national',
                onSelected: (_) => onSearchModeChanged('national'),
              ),
            ],
          ),
          if (searchMode == 'wilaya') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onChooseWilayas,
              icon: const Icon(Icons.location_city_outlined),
              label: Text(
                selectedWilayaIds.isEmpty
                    ? 'Choisir une ou plusieurs wilayas'
                    : wilayaNames(selectedWilayaIds),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<List<int>?> showWilayaMultiSelectSheet({
  required BuildContext context,
  required List<int> selectedIds,
}) async {
  final temporarySelected = [...selectedIds];

  return showModalBottomSheet<List<int>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(temporarySelected),
                      child: const Text(
                        'Valider',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: algeriaWilayas.length,
                    itemBuilder: (context, index) {
                      final wilaya = algeriaWilayas[index];
                      final selected = temporarySelected.contains(wilaya.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: selected,
                          activeColor: AppColors.primaryGreen,
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            '${wilaya.code} - ${wilaya.name}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              if (value == true) {
                                temporarySelected.add(wilaya.id);
                              } else {
                                temporarySelected.remove(wilaya.id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
