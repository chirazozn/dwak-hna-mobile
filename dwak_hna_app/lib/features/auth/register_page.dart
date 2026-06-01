import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import 'verify_register_code_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService authService = AuthService();

  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> register() async {
    final nom = nomController.text.trim();
    final prenom = prenomController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final telephone = telephoneController.text.trim();
    final password = passwordController.text;

    if (nom.isEmpty) {
      showMessage('Nom obligatoire');
      return;
    }

    if (prenom.isEmpty) {
      showMessage('Prénom obligatoire');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      showMessage('Email invalide');
      return;
    }

    if (password.length < 6) {
      showMessage('Mot de passe minimum 6 caractères');
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      await authService.sendRegisterCode(email: email);

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyRegisterCodePage(
            nom: nom,
            prenom: prenom,
            email: email,
            telephone: telephone,
            password: password,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  InputDecoration decoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: AppColors.primaryGreen,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
          children: [
            const Text(
              'Créer un compte',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Inscrivez-vous pour utiliser Dwak Hna',
              style: TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 26),

            TextField(
              controller: nomController,
              decoration: decoration(
                label: 'Nom',
                icon: Icons.person_outline,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: prenomController,
              decoration: decoration(
                label: 'Prénom',
                icon: Icons.person_outline,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: decoration(
                label: 'Email',
                icon: Icons.email_outlined,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: telephoneController,
              keyboardType: TextInputType.phone,
              decoration: decoration(
                label: 'Téléphone',
                icon: Icons.phone_outlined,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: decoration(
                label: 'Mot de passe',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Envoyer le code',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'J’ai déjà un compte',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
