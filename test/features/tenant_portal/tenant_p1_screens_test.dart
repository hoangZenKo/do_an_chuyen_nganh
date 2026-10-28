import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rental_room_management/core/network/api_failure.dart';
import 'package:rental_room_management/data/operations/p1_operations_api.dart';
import 'package:rental_room_management/features/operations/p1_providers.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_announcements_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_online_payment_screen.dart';
import 'package:rental_room_management/models/p1_operations.dart';

class _Api extends P1OperationsApi {
  _Api() : super(Dio());
  bool unavailable = false;
  bool reviewRequired = false;
  bool partialPayment = false;
  bool cancelled = false;
  bool invoiceIsDemo = true;
  String checkoutUrl =
      'http://localhost:3000/api/v1/payments/demo/checkout/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final demoSources = <String>[];
  final statusInvoices = <String>[];
  String status = 'pending';
  int creations = 0;
  int statusReads = 0;
  int acknowledgements = 0;
  List<AnnouncementItem> notices = [];

  PaymentLinkInfo get link => PaymentLinkInfo(
      status: status,
      provider: 'DEMO_CARD',
      demo: true,
      invoiceIsDemo: invoiceIsDemo,
      canCreateDemoInvoice: !invoiceIsDemo,
      amount: 3500000,
      checkoutUrl: checkoutUrl,
      qrCode: 'test-payment-qr',
      bankBin: '970422',
      accountName: 'TEST BANK',
      accountNumber: '123456789',
      description: 'HD123456',
      invoiceStatus: cancelled
          ? 'cancelled'
          : partialPayment
              ? 'partial'
              : status == 'paid'
                  ? 'paid'
                  : 'unpaid',
      paidAmount: partialPayment
          ? 500000
          : status == 'paid'
              ? 3500000
              : 0,
      remainingAmount: partialPayment
          ? 3000000
          : status == 'paid'
              ? 0
              : 3500000,
      reviewRequired: reviewRequired,
      canPay:
          invoiceIsDemo && !reviewRequired && !cancelled && status == 'pending',
      canCreateLink: invoiceIsDemo &&
          !reviewRequired &&
          !cancelled &&
          (partialPayment || status != 'paid'),
      expiresAt: DateTime.now().add(const Duration(minutes: 30)));

  @override
  Future<PaymentLinkInfo> paymentLink(String invoiceId) async {
    creations++;
    if (unavailable) {
      throw const ApiFailure(
          message: 'Thanh toán trực tuyến đang tắt trên backend.');
    }
    return link;
  }

  @override
  Future<PaymentLinkInfo?> paymentStatus(String invoiceId) async {
    statusInvoices.add(invoiceId);
    if (unavailable) {
      throw const ApiFailure(
          message: 'Thanh toán trực tuyến đang tắt trên backend.');
    }
    statusReads++;
    return link;
  }

  @override
  Future<String> createDemoInvoice(String invoiceId) async {
    demoSources.add(invoiceId);
    invoiceIsDemo = true;
    return 'separate-demo-invoice';
  }

  @override
  Future<List<AnnouncementItem>> announcements({bool tenant = false}) async =>
      notices;

  @override
  Future<void> markAnnouncementRead(String id) async {
    acknowledgements++;
    notices = [
      AnnouncementItem(
          id: id,
          title: 'Lịch vệ sinh',
          body: 'Vệ sinh khu vực chung vào sáng mai.',
          status: 'sent',
          sendAt: DateTime.now(),
          readAt: DateTime.now())
    ];
  }
}

Future<void> _mount(WidgetTester tester, _Api api, Widget screen) async {
  await tester.pumpWidget(ProviderScope(
      overrides: [p1OperationsApiProvider.overrideWithValue(api)],
      child: MaterialApp(home: screen)));
  await tester.pumpAndSettle();
}

void main() {
  for (final url in [
    'https://evil.example/api/v1/payments/demo/checkout/${'a' * 43}',
    'javascript:alert(1)',
    'http://localhost:3000/api/v1/payments/demo/checkout/invalid',
  ]) {
    testWidgets('hides QR for untrusted checkout URL $url', (tester) async {
      final api = _Api()..checkoutUrl = url;
      await _mount(
          tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Mở trang thanh toán'), findsNothing);
      expect(find.textContaining('Chưa kết nối được đến trang thanh toán.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'requires explicit confirmation before creating a separate test invoice',
      (tester) async {
    final api = _Api()..invoiceIsDemo = false;
    await _mount(tester, api,
        const TenantOnlinePaymentScreen(invoiceId: 'real-invoice'));
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.text('Tạo hóa đơn kiểm thử'));
    await tester.pumpAndSettle();
    expect(api.demoSources, isEmpty);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(api.demoSources, isEmpty);
    await tester.tap(find.text('Tạo hóa đơn kiểm thử'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo hóa đơn'));
    await tester.pumpAndSettle();
    expect(api.demoSources, ['real-invoice']);
    expect(api.statusInvoices.last, 'separate-demo-invoice');
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 430.0, 1280.0]) {
    testWidgets(
        'payment QR fits width $width and stays pending without webhook',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      await _mount(
          tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Thanh toán thành công'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(api.statusReads, 2);
      expect(find.text('Thanh toán thành công'), findsNothing);
      api.status = 'paid';
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Thanh toán thành công'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      final readsAfterPayment = api.statusReads;
      await tester.pump(const Duration(seconds: 10));
      expect(api.statusReads, readsAfterPayment);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('missing merchant configuration cannot display a payable QR',
      (tester) async {
    final api = _Api()..unavailable = true;
    await _mount(
        tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
    expect(find.text('Thanh toán trực tuyến đang tắt trên backend.'),
        findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Thanh toán thành công'), findsNothing);
  });

  testWidgets('payment polling stops while the application is paused',
      (tester) async {
    final api = _Api();
    await _mount(
        tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(api.statusReads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(api.statusReads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'payment uses product copy and retains the test environment notice',
      (tester) async {
    await _mount(tester, _Api(),
        const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
    expect(find.text('Thanh toán bằng thẻ'), findsOneWidget);
    expect(find.textContaining(RegExp('demo', caseSensitive: false)),
        findsNothing);
    expect(find.textContaining('Môi trường kiểm thử — không thu tiền thật.'),
        findsOneWidget);
    expect(find.textContaining('4242 4242 4242 4242'), findsOneWidget);
    expect(find.text('TEST BANK'), findsNothing);
    expect(find.text('123456789'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Mở trang thanh toán'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mở trang thanh toán'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reopening a paid invoice does not create another checkout',
      (tester) async {
    final api = _Api()..status = 'paid';
    await _mount(
        tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(api.creations, 0);
    await tester.pump(const Duration(seconds: 20));
    expect(api.statusReads, 1);
  });

  testWidgets(
      'a paid payment link with a remaining balance is not paid in full',
      (tester) async {
    final api = _Api()
      ..status = 'paid'
      ..partialPayment = true;
    await _mount(
        tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
    expect(find.text('Thanh toán thành công'), findsNothing);
    expect(find.textContaining('Đã ghi nhận'), findsOneWidget);
    expect(find.text('Tạo QR cho số tiền còn lại'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(api.creations, 0);
  });

  testWidgets('review-required transfers hide QR and prevent another payment',
      (tester) async {
    final api = _Api()..reviewRequired = true;
    await _mount(
        tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
    expect(find.text('Đang chờ đối soát'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Tạo QR cho số tiền còn lại'), findsNothing);
    expect(find.text('Thanh toán thành công'), findsNothing);
    expect(api.creations, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cancelled invoices cannot show a payable QR', (tester) async {
    final api = _Api()..cancelled = true;
    await _mount(
        tester, api, const TenantOnlinePaymentScreen(invoiceId: 'invoice-1'));
    expect(find.text('Hóa đơn đã hủy'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Tạo QR cho số tiền còn lại'), findsNothing);
    expect(api.creations, 0);
  });

  testWidgets('tenant acknowledges an announcement only on explicit action',
      (tester) async {
    final api = _Api()
      ..notices = [
        AnnouncementItem(
            id: 'notice-1',
            title: 'Lịch vệ sinh',
            body: 'Vệ sinh khu vực chung vào sáng mai.',
            status: 'sent',
            sendAt: DateTime.now())
      ];
    await _mount(tester, api, const TenantAnnouncementsScreen());
    expect(find.textContaining('Chưa xác nhận'), findsOneWidget);
    await tester.tap(find.text('Lịch vệ sinh'));
    await tester.pumpAndSettle();
    expect(find.text('Vệ sinh khu vực chung vào sáng mai.'), findsOneWidget);
    expect(api.acknowledgements, 0);
    await tester.tap(find.text('Xác nhận đã đọc'));
    await tester.pumpAndSettle();
    expect(api.acknowledgements, 1);
    expect(find.textContaining('Đã xác nhận'), findsOneWidget);
  });

  testWidgets('empty announcement inbox explains its state', (tester) async {
    await _mount(tester, _Api(), const TenantAnnouncementsScreen());
    expect(find.text('Chưa có thông báo từ chủ trọ.'), findsOneWidget);
  });
}
