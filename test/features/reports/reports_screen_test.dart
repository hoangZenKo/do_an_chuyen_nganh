import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_room_management/core/theme/app_theme.dart';
import 'package:rental_room_management/features/auth/auth_providers.dart';
import 'package:rental_room_management/features/reports/reports_providers.dart';
import 'package:rental_room_management/features/reports/reports_screen.dart';
import 'package:rental_room_management/models/auth_models.dart';
import 'package:rental_room_management/models/reports.dart';

class _LandlordSession extends SessionController {
  @override
  SessionState build() => const SessionState.authenticated(AuthSession(
        user: LandlordUser(
            id: 'owner', fullName: 'Owner', email: 'owner@test.com'),
        accessToken: 'test',
        refreshToken: 'test',
      ));
}

final _report = MonthlyReport.fromJson({
  'month': '2026-10-01',
  'summary': {
    'activeLeases': 12,
    'invoiceCount': 12,
    'billedAmount': 36000000,
    'receivedAmount': 30000000,
    'outstandingAmount': 6000000,
    'expenseAmount': 5000000,
    'estimatedProfit': 25000000,
  },
  'invoices': [
    {
      'id': 'invoice',
      'roomName': 'A101',
      'tenantName': 'Tenant',
      'remainingAmount': 6000000,
    },
  ],
});

Future<void> _pumpReports(
  WidgetTester tester,
  ThemeData theme, {
  Future<MonthlyReport> Function()? loadReport,
  bool emptyReminders = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionControllerProvider.overrideWith(_LandlordSession.new),
      selectedReportMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
      monthlyReportProvider.overrideWith(
          (ref) async => loadReport == null ? _report : await loadReport()),
      billingRemindersProvider.overrideWith((ref) async => emptyReminders
          ? []
          : const [
              BillingReminder(
                id: 'reminder',
                kind: 'overdue',
                invoiceId: 'invoice',
                remainingAmount: 6000000,
                suggestedMessage: 'Payment reminder',
                roomName: 'A101',
                tenantName: 'Tenant',
              ),
            ]),
      billingReminderPolicyProvider.overrideWith((ref) async => {
            'policy': {
              'enabled': true,
              'beforeDays': [3, 1],
              'overdueDays': [1, 7, 30],
              'channels': ['IN_APP'],
            },
          }),
    ],
    child: MaterialApp(
      theme: theme,
      home: const ReportsScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void _expectReadableCards(WidgetTester tester) {
  final cards = tester.widgetList<Container>(find.byType(Container)).where(
        (widget) =>
            widget.padding == const EdgeInsets.all(16) &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).border != null,
      );
  expect(cards, isNotEmpty);
  final context = tester.element(find.byType(ReportsScreen));
  final colors = Theme.of(context).colorScheme;
  for (final card in cards) {
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, colors.surface);
    expect((decoration.border! as Border).top.color, colors.outline);
  }
  final paragraph = tester.renderObject<RenderParagraph>(
    find.text('Tổng hợp tháng'),
  );
  final foreground = paragraph.text.style!.color!;
  final background = colors.surface;
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  final contrast = light > dark
      ? (light + 0.05) / (dark + 0.05)
      : (dark + 0.05) / (light + 0.05);
  expect(contrast, greaterThanOrEqualTo(4.5));
}

void main() {
  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark
        ? AppTheme.dark
        : ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.teal));

    testWidgets('report cards follow the $brightness theme', (tester) async {
      await _pumpReports(tester, theme);
      await tester.pumpAndSettle();
      _expectReadableCards(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(
        ProviderScope.containerOf(tester.element(find.byType(ReportsScreen)))
            .read(selectedReportMonthProvider),
        DateTime(2026, 9),
      );

      await tester.ensureVisible(find.text('Cấu hình'));
      await tester.tap(find.text('Cấu hình'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading and error cards use the active surface', (tester) async {
    final pending = Completer<MonthlyReport>();
    await _pumpReports(tester, AppTheme.dark,
        loadReport: () => pending.future, emptyReminders: true);
    final loading = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(loading.color, AppTheme.dark.colorScheme.primary);
    pending.completeError(StateError('Report unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Report unavailable'), findsOneWidget);
    expect(find.text('Không có hóa đơn cần nhắc.'), findsOneWidget);
    final cards = tester.widgetList<Container>(find.byType(Container)).where(
          (widget) => widget.decoration is BoxDecoration,
        );
    for (final card in cards) {
      expect((card.decoration! as BoxDecoration).color,
          AppTheme.dark.colorScheme.surface);
    }
    expect(tester.takeException(), isNull);
  });
}
