import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../widgets/bottom_navbar.dart';
import '../chat/chat_screen.dart';
import '../../services/message_notification_service.dart';
import 'package:mechfind/utils.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
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
      // Get all messages involving the current user
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
        
        // Only include conversations with mechanics
        if (otherUser != null && otherUser['role'] == 'mechanic' && otherUserId != null && !conversationMap.containsKey(otherUserId)) {
          // Count unread messages from this mechanic
          final unreadResponse = await supabase
              .from('messages')
              .select('id')
              .eq('sender_id', otherUserId)
              .eq('receiver_id', user.id)
              .eq('is_read', false);

          conversationMap[otherUserId] = {
            'mechanic_id': otherUserId,
            'mechanic_name': otherUser['full_name'] ?? 'Unknown Mechanic',
            'mechanic_image_url': otherUser['image_url'],
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
        .channel('public:messages:user_${user.id}')
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markMessagesAsRead(String mechanicId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', mechanicId)
          .eq('receiver_id', user.id)
          .eq('is_read', false);
      
      // Update the global notification service
      MessageNotificationService().refresh();
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            fontFamily: AppFonts.primaryFont,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
                context, '/userHome', (route) => false);
          },
        ),
        actions: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
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
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading()
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
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
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 2) return;
          switch (index) {
            case 0:
              Navigator.pushNamedAndRemoveUntil(
                  context, '/userHome', (route) => false);
              break;
            case 1:
              Navigator.pushNamed(context, '/find-mechanics');
              break;
            case 3:
              Navigator.pushNamed(context, '/history');
              break;
            case 4:
              Navigator.pushNamed(context, '/settings');
              break;
          }
        },
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () async {
            // Mark messages as read when opening chat
            await _markMessagesAsRead(conversation['mechanic_id']);
            
            // Navigate to functional chat screen
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                  mechanicId: conversation['mechanic_id'],
                  mechanicName: conversation['mechanic_name'],
                  mechanicImageUrl: conversation['mechanic_image_url'],
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
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.primary.withOpacity(0.1),
          highlightColor: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Mechanic Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundImage: conversation['mechanic_image_url'] != null
                      ? NetworkImage(conversation['mechanic_image_url'])
                      : null,
                  backgroundColor: AppColors.primary,
                  child: conversation['mechanic_image_url'] == null
                      ? Text(
                          conversation['mechanic_name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppFonts.primaryFont,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                
                // Conversation Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation['mechanic_name'],
                              style: AppTextStyles.heading.copyWith(
                                fontSize: FontSizes.subHeading,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(conversation['last_message_time']),
                            style: TextStyle(
                              fontSize: FontSizes.caption,
                              color: AppColors.textSecondary,
                              fontFamily: AppFonts.primaryFont,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation['last_message'],
                              style: TextStyle(
                                fontSize: FontSizes.body,
                                color: conversation['unread_count'] > 0
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: conversation['unread_count'] > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                fontFamily: AppFonts.primaryFont,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation['unread_count'] > 0)
                            AnimatedBuilder(
                              animation: _badgeAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _badgeAnimation.value,
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          spreadRadius: 1,
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      conversation['unread_count'].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: AppFonts.primaryFont,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
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
                              height: 14,
                              width: 250,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: const Icon(
                  Icons.message_outlined,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: FontSizes.subHeading,
              fontFamily: AppFonts.primaryFont,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with a mechanic',
            style: TextStyle(
              fontSize: FontSizes.body,
              fontFamily: AppFonts.primaryFont,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _badgeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _badgeAnimation.value * 2),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/find-mechanics');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 4 + (_badgeAnimation.value * 2),
                  ),
                  child: Text(
                    'Find Mechanics',
                    style: TextStyle(
                      fontFamily: AppFonts.primaryFont,
                      fontSize: FontSizes.body,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }
}
