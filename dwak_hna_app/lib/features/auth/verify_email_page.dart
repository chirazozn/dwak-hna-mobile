import 'package:flutter/material.dart';

import '../../app_shell.dart';
import '../../core/theme/app_colors.dart';

class VerifyEmailPage extends StatelessWidget {
  final String email;
  const VerifyEmailPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(30)),
                child: const Icon(Icons.mark_email_read_outlined, size: 72, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 28),
              const Text('Vérifiez votre email', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('Nous avons envoyé un lien de vérification à $email.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey)),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(AppShell.routeName, (_) => false),
                child: const Text('J’ai vérifié mon email'),
              ),
              TextButton(onPressed: () {}, child: const Text('Renvoyer le lien')),
            ],
          ),
        ),
      ),
    );
  }
}
