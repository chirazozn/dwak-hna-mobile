import 'package:flutter/material.dart';

import '../../data/services/message_predefini_service.dart';
import '../theme/app_colors.dart';

class PredefinedMessageField extends StatefulWidget {
  final TextEditingController controller;
  final String type;

  const PredefinedMessageField({
    super.key,
    required this.controller,
    this.type = 'patient_demande',
  });

  @override
  State<PredefinedMessageField> createState() => _PredefinedMessageFieldState();
}

class _PredefinedMessageFieldState extends State<PredefinedMessageField> {
  final MessagePredefiniService messageService = MessagePredefiniService();

  bool isLoading = true;
  List<dynamic> messages = [];
  String? selectedMessage;

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  Future<void> loadMessages() async {
    try {
      final data = await messageService.getMessages(
        type: widget.type,
      );

      if (!mounted) return;

      setState(() {
        messages = data;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        messages = [];
        isLoading = false;
      });
    }
  }

  void selectMessage(String message) {
    setState(() {
      selectedMessage = message;
    });

    widget.controller.text = message;
  }

  Future<void> openMessagesSheet() async {
    if (messages.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              const Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.primaryGreen,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Messages prédéfinis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Expanded(
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final content = message['contenu']?.toString() ?? '';
                    final isSelected = selectedMessage == content;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            selectMessage(content);
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : AppColors.lightGreen,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_rounded
                                        : Icons.message_outlined,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primaryGreen,
                                    size: 20,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Text(
                                    content,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedMessage =
        selectedMessage != null && selectedMessage!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Message',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 10),

        if (isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                SizedBox(width: 12),
                Text(
                  'Chargement des messages...',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else if (messages.isNotEmpty)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: openMessagesSheet,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.format_quote_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasSelectedMessage
                                ? 'Message sélectionné'
                                : 'Choisir un message prédéfini',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasSelectedMessage
                                ? selectedMessage!
                                : '${messages.length} messages disponibles',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textGrey,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              'Aucun message prédéfini disponible.',
              style: TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        const SizedBox(height: 12),

        TextField(
          controller: widget.controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Message personnalisé',
            hintText: 'Écrivez votre propre message...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
