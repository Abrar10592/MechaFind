import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:mechfind/utils.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversationUsers = [];

  @override
  void initState() {
    super.initState();
    _loadConversationUsers();
  }

  Future<void> _loadConversationUsers() async {
    final user = supabase.auth.currentUser;
    if (user == null) return _showError("User not logged in.");

    try {
      final response = await supabase.rpc('get_latest_conversations', params: {
        'current_user_id': user.id,
      });

      setState(() {
        _conversationUsers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showError("Failed to load conversations: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'messages'.tr(),
          style: TextStyle(
            color: Colors.white,
            fontFamily: AppFonts.primaryFont,
            fontSize: FontSizes.subHeading,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
      ),
      body: _conversationUsers.isEmpty
          ? Center(
              child: Text('no_chats'.tr(), style: AppTextStyles.body),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _conversationUsers.length,
              itemBuilder: (context, index) {
                final user = _conversationUsers[index];
                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: user['id'],
                          receiverName: user['full_name'],
                          receiverImageUrl: user['image_url'],
                        ),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundImage: user['image_url'] != null
                        ? NetworkImage(user['image_url'])
                        : const AssetImage('zob_assets/user_icon.png') as ImageProvider,
                  ),
                  title: Text(
                    user['full_name'],
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    user['last_message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
