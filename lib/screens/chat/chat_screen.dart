import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String mechanicId;
  final String mechanicName;
  final String? mechanicImageUrl;

  const ChatScreen({
    super.key,
    required this.mechanicId,
    required this.mechanicName,
    this.mechanicImageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_subscription != null) {
      supabase.removeChannel(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError("User not logged in.");
      return;
    }

    try {
      final response = await supabase
          .from('messages')
          .select('id, sender_id, receiver_id, content, created_at, is_read')
          .or(
            'and(sender_id.eq.${user.id},receiver_id.eq.${widget.mechanicId}),and(sender_id.eq.${widget.mechanicId},receiver_id.eq.${user.id})',
          )
          .order('created_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response)
          ..sort((a, b) => DateTime.parse(a['created_at'])
              .compareTo(DateTime.parse(b['created_at'])));
        _isLoading = false;
      });

      // Mark messages from mechanic as read
      await _markMessagesAsRead();
      
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      _showError("Error loading messages: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', widget.mechanicId)
          .eq('receiver_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _subscription = supabase
        .channel('public:messages:chat_${user.id}_${widget.mechanicId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMessage = payload.newRecord;

            final isRelevant =
                (newMessage['sender_id'] == user.id &&
                        newMessage['receiver_id'] == widget.mechanicId) ||
                    (newMessage['sender_id'] == widget.mechanicId &&
                        newMessage['receiver_id'] == user.id);

            if (isRelevant) {
              setState(() {
                _messages.add(Map<String, dynamic>.from(newMessage));
                _messages.sort((a, b) => DateTime.parse(a['created_at'])
                    .compareTo(DateTime.parse(b['created_at'])));
              });

              // If message is from mechanic, mark as read
              if (newMessage['sender_id'] == widget.mechanicId) {
                _markMessagesAsRead();
              }
              
              Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError("User not logged in.");
      return;
    }

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await supabase.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.mechanicId,
        'content': content,
        'is_read': false,
      });
      _messageController.clear();
    } catch (e) {
      _showError("Error sending message: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Row(
            children: [
              Hero(
                tag: 'mechanic-avatar-${widget.mechanicName}',
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.mechanicImageUrl != null
                      ? NetworkImage(widget.mechanicImageUrl!)
                      : null,
                  backgroundColor: const Color(0xFF0D47A1),
                  child: widget.mechanicImageUrl == null
                      ? Text(
                          widget.mechanicName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.mechanicName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Mechanic',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Color(0xFF0D47A1)),
            onPressed: () {
              // Call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Calling ${widget.mechanicName}...'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {
              // More options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet\nStart the conversation!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300 + (index * 50)),
                            curve: Curves.easeOutCubic,
                            child: _buildMessageBubble(_messages[index], user?.id),
                          );
                        },
                      ),
          ),
          
          // Message Input Area
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Row(
                children: [
                  // Message input field
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Send button with animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D47A1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D47A1).withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, String? currentUserId) {
    final isFromCurrentUser = message['sender_id'] == currentUserId;
    final timestamp = DateTime.parse(message['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isFromCurrentUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.mechanicImageUrl != null
                  ? NetworkImage(widget.mechanicImageUrl!)
                  : null,
              backgroundColor: const Color(0xFF0D47A1),
              child: widget.mechanicImageUrl == null
                  ? Text(
                      widget.mechanicName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFromCurrentUser 
                    ? const Color(0xFF0D47A1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: isFromCurrentUser 
                      ? const Radius.circular(18) 
                      : const Radius.circular(4),
                  bottomRight: isFromCurrentUser 
                      ? const Radius.circular(4) 
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'],
                    style: TextStyle(
                      color: isFromCurrentUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(
                          color: isFromCurrentUser 
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                      if (isFromCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message['is_read'] ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message['is_read'] 
                              ? Colors.blue[200] 
                              : Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isFromCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(
                Icons.person,
                color: Colors.grey,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    }
  }
}
