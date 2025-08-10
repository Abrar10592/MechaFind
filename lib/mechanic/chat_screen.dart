// ignore_for_file: unnecessary_import, prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:mechfind/utils.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverImageUrl;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverImageUrl,
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
    if (user == null) return _showError("User not logged in.");

    try {
      final response = await supabase
          .from('messages')
          .select('id, sender_id, receiver_id, content, created_at')
          .or(
            'and(sender_id.eq.${user.id},receiver_id.eq.${widget.receiverId}),and(sender_id.eq.${widget.receiverId},receiver_id.eq.${user.id})',
          )
          .order('created_at', ascending: true);
          

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response)
          ..sort((a, b) => DateTime.parse(a['created_at'])
              .compareTo(DateTime.parse(b['created_at'])));
      });

      Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      _showError("Error loading messages: $e");
    }
  }

  void _setupRealtimeSubscription() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _subscription = supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMessage = payload.newRecord;
            // ignore: unnecessary_null_comparison
            if (newMessage == null) return;

            final isRelevant =
                (newMessage['sender_id'] == user.id &&
                        newMessage['receiver_id'] == widget.receiverId) ||
                    (newMessage['sender_id'] == widget.receiverId &&
                        newMessage['receiver_id'] == user.id);

            if (isRelevant) {
              setState(() {
                _messages.add(Map<String, dynamic>.from(newMessage));
                _messages.sort((a, b) => DateTime.parse(a['created_at'])
                    .compareTo(DateTime.parse(b['created_at'])));
              });
              Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return _showError("User not logged in.");

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      await supabase.from('messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.receiverId,
        'content': content,
        'is_read': false,
      });
      _messageController.clear();
    } catch (e) {
      _showError("Error sending message: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: CircleAvatar(
                radius: 16,
                backgroundImage: widget.receiverImageUrl != null
                    ? NetworkImage(widget.receiverImageUrl!)
                    : const AssetImage('zob_assets/user_icon.png')
                        as ImageProvider,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.receiverName,
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppFonts.primaryFont,
                fontSize: FontSizes.subHeading,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('no_messages'.tr(), style: AppTextStyles.body),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_id'] == user?.id;
                      final time = DateFormat('hh:mm a')
                          .format(DateTime.parse(message['created_at']));

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary : Colors.grey[200],
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                              bottomLeft:
                                  isMe ? Radius.circular(12) : Radius.zero,
                              bottomRight:
                                  isMe ? Radius.zero : Radius.circular(12),
                            ),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe ? "You" : widget.receiverName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isMe ? Colors.white : Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message['content'].toString().length > 60
                                    ? message['content']
                                            .toString()
                                            .substring(0, 60) +
                                        '...'
                                    : message['content'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'type_message'.tr(),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: AppTextStyles.body,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
