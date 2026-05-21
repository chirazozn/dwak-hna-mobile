import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_logo.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onNotificationTap;

  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 54,
            height: 54,
            color: AppColors.lightGreen,
            child: const AppLogo(height: 45),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onNotificationTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}
