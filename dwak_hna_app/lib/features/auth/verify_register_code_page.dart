import 'package:flutter/material.dart';

import '../../app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';

class VerifyRegisterCodePage extends StatefulWidget {
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String password;

  const VerifyRegisterCodePage({
    super.key,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.password,
  });

  @override
  State<VerifyRegisterCodePage> createState() => _VerifyRegisterCodePageState();
}

class _VerifyRegisterCodePageState extends State<VerifyRegisterCodePage> {
  final AuthService authService = AuthService();
  final TextEditingController codeController = TextEditingController();

  bool isLoading = false;
  bool isResending = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> verifyCode() async {
    final code = codeController.text.trim();

    if (code.length < 4) {
      showMessage('Code invalide');
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final success = await authService.verifyRegisterCode(
        nom: widget.nom,
        prenom: widget.prenom,
        email: widget.email,
        telephone: widget.telephone,
        password: widget.password,
        code: code,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const AppShell(),
          ),
          (route) => false,
        );
        return;
      }

      showMessage('Code incorrect');
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

  Future<void> resendCode() async {
    try {
      setState(() {
        isResending = true;
      });

      final success = await authService.sendRegisterCode(
        email: widget.email,
      );

      if (!mounted) return;

      if (success) {
        showMessage('Nouveau code envoyé');
      } else {
        showMessage('Impossible d’envoyer le code');
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() {
        isResending = false;
      });
    }
  }

  InputDecoration decoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: AppColors.primaryGreen,
      ),
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Confirmation email',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.primaryGreen,
              size: 70,
            ),
            const SizedBox(height: 18),
            const Text(
              'Vérifiez votre email',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Un code de confirmation a été envoyé à :\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: decoration(
                label: 'Code de confirmation',
                icon: Icons.lock_outline,
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : verifyCode,
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
                        'Confirmer mon compte',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: isResending ? null : resendCode,
              child: Text(
                isResending ? 'Envoi...' : 'Renvoyer le code',
                style: const TextStyle(
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