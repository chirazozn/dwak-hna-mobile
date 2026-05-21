import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService notificationService = NotificationService();

  bool isLoading = true;
  String? error;

  List<AppNotif> notifications = [];
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final result = await notificationService.getPatientNotifications();

      if (!mounted) return;

      setState(() {
        notifications = result.notifications;
        unreadCount = result.unreadCount;
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

  Future<void> markAsRead(AppNotif notif) async {
    try {
      await notificationService.markAsRead(notif);
      await loadNotifications();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await notificationService.markAllAsRead();
      await loadNotifications();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  IconData iconForType(String type) {
    switch (type) {
      case 'demande_acceptee':
        return Icons.check_circle_outline_rounded;
      case 'demande_refusee':
        return Icons.cancel_outlined;
      case 'demande_annulee':
        return Icons.info_outline_rounded;
      case 'tous':
      case 'patient':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color colorForType(String type) {
    switch (type) {
      case 'demande_acceptee':
        return AppColors.primaryGreen;
      case 'demande_refusee':
        return Colors.red;
      case 'demande_annulee':
        return Colors.orange;
      default:
        return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: markAllAsRead,
              child: const Text(
                'Tout lire',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadNotifications,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historique',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$unreadCount non lue(s)',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 70),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                _InfoCard(
                  icon: Icons.error_outline,
                  title: 'Erreur',
                  message: error!,
                  color: Colors.red,
                )
              else if (notifications.isEmpty)
                const _InfoCard(
                  icon: Icons.notifications_none_rounded,
                  title: 'Aucune notification',
                  message: 'Vous n’avez pas encore de notification.',
                  color: AppColors.primaryGreen,
                )
              else
                ...notifications.map(
                  (notif) => _NotificationCard(
                    notif: notif,
                    icon: iconForType(notif.typeNotif),
                    color: colorForType(notif.typeNotif),
                    onRead: () => markAsRead(notif),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotif notif;
  final IconData icon;
  final Color color;
  final VoidCallback onRead;

  const _NotificationCard({
    required this.notif,
    required this.icon,
    required this.color,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notif.estLue ? Colors.white : AppColors.lightGreen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: notif.estLue
              ? Colors.transparent
              : AppColors.primaryGreen.withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notif.estLue ? color.withOpacity(0.10) : Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.titre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  notif.corps,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notif.envoyeLe,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!notif.estLue) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onRead,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text(
                        'Marquer comme lue',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ],
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
            size: 48,
          ),
          const SizedBox(height: 14),
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
