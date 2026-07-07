import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/auth_error.dart' show avatarInitial;
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/locale_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../theme/app_style.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _service.markAllRead();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.getNotifications();
      setState(() => _notifications = items);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).notifications),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _service.markAllRead();
                await _load();
              },
              child: Text(AppLocalizations.of(context).markAllRead),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.65,
                          child: PremiumEmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: AppLocalizations.of(context).emptyNotifications,
                            subtitle: AppLocalizations.of(context).emptyNotificationsSubtitle,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, i) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n = _notifications[i];
                        return _NotificationTile(
                          notification: n,
                          onTap: () {
                            _service.markRead(n.id);
                            if (n.postId != null) {
                              context.push('/post/${n.postId}');
                            } else if (n.type == 'follow') {
                              context.push('/profile/${n.actorId}');
                            }
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  IconData get _icon {
    switch (notification.type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'new_post':
        return Icons.article;
      default:
        return Icons.notifications;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (notification.type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'follow':
        return Colors.green;
      case 'new_post':
        return const Color(0xFF9575CD);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = notification.actor;
    return ListTile(
      tileColor: notification.isRead
          ? null
          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: actor?.avatarUrl != null
                ? CachedNetworkImageProvider(actor!.avatarUrl!)
                : null,
            child: actor?.avatarUrl == null
                ? Text(avatarInitial(actor?.displayName))
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _iconColor(context),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 1.5),
              ),
              child: Icon(_icon, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
      title: Text(
        notification.body,
        style: TextStyle(
          fontWeight:
              notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        timeago.format(notification.createdAt, locale: LocaleController.instance.timeagoLocale),
      ),
      onTap: onTap,
    );
  }
}
