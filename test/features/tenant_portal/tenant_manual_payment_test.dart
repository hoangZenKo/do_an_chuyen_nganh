import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/data/billing/manual_transfer_api.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/billing/transfer_account_dialog.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_manual_payment_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_invoice_detail_screen.dart';
import 'package:rental_room_management/features/tenant_portal/tenant_portal_providers.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/billing.dart';

final identity = StateProvider<String?>((ref) => 'user');
const recipient = TransferAccount(
    version: 2,
    enabled: true,
    bankName: 'Bank test',
    accountName: 'TEST OWNER',
    accountNumber: '0012345678');
final invoice = Invoice(
    id: 'invoice',
    leaseId: 'lease',
    roomId: 'room',
    tenantId: 'tenant',
    billingMonth: DateTime(2026, 10),
    rentAmount: 10000,
    electricityAmount: 0,
    waterAmount: 0,
    otherAmount: 0,
    totalAmount: 10000,
    paidAmount: 0,
    remainingAmount: 10000,
    status: InvoiceStatus.unpaid);

class Session extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
      user: LandlordUser(
          id: 'user',
          fullName: 'Owner',
          email: 'owner@test.local',
          role: 'landlord'),
      accessToken: 'access',
      refreshToken: 'refresh'));
}

class Api extends ManualTransferApi {
  Api() : super(Dio());
  TransferAccount? saved;
  Completer<TransferAccount>? delayed;
  bool conflict = false;
  @override
  Future<TransferAccount> account(String propertyId) async =>
      delayed == null ? accountValue : delayed!.future;
  TransferAccount get accountValue => recipient;
  @override
  Future<TransferAccount> save(String propertyId, TransferAccount value) async {
    saved = value;
    if (conflict) throw StateError('Conflict: reload');
    return value;
  }
}

Future<ProviderContainer> mount(WidgetTester tester,
    {bool pending = false,
    bool configured = true,
    Api? api,
    Size size = const Size(1000, 1100),
    double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(overrides: [
    sessionIdentityProvider.overrideWith((ref) => ref.watch(identity)),
    sessionControllerProvider.overrideWith(Session.new),
    if (api != null) manualTransferApiProvider.overrideWithValue(api),
    transferInstructionsProvider.overrideWith((ref, id) async =>
        TransferInstructions(
            reference: 'HD invoice',
            remainingAmount: 10000,
            pendingAmount: pending ? 10000 : 0,
            availableAmount: pending ? 0 : 10000,
            canSubmit: !pending && configured,
            account: configured ? recipient : null)),
    tenantPortalInvoiceProvider.overrideWith((ref, id) async => invoice),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: api == null
            ? const TenantManualPaymentScreen(invoiceId: 'invoice')
            : Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        child: const Text('Configure'),
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => const TransferAccountDialog(
                                propertyId: 'property'))))),
      )));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
      'shows bank instructions and explicitly does not promise an automatic debit',
      (tester) async {
    await mount(tester);
    expect(find.text('0012345678'), findsOneWidget);
    expect(find.text('HD invoice'), findsOneWidget);
    expect(find.textContaining('không tự trừ tiền'), findsOneWidget);
    expect(find.textContaining('4242'), findsNothing);
  });
  testWidgets('fully reserved pending balance hides the transfer-proof action',
      (tester) async {
    await mount(tester, pending: true);
    expect(find.textContaining('Đang chờ chủ trọ xác nhận:'), findsOneWidget);
    expect(find.text('Tôi đã chuyển tiền — gửi chứng từ'), findsNothing);
  });
  testWidgets(
      'missing recipient never fabricates account details or a payable button',
      (tester) async {
    await mount(tester, configured: false);
    expect(
        find.textContaining('Chưa có thông tin chuyển khoản'), findsOneWidget);
    expect(find.text('0012345678'), findsNothing);
    expect(find.text('Tôi đã chuyển tiền — gửi chứng từ'), findsNothing);
  });
  testWidgets(
      'opens the existing pending proof flow without accepting a card or updating debt',
      (tester) async {
    await mount(tester);
    await tester.ensureVisible(find.text('Tôi đã chuyển tiền — gửi chứng từ'));
    await tester.tap(find.text('Tôi đã chuyển tiền — gửi chứng từ'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi chứng từ thanh toán'), findsOneWidget);
    expect(find.textContaining('chưa ghi nhận đã thu tiền'), findsOneWidget);
    expect(find.text('Phương thức thanh toán'), findsNothing);
    await tester.tap(find.text('Gửi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Upload ít nhất'), findsOneWidget);
    expect(invoice.paidAmount, 0);
  });
  testWidgets(
      'focused proof dialog closes without disposing fields during its transition',
      (tester) async {
    await mount(tester);
    await tester.ensureVisible(find.text('Tôi đã chuyển tiền — gửi chứng từ'));
    await tester.tap(find.text('Tôi đã chuyển tiền — gửi chứng từ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, 'Ghi chú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi chứng từ thanh toán'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'an old transfer page stays invalid after switching away and back',
      (tester) async {
    final container = await mount(tester);
    container.read(identity.notifier).state = 'other';
    await tester.pumpAndSettle();
    expect(find.textContaining('Phiên đã thay đổi'), findsOneWidget);
    container.read(identity.notifier).state = 'user';
    await tester.pumpAndSettle();
    expect(find.text('0012345678'), findsNothing);
  });
  testWidgets('recipient editor preserves leading zeros and the read version',
      (tester) async {
    final api = Api();
    await mount(tester, api: api);
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu tài khoản'));
    await tester.pumpAndSettle();
    expect(api.saved?.accountNumber, '0012345678');
    expect(api.saved?.version, 2);
  });

  testWidgets(
      'account switch clears an already open proof form and cannot resurrect it',
      (tester) async {
    final container = await mount(tester);
    await tester.ensureVisible(find.text('Tôi đã chuyển tiền — gửi chứng từ'));
    await tester.tap(find.text('Tôi đã chuyển tiền — gửi chứng từ'));
    await tester.pumpAndSettle();
    container.read(identity.notifier).state = 'other';
    await tester.pumpAndSettle();
    expect(find.text('Gửi chứng từ thanh toán'), findsNothing);
    expect(find.text('Gửi'), findsNothing);
    container.read(identity.notifier).state = 'user';
    await tester.pumpAndSettle();
    expect(find.text('Gửi chứng từ thanh toán'), findsNothing);
  });

  testWidgets(
      'real invoice enters manual transfer and never exposes the fake card action',
      (tester) async {
    await mount(tester);
    final element = tester.element(find.byType(TenantManualPaymentScreen));
    Navigator.of(element).push(MaterialPageRoute<void>(
        builder: (_) => const TenantInvoiceDetailScreen(invoiceId: 'invoice')));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán chuyển khoản'), findsWidgets);
    expect(find.text('Thử thanh toán thẻ (không trừ tiền)'), findsNothing);
    expect(find.text('Thanh toán bằng thẻ'), findsNothing);
  });
  testWidgets('ambiguous account write forces a fresh read before saving again',
      (tester) async {
    final api = Api()..conflict = true;
    await mount(tester, api: api);
    await tester.tap(find.text('Configure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu tài khoản'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Lưu tài khoản'))
            .onPressed,
        isNull);
    expect(find.text('Tải lại thông tin'), findsOneWidget);
  });
  testWidgets('recipient editor discards a late load after account switch',
      (tester) async {
    final delayed = Completer<TransferAccount>();
    final api = Api()..delayed = delayed;
    final container = await mount(tester, api: api);
    await tester.tap(find.text('Configure'));
    await tester.pump();
    container.read(identity.notifier).state = 'other';
    await tester.pump();
    delayed.complete(recipient);
    await tester.pumpAndSettle();
    expect(find.text('Phiên đã thay đổi'), findsOneWidget);
    expect(find.text('0012345678'), findsNothing);
  });
  testWidgets('320px with large text has no layout exception', (tester) async {
    await mount(tester, size: const Size(320, 900), scale: 2);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
