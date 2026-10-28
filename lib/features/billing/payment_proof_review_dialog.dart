import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../models/tenant_portal.dart';
import '../auth/auth_providers.dart';
import 'billing_providers.dart';

Future<void> showReviewPaymentProofDialog(
  BuildContext context,
  PaymentProof proof,
  String status,
) =>
    showDialog<void>(
      context: context,
      builder: (_) => _PaymentProofReviewDialog(proof: proof, status: status),
    );

class _PaymentProofReviewDialog extends ConsumerStatefulWidget {
  const _PaymentProofReviewDialog({required this.proof, required this.status});

  final PaymentProof proof;
  final String status;

  @override
  ConsumerState<_PaymentProofReviewDialog> createState() =>
      _PaymentProofReviewDialogState();
}

class _PaymentProofReviewDialogState
    extends ConsumerState<_PaymentProofReviewDialog> {
  late final String? owner;
  var invalidated = false;
  final note = TextEditingController();
  String? error;
  var loading = false;
  var confirmedFunds = false;

  @override
  void initState() {
    super.initState();
    owner = ref.read(sessionIdentityProvider);
    ref.listenManual(sessionIdentityProvider, (_, next) {
      if (next != owner) invalidated = true;
    });
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proof = widget.proof;
    final status = widget.status;
    final approving = status == 'approved';
    final dialogContext = context;
    return AlertDialog(
      title: Text(approving ? 'Duyệt chứng từ' : 'Từ chối chứng từ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${proof.tenantName ?? 'Tenant'} · ${proof.roomName ?? 'Phòng'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatCurrencyVnd(proof.amount)} · ${switch (proof.method) {
                'bank_transfer' || 'bankTransfer' => 'Chuyển khoản',
                'cash' => 'Tiền mặt',
                'other' => 'Khác',
                _ => proof.method
              }}',
              style: const TextStyle(color: Color(0xFF8891A8)),
            ),
            const SizedBox(height: 12),
            if (approving)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                    'Tôi đã kiểm tra và nhận đủ khoản tiền này trong tài khoản ngân hàng hoặc bằng tiền mặt.'),
                subtitle: const Text(
                    'Ảnh chứng từ không tự chứng minh tiền đã vào tài khoản. Duyệt sẽ ghi nhận khoản thu và giảm công nợ.'),
                value: confirmedFunds,
                onChanged: loading
                    ? null
                    : (value) => setState(() => confirmedFunds = value == true),
              ),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText:
                    approving ? 'Ghi chú cho thanh toán' : 'Lý do từ chối',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(dialogContext),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: loading || (approving && !confirmedFunds)
              ? null
              : () async {
                  if (invalidated ||
                      owner == null ||
                      ref.read(sessionIdentityProvider) != owner) {
                    setState(() => error =
                        'Phiên đã thay đổi. Đóng và mở lại danh sách chứng từ.');
                    return;
                  }
                  if (!approving && note.text.trim().isEmpty) {
                    setState(() => error = 'Nhập lý do từ chối.');
                    return;
                  }
                  setState(() {
                    loading = true;
                    error = null;
                  });
                  try {
                    await ref
                        .read(billingPaymentControllerProvider.notifier)
                        .reviewPaymentProof(
                          proofId: proof.id,
                          invoiceId: proof.invoiceId,
                          status: status,
                          note: note.text,
                        );
                    if (invalidated || !dialogContext.mounted) return;
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            approving
                                ? 'Đã duyệt chứng từ thanh toán.'
                                : 'Đã từ chối chứng từ thanh toán.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (invalidated || !dialogContext.mounted) return;
                    setState(() {
                      loading = false;
                      error = '$e';
                    });
                  }
                },
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(approving ? 'Duyệt' : 'Từ chối'),
        ),
      ],
    );
  }
}
