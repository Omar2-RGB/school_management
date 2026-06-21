import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local_database/database_helper.dart';
import '../../models/notification_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('يرجى تسجيل الدخول');

      final data = await DatabaseHelper.getUserNotifications(user.id);
      final notifications = data.map((json) => NotificationModel.fromJson(json)).toList();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في تحميل الإشعارات: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await DatabaseHelper.markNotificationAsRead(id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            title: _notifications[index].title,
            body: _notifications[index].body,
            type: _notifications[index].type,
            isRead: true,
            relatedId: _notifications[index].relatedId,
            createdAt: _notifications[index].createdAt,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await DatabaseHelper.markAllNotificationsAsRead(user.id);
      setState(() {
        _notifications = _notifications.map((n) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            body: n.body,
            type: n.type,
            isRead: true,
            relatedId: n.relatedId,
            createdAt: n.createdAt,
          );
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم تحديد جميع الإشعارات كمقروءة'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _deleteNotification(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الإشعار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await DatabaseHelper.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حذف الإشعار'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'تحديد الكل كمقروء',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: AppColors.danger),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('لا توجد إشعارات'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final isUnread = !notification.isRead;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isUnread ? AppColors.primary.withValues(alpha: 0.05) : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isUnread ? AppColors.primary : Colors.grey,
                              child: Icon(
                                _getIconForType(notification.type),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notification.body),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(notification.createdAt),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isUnread)
                                  CircleAvatar(
                                    radius: 4,
                                    backgroundColor: AppColors.primary,
                                  ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteNotification(notification.id);
                                    } else if (value == 'mark_read') {
                                      _markAsRead(notification.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (isUnread)
                                      const PopupMenuItem(
                                        value: 'mark_read',
                                        child: Text('تحديد كمقروء'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف', style: TextStyle(color: AppColors.danger)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              if (isUnread) {
                                _markAsRead(notification.id);
                              }
                              // التنقل إلى التفاصيل حسب النوع
                            },
                          ),
                        );
                      },
                    ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'absence':
        return Icons.person_off;
      case 'grade':
        return Icons.grade;
      case 'payment':
        return Icons.money;
      case 'system':
        return Icons.settings;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return 'قبل ${diff.inDays} يوم';
    } else if (diff.inHours > 0) {
      return 'قبل ${diff.inHours} ساعة';
    } else if (diff.inMinutes > 0) {
      return 'قبل ${diff.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}