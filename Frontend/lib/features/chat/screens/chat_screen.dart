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
import '../services/chat_badge_manager.dart';
import '../../auth/services/auth_service.dart';
import 'package:flutter/services.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';
import 'create_poll_screen.dart';
import '../widgets/poll_voters_sheet.dart';



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
  final AuthService _authService = AuthService();
  final PollService _pollService = PollService();

  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _groupScrollController = ScrollController();
  final ScrollController _announcementScrollController = ScrollController();

  bool _isTyping = false;
  final bool _showSystemTyping = false;
  bool _isSending = false;

  late List<Message> _announcementMessages;
  late List<Message> _groupMessages;
  List<Poll> _polls = [];
  bool _isLoadingPolls = false;

  late String _activeTripId;
  String? _currentUserId;
  String _currentUserName = 'You (Trip Leader)';
  String _currentUserAvatar = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80';

  final Set<String> _selectedMessageIds = {};
  Message? _editingMessage;

  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;

  List<Message> get _currentTabMessages {
    if (_tabController.index == 0) return _announcementMessages;
    if (_tabController.index == 1) return _groupMessages;
    return [];
  }

  List<Message> get _selectedMessages => _currentTabMessages
      .where((m) => _selectedMessageIds.contains(m.id))
      .toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: (widget.initialTabIndex >= 0 && widget.initialTabIndex < 3)
          ? widget.initialTabIndex
          : 0,
    );
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _scrollToBottom(_groupScrollController);
        ChatBadgeManager().markAsRead(_activeTripId, chatType: 'group');
      } else if (_tabController.index == 0) {
        ChatBadgeManager().markAsRead(_activeTripId, chatType: 'announcement');
      } else if (_tabController.index == 2) {
        _loadPolls();
      }
      if (_selectedMessageIds.isNotEmpty) {
        setState(() {
          _selectedMessageIds.clear();
        });
      } else {
        setState(() {});
      }
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

    final List<String> alternateTripIds = [];
    if (widget.tripData != null) {
      final tripDbId = (widget.tripData!['_id'] ?? widget.tripData!['id'])?.toString().trim();
      if (tripDbId != null && tripDbId.isNotEmpty && tripDbId != _activeTripId) {
        alternateTripIds.add(tripDbId);
      }
      final invCode = widget.tripData!['invitationCode']?.toString().trim();
      if (invCode != null && invCode.isNotEmpty && invCode != _activeTripId) {
        alternateTripIds.add(invCode);
      }
    }
    if (widget.tripId != null && widget.tripId!.trim().isNotEmpty && widget.tripId!.trim() != _activeTripId) {
      alternateTripIds.add(widget.tripId!.trim());
    }

    _initCurrentUser();
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
    _loadPolls();
    _initSocketConnection(alternateTripIds: alternateTripIds);

    ChatBadgeManager().setChatOpen(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_groupScrollController.hasClients) {
        _groupScrollController.jumpTo(_groupScrollController.position.maxScrollExtent);
      }
      ChatBadgeManager().markAsRead(_activeTripId);
    });
  }

  Future<void> _initCurrentUser() async {
    final uid = await _authService.getCurrentUserId();
    if (uid != null && uid.isNotEmpty && mounted) {
      setState(() {
        _currentUserId = uid;
      });
      _socketService.updateCurrentUserId(uid);
      _reapplyOwnershipToExistingMessages(uid);
    }
  }

  void _reapplyOwnershipToExistingMessages(String userId) {
    if (userId.isEmpty) return;
    bool groupChanged = false;
    for (int i = 0; i < _groupMessages.length; i++) {
      final m = _groupMessages[i];
      if (m.senderId != null && m.senderId!.isNotEmpty) {
        final shouldBeMe = (m.senderId == userId);
        if (m.isMe != shouldBeMe) {
          _groupMessages[i] = _adjustMessageOwnership(m);
          groupChanged = true;
        }
      }
    }
    if (groupChanged) {
      _tripGroupMessagesStore[_activeTripId] = _groupMessages;
    }

    bool announcementChanged = false;
    for (int i = 0; i < _announcementMessages.length; i++) {
      final m = _announcementMessages[i];
      if (m.senderId != null && m.senderId!.isNotEmpty) {
        final shouldBeMe = (m.senderId == userId);
        if (m.isMe != shouldBeMe) {
          _announcementMessages[i] = _adjustMessageOwnership(m);
          announcementChanged = true;
        }
      }
    }
    if (announcementChanged) {
      _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
    }

    if (groupChanged || announcementChanged) {
      setState(() {});
    }
  }

  Message _adjustMessageOwnership(Message msg) {
    if (_currentUserId != null && _currentUserId!.isNotEmpty && msg.senderId != null && msg.senderId!.isNotEmpty) {
      final shouldBeMe = (msg.senderId == _currentUserId);
      if (msg.isMe != shouldBeMe) {
        return Message(
          id: msg.id,
          senderId: msg.senderId,
          senderName: msg.senderName,
          senderAvatar: msg.senderAvatar,
          content: msg.content,
          timestamp: msg.timestamp,
          isMe: shouldBeMe,
          type: msg.type,
          attachmentUrl: msg.attachmentUrl,
          latitude: msg.latitude,
          longitude: msg.longitude,
          isLeader: msg.isLeader,
        );
      }
    }
    return msg;
  }

  void _initSocketConnection({List<String>? alternateTripIds}) {
    if (_activeTripId.isEmpty) return;
    final isRemoved = widget.tripData?['isRemovedFromTrip'] == true ||
        widget.tripData?['participantStatus'] == 'removed' ||
        widget.tripData?['participantStatus'] == 'left';
    if (isRemoved) return;
    _socketService.connect(
      _activeTripId,
      currentUserId: _currentUserId,
      alternateTripIds: alternateTripIds,
      onAnnouncement: (Message newMsg) {
        if (mounted) {
          final correctedMsg = _adjustMessageOwnership(newMsg);
          final index = _announcementMessages.indexWhere((m) =>
              (m.id.isNotEmpty && m.id == correctedMsg.id) ||
              (m.content.trim() == correctedMsg.content.trim() &&
                  m.senderName == correctedMsg.senderName &&
                  m.timestamp.difference(correctedMsg.timestamp).inSeconds.abs() < 10));
          if (index != -1) {
            if (_announcementMessages[index].isMe != correctedMsg.isMe) {
              setState(() {
                _announcementMessages[index] = correctedMsg;
                _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
              });
            }
          } else {
            setState(() {
              _announcementMessages.add(correctedMsg);
              _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
            });
            _scrollToBottom(_announcementScrollController);
          }
        }
      },
      onGroupMessage: (Message newMsg) {
        if (mounted) {
          final correctedMsg = _adjustMessageOwnership(newMsg);
          final index = _groupMessages.indexWhere((m) =>
              (m.id.isNotEmpty && m.id == correctedMsg.id) ||
              (m.content.trim() == correctedMsg.content.trim() &&
                  m.senderName == correctedMsg.senderName &&
                  m.timestamp.difference(correctedMsg.timestamp).inSeconds.abs() < 10));
          if (index != -1) {
            if (_groupMessages[index].isMe != correctedMsg.isMe) {
              setState(() {
                _groupMessages[index] = correctedMsg;
                _tripGroupMessagesStore[_activeTripId] = _groupMessages;
              });
            }
          } else {
            setState(() {
              _groupMessages.add(correctedMsg);
              _tripGroupMessagesStore[_activeTripId] = _groupMessages;
            });
            _scrollToBottom(_groupScrollController);
          }
        }
      },
      onMessageEdited: (String messageId, String newContent, bool isEdited) {
        if (mounted) {
          setState(() {
            final gIndex = _groupMessages.indexWhere((m) => m.id == messageId);
            if (gIndex != -1) {
              _groupMessages[gIndex] = _groupMessages[gIndex].copyWith(content: newContent, isEdited: isEdited);
              _tripGroupMessagesStore[_activeTripId] = _groupMessages;
            }
            final aIndex = _announcementMessages.indexWhere((m) => m.id == messageId);
            if (aIndex != -1) {
              _announcementMessages[aIndex] = _announcementMessages[aIndex].copyWith(content: newContent, isEdited: isEdited);
              _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
            }
          });
        }
      },
      onMessagesDeleted: (List<String> messageIds) {
        if (mounted) {
          setState(() {
            _groupMessages.removeWhere((m) => messageIds.contains(m.id));
            _announcementMessages.removeWhere((m) => messageIds.contains(m.id));
            _tripGroupMessagesStore[_activeTripId] = _groupMessages;
            _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
            _selectedMessageIds.removeWhere((id) => messageIds.contains(id));
            if (_editingMessage != null && messageIds.contains(_editingMessage!.id)) {
              _editingMessage = null;
              _messageController.clear();
              _isTyping = false;
            }
          });
        }
      },
      onPollCreated: (Poll newPoll) {
        if (mounted) {
          setState(() {
            _polls.removeWhere((p) => p.id == newPoll.id);
            _polls.insert(0, newPoll);
          });
        }
      },
      onPollUpdated: (Poll updatedPoll) {
        if (mounted) {
          setState(() {
            final idx = _polls.indexWhere((p) => p.id == updatedPoll.id);
            if (idx != -1) {
              _polls[idx] = updatedPoll;
            } else {
              _polls.insert(0, updatedPoll);
            }
          });
        }
      },
      onPollDeleted: (String pollId) {
        if (mounted) {
          setState(() {
            _polls.removeWhere((p) => p.id == pollId);
          });
        }
      },
    );
  }

  Future<void> _loadPolls() async {
    if (_activeTripId.isEmpty) return;
    setState(() => _isLoadingPolls = true);
    final fetched = await _pollService.getPolls(_activeTripId);
    if (mounted) {
      setState(() {
        _polls = fetched;
        _isLoadingPolls = false;
      });
    }
  }

  Future<void> _handleVote(Poll poll, PollOption option) async {
    final res = await _pollService.votePoll(_activeTripId, poll.id, option.id);
    if (res['success'] == true && res['poll'] != null && mounted) {
      setState(() {
        final idx = _polls.indexWhere((p) => p.id == poll.id);
        if (idx != -1) {
          _polls[idx] = res['poll'] as Poll;
        }
      });
    } else if (mounted && res['message'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleEditPoll(Poll poll) async {
    final updated = await Navigator.push<Poll>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePollScreen(
          tripId: _activeTripId,
          existingPoll: poll,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = _polls.indexWhere((p) => p.id == updated.id);
        if (idx != -1) {
          _polls[idx] = updated;
        }
      });
    }
  }

  Future<void> _confirmDeletePoll(Poll poll) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Poll'),
        content: Text('Are you sure you want to delete the poll "${poll.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _pollService.deletePoll(_activeTripId, poll.id);
      if (res['success'] == true && mounted) {
        setState(() {
          _polls.removeWhere((p) => p.id == poll.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll deleted successfully.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  String _formatPollTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _startEditSelectedMessage() {
    final selectedMsgs = _selectedMessages;
    if (selectedMsgs.length != 1) return;
    final msg = selectedMsgs.first;
    if (!msg.isMe) return;

    setState(() {
      _editingMessage = msg;
      _messageController.text = msg.content;
      _isTyping = msg.content.trim().isNotEmpty;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _saveEditedMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _editingMessage == null) return;

    final targetMsgId = _editingMessage!.id;
    final originalContent = _editingMessage!.content;
    final isAnnouncement = _tabController.index == 0;

    setState(() {
      if (isAnnouncement) {
        final aIndex = _announcementMessages.indexWhere((m) => m.id == targetMsgId);
        if (aIndex != -1) {
          _announcementMessages[aIndex] = _announcementMessages[aIndex].copyWith(content: text, isEdited: true);
          _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
        }
      } else {
        final gIndex = _groupMessages.indexWhere((m) => m.id == targetMsgId);
        if (gIndex != -1) {
          _groupMessages[gIndex] = _groupMessages[gIndex].copyWith(content: text, isEdited: true);
          _tripGroupMessagesStore[_activeTripId] = _groupMessages;
        }
      }
      _editingMessage = null;
      _isTyping = false;
    });

    _messageController.clear();

    if (text != originalContent) {
      await _chatService.editMessage(_activeTripId, targetMsgId, text);
    }
  }

  void _copySelectedMessages() {
    final selectedMsgs = _selectedMessages;
    if (selectedMsgs.isEmpty) return;

    // Sort chronologically by timestamp
    selectedMsgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    String textToCopy = '';
    if (selectedMsgs.length == 1) {
      textToCopy = selectedMsgs.first.content;
    } else {
      // Format: [dd/MM, h:mm a] SenderName: message
      // e.g.: [10/10, 8:35 am] Neel: Brbr
      final lines = selectedMsgs.map((m) {
        final dateStr = '${m.timestamp.day.toString().padLeft(2, '0')}/${m.timestamp.month.toString().padLeft(2, '0')}';
        final hour = m.timestamp.hour == 0
            ? 12
            : (m.timestamp.hour > 12 ? m.timestamp.hour - 12 : m.timestamp.hour);
        final min = m.timestamp.minute.toString().padLeft(2, '0');
        final ampm = m.timestamp.hour >= 12 ? 'pm' : 'am';
        final sender = m.senderName;
        return '[$dateStr, $hour:$min $ampm] $sender: ${m.content}';
      }).toList();
      textToCopy = lines.join('\n');
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(selectedMsgs.length == 1 ? 'Message copied' : '${selectedMsgs.length} messages copied'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );

    setState(() {
      _selectedMessageIds.clear();
    });
  }

  void _confirmDeleteSelectedMessages() {
    final selectedMsgs = _selectedMessages;
    if (selectedMsgs.isEmpty) return;

    final canDeleteForEveryone = widget.isTripLeader || selectedMsgs.every((m) => m.isMe);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (canDeleteForEveryone) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteSelectedMessages(deleteType: 'forEveryone');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.centerRight,
                      child: const Text(
                        'Delete for everyone',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteSelectedMessages(deleteType: 'forMe');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.centerRight,
                    child: const Text(
                      'Delete for me',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedMessageIds.clear();
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.centerRight,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSelectedMessages({required String deleteType}) async {
    final idsToDelete = _selectedMessageIds.toList();
    if (idsToDelete.isEmpty) return;

    setState(() {
      _groupMessages.removeWhere((m) => idsToDelete.contains(m.id));
      _announcementMessages.removeWhere((m) => idsToDelete.contains(m.id));
      _tripGroupMessagesStore[_activeTripId] = _groupMessages;
      _tripAnnouncementsStore[_activeTripId] = _announcementMessages;
      _selectedMessageIds.clear();
      if (_editingMessage != null && idsToDelete.contains(_editingMessage!.id)) {
        _editingMessage = null;
        _messageController.clear();
        _isTyping = false;
      }
    });

    await _chatService.deleteMessages(_activeTripId, idsToDelete, deleteType: deleteType);
  }

  Future<void> _loadAnnouncements() async {
    if (_activeTripId.isEmpty) return;
    final res = await _chatService.getAnnouncements(_activeTripId);
    if (mounted) {
      if (res['success'] == true && res['data'] != null) {
        final List<Message> fetched = List<Message>.from(res['data']);
        setState(() {
          _announcementMessages = fetched;
          _tripAnnouncementsStore[_activeTripId] = fetched;
        });
        ChatBadgeManager().markAsRead(_activeTripId, chatType: 'announcement');
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
      _scrollToBottom(_groupScrollController);
      ChatBadgeManager().markAsRead(_activeTripId, chatType: 'group');
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
        final uid = (uData['_id'] ?? uData['id'])?.toString().trim();

        setState(() {
          if (uid != null && uid.isNotEmpty) {
            _currentUserId = uid;
          }
          _currentUserName = widget.isTripLeader ? '$fullName (Trip Leader)' : fullName;
          if (photo != null && photo.isNotEmpty) {
            _currentUserAvatar = photo;
          }
        });
        if (uid != null && uid.isNotEmpty) {
          _socketService.updateCurrentUserId(uid);
          _reapplyOwnershipToExistingMessages(uid);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    ChatBadgeManager().setChatOpen(false);
    ChatBadgeManager().markAsRead(_activeTripId);
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

    if (_editingMessage != null) {
      await _saveEditedMessage();
      return;
    }

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
              senderId: _currentUserId,
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
            senderId: _currentUserId,
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
    return PopScope(
      canPop: !_isSelectionMode && _editingMessage == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          setState(() {
            _selectedMessageIds.clear();
          });
          return;
        }
        if (_editingMessage != null) {
          setState(() {
            _editingMessage = null;
            _messageController.clear();
            _isTyping = false;
          });
          return;
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) {
            if (_tabController.index == 2 && widget.isTripLeader) {
              return FloatingActionButton(
                onPressed: () async {
                  final newPoll = await Navigator.push<Poll>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePollScreen(tripId: _activeTripId),
                    ),
                  );
                  if (newPoll != null && mounted) {
                    setState(() {
                      _polls.removeWhere((p) => p.id == newPoll.id);
                      _polls.insert(0, newPoll);
                    });
                  }
                },
                backgroundColor: const Color(0xFF1E5AE6),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add, size: 28),
              );
            }
            return const SizedBox.shrink();
          },
        ),
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
                    // Tab 3: Poll
                    _buildPollsList(),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, child) {
                  if (_tabController.index == 2) {
                    return const SizedBox.shrink();
                  }
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
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      final canEdit = _selectedMessages.length == 1 && _selectedMessages.first.isMe;

      return PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
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
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () {
              setState(() {
                _selectedMessageIds.clear();
              });
            },
          ),
          titleSpacing: 0,
          title: Text(
            '${_selectedMessageIds.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (canEdit)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: 'Edit',
                onPressed: _startEditSelectedMessage,
              ),
            IconButton(
              icon: const Icon(Icons.content_copy_rounded, color: Colors.white),
              tooltip: 'Copy',
              onPressed: _copySelectedMessages,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Delete',
              onPressed: _confirmDeleteSelectedMessages,
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }

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
              _tabController.index == 0
                  ? Icons.campaign_rounded
                  : (_tabController.index == 1 ? Icons.groups_outlined : Icons.poll_outlined),
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
                    : (_tabController.index == 1
                        ? 'Group Discussion'
                        : (widget.isTripLeader ? 'Polls (Leader Mode)' : 'Trip Polls')),
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
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.poll_outlined, size: 18),
                SizedBox(width: 6),
                Text('Poll'),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: messages.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return _buildMessageItem(messages[index], isAnnouncement: isAnnouncement);
      },
    );
  }

  Widget _buildPollsList() {
    if (_isLoadingPolls && _polls.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E5AE6)),
      );
    }

    if (_polls.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                ),
                child: const Icon(
                  Icons.poll_outlined,
                  size: 40,
                  color: Color(0xFF1E5AE6),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No polls created yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isTripLeader
                    ? 'As the Trip Leader, tap the + button to create a poll and get quick decisions from your group!'
                    : 'When the Trip Leader creates a poll, it will appear here for you to vote.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              if (widget.isTripLeader) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final newPoll = await Navigator.push<Poll>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreatePollScreen(tripId: _activeTripId),
                      ),
                    );
                    if (newPoll != null && mounted) {
                      setState(() {
                        _polls.removeWhere((p) => p.id == newPoll.id);
                        _polls.insert(0, newPoll);
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Poll'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5AE6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPolls,
      color: const Color(0xFF1E5AE6),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _polls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final poll = _polls[index];
          return _buildPollCard(poll);
        },
      ),
    );
  }

  Widget _buildPollCard(Poll poll) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator header row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1E5AE6),
                backgroundImage: poll.creatorAvatar != null && poll.creatorAvatar!.isNotEmpty
                    ? CachedNetworkImageProvider(poll.creatorAvatar!)
                    : null,
                child: (poll.creatorAvatar == null || poll.creatorAvatar!.isEmpty)
                    ? Text(
                        poll.creatorName.isNotEmpty ? poll.creatorName[0].toUpperCase() : 'T',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            poll.creatorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                          ),
                          child: const Text(
                            'Trip Leader',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E5AE6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPollTime(poll.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              if (widget.isTripLeader)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF64748B), size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'edit') {
                      _handleEditPoll(poll);
                    } else if (val == 'delete') {
                      _confirmDeletePoll(poll);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F172A)),
                          SizedBox(width: 8),
                          Text('Edit Poll'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('Delete Poll', style: TextStyle(color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Question
          Text(
            poll.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          // Multiple answers pill
          Row(
            children: [
              Icon(
                poll.allowMultipleAnswers ? Icons.done_all_rounded : Icons.radio_button_checked,
                size: 13,
                color: poll.allowMultipleAnswers ? const Color(0xFF10B981) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                poll.allowMultipleAnswers ? 'Multiple choices allowed' : 'Select one option',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: poll.allowMultipleAnswers ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Options list
          Column(
            children: poll.options.map((opt) {
              final isVoted = opt.hasVoted;
              final percent = (opt.percentage / 100).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _handleVote(poll, opt),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: isVoted ? const Color(0xFFF0FDF4) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isVoted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                        width: isVoted ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Progress bar fill
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: percent,
                              child: Container(
                                color: isVoted
                                    ? const Color(0xFFD1FAE5).withOpacity(0.6)
                                    : const Color(0xFFF1F5F9),
                              ),
                            ),
                          ),
                        ),
                        // Foreground content
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                poll.allowMultipleAnswers
                                    ? (isVoted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                                    : (isVoted ? Icons.radio_button_checked : Icons.radio_button_off),
                                color: isVoted ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  opt.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isVoted ? FontWeight.bold : FontWeight.w500,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${opt.voteCount} (${opt.percentage}%)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isVoted ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 6),

          // Total votes, view votes button and live status
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${poll.totalVotes} ${poll.totalVotes == 1 ? 'vote' : 'votes'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => PollVotersSheet(
                      tripId: _activeTripId,
                      poll: poll,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF1E5AE6)),
                      SizedBox(width: 4),
                      Text(
                        'View Votes',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5AE6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message, {required bool isAnnouncement}) {
    if (message.type == MessageType.system) {
      return _buildSystemMessage(message);
    }

    final canSelect = !isAnnouncement || widget.isTripLeader;
    final isSelected = canSelect && _selectedMessageIds.contains(message.id);

    return InkWell(
      onLongPress: canSelect
          ? () {
              setState(() {
                if (!_selectedMessageIds.contains(message.id)) {
                  _selectedMessageIds.add(message.id);
                }
              });
            }
          : null,
      onTap: canSelect && _isSelectionMode
          ? () {
              setState(() {
                if (_selectedMessageIds.contains(message.id)) {
                  _selectedMessageIds.remove(message.id);
                } else {
                  _selectedMessageIds.add(message.id);
                }
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? const Color(0xFF00C6FF).withValues(alpha: 0.18) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: isAnnouncement
            ? _buildAnnouncementCard(message)
            : Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
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
              ),
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
                    Row(
                      children: [
                        if (message.isEdited) ...[
                          const Text(
                            'Edited ',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                        Text(
                          _formatTime(message.timestamp),
                          style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                        ),
                      ],
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
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (message.isEdited) ...[
                Text(
                  'Edited ',
                  style: TextStyle(
                    color: message.isMe ? Colors.white70 : AppColors.textLight,
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  color: message.isMe ? Colors.white70 : AppColors.textLight,
                  fontSize: 9,
                ),
              ),
              if (message.isMe) ...[
                const SizedBox(width: 3),
                const Icon(
                  Icons.done_all,
                  size: 12,
                  color: Colors.white70,
                ),
              ],
            ],
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

  Widget _buildEditingBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Editing message',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _editingMessage?.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textLight),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
                _isTyping = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomArea() {
    final isRemoved = widget.tripData?['isRemovedFromTrip'] == true ||
        widget.tripData?['participantStatus'] == 'removed' ||
        widget.tripData?['participantStatus'] == 'left';

    if (isRemoved) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFFFEE2E2),
          border: Border(top: BorderSide(color: Color(0xFFFECACA))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_outline, size: 16, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text(
              'You have left or been removed from this trip (Read-only)',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingMessage != null) _buildEditingBar(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          hintText: _editingMessage != null
                              ? 'Edit message...'
                              : (isAnnouncementTab
                                  ? 'Post an announcement as Trip Leader...'
                                  : 'Type a message...'),
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
                      child: Icon(
                        _editingMessage != null ? Icons.check : Icons.send,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
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

