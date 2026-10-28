import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../data/billing/manual_transfer_api.dart';
import '../auth/auth_providers.dart';
import '../listings/listing_widgets.dart';
import 'tenant_payment_proof_dialog.dart';
import 'tenant_portal_providers.dart';

class TenantManualPaymentScreen extends ConsumerStatefulWidget {
  const TenantManualPaymentScreen({super.key, required this.invoiceId});
  final String invoiceId;
  @override
  ConsumerState<TenantManualPaymentScreen> createState() =>
      _TenantManualPaymentScreenState();
}

class _TenantManualPaymentScreenState
    extends ConsumerState<TenantManualPaymentScreen> {
  late final String? _owner;
  bool _invalidated = false;
  bool _openingProof = false;
  @override
  void initState() {
    super.initState();
    _owner = ref.read(sessionIdentityProvider);
  }

  void _refresh() {
    ref.invalidate(transferInstructionsProvider(widget.invoiceId));
    ref.invalidate(tenantPortalInvoiceProvider(widget.invoiceId));
    ref.invalidate(tenantPortalInvoicesProvider);
    ref.invalidate(tenantPortalDashboardProvider);
  }

  Future<void> _openProof(TransferInstructions instructions) async {
    if (_openingProof ||
        _invalidated ||
        ref.read(sessionIdentityProvider) != _owner) {
      return;
    }
    setState(() => _openingProof = true);
    try {
      final invoice =
          await ref.read(tenantPortalInvoiceProvider(widget.invoiceId).future);
      if (!mounted ||
          _invalidated ||
          ref.read(sessionIdentityProvider) != _owner) {
        return;
      }
      if (invoice.isDemo || invoice.remainingAmount <= 0) {
        _refresh();
        return;
      }
      await showTenantPaymentProofDialog(context, ref, invoice,
          initialAmount: instructions.availableAmount,
          reference: instructions.reference,
          bankTransferOnly: true);
      if (mounted && ref.read(sessionIdentityProvider) == _owner) _refresh();
    } catch (error) {
      if (mounted && ref.read(sessionIdentityProvider) == _owner) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không mở được chứng từ: $error')));
      }
    } finally {
      if (mounted) setState(() => _openingProof = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionIdentityProvider) != _owner || _owner == null) {
      _invalidated = true;
    }
    return ListingTheme(
        child: Scaffold(
      backgroundColor: kAirbnbSurface,
      appBar: AppBar(title: const Text('Thanh toán chuyển khoản')),
      body: _invalidated
          ? const Center(
              child: Text('Phiên đã thay đổi. Đóng và mở lại hóa đơn.'))
          : ref.watch(transferInstructionsProvider(widget.invoiceId)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$error'),
                              TextButton(
                                  onPressed: _refresh,
                                  child: const Text('Thử lại'))
                            ]))),
                data: (instructions) => RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20, 20, 20,
                            20 + MediaQuery.paddingOf(context).bottom),
                        children: [
                          Text(formatCurrencyVnd(instructions.remainingAmount),
                              style: const TextStyle(
                                  fontSize: 30, fontWeight: FontWeight.w900)),
                          const Text('Dư nợ chưa được xác nhận thu'),
                          const SizedBox(height: 16),
                          const Text(
                              '1. Chuyển khoản bằng app ngân hàng\n2. Gửi chứng từ sau khi chuyển tiền\n3. Chờ chủ trọ kiểm tra và xác nhận',
                              style: TextStyle(height: 1.8)),
                          const SizedBox(height: 16),
                          const Text(
                              'Ứng dụng không tự trừ tiền và không tự xác minh số dư ngân hàng. Không nhập số thẻ, CVC, mật khẩu hoặc OTP tại đây.'),
                          if (instructions.pendingAmount > 0) ...[
                            const SizedBox(height: 16),
                            Text(
                                'Đang chờ chủ trọ xác nhận: ${formatCurrencyVnd(instructions.pendingAmount)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const Text(
                                'Chứng từ chưa làm giảm công nợ. Không chuyển lại khoản tiền đang chờ xác nhận.'),
                          ],
                          const SizedBox(height: 20),
                          if (instructions.account case final account?) ...[
                            _copyRow('Ngân hàng', account.bankName),
                            _copyRow('Chủ tài khoản', account.accountName),
                            _copyRow('Số tài khoản', account.accountNumber),
                            _copyRow('Nội dung chuyển khoản',
                                instructions.reference),
                            const Text(
                                'Đối chiếu tên người nhận trong app ngân hàng trước khi chuyển. Ảnh QR do chủ trọ cung cấp; số tiền và nội dung có thể cần nhập lại.'),
                            if (instructions.canSubmit &&
                                account.qrImagePath != null)
                              _PrivateBankQr(path: account.qrImagePath!),
                          ] else if (instructions.remainingAmount > 0 &&
                              instructions.pendingAmount == 0)
                            const Text(
                                'Chưa có thông tin chuyển khoản khả dụng. Liên hệ chủ trọ; không chuyển tiền theo tài khoản không được xác nhận.'),
                          if (instructions.canSubmit) ...[
                            const SizedBox(height: 16),
                            Text(
                                'Số tiền chưa có chứng từ chờ duyệt: ${formatCurrencyVnd(instructions.availableAmount)}'),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                                icon: const Icon(Icons.upload_file_outlined),
                                label: const Text(
                                    'Tôi đã chuyển tiền — gửi chứng từ'),
                                onPressed: _openingProof
                                    ? null
                                    : () => _openProof(instructions)),
                          ],
                          if (instructions.remainingAmount == 0)
                            const Text(
                                'Hóa đơn không còn dư nợ cần thanh toán.'),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh),
                              label:
                                  const Text('Kiểm tra trạng thái xác nhận')),
                        ])),
              ),
    ));
  }

  Widget _copyRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: kAirbnbMuted)),
          SelectableText(value,
              style: const TextStyle(fontWeight: FontWeight.w800))
        ])),
        IconButton(
            tooltip: 'Sao chép $label',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              if (_invalidated || ref.read(sessionIdentityProvider) != _owner) {
                return;
              }
              await Clipboard.setData(ClipboardData(text: value));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã sao chép $label')));
              }
            }),
      ]));
}

class _PrivateBankQr extends ConsumerStatefulWidget {
  const _PrivateBankQr({required this.path});
  final String path;
  @override
  ConsumerState<_PrivateBankQr> createState() => _PrivateBankQrState();
}

class _PrivateBankQrState extends ConsumerState<_PrivateBankQr> {
  late Future<String> _url;
  @override
  void initState() {
    super.initState();
    _url = ref.read(uploadApiProvider).accessUrl(widget.path);
  }

  @override
  void didUpdateWidget(covariant _PrivateBankQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _url = ref.read(uploadApiProvider).accessUrl(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: FutureBuilder<String>(
          future: _url,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                  onPressed: () => setState(() => _url =
                      ref.read(uploadApiProvider).accessUrl(widget.path)),
                  child: const Text('Tải lại ảnh QR'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Image.network(snapshot.data!,
                height: 260,
                fit: BoxFit.contain,
                semanticLabel: 'Ảnh QR ngân hàng do chủ trọ cung cấp',
                errorBuilder: (_, __, ___) => const Text(
                    'Không hiển thị được QR. Dùng thông tin tài khoản ở trên.'));
          }));
}
