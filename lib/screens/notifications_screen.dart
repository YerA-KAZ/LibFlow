import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../services/dummy_books.dart';
import '../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback onNavigateToMyBooks;

  const NotificationsScreen({super.key, required this.onNavigateToMyBooks});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotification> _notifications = DummyDataService.getSampleNotifications();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Хабарламалар',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n.isRead = true;
                }
              });
            },
            child: const Text('Барлығын оқылды деу'),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: isDark ? Colors.white24 : Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('Жаңа хабарламалар жоқ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                IconData icon;
                Color iconColor;

                switch (notif.type) {
                  case 'deadline':
                    icon = Icons.alarm_rounded;
                    iconColor = AppColors.error;
                    break;
                  case 'reservation':
                    icon = Icons.bookmark_added_rounded;
                    iconColor = AppColors.success;
                    break;
                  default:
                    icon = Icons.info_outline_rounded;
                    iconColor = AppColors.primaryLight;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() => notif.isRead = true);
                    if (notif.type == 'deadline' || notif.type == 'reservation') {
                      Navigator.pop(context);
                      widget.onNavigateToMyBooks();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? (isDark ? AppColors.surfaceDark : Colors.white)
                          : (isDark ? const Color(0xFF1E2D4A) : const Color(0xFFEFF6FF)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: notif.isRead
                            ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                            : AppColors.primaryLight.withAlpha(100),
                        width: notif.isRead ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: iconColor.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: notif.isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!notif.isRead)
                                    const CircleAvatar(
                                      radius: 4,
                                      backgroundColor: AppColors.primaryLight,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${notif.time.hour}:${notif.time.minute.toString().padLeft(2, '0')} • бүгін',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
