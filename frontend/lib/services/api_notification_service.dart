import 'dart:async';

import 'package:flutter/foundation.dart';

import '../controllers/auth_controller.dart';
import 'api_client.dart';
import 'local_push_service.dart';

/// One in-app notification (verification request / info) for the super admin.
class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.entityType,
    required this.entityId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final String? entityType; // vehicle | customer | sale
  final int? entityId;
  bool isRead;
  final DateTime createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] as int,
        type: (j['type'] as String?) ?? 'info',
        title: (j['title'] as String?) ?? '',
        message: (j['message'] as String?) ?? '',
        entityType: j['entity_type'] as String?,
        entityId: j['entity_id'] as int?,
        isRead: (j['is_read'] as bool?) ?? false,
        createdAt:
            DateTime.tryParse((j['created_at'] as String?) ?? '') ?? DateTime.now(),
      );
}

/// Fetches + caches the signed-in user's in-app notifications.
class NotificationFeed extends ChangeNotifier {
  NotificationFeed({required AuthController auth, ApiClient? client})
      : _auth = auth,
        _api = client ?? ApiClient();

  final AuthController _auth;
  final ApiClient _api;
  final List<NotificationItem> _items = [];
  // Track which notification IDs have already triggered a local push.
  final Set<int> _pushedIds = {};

  List<NotificationItem> all() => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> refresh() async {
    final id = _auth.currentUserId;
    if (id == 0) {
      _items.clear();
      notifyListeners();
      return;
    }
    final data = await _api.get('/notifications', query: {'user_id': id});
    _items
      ..clear()
      ..addAll((data as List)
          .map((j) => NotificationItem.fromJson(j as Map<String, dynamic>)));

    // Fire a system-tray push for each new unread verification request.
    for (final n in _items) {
      if (!n.isRead &&
          n.type == 'verification_request' &&
          !_pushedIds.contains(n.id)) {
        _pushedIds.add(n.id);
        unawaited(LocalPushService.show(
          id: n.id,
          title: n.title,
          body: n.message.isNotEmpty ? n.message : 'Tap to review',
        ));
      }
    }

    notifyListeners();
  }

  void markRead(int id) {
    final n = _items.where((x) => x.id == id).cast<NotificationItem?>().firstOrNull;
    if (n == null || n.isRead) return;
    n.isRead = true;
    notifyListeners();
    unawaited(_api.post('/notifications/$id/read').catchError((_) => null));
  }
}
