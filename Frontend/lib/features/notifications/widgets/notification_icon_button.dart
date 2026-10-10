import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/notification_socket_manager.dart';
import 'notification_sheet.dart';

class NotificationIconButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Color iconColor;
  final double iconSize;

  const NotificationIconButton({
    super.key,
    this.onTap,
    this.iconColor = AppColors.textPrimary,
    this.iconSize = 26,
  });

  @override
  State<NotificationIconButton> createState() => _NotificationIconButtonState();
}

class _NotificationIconButtonState extends State<NotificationIconButton> {
  final NotificationSocketManager _manager = NotificationSocketManager();

  @override
  void initState() {
    super.initState();
    _manager.init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _manager.unreadCount,
      builder: (context, unreadCount, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: widget.iconColor,
                size: widget.iconSize,
              ),
              onPressed: widget.onTap ?? () => NotificationSheet.show(context),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
