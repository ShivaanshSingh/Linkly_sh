import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final UserModel user;
  final List<MessageModel> initialMessages;

  const ChatScreen({
    super.key,
    required this.user,
    this.initialMessages = const [],
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List<MessageModel> _messages = [];
  final bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _messages = widget.initialMessages;
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scrollToBottom();
      }
    });
    
    _loadMessages();
  }

  void _loadMessages() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) return;

    // Listen to real-time messages from Firebase
    MessageService.getMessages(authService.user!.uid, widget.user.uid)
        .listen((messages) {
      if (mounted) {
        debugPrint('📱 ChatScreen: Received ${messages.length} messages');
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
        
        // Mark messages as read when they are loaded
        _markMessagesAsRead();
      }
    }, onError: (error) {
      debugPrint('❌ ChatScreen: Error loading messages: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear(); // Clear input immediately for better UX

    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: authService.user!.uid,
      receiverId: widget.user.uid,
      text: messageText,
      timestamp: DateTime.now(),
      messageType: 'text',
    );

    try {
      debugPrint('📤 ChatScreen: Sending message: ${message.text}');
      // Send message to Firebase
      await MessageService.sendMessage(message);
      debugPrint('✅ ChatScreen: Message sent successfully');
      _scrollToBottom();
      
    } catch (e) {
      debugPrint('❌ ChatScreen: Failed to send message: $e');
      // Show error message and restore text
      _messageController.text = messageText;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _markMessagesAsRead() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.user == null) return;

    try {
      await MessageService.markChatAsRead(authService.user!.uid, widget.user.uid);
    } catch (e) {
      debugPrint('Failed to mark messages as read: $e');
    }
  }


  void _showMessageOptions(MessageModel message) {
    final authService = Provider.of<AuthService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.reply,
              title: 'Reply',
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(message);
              },
            ),
            _buildOptionTile(
              icon: Icons.copy,
              title: 'Copy',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.text));
                _showSnackBar('Message copied to clipboard');
              },
            ),
            if (message.senderId == authService.user?.uid) ...[
              _buildOptionTile(
                icon: Icons.edit,
                title: 'Edit',
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              _buildOptionTile(
                icon: Icons.delete,
                title: 'Delete',
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
                isDestructive: true,
              ),
            ],
            _buildOptionTile(
              icon: Icons.emoji_emotions,
              title: 'React',
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : AppColors.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _replyToMessage(MessageModel message) {
    _messageController.text = 'Replying to: ${message.text}';
    _focusNode.requestFocus();
  }

  void _editMessage(MessageModel message) {
    _messageController.text = message.text;
    _focusNode.requestFocus();
  }

  void _deleteMessage(MessageModel message) {
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    _showSnackBar('Message deleted');
  }

  void _showReactionPicker(MessageModel message) {
    final reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Reaction',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Wrap(
          spacing: 16,
          children: reactions.map((reaction) => GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _addReaction(message, reaction);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                reaction,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  void _addReaction(MessageModel message, String reaction) {
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        final updatedMessage = _messages[index].copyWith(
          reactions: [...message.reactions, reaction],
        );
        _messages[index] = updatedMessage;
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              backgroundImage: widget.user.profileImageUrl != null
                  ? NetworkImage(widget.user.profileImageUrl!)
                  : null,
              child: widget.user.profileImageUrl == null
                  ? Text(
                      widget.user.fullName.isNotEmpty
                          ? widget.user.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              // TODO: Implement video call
            },
          ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              // TODO: Implement voice call
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF2D2D2D),
            onSelected: (value) {
              switch (value) {
                case 'view_profile':
                  // TODO: Navigate to profile
                  break;
                case 'block':
                  // TODO: Block user
                  break;
                case 'clear_chat':
                  _clearChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view_profile',
                child: Text('View Profile', style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('Block User', style: TextStyle(color: Colors.red)),
              ),
              const PopupMenuItem(
                value: 'clear_chat',
                child: Text('Clear Chat', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              border: Border(
                top: BorderSide(color: Color(0xFF374151), width: 1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.primary),
                  onPressed: () {
                    // TODO: Implement file attachment
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
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
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isMe = message.senderId == authService.user?.uid;
    final showAvatar = _shouldShowAvatar(message);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages
          if (!isMe && showAvatar) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.primary,
              backgroundImage: widget.user.profileImageUrl != null
                  ? NetworkImage(widget.user.profileImageUrl!)
                  : null,
              child: widget.user.profileImageUrl == null
                  ? Text(
                      widget.user.fullName.isNotEmpty
                          ? widget.user.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          // Spacer for sent messages
          if (isMe) ...[
            const Spacer(),
          ],
          // Message bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMe ? AppColors.primary.withOpacity(0.3) : const Color(0xFF404040),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name for received messages
                    if (!isMe && showAvatar) ...[
                      Text(
                        widget.user.fullName,
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (message.replyToText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.replyToText!,
                          style: TextStyle(
                            color: isMe ? Colors.white70 : const Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    if (message.reactions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: message.reactions.map((reaction) => Text(
                          reaction,
                          style: const TextStyle(fontSize: 16),
                        )).toList(),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: isMe ? Colors.white70 : const Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            color: message.isRead ? Colors.blue : Colors.grey,
                            size: 16,
                          ),
                        ],
                        if (message.isEdited) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'edited',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  bool _shouldShowAvatar(MessageModel message) {
    final index = _messages.indexOf(message);
    if (index == 0) return true;
    
    final previousMessage = _messages[index - 1];
    return previousMessage.senderId != message.senderId;
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}';
    } else if (difference.inHours > 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to clear all messages? This action cannot be undone.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              Navigator.pop(context);
              _showSnackBar('Chat cleared');
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}