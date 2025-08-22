import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mechfind/utils.dart';
import 'package:mechfind/services/message_notification_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with TickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  late AnimationController _pulseController;
  late AnimationController _badgeController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _badgeAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isLoading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Initialize animations
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _badgeAnimation = Tween<double>(
      begin: 0.8,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticInOut,
    ));
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _pulseController.repeat(reverse: true);
    _badgeController.repeat(reverse: true);
    _shimmerController.repeat();
    
    // Load real conversations
    _loadConversations();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _badgeController.dispose();
    _shimmerController.dispose();
    if (_subscription != null) {
      supabase.removeChannel(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError("User not logged in.");
      return;
    }

    try {
      // Get all messages involving the current user (mechanic)
      final response = await supabase
          .from('messages')
          .select('''
            sender_id,
            receiver_id,
            content,
            created_at,
            is_read,
            sender:users!messages_sender_id_fkey(id, full_name, image_url, role),
            receiver:users!messages_receiver_id_fkey(id, full_name, image_url, role)
          ''')
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .order('created_at', ascending: false);

      // Group messages by the other user (not current user) and get the latest message from each conversation
      Map<String, Map<String, dynamic>> conversationMap = {};
      
      for (var message in response) {
        final senderId = message['sender_id'];
        final receiverId = message['receiver_id'];
        final sender = message['sender'];
        final receiver = message['receiver'];
        
        // Determine the other user (not the current user)
        String? otherUserId;
        Map<String, dynamic>? otherUser;
        
        if (senderId == user.id) {
          // Current user sent this message, so other user is the receiver
          otherUserId = receiverId;
          otherUser = receiver;
        } else {
          // Current user received this message, so other user is the sender
          otherUserId = senderId;
          otherUser = sender;
        }
        
        // Only include conversations with regular users (not mechanics)
        if (otherUser != null && otherUser['role'] == 'user' && otherUserId != null && !conversationMap.containsKey(otherUserId)) {
          // Count unread messages from this user
          final unreadResponse = await supabase
              .from('messages')
              .select('id')
              .eq('sender_id', otherUserId)
              .eq('receiver_id', user.id)
              .eq('is_read', false);

          conversationMap[otherUserId] = {
            'id': otherUserId,
            'full_name': otherUser['full_name'] ?? 'Unknown User',
            'image_url': otherUser['image_url'],
            'last_message': message['content'],
            'last_message_time': DateTime.parse(message['created_at']),
            'unread_count': unreadResponse.length,
            'is_read': message['is_read'],
          };
        }
      }

      setState(() {
        _conversations = conversationMap.values.toList()
          ..sort((a, b) => b['last_message_time'].compareTo(a['last_message_time']));
        _isLoading = false;
      });
    } catch (e) {
      _showError("Failed to load conversations: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _subscription = supabase
        .channel('public:messages:mechanic_${user.id}')
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
            _loadConversations(); // Refresh conversations on new message
            MessageNotificationService().refresh(); // Update global notification count
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
            _loadConversations(); // Refresh conversations on message update (e.g., read status)
            MessageNotificationService().refresh(); // Update global notification count
          },
        )
        .subscribe();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _markMessagesAsRead(String userId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', userId)
          .eq('receiver_id', user.id)
          .eq('is_read', false);
      
      // Update the global notification service
      MessageNotificationService().refresh();
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'yesterday'.tr();
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          'messages'.tr(),
          style: AppTextStyles.heading.copyWith(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
            fontSize: FontSizes.heading,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _loadConversations();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              Colors.grey.shade50,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? _buildShimmerLoading()
            : _conversations.isEmpty
                ? _buildEmptyState()
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: RefreshIndicator(
                      onRefresh: _loadConversations,
                      color: AppColors.primary,
                      backgroundColor: Colors.white,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          return TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 600 + (index * 100)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset((1 - value) * 300, 0),
                                child: Opacity(
                                  opacity: value,
                                  child: _buildConversationCard(conversation),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final unreadCount = conversation['unread_count'] ?? 0;
    final hasUnread = unreadCount > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: hasUnread 
              ? AppColors.primary.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () async {
            // Mark messages as read when opening chat
            await _markMessagesAsRead(conversation['id']);
            
            // Navigate to chat screen
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                  receiverId: conversation['id'],
                  receiverName: conversation['full_name'],
                  receiverImageUrl: conversation['image_url'],
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    )),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ).then((_) {
              // Refresh conversations when returning from chat
              _loadConversations();
            });
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primary.withOpacity(0.1),
          highlightColor: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Enhanced User Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundImage: conversation['image_url'] != null
                          ? NetworkImage(conversation['image_url'])
                          : null,
                      backgroundColor: AppColors.primary,
                      child: conversation['image_url'] == null
                          ? Text(
                              conversation['full_name'][0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppFonts.primaryFont,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Enhanced Conversation Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation['full_name'],
                              style: AppTextStyles.heading.copyWith(
                                fontSize: FontSizes.subHeading,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: AppFonts.primaryFont,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              _formatTime(conversation['last_message_time']),
                              style: TextStyle(
                                fontSize: FontSizes.caption,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppFonts.primaryFont,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: hasUnread
                                    ? AppColors.primary.withOpacity(0.05)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasUnread
                                      ? AppColors.primary.withOpacity(0.2)
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                conversation['last_message'],
                                style: TextStyle(
                                  fontSize: FontSizes.body,
                                  color: hasUnread
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: hasUnread
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                  fontFamily: AppFonts.secondaryFont,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 12),
                            AnimatedBuilder(
                              animation: _badgeAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _badgeAnimation.value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.danger,
                                          AppColors.danger.withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.danger.withOpacity(0.4),
                                          spreadRadius: 2,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: AppFonts.primaryFont,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Shimmer avatar
                  AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey[300]!,
                              Colors.grey[100]!,
                              Colors.grey[300]!,
                            ],
                            stops: [
                              (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                              _shimmerAnimation.value.clamp(0.0, 1.0),
                              (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  
                  // Shimmer content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name shimmer
                        AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 16,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey[300]!,
                                    Colors.grey[100]!,
                                    Colors.grey[300]!,
                                  ],
                                  stops: [
                                    (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                                    _shimmerAnimation.value.clamp(0.0, 1.0),
                                    (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Message shimmer
                        AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 12,
                              width: MediaQuery.of(context).size.width * 0.6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.grey[300]!,
                                    Colors.grey[100]!,
                                    Colors.grey[300]!,
                                  ],
                                  stops: [
                                    (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                                    _shimmerAnimation.value.clamp(0.0, 1.0),
                                    (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'no_conversations_yet'.tr(),
              style: AppTextStyles.heading.copyWith(
                fontSize: FontSizes.subHeading,
                fontFamily: AppFonts.primaryFont,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'no_conversations_description'.tr(),
                style: AppTextStyles.body.copyWith(
                  fontSize: FontSizes.body,
                  fontFamily: AppFonts.secondaryFont,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
