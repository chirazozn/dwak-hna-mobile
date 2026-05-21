import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/app_request.dart';

class RequestTrackingPage extends StatelessWidget {
  final AppRequest request;
  const RequestTrackingPage({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Suivi #${request.id}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(request.pharmacyName, style: const TextStyle(color: AppColors.textGrey)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...List.generate(request.steps.length, (index) {
              final done = index <= request.activeStep;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.primaryGreen : AppColors.lightGreen),
                        child: Icon(done ? Icons.check_rounded : Icons.circle_outlined, color: done ? Colors.white : AppColors.primaryGreen, size: 18),
                      ),
                      if (index != request.steps.length - 1)
                        Container(width: 2, height: 52, color: done ? AppColors.primaryGreen : AppColors.lightGreen),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.steps[index], style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(done ? 'Étape validée' : 'En attente', style: const TextStyle(color: AppColors.textGrey)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 18),
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.star_rounded), label: const Text('Noter la pharmacie')),
          ],
        ),
      ),
    );
  }
}
