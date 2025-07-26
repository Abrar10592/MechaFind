import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/bottom_navbar.dart';
import '../chat/chat_screen.dart';
import 'package:mechfind/utils.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with TickerProviderStateMixin {
  List<ChatConversation> _conversations = [];
  late AnimationController _pulseController;
  late AnimationController _badgeController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _badgeAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isLoading = true;

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
    
    // Simulate loading
    _loadConversations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _badgeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _loadConversations() {
    // Simulate loading delay to show shimmer effect
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Sample chat conversations with mechanics/workshops
          _conversations = [
            ChatConversation(
              mechanicId: 'mech_1',
              mechanicName: 'AutoCare Plus',
              mechanicLocation: '123 Main St, Downtown',
              lastMessage: 'Thank you for choosing our service! How was the engine repair?',
              lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
              isOnline: true,
              unreadCount: 2,
              isFromMechanic: true,
              isTyping: false,
            ),
            ChatConversation(
              mechanicId: 'mech_2',
              mechanicName: 'QuickFix Motors',
              mechanicLocation: '456 Oak Ave, Midtown',
              lastMessage: 'Great! I will be there in 15 minutes.',
              lastMessageTime: DateTime.now().subtract(const Duration(hours: 5)),
              isOnline: false,
              unreadCount: 0,
              isFromMechanic: false,
              isTyping: false,
            ),
            ChatConversation(
              mechanicId: 'mech_3',
              mechanicName: 'Elite Auto Workshop',
              mechanicLocation: '789 Pine Rd, Uptown',
              lastMessage: 'Your brake service is completed. The total cost is ৳8,500.',
              lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
              isOnline: false,
              unreadCount: 0,
              isFromMechanic: true,
              isTyping: false,
            ),
            ChatConversation(
              mechanicId: 'mech_4',
              mechanicName: 'City Garage',
              mechanicLocation: '321 Park Street, Central',
              lastMessage: 'Can you send me the location details?',
              lastMessageTime: DateTime.now().subtract(const Duration(days: 3)),
              isOnline: true,
              unreadCount: 1,
              isFromMechanic: false,
              isTyping: true, // This mechanic is currently typing
            ),
          ];
        });
      }
    });
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
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    // Search functionality
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Search feature coming soon'),
                    ));
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
              : ListView.builder(
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

  Widget _buildConversationCard(ChatConversation conversation) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            // Add a subtle scale animation on tap
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
                  mechanicName: conversation.mechanicName,
                  isOnline: conversation.isOnline,
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
            );
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.primary.withOpacity(0.1),
          highlightColor: AppColors.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Mechanic Avatar with animated online indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        conversation.mechanicName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppFonts.primaryFont,
                        ),
                      ),
                    ),
                    if (conversation.isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
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
                              conversation.mechanicName,
                              style: AppTextStyles.heading.copyWith(
                                fontSize: FontSizes.subHeading,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(conversation.lastMessageTime),
                            style: TextStyle(
                              fontSize: FontSizes.caption,
                              color: AppColors.textSecondary,
                              fontFamily: AppFonts.primaryFont,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              conversation.mechanicLocation,
                              style: TextStyle(
                                fontSize: FontSizes.caption,
                                color: AppColors.textSecondary,
                                fontFamily: AppFonts.primaryFont,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (!conversation.isFromMechanic)
                            Icon(
                              Icons.reply,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          if (!conversation.isFromMechanic)
                            const SizedBox(width: 4),
                          Expanded(
                            child: conversation.isTyping
                                ? _buildTypingIndicator()
                                : Text(
                                    conversation.lastMessage,
                                    style: TextStyle(
                                      fontSize: FontSizes.body,
                                      color: conversation.unreadCount > 0
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontWeight: conversation.unreadCount > 0
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                      fontFamily: AppFonts.primaryFont,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          if (conversation.unreadCount > 0)
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
                                      conversation.unreadCount.toString(),
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
      itemCount: 6, // Show 6 shimmer cards
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
                        
                        // Location shimmer
                        AnimatedBuilder(
                          animation: _shimmerAnimation,
                          builder: (context, child) {
                            return Container(
                              height: 12,
                              width: 200,
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

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        Text(
          'Typing',
          style: TextStyle(
            fontSize: FontSizes.body,
            color: AppColors.primary,
            fontStyle: FontStyle.italic,
            fontFamily: AppFonts.primaryFont,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 20,
          height: 8,
          child: Row(
            children: List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final delay = index * 0.2;
                  final animationValue = (_pulseController.value + delay) % 1.0;
                  final opacity = (animationValue < 0.5) 
                      ? animationValue * 2 
                      : (1.0 - animationValue) * 2;
                  
                  return Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(opacity.clamp(0.3, 1.0)),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ],
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

class ChatConversation {
  final String mechanicId;
  final String mechanicName;
  final String mechanicLocation;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isOnline;
  final int unreadCount;
  final bool isFromMechanic;
  final bool isTyping;

  ChatConversation({
    required this.mechanicId,
    required this.mechanicName,
    required this.mechanicLocation,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isOnline,
    required this.unreadCount,
    required this.isFromMechanic,
    this.isTyping = false,
  });
}
