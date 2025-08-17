import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessageNotificationService extends ChangeNotifier {
  static final MessageNotificationService _instance = MessageNotificationService._internal();
  factory MessageNotificationService() => _instance;
  MessageNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  RealtimeChannel? _subscription;

  int get unreadCount => _unreadCount;
  bool get hasUnreadMessages => _unreadCount > 0;

  Future<void> initialize() async {
    await _loadUnreadCount();
    _setupRealtimeSubscription();
  }

  Future<void> _loadUnreadCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _unreadCount = 0;
      notifyListeners();
      return;
    }

    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', user.id)
          .eq('is_read', false);

      _unreadCount = response.length;
      notifyListeners();
    } catch (e) {
      print('Error loading unread count: $e');
      _unreadCount = 0;
      notifyListeners();
    }
  }

  void _setupRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Remove existing subscription if any
    if (_subscription != null) {
      _supabase.removeChannel(_subscription!);
    }

    _subscription = _supabase
        .channel('message_notifications_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: user.id,
          ),
          callback: (payload) {
            _loadUnreadCount(); // Refresh unread count on new message
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: user.id,
          ),
          callback: (payload) {
            _loadUnreadCount(); // Refresh unread count on message update (e.g., read status)
          },
        )
        .subscribe();
  }

  Future<void> markMessagesAsRead(String senderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', senderId)
          .eq('receiver_id', user.id)
          .eq('is_read', false);

      // Refresh the unread count after marking messages as read
      await _loadUnreadCount();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> refresh() async {
    await _loadUnreadCount();
  }

  void dispose() {
    if (_subscription != null) {
      _supabase.removeChannel(_subscription!);
      _subscription = null;
    }
    super.dispose();
  }
}
