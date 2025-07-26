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

class _MessagesPageState extends State<MessagesPage> {
  List<ChatConversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
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
      ),
    ];
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
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Search functionality
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Search feature coming soon'),
              ));
            },
          ),
        ],
      ),
      body: _conversations.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                return _buildConversationCard(conversation);
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  mechanicName: conversation.mechanicName,
                  isOnline: conversation.isOnline,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Mechanic Avatar
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
                          ),
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
                            child: Text(
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
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.message_outlined,
            size: 64,
            color: AppColors.textSecondary,
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
          ElevatedButton(
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
            ),
            child: Text(
              'Find Mechanics',
              style: TextStyle(
                fontFamily: AppFonts.primaryFont,
                fontSize: FontSizes.body,
              ),
            ),
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

  ChatConversation({
    required this.mechanicId,
    required this.mechanicName,
    required this.mechanicLocation,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isOnline,
    required this.unreadCount,
    required this.isFromMechanic,
  });
}
