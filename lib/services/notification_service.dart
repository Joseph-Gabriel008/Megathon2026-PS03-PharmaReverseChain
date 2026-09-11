// lib/services/notification_service.dart
//
// Notification service for in-app alerts to users.
// Writes to the notifications table (created in schema.sql).
// Supports realtime subscriptions for live badge counts.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? relatedBatchId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedBatchId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? '',
        type: j['type'] as String? ?? '',
        relatedBatchId: j['related_batch_id'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class NotificationService {
  final SupabaseClient _client;

  NotificationService(this._client);

  bool get _isMock =>
      AppConstants.forceOfflineDemoMode ||
      AppConstants.supabaseUrl.contains('YOUR_PROJECT_ID');

  // ─────────────────────────────────────────────────────────────────────────
  //  Read
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<AppNotification>> getMyNotifications({int limit = 30}) async {
    if (_isMock) return _mockNotifications();
    try {
      final data = await _client
          .from('notifications')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((n) => AppNotification.fromJson(n)).toList();
    } catch (e) {
      debugPrint('NotificationService.getMyNotifications: $e');
      return _mockNotifications();
    }
  }

  Future<int> getUnreadCount() async {
    if (_isMock) return 2;
    try {
      final data = await _client
          .from('notifications')
          .select('id')
          .eq('is_read', false);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Write
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedBatchId,
  }) async {
    if (_isMock) return;
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'related_batch_id': relatedBatchId,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('NotificationService.createNotification: $e');
    }
  }

  Future<void> markRead(String notificationId) async {
    if (_isMock) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('NotificationService.markRead: $e');
    }
  }

  Future<void> markAllRead() async {
    if (_isMock) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('is_read', false);
    } catch (e) {
      debugPrint('NotificationService.markAllRead: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Realtime subscription
  // ─────────────────────────────────────────────────────────────────────────

  /// Subscribe to new notifications for the current user.
  /// Returns a channel; caller must call `channel.unsubscribe()` on dispose.
  RealtimeChannel subscribeToMyNotifications(
    String userId,
    void Function(AppNotification) onNew,
  ) {
    return _client
        .channel('notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            try {
              final n = AppNotification.fromJson(payload.newRecord);
              onNew(n);
            } catch (e) {
              debugPrint('NotificationService realtime parse error: $e');
            }
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Mock data
  // ─────────────────────────────────────────────────────────────────────────

  List<AppNotification> _mockNotifications() => [
        AppNotification(
          id: 'notif-1',
          userId: 'demo-user',
          title: 'New Return Request',
          message: 'Batch PARA500-2026-001 requires pickup from City Pharmacy.',
          type: 'RETURN_INITIATED',
          relatedBatchId: 'batch-001',
          isRead: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        AppNotification(
          id: 'notif-2',
          userId: 'demo-user',
          title: 'Batch Collected',
          message: 'Batch AMOX250-2026-003 has been collected by distributor.',
          type: 'COLLECTED',
          relatedBatchId: 'batch-002',
          isRead: true,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
}
