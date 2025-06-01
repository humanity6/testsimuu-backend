import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../providers/app_providers.dart';
import '../theme.dart';
import 'package:intl/intl.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, notificationService, _) {
        final unreadCount = notificationService.unreadCount;
        final notifications = notificationService.notifications;
        
        return PopupMenuButton<String>(
          tooltip: 'Notifications',
          onSelected: (String id) {
            notificationService.markAsRead(id);
          },
          itemBuilder: (BuildContext context) {
            if (notifications.isEmpty) {
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(context.tr('No notifications')),
                ),
              ];
            }
            
            return notifications.map((notification) {
              return PopupMenuItem<String>(
                value: notification.id,
                child: _buildNotificationItem(notification),
              );
            }).toList();
          },
          offset: const Offset(0, 50),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.darkBlue,
                ),
                onPressed: null,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    final dateFormat = DateFormat('MMM dd, HH:mm');
    
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: notification.isRead ? null : AppColors.limeYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Icon(
              NotificationService.getIconForType(notification.type),
              color: NotificationService.getColorForType(notification.type),
              size: 16,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(notification.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.darkGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 