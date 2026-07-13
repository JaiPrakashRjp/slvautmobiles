import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const _kLastPushedKey = 'notif_last_pushed_id';

  final AuthController _auth;
  final ApiClient _api;
  final List<NotificationItem> _items = [];
  // High-water mark of the newest notification id we've already pushed. Persisted
  // so a push fires only ONCE per notification, even across app restarts (fixes
  // the duplicate push on every close/reopen). null = not yet loaded.
  int? _lastPushedId;
  bool _loading = false;

  List<NotificationItem> all() => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.isRead).length;
  bool get isLoading => _loading;

  Future<void> refresh() async {
    final id = _auth.currentUserId;
    if (id == 0) {
      _items.clear();
      notifyListeners();
      return;
    }
    // Load the persisted "last pushed" high-water mark once.
    final prefs = await SharedPreferences.getInstance();
    _lastPushedId ??= prefs.getInt(_kLastPushedKey);
    _loading = true;
    notifyListeners();
    try {
      // user_id is derived from the Bearer token server-side.
      final data = await _api.get('/notifications');
      _items
        ..clear()
        ..addAll((data as List)
            .map((j) => NotificationItem.fromJson(j as Map<String, dynamic>)));

      final maxId = _items.isEmpty
          ? 0
          : _items.map((n) => n.id).reduce((a, b) => a > b ? a : b);
      final baseline = _lastPushedId;
      if (baseline == null) {
        // First run on this device — treat the existing backlog as already seen
        // so we don't spam a push for every old pending item.
        _lastPushedId = maxId;
      } else {
        // Push a system-tray notification only for genuinely NEW unread
        // verification requests (id above the last one we pushed).
        for (final n in _items) {
          if (n.id > baseline &&
              !n.isRead &&
              n.type == 'verification_request') {
            unawaited(LocalPushService.show(
              id: n.id,
              title: n.title,
              body: n.message.isNotEmpty ? n.message : 'Tap to review',
            ));
          }
        }
        if (maxId > baseline) _lastPushedId = maxId;
      }
      if (_lastPushedId != baseline && _lastPushedId != null) {
        await prefs.setInt(_kLastPushedKey, _lastPushedId!);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void markRead(int id) {
    final n = _items.where((x) => x.id == id).cast<NotificationItem?>().firstOrNull;
    if (n == null || n.isRead) return;
    n.isRead = true;
    notifyListeners();
    unawaited(_api.post('/notifications/$id/read').catchError((_) => null));
  }
}
