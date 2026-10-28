import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../rooms/room_providers.dart';
import 'chatbot_providers.dart';
import 'widgets/chat_message_bubble.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});
  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? suggestion]) {
    final message = (suggestion ?? _composer.text).trim();
    if (message.isEmpty ||
        message.length > 1000 ||
        ref.read(chatbotControllerProvider).isSending) {
      return;
    }
    ref.read(chatbotControllerProvider.notifier).send(message);
    _composer.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotControllerProvider);
    final session = ref.watch(sessionControllerProvider).session;
    ref.listen(sessionControllerProvider, (previous, next) {
      if (!identical(previous?.session, next.session)) {
        _composer.clear();
      }
    });
    ref.listen(chatbotControllerProvider, (previous, next) {
      if (previous?.sessionId != next.sessionId ||
          previous?.propertyId != next.propertyId) {
        _composer.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });

    if (session?.user.role != 'landlord') {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: const Text('Trợ lý AI'),
        ),
        body: const Center(
          child: Text(
            'Chức năng hiện chỉ dành cho chủ trọ.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    var scope = 'Hướng dẫn chung';
    if (state.propertyId != null) {
      final properties = ref.watch(propertiesProvider).valueOrNull ?? [];
      final names =
          properties.where((property) => property.id == state.propertyId);
      scope = names.isEmpty ? 'Khu trọ đang chọn' : names.first.name;
    }

    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0D9488),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
          error: Color(0xFFEF4444),
          outlineVariant: Color(0xFFE2E8F0),
          primaryContainer: Color(0xFFF1F5F9),
          onPrimaryContainer: Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: false,
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Trợ lý AI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'Atrium',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Xóa cuộc trò chuyện',
              icon: const Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF64748B)),
              onPressed: () {
                _composer.clear();
                ref.invalidate(chatbotControllerProvider);
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  if (!keyboardVisible)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.menu_book_outlined,
                                  size: 15, color: Color(0xFF0D9488)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Phạm vi: $scope',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Hỏi đáp tài liệu hướng dẫn. Mỗi câu hỏi được xử lý độc lập.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1, color: Color(0xFFEDF2F7)),
                  Expanded(
                    child: state.messages.isEmpty
                        ? _Welcome(onSelect: _send)
                        : ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            children: [
                              for (final message in state.messages)
                                ChatMessageBubble(message: message),
                              if (state.isSending)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 14,
                                          color: Color(0xFF0D9488),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF0D9488),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Đang tìm nguồn và soạn câu trả lời…',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.error!.message,
                              style: const TextStyle(color: Color(0xFFEF4444)),
                            ),
                            TextButton.icon(
                              onPressed: state.isSending
                                  ? null
                                  : () => ref
                                      .read(chatbotControllerProvider.notifier)
                                      .retry(),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Thử lại câu hỏi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFEDF2F7)),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 6),
                          const Icon(Icons.add_rounded, color: Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              controller: _composer,
                              enabled: !state.isSending,
                              minLines: 1,
                              maxLines: keyboardVisible ? 2 : 4,
                              maxLength: 1000,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                counterText: '',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                hintText: 'Ví dụ: Cách tạo hóa đơn?',
                                hintStyle: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Gửi câu hỏi',
                            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: (state.isSending ||
                                      _composer.text.trim().isEmpty ||
                                      _composer.text.trim().length > 1000)
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF0D9488),
                              foregroundColor: (state.isSending ||
                                      _composer.text.trim().isEmpty ||
                                      _composer.text.trim().length > 1000)
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white,
                              minimumSize: const Size(34, 34),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: state.isSending ||
                                    _composer.text.trim().isEmpty ||
                                    _composer.text.trim().length > 1000
                                ? null
                                : _send,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 24,
              color: Color(0xFF0D9488),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Bạn muốn tìm hướng dẫn gì?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tra cứu cách sử dụng ứng dụng và mở tài liệu gốc để kiểm chứng. Trợ lý chưa đọc số dư trực tiếp hoặc thực hiện thao tác thay bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          for (final question in const [
            'Cách tạo hóa đơn cho người thuê?',
            'Làm sao thêm hợp đồng thuê?',
            'Duyệt chứng từ thanh toán ở đâu?'
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(question),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            question,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Cuộc trò chuyện chỉ nằm trong phiên này, không được lưu làm lịch sử.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

