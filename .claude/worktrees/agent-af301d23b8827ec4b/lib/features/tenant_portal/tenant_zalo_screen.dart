import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../models/notification_delivery.dart';
import 'tenant_portal_providers.dart';

class TenantZaloScreen extends ConsumerWidget {
  const TenantZaloScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(tenantPortalZaloMessagesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFE8F3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0068FF),
        foregroundColor: Colors.white,
        title: const Text(
          'Zalo',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Nhắn chủ trọ',
            onPressed: () => _showTenantZaloComposer(context, ref),
            icon: const Icon(Icons.edit_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0068FF),
        onRefresh: () => ref.refresh(tenantPortalZaloMessagesProvider.future),
        child: messagesAsync.when(
          loading: () => const _LoadingMessages(),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Surface(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Không tải được tin Zalo: $error',
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          data: (messages) {
            final unread = messages.where((message) => !message.read).length;
            final latest = messages.isEmpty ? null : messages.first;
            final conversations = _buildConversations(messages);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _TenantZaloHeader(
                  landlordName: latest?.landlordName ?? 'Chủ trọ',
                  phone: latest?.tenantZaloPhone ?? latest?.recipient ?? '',
                  total: messages.length,
                  unread: unread,
                ),
                const SizedBox(height: 14),
                if (messages.isEmpty)
                  _EmptyMessages(
                    onCompose: () => _showTenantZaloComposer(context, ref),
                  )
                else
                  ...conversations.map(
                    (conversation) => _TenantZaloMessageTile(
                      item: conversation.latest,
                      onTap: () async {
                        final unreadMessages =
                            conversation.messages.where((m) => !m.read);
                        for (final message in unreadMessages) {
                          await ref
                              .read(
                                  tenantNotificationControllerProvider.notifier)
                              .markZaloRead(message.id);
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          PageRouteBuilder<void>(
                            pageBuilder: (_, __, ___) => _TenantZaloChatScreen(
                              conversation: conversation,
                            ),
                            transitionsBuilder: (_, animation, __, child) {
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              );
                              return FadeTransition(
                                opacity: curved,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1, 0),
                                    end: Offset.zero,
                                  ).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TenantZaloConversation {
  const _TenantZaloConversation({required this.key, required this.messages});

  final String key;
  final List<NotificationDeliveryLog> messages;

  NotificationDeliveryLog get latest => messages.last;
}

DateTime _messageTime(NotificationDeliveryLog item) {
  return item.sentAt ??
      item.updatedAt ??
      item.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

List<_TenantZaloConversation> _buildConversations(
  List<NotificationDeliveryLog> messages,
) {
  final groups = <String, List<NotificationDeliveryLog>>{};
  for (final message in messages) {
    final key =
        '${message.landlordName ?? 'landlord'}-${message.tenantZaloPhone ?? message.recipient}';
    groups.putIfAbsent(key, () => []).add(message);
  }
  final conversations = groups.entries.map((entry) {
    final items = [...entry.value]
      ..sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
    return _TenantZaloConversation(key: entry.key, messages: items);
  }).toList()
    ..sort((a, b) => _messageTime(b.latest).compareTo(_messageTime(a.latest)));
  return conversations;
}

class _TenantZaloHeader extends StatelessWidget {
  const _TenantZaloHeader({
    required this.landlordName,
    required this.phone,
    required this.total,
    required this.unread,
  });

  final String landlordName;
  final String phone;
  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0068FF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0068FF).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Text(
              _initials(landlordName),
              style: const TextStyle(
                color: Color(0xFF0068FF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  landlordName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone.isEmpty
                      ? '$total tin nhắn · $unread chưa đọc'
                      : 'Zalo $phone · $total tin nhắn · $unread chưa đọc',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantZaloMessageTile extends StatelessWidget {
  const _TenantZaloMessageTile({required this.item, required this.onTap});

  final NotificationDeliveryLog item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = item.isTenantMessage
        ? 'Bạn'
        : item.landlordName ?? 'Chủ trọ';
    final preview = item.isTenantMessage
        ? 'Bạn: ${item.messageText()}'
        : item.messageText();
    final isUnread = !item.read && !item.isTenantMessage;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Surface(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: item.isTenantMessage
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0068FF),
                      child: Text(
                        _initials(displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.landlordName ?? 'Chủ trọ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: !isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            _timeAgo(item.sentAt ?? item.updatedAt),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: !isUnread
                              ? const Color(0xFF64748B)
                              : const Color(0xFF0F172A),
                          fontSize: 12,
                          height: 1.35,
                          fontWeight:
                              !isUnread ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item.roomName} · ${formatCurrencyVnd(item.amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0068FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantZaloChatScreen extends ConsumerStatefulWidget {
  const _TenantZaloChatScreen({required this.conversation});

  final _TenantZaloConversation conversation;

  @override
  ConsumerState<_TenantZaloChatScreen> createState() =>
      _TenantZaloChatScreenState();
}

class _TenantZaloChatScreenState extends ConsumerState<_TenantZaloChatScreen> {
  final TextEditingController _message = TextEditingController();
  final List<NotificationDeliveryLog> _sentMessages = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent =
          await ref.read(tenantZaloMessageControllerProvider.notifier).send(text);
      if (!mounted) return;
      setState(() {
        _sentMessages.add(sent);
        _message.clear();
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.conversation.latest;
    final messages = [
      ...widget.conversation.messages,
      ..._sentMessages,
    ]..sort((a, b) => _messageTime(a).compareTo(_messageTime(b)));
    return Scaffold(
      backgroundColor: const Color(0xFFE8F3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0068FF),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                _initials(item.landlordName ?? 'Chủ trọ'),
                style: const TextStyle(
                  color: Color(0xFF0068FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.landlordName ?? 'Chủ trọ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    item.tenantZaloPhone ?? item.recipient,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _formatDateTime(
                  _messageTime(messages.first),
                ),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          for (final message in messages) ...[
            Align(
              alignment: message.isTenantMessage
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: message.isTenantMessage
                        ? const Color(0xFF0068FF)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(8),
                      topRight: const Radius.circular(8),
                      bottomLeft: Radius.circular(
                        message.isTenantMessage ? 8 : 2,
                      ),
                      bottomRight: Radius.circular(
                        message.isTenantMessage ? 2 : 8,
                      ),
                    ),
                  ),
                  child: Text(
                    message.messageText(),
                    style: TextStyle(
                      color: message.isTenantMessage
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
          _Surface(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _InfoLine(label: 'Phòng', value: item.roomName),
                  _InfoLine(label: 'Tháng', value: item.billingMonth),
                  _InfoLine(
                    label: 'Số tiền',
                    value: formatCurrencyVnd(item.amount),
                  ),
                  _InfoLine(label: 'Hạn thanh toán', value: item.dueDateText),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: item.messageText()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã copy nội dung tin nhắn.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy nội dung'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0068FF),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFD8E6F7))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(
                  'Không gửi được tin: $_error',
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Nhắn chủ trọ...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    tooltip: 'Gửi tin nhắn',
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0068FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
        child: Column(
          children: [
            const Icon(
              Icons.mark_chat_unread_outlined,
              color: Color(0xFF94A3B8),
              size: 38,
            ),
            const SizedBox(height: 10),
            const Text(
              'Chưa có tin Zalo',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCompose,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Nhắn chủ trọ'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0068FF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMessages extends StatelessWidget {
  const _LoadingMessages();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, index) => _Surface(
        child: Container(
          height: index == 0 ? 82 : 96,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: 5,
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E6F7)),
      ),
      child: child,
    );
  }
}

Future<void> _showTenantZaloComposer(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = TextEditingController();
  String? error;
  var loading = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setState) => AlertDialog(
        title: const Text('Nhắn chủ trọ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              enabled: !loading,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                hintText: 'Nhập tin nhắn bạn muốn gửi...',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: loading ? null : () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: loading
                ? null
                : () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setState(() => error = 'Nhập nội dung tin nhắn.');
                      return;
                    }
                    setState(() {
                      loading = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(tenantZaloMessageControllerProvider.notifier)
                          .send(text);
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã gửi tin nhắn.')),
                      );
                    } catch (err) {
                      setState(() {
                        loading = false;
                        error = '$err';
                      });
                    }
                  },
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Gửi'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
}

String _timeAgo(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes}p';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays} ngày';
  return formatDate(local);
}

String _formatDateTime(DateTime? date) {
  if (date == null) return 'Chưa có thời gian gửi';
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatDate(local)} $hour:$minute';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'Z';
  final first = String.fromCharCode(parts.first.runes.first);
  final last =
      parts.length > 1 ? String.fromCharCode(parts.last.runes.first) : '';
  return (first + last).toUpperCase();
}
