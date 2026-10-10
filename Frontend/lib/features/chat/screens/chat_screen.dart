import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../models/message.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tripsync/core/utils/image_utils.dart';
import '../../profile/services/user_service.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';



class ChatScreen extends StatefulWidget {
  final bool isTripLeader;
  final String tripName;
  final String? tripId;
  final Map<String, dynamic>? tripData;
  final int initialTabIndex;

  const ChatScreen({
    super.key,
    this.isTripLeader = false,
    this.tripName = 'Trip Chat',
    this.tripId,
    this.tripData,
    this.initialTabIndex = 0,
  });


  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Global in-memory storage for trip-specific announcements & group chat per trip
final Map<String, List<Message>> _tripAnnouncementsStore = {};
final Map<String, List<Message>> _tripGroupMessagesStore = {};

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final SocketService _socketService = SocketService();

  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _groupScrollController = ScrollController();
  final ScrollController _announcementScrollController = ScrollController();

  bool _isTyping = false;
  bool _showSystemTyping = false;
  bool _isLoadingAnnouncements = false;
  bool _isSending = false;

  late List<Message> _announcementMessages;
  late List<Message> _groupMessages;
  late String _activeTripId;
  String _currentUserName = 'You (Trip Leader)';
  String _currentUserAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex < 2)
          ? widget.initialTabIndex
          : 0,
    );
    _tabController.addListener(() {
      setState(() {});
    });


    String rawTripId = '';
    if (widget.tripId != null && widget.tripId!.trim().isNotEmpty) {
      rawTripId = widget.tripId!.trim();
    } else if (widget.tripData != null) {
      rawTripId = (widget.tripData!['_id'] ?? widget.tripData!['id'] ?? '').toString().trim();
    }
    if (rawTripId.isEmpty) {
      rawTripId = widget.tripName.trim().toLowerCase();
    }
    _activeTripId = rawTripId;

    _fetchUserProfile();

    // Initialize per-trip announcements store dynamically
    if (!_tripAnnouncementsStore.containsKey(_activeTripId)) {
      _tripAnnouncementsStore[_activeTripId] = [];
    }
    _announcementMessages = _tripAnnouncementsStore[_activeTripId]!;

    // Initialize per-trip group messages store
    if (!_tripGroupMessagesStore.containsKey(_activeTripId)) {
      _tripGroupMessagesStore[_activeTripId] = [];
    }
    _groupMessages = _tripGroupMessagesStore[_activeTripId]!;

    _loadAnnouncements();
    _loadGroupMessages();
    _initSocketConnection();
  }

  void _initSocketConnection() {
    if (_activeTripId.isEmpty) return;
    _socketService.connect(
      _activeTripId,
      onAnnouncement: (Message newMsg) {
        if (mounted) {
          final exists = _announcementMessages.any((m) =>
              m.id == newMsg.id ||
              (m.content.trim() == newMsg.content.trim() &&
                  m.senderName == newMsg.senderName &&
                  m.timestamp.difference(newMsg.timestamp).inSeconds.abs() < 10));
          if (!exists) {
            setState(() {
              _announcementMessages.add(newMsg);
              _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
            });
            _scrollToBottom(_announcementScrollController);
          }
        }
      },
      onGroupMessage: (Message newMsg) {
        if (mounted) {
          final exists = _groupMessages.any((m) =>
              m.id == newMsg.id ||
              (m.content.trim() == newMsg.content.trim() &&
                  m.senderName == newMsg.senderName &&
                  m.timestamp.difference(newMsg.timestamp).inSeconds.abs() < 10));
          if (!exists) {
            setState(() {
              _groupMessages.add(newMsg);
              _tripGroupMessagesStore[_activeTripId] = _groupMessages;
            });
            _scrollToBottom(_groupScrollController);
          }
        }
      },
    );
  }


  Future<void> _loadAnnouncements() async {
    if (_activeTripId.isEmpty) return;
    setState(() {
      _isLoadingAnnouncements = true;
    });

    final res = await _chatService.getAnnouncements(_activeTripId);
    if (mounted) {
      setState(() {
        _isLoadingAnnouncements = false;
      });
      if (res['success'] == true && res['data'] != null) {
        final List<Message> fetched = List<Message>.from(res['data']);
        setState(() {
          _announcementMessages = fetched;
          _tripAnnouncementsStore[_activeTripId] = fetched;
        });
      }
    }
  }

  Future<void> _loadGroupMessages() async {
    if (_activeTripId.isEmpty) return;
    final res = await _chatService.getGroupMessages(_activeTripId);
    if (mounted && res['success'] == true && res['data'] != null) {
      final List<Message> fetched = List<Message>.from(res['data']);
      setState(() {
        _groupMessages = fetched;
        _tripGroupMessagesStore[_activeTripId] = fetched;
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final userService = UserService();
      final res = await userService.getProfile();
      if (res['success'] == true && res['data'] != null && mounted) {
        final uData = res['data'];
        final fn = (uData['firstName'] ?? '').toString().trim();
        final ln = (uData['lastName'] ?? '').toString().trim();
        String fullName = '$fn $ln'.trim();
        if (fullName.isEmpty) fullName = (uData['name'] ?? '').toString().trim();
        if (fullName.isEmpty) fullName = 'Trip Leader';

        final photo = uData['profilePhoto']?.toString();

        setState(() {
          _currentUserName = widget.isTripLeader ? '$fullName (Trip Leader)' : fullName;
          if (photo != null && photo.isNotEmpty) {
            _currentUserAvatar = photo;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _socketService.disconnect();
    _tabController.dispose();
    _messageController.dispose();
    _groupScrollController.dispose();
    _announcementScrollController.dispose();
    super.dispose();
  }


  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final isAnnouncementTab = _tabController.index == 0;

    if (isAnnouncementTab && !widget.isTripLeader) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Trip Leader can send announcements!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    _messageController.clear();
    setState(() {
      _isTyping = false;
      _isSending = true;
    });

    if (isAnnouncementTab) {
      final res = await _chatService.postAnnouncement(_activeTripId, text);
      if (mounted) {
        setState(() => _isSending = false);
        if (res['success'] == true && res['data'] != null) {
          final newMsg = res['data'] as Message;
          setState(() {
            final exists = _announcementMessages.any((m) => m.id == newMsg.id || (m.content.trim() == newMsg.content.trim() && m.senderName == newMsg.senderName));
            if (!exists) {
              _announcementMessages.add(newMsg);
              _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
            }
          });
          _scrollToBottom(_announcementScrollController);
        } else {
          // Fallback if backend responds with error or dummy tripId
          if (res['message'] != null && res['message'].toString().contains('Only the Trip Leader')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['message']),
                backgroundColor: AppColors.error,
              ),
            );
          } else {
            final fallbackMsg = Message(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              senderName: _currentUserName,
              senderAvatar: _currentUserAvatar,
              content: text,
              timestamp: DateTime.now(),
              isMe: true,
              isLeader: widget.isTripLeader,
              type: MessageType.announcement,
            );
            setState(() {
              _announcementMessages.add(fallbackMsg);
              _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
            });
            _scrollToBottom(_announcementScrollController);
          }
        }
      }
    } else {
      final res = await _chatService.sendGroupMessage(_activeTripId, text);
      if (mounted) {
        setState(() => _isSending = false);
        if (res['success'] == true && res['data'] != null) {
          final newMsg = res['data'] as Message;
          setState(() {
            final exists = _groupMessages.any((m) => m.id == newMsg.id || (m.content.trim() == newMsg.content.trim() && m.senderName == newMsg.senderName));
            if (!exists) {
              _groupMessages.add(newMsg);
              _tripGroupMessagesStore[_activeTripId] = _groupMessages;
            }
          });
          _scrollToBottom(_groupScrollController);
        }
 else {
          final fallbackMsg = Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            senderName: _currentUserName,
            senderAvatar: _currentUserAvatar,
            content: text,
            timestamp: DateTime.now(),
            isMe: true,
            isLeader: widget.isTripLeader,
            type: MessageType.text,
          );
          setState(() {
            _groupMessages.add(fallbackMsg);
            _tripGroupMessagesStore[_activeTripId] = _groupMessages;
          });
          _scrollToBottom(_groupScrollController);
        }
      }
    }
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Announcements (Leader Broadcast Channel)
                  _buildMessageList(_announcementMessages, _announcementScrollController, isAnnouncement: true),
                  // Tab 2: Group Chat (Everyone)
                  _buildMessageList(_groupMessages, _groupScrollController, isAnnouncement: false),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_tabController.index == 1 && _showSystemTyping) _buildTypingIndicator(),
                    _buildBottomArea(),
                  ],
                );
              },
            ),
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
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.2),
            ),
            child: Icon(
              _tabController.index == 0 ? Icons.campaign_rounded : Icons.groups_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.tripName} Chat',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _tabController.index == 0
                    ? (widget.isTripLeader ? 'Announcements (Leader Mode)' : 'Announcements (Read Only)')
                    : 'Group Discussion',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 18),
                SizedBox(width: 6),
                Text('Announcements'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 16),
                SizedBox(width: 6),
                Text('Group Chat'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, ScrollController controller, {required bool isAnnouncement}) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAnnouncement ? Icons.campaign_outlined : Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 12),
            Text(
              isAnnouncement ? 'No announcements yet' : 'No messages yet in Group Chat',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: messages.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return _buildMessageItem(messages[index], isAnnouncement: isAnnouncement);
      },
    );
  }

  Widget _buildMessageItem(Message message, {required bool isAnnouncement}) {
    if (message.type == MessageType.system) {
      return _buildSystemMessage(message);
    }

    if (isAnnouncement) {
      return _buildAnnouncementCard(message);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isMe) ...[
            _buildUserAvatar(message.senderAvatar, message.senderName, radius: 16),
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
            _buildUserAvatar(message.senderAvatar, message.senderName, radius: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String? photo, String name, {double radius = 16}) {
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'User';
    final initial = cleanName[0].toUpperCase();

    String cleanUrl = photo ?? '';
    if (cleanUrl.isNotEmpty && !cleanUrl.startsWith('http')) {
      cleanUrl = ApiEndpoints.buildImageUrl(cleanUrl);
    }
    final finalUrl = ImageUtils.getOptimizedImageUrl(cleanUrl, fallbackName: cleanName);

    if (cleanUrl.isEmpty && (finalUrl.isEmpty || finalUrl.contains('ui-avatars.com'))) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.85,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE2E8F0),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: finalUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.primary,
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.85,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.primary,
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.85,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAnnouncementCard(Message message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFFBEB), // Warm yellow highlight background
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)), // Amber border
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildUserAvatar(message.senderAvatar, message.senderName, radius: 16),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          message.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LEADER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatTime(message.timestamp),
                      style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
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
            color: message.isMe ? AppColors.primary.withOpacity(0.15) : Colors.black.withOpacity(0.03),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
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
        children: const [
          Text(
            'Someone is typing...',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomArea() {
    final isAnnouncementTab = _tabController.index == 0;
    final canSend = !isAnnouncementTab || widget.isTripLeader;

    if (!canSend) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border(top: BorderSide(color: Colors.amber.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_outline, size: 16, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text(
              'Only Trip Leaders can post announcements',
              style: TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

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
                  decoration: InputDecoration(
                    hintText: isAnnouncementTab
                        ? 'Post an announcement as Trip Leader...'
                        : 'Type a message...',
                    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    final localTime = dateTime.toLocal();
    final hour24 = localTime.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }
}

