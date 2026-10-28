import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/format.dart';
import '../../models/p1_operations.dart';
import '../listings/listing_widgets.dart';
import '../operations/p1_providers.dart';
import 'tenant_invoice_detail_screen.dart';
import 'tenant_portal_providers.dart';

class TenantOnlinePaymentScreen extends ConsumerStatefulWidget {
  const TenantOnlinePaymentScreen({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  ConsumerState<TenantOnlinePaymentScreen> createState() =>
      _TenantOnlinePaymentScreenState();
}

class _TenantOnlinePaymentScreenState
    extends ConsumerState<TenantOnlinePaymentScreen>
    with WidgetsBindingObserver {
  PaymentLinkInfo? _link;
  String? _demoInvoiceId;
  String? _error;
  bool _loading = true;
  bool _checking = false;
  bool _foreground = true;
  Timer? _timer;

  String get _invoiceId => _demoInvoiceId ?? widget.invoiceId;
  bool get _expired => _link?.expiresAt?.isBefore(DateTime.now()) ?? false;
  Uri? get _checkoutUri {
    final uri = Uri.tryParse(_link?.checkoutUrl ?? '');
    final base = Uri.tryParse(const String.fromEnvironment(
        'DEMO_PAYMENT_BASE_URL',
        defaultValue: ApiConfig.baseUrl));
    if (uri == null ||
        base == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.origin != base.origin ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(r'^/api/v1/payments/demo/checkout/[A-Za-z0-9_-]{43}$')
            .hasMatch(uri.path)) {
      return null;
    }
    return uri;
  }

  bool get _canPay =>
      _link?.provider == 'DEMO_CARD' &&
      _link?.demo == true &&
      _link?.invoiceIsDemo == true &&
      _link?.canPay == true &&
      _link?.status == 'pending' &&
      !_expired &&
      _link?.reviewRequired != true &&
      _link?.invoicePaid != true &&
      _link?.invoiceCancelled != true &&
      _checkoutUri != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_check());
    } else {
      _timer?.cancel();
    }
  }

  void _watch() {
    _timer?.cancel();
    if (mounted &&
        _foreground &&
        !_loading &&
        _link?.status == 'pending' &&
        !_expired &&
        _link?.invoicePaid != true &&
        _link?.invoiceCancelled != true) {
      _timer = Timer(const Duration(seconds: 5), () => unawaited(_check()));
    }
  }

  void _invalidateInvoice() {
    ref.invalidate(tenantPortalInvoiceProvider(_invoiceId));
    ref.invalidate(tenantPortalInvoicesProvider);
    ref.invalidate(tenantPortalDashboardProvider);
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      final api = ref.read(p1OperationsApiProvider);
      var link = await api.paymentStatus(_invoiceId);
      if (!mounted) return;
      if (link?.canCreateLink == true &&
          (link!.status == 'not_created' ||
              (link.status == 'pending' && link.checkoutUrl == null))) {
        link = await api.paymentLink(_invoiceId);
      }
      if (mounted) {
        setState(() {
          _link = link;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _watch();
      }
    }
  }

  Future<void> _createDemo() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Tạo hóa đơn kiểm thử?'),
                content: const Text(
                    'Tạo hóa đơn riêng 10.000đ để trải nghiệm thanh toán QR và thẻ. '
                    'Hóa đơn gốc và công nợ hiện tại không thay đổi. Không thu tiền thật.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Tạo hóa đơn'))
                ]));
    if (confirmed != true || !mounted || _loading || _checking) return;
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(p1OperationsApiProvider)
          .createDemoInvoice(widget.invoiceId);
      if (!mounted) return;
      _demoInvoiceId = id;
      _invalidateInvoice();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _watch();
      }
    }
  }

  Future<void> _create() async {
    if (_loading || _checking) return;
    _timer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final link =
          await ref.read(p1OperationsApiProvider).paymentLink(_invoiceId);
      if (mounted) setState(() => _link = link);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _watch();
      }
    }
  }

  Future<void> _check() async {
    if (_checking || _loading || !mounted) return;
    setState(() => _checking = true);
    try {
      final link =
          await ref.read(p1OperationsApiProvider).paymentStatus(_invoiceId);
      if (!mounted) return;
      setState(() {
        _link = link;
        _error = null;
      });
      if (link?.invoicePaid == true || (link?.paidAmount ?? 0) > 0) {
        _invalidateInvoice();
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        _watch();
      }
    }
  }

  Future<void> _openCheckout() async {
    if (!_canPay) return;
    try {
      if (!await launchUrl(_checkoutUri!,
              mode: LaunchMode.externalApplication) &&
          mounted) {
        setState(() => _error =
            'Không mở được trang thanh toán. Bạn có thể dùng camera điện thoại để quét QR.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Không mở được trang thanh toán. Kiểm tra kết nối mạng rồi thử lại.');
      }
    }
  }

  Future<void> _copyLink() async {
    if (!_canPay) return;
    try {
      await Clipboard.setData(ClipboardData(text: _checkoutUri.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã sao chép liên kết thanh toán.')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không sao chép được liên kết.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final paid = link?.invoiceIsDemo == true && link?.invoicePaid == true;
    return ListingTheme(
        child: Scaffold(
      appBar: AppBar(title: const Text('Thanh toán bằng thẻ')),
      body: SafeArea(
          child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0xFFFFF1CB),
                    borderRadius: BorderRadius.all(Radius.circular(12))),
                child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                        'Môi trường kiểm thử — không thu tiền thật.\nChỉ dùng thẻ được cung cấp, không nhập thẻ ngân hàng thật.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF634B13),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)))),
            const SizedBox(height: 24),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else if (paid) ...[
              const Icon(Icons.verified_rounded,
                  size: 64, color: Color(0xFF176B52)),
              const SizedBox(height: 16),
              const Text('Thanh toán thành công',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                  'Hóa đơn kiểm thử đã được cập nhật. Bạn có thể xem lại chi tiết giao dịch trong ứng dụng.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: () {
                    _invalidateInvoice();
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => TenantInvoiceDetailScreen(
                                invoiceId: _invoiceId)));
                  },
                  child: const Text('Xem hóa đơn')),
            ] else if (link?.invoiceCancelled == true) ...[
              const Text('Hóa đơn đã hủy', textAlign: TextAlign.center),
            ] else if (link?.reviewRequired == true) ...[
              const Text('Đang chờ đối soát', textAlign: TextAlign.center),
            ] else ...[
              Text(
                  formatCurrencyVnd(link?.remainingAmount ?? link?.amount ?? 0),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800)),
              if ((link?.paidAmount ?? 0) > 0)
                Text('Đã ghi nhận ${formatCurrencyVnd(link!.paidAmount!)}.',
                    textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (_canPay) ...[
                LayoutBuilder(
                    builder: (context, constraints) => Center(
                        child: Semantics(
                            label: 'QR mở trang thanh toán',
                            child: QrImageView(
                                data: _checkoutUri.toString(),
                                size: math.min(250, constraints.maxWidth),
                                backgroundColor: Colors.white)))),
                const SizedBox(height: 16),
                const Text(
                    'Quét bằng camera điện thoại để mở trang thanh toán.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                const SelectableText(
                    'Thẻ kiểm thử: 4242 4242 4242 4242\nHết hạn: 12/34 · CVC: 123',
                    textAlign: TextAlign.center),
                if (link?.expiresAt != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          'Hiệu lực đến ${formatDate(link!.expiresAt!.toLocal())} ${TimeOfDay.fromDateTime(link.expiresAt!.toLocal()).format(context)}',
                          textAlign: TextAlign.center)),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: _openCheckout,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở trang thanh toán')),
                TextButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy),
                    label: const Text('Sao chép liên kết thanh toán')),
              ] else ...[
                Text(
                    link?.unavailableReason ??
                        (_expired
                            ? 'Phiên đã hết hạn. Tạo mã QR mới để tiếp tục.'
                            : 'Chưa có mã QR còn hiệu lực cho dư nợ hiện tại.'),
                    textAlign: TextAlign.center),
                if (link?.canPay == true && _checkoutUri == null)
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                          'Chưa kết nối được đến trang thanh toán. Vui lòng kiểm tra cấu hình kết nối.',
                          textAlign: TextAlign.center)),
                const SizedBox(height: 12),
                if (link?.canCreateDemoInvoice == true)
                  FilledButton(
                      onPressed: _createDemo,
                      child: const Text('Tạo hóa đơn kiểm thử')),
                if (link?.canCreateLink == true)
                  FilledButton(
                      onPressed: _create,
                      child: const Text('Tạo QR cho số tiền còn lại')),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Kiểm tra thanh toán')),
              const SizedBox(height: 16),
              const Text(
                  'Hóa đơn chỉ cập nhật sau khi giao dịch được xác nhận. Quét QR hoặc mở trang thanh toán chưa hoàn tất thanh toán.',
                  textAlign: TextAlign.center),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_link == null)
                TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      unawaited(_load());
                    },
                    child: const Text('Thử lại')),
            ],
          ]),
        ),
      )),
    ));
  }
}
