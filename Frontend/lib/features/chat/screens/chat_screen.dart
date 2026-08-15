import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isTyping = false;
  bool _showSystemTyping = true; // Rahul Sharma is typing...

  final List<Message> _messages = [
    Message(
      id: '1',
      senderName: 'System',
      senderAvatar: '',
      content: 'Rahul Sharma joined the trip.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isMe: false,
      type: MessageType.system,
    ),
    Message(
      id: '2',
      senderName: 'Rahul Sharma',
      senderAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
      content: 'Hey everyone! Excited for our Paris getaway next week. Did we finalize the hotel?',
      timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 50)),
      isMe: false,
    ),
    Message(
      id: '3',
      senderName: 'Sneha Joshi',
      senderAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80',
      content: 'Yes! We are staying at Le Bristol Paris. It is very close to the Seine river. 🏨',
      timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 45)),
      isMe: false,
    ),
    Message(
      id: '4',
      senderName: 'Rahul Sharma',
      senderAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
      content: 'Awesome. I just added our first expense of dinner tickets in the app.',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isMe: false,
    ),
    Message(
      id: '5',
      senderName: 'System',
      senderAvatar: '',
      content: 'Rahul Sharma added an expense: Dinner at Le Meurice (- ₹4,850)',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 59)),
      isMe: false,
      type: MessageType.system,
    ),
    Message(
      id: '6',
      senderName: 'Sneha Joshi',
      senderAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80',
      content: 'I booked the Seine River Cruise Tickets!',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isMe: false,
    ),
    Message(
      id: '7',
      senderName: 'System',
      senderAvatar: '',
      content: 'Sneha Joshi completed a task: Book Seine River Cruise Tickets',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 58)),
      isMe: false,
      type: MessageType.system,
    ),
    Message(
      id: '8',
      senderName: 'You',
      senderAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      content: 'Perfect. I will upload some of our planned spots here.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
      isMe: true,
    ),
    Message(
      id: '9',
      senderName: 'You',
      senderAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
      content: 'Eiffel Tower at Night 🌙',
      timestamp: DateTime.now().subtract(const Duration(minutes: 38)),
      isMe: true,
      type: MessageType.image,
      attachmentUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&auto=format&fit=crop&q=80',
    ),
    Message(
      id: '10',
      senderName: 'Sneha Joshi',
      senderAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80',
      content: 'Here is where we will meet on May 20th:',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      isMe: false,
    ),
    Message(
      id: '11',
      senderName: 'Sneha Joshi',
      senderAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80',
      content: 'Charles de Gaulle Airport, Terminal 2E',
      timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
      isMe: false,
      type: MessageType.location,
      latitude: 49.0097,
      longitude: 2.5479,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Simulate other users typing effect
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showSystemTyping = true;
        });
      }
    });
    Timer(const Duration(seconds: 9), () {
      if (mounted) {
        setState(() {
          _showSystemTyping = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderName: 'You',
          senderAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
          content: text,
          timestamp: DateTime.now(),
          isMe: true,
        ),
      );
      _messageController.clear();
      _isTyping = false;
    });

    _scrollToBottom();

    // Auto replies/simulated interactions
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSystemTyping = true;
        });
      }
      _scrollToBottom();
    });

    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showSystemTyping = false;
          _messages.add(
            Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              senderName: 'Rahul Sharma',
              senderAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&auto=format&fit=crop&q=80',
              content: 'Got it! I am packing my bags now.',
              timestamp: DateTime.now(),
              isMe: false,
            ),
          );
        });
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildMessageItem(_messages[index]);
                },
              ),
            ),
            if (_showSystemTyping) _buildTypingIndicator(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.12),
      scrolledUnderElevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Group Avatar
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Group Title & Members
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Paris Getaway Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Rahul, Sneha +6 others',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white, size: 22),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessageItem(Message message) {
    if (message.type == MessageType.system) {
      return _buildSystemMessage(message);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(message.senderAvatar),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!message.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                _buildMessageBubble(message),
              ],
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(message.senderAvatar),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(message.isMe ? 16 : 4),
      bottomRight: Radius.circular(message.isMe ? 4 : 16),
    );

    if (message.type == MessageType.image) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              message.attachmentUrl ?? '',
              width: 220,
              height: 150,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                message.content,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(fontSize: 9, color: AppColors.textLight),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (message.type == MessageType.location) {
      return Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mock map placeholder
            Container(
              height: 100,
              color: const Color(0xFFE3F2FD),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.6,
                      child: GridPaper(
                        color: Colors.blue.withOpacity(0.2),
                        divisions: 1,
                        subdivisions: 1,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.location_on,
                    color: AppColors.error,
                    size: 36,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shared Location',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.content,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 8),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(fontSize: 9, color: AppColors.textLight),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Text Message
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: message.isMe ? null : Colors.white,
        gradient: message.isMe
            ? const LinearGradient(
                colors: [AppColors.primary, Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: borderRadius,
        border: message.isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: message.isMe
                ? AppColors.primary.withOpacity(0.15)
                : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: message.isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: message.isMe ? Colors.white70 : AppColors.textLight,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(Message message) {
    IconData eventIcon = Icons.info_outline;
    Color iconColor = AppColors.primary;

    if (message.content.contains('expense')) {
      eventIcon = Icons.account_balance_wallet_outlined;
      iconColor = AppColors.error;
    } else if (message.content.contains('task')) {
      eventIcon = Icons.check_circle_outline;
      iconColor = AppColors.secondary;
    } else if (message.content.contains('joined')) {
      eventIcon = Icons.person_add_alt_1_outlined;
      iconColor = const Color(0xFF9333EA);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(eventIcon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.content,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 56.0, bottom: 8.0),
      child: Row(
        children: [
          const Text(
            'Rahul Sharma is typing',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
          _BouncingDots(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachments
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 24),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary, size: 22),
              onPressed: () {},
            ),
            const SizedBox(width: 4),
            // Text Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (text) {
                    setState(() {
                      _isTyping = text.trim().isNotEmpty;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send Button
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  gradient: _isTyping
                      ? const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _isTyping ? null : AppColors.textLight.withOpacity(0.5),
                  shape: BoxShape.circle,
                  boxShadow: _isTyping
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _BouncingDots extends StatefulWidget {
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (1.0 + (_controller.value - delay)) % 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              height: 4,
              width: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3 + (value * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
