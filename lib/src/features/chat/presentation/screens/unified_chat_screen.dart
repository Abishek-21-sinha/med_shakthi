import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:med_shakthi/src/features/chat/services/chat_service.dart';
import 'package:intl/intl.dart';

class UnifiedChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? otherUserImage;
  final String otherUserId;

  const UnifiedChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.otherUserImage,
    required this.otherUserId,
  });

  @override
  State<UnifiedChatScreen> createState() => _UnifiedChatScreenState();
}

class _UnifiedChatScreenState extends State<UnifiedChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final SupabaseClient _supabase = Supabase.instance.client;
  final FocusNode _focusNode = FocusNode();

  static const _teal = Color(0xFF4C8077);

  late String _currentUserId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser!.id;
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent + 100);
        }
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageCtrl.clear();
    _focusNode.requestFocus();

    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        message: text,
        senderId: _currentUserId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatTime(DateTime dt) => DateFormat('hh:mm a').format(dt);

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) return 'Today';
    if (msgDay == yesterday) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 19,
              backgroundColor: _teal.withValues(alpha: 0.18),
              backgroundImage:
                  widget.otherUserImage != null &&
                      widget.otherUserImage!.isNotEmpty
                  ? NetworkImage(widget.otherUserImage!)
                  : null,
              child:
                  widget.otherUserImage == null ||
                      widget.otherUserImage!.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: _teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName
                        : 'Customer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.appBarTheme.foregroundColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Order Chat',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.appBarTheme.foregroundColor?.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Messages ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _teal),
                  );
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _teal.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: _teal,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Type your message below',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom(animated: false);

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _currentUserId;
                    final time = DateTime.parse(msg['created_at']).toLocal();

                    // Date divider
                    bool showDate = false;
                    if (index == 0) {
                      showDate = true;
                    } else {
                      final prevTime = DateTime.parse(
                        messages[index - 1]['created_at'],
                      ).toLocal();
                      final prevDay = DateTime(
                        prevTime.year,
                        prevTime.month,
                        prevTime.day,
                      );
                      final curDay = DateTime(time.year, time.month, time.day);
                      showDate = curDay != prevDay;
                    }

                    return Column(
                      children: [
                        if (showDate)
                          _DateDivider(label: _formatDateDivider(time)),
                        _MessageBubble(
                          message: msg['message'] ?? '',
                          time: _formatTime(time),
                          isMe: isMe,
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Input Bar ────────────────────────────────────────────
          _InputBar(
            controller: _messageCtrl,
            focusNode: _focusNode,
            isSending: _isSending,
            onSend: _handleSend,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.time,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 3,
          bottom: 3,
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF4C8077), Color(0xFF3a6b63)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe
              ? null
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark ? const Color(0xDEFFFFFF) : Colors.black87),
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.65)
                        : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date Divider ─────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final String label;
  const _DateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final bool isDark;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.isDark,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final hasText = widget.controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  // static const _teal = Color(0xFF4C8077); // Removed as per instruction

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const teal = Color(0xFF4C8077);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── Text Field ──────────────────────────────────────
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.isDark
                          ? const Color(0xDEFFFFFF)
                          : Colors.black.withValues(alpha: 0.87),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                    ),
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ── Send Button ─────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hasText ? teal : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  boxShadow: _hasText
                      ? [
                          BoxShadow(
                            color: teal.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: widget.isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _hasText ? widget.onSend : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
