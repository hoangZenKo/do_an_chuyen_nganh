import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/format.dart';
import '../operations/p1_providers.dart';

class PaymentEventsScreen extends ConsumerStatefulWidget {
  const PaymentEventsScreen({super.key, required this.invoiceId});
  final String invoiceId;
  @override
  ConsumerState<PaymentEventsScreen> createState() =>
      _PaymentEventsScreenState();
}

class _PaymentEventsScreenState extends ConsumerState<PaymentEventsScreen> {
  late Future<List<Map<String, dynamic>>> _events =
      ref.read(p1OperationsApiProvider).paymentEvents(widget.invoiceId);
  void _reload() => setState(() => _events =
      ref.read(p1OperationsApiProvider).paymentEvents(widget.invoiceId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar:
            AppBar(title: const Text('Lịch sử thanh toán online'), actions: [
          IconButton(
              tooltip: 'Tải lại',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded))
        ]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${snapshot.error}', textAlign: TextAlign.center),
                  TextButton(onPressed: _reload, child: const Text('Thử lại'))
                ]));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = snapshot.data!;
              return ListView(padding: const EdgeInsets.all(20), children: [
                const Text(
                    'Mã DEMO là xác nhận mô phỏng nội bộ, không có tiền thật. Giao dịch ngân hàng cũ chỉ lưu để tra cứu; cổng demo không tự xử lý hoặc phân bổ các giao dịch này.',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 20),
                if (events.isEmpty)
                  const Text(
                      'Chưa có xác nhận thanh toán online cho hóa đơn này.'),
                ...events.map((event) {
                  final review = event['status'] == 'REVIEW_REQUIRED';
                  final reason = event['reason'] as String?;
                  return Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    formatCurrencyVnd(
                                        (event['amount'] as num).toInt()),
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                Text(
                                    '${(event['reference'] as String).startsWith('demo-') ? 'DEMO · ' : ''}Mã giao dịch: ${event['reference']}'),
                                Text(review
                                    ? 'Cần kiểm tra: ${_reason(reason)}'
                                    : 'Đã đối soát'),
                              ])));
                })
              ]);
            }));
  }
}

String _reason(String? reason) => switch (reason) {
      'AMOUNT_MISMATCH' => 'Số tiền không khớp mã QR',
      'EXCEEDS_BALANCE' => 'Số tiền vượt dư nợ hiện tại',
      'INVOICE_CANCELLED' => 'Hóa đơn đã hủy',
      'PROVIDER_ID_MISMATCH' => 'Liên kết không khớp',
      'ACCOUNT_MISMATCH' => 'Tài khoản ngân hàng không khớp',
      'LINK_ALREADY_PAID' => 'Liên kết đã được thanh toán trước đó',
      _ => 'Cần xác minh với ngân hàng'
    };
