import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/format.dart';
import '../../models/billing.dart';

Future<Uint8List> buildInvoicePdf(Invoice invoice) async {
  final document = pw.Document();
  final theme = await _buildTheme();
  final logo = await _loadLogo();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: theme,
      build: (context) => [
        _header(invoice, logo),
        pw.SizedBox(height: 22),
        _parties(invoice),
        pw.SizedBox(height: 18),
        _amountTable(invoice),
        pw.SizedBox(height: 18),
        _paymentSummary(invoice),
        if (invoice.payments.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _paymentHistory(invoice),
        ],
        if (invoice.note != null && invoice.note!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _note(
            'Ghi chú',
            invoice.isDemo && invoice.note!.startsWith('DEMO CARD -')
                ? 'Hóa đơn kiểm thử, không phát sinh công nợ thực tế.'
                : invoice.note!,
          ),
        ],
        if (invoice.status == InvoiceStatus.cancelled) ...[
          pw.SizedBox(height: 18),
          _note(
            'Thông tin hủy',
            [
              if (invoice.cancelledAt != null)
                'Ngày hủy: ${formatDate(invoice.cancelledAt)}',
              if (invoice.cancelledNote != null)
                'Lý do: ${invoice.cancelledNote}',
            ].join('\n'),
          ),
        ],
        pw.SizedBox(height: 24),
        _footer(),
      ],
    ),
  );

  return document.save();
}

Future<void> shareInvoicePdf(Invoice invoice) async {
  final bytes = await buildInvoicePdf(invoice);
  await Printing.sharePdf(bytes: bytes, filename: invoicePdfFileName(invoice));
}

String invoicePdfFileName(Invoice invoice) {
  final room = _safeFilePart(invoice.roomName ?? invoice.roomId);
  final month = invoice.billingMonth == null
      ? 'unknown'
      : '${invoice.billingMonth!.year}-${invoice.billingMonth!.month.toString().padLeft(2, '0')}';
  return 'hoa-don-$room-$month.pdf';
}

Future<pw.ThemeData> _buildTheme() async {
  try {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: italic,
    );
  } catch (_) {
    return pw.ThemeData.base();
  }
}

Future<pw.MemoryImage?> _loadLogo() async {
  try {
    final data = await rootBundle.load('assets/images/atrium_living_logo.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

pw.Widget _header(Invoice invoice, pw.MemoryImage? logo) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (logo != null)
        pw.Container(
          width: 54,
          height: 54,
          margin: const pw.EdgeInsets.only(right: 14),
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Atrium Living',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              invoice.propertyName ?? 'Quản lý khu trọ',
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.blueGrey600,
              ),
            ),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'HÓA ĐƠN',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 5),
          if (invoice.isDemo) ...[
            pw.Text(
              'Bản kiểm thử - Không dùng để đối soát công nợ',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 5),
          ],
          _statusPill(invoice.status),
          pw.SizedBox(height: 8),
          pw.Text(
            'Tháng ${formatMonth(invoice.billingMonth)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _parties(Invoice invoice) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: _boxDecoration(),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _infoBlock(
            'Khách thuê',
            [
              invoice.tenantName ?? 'Khách thuê',
              'Phòng ${invoice.roomName ?? invoice.roomId}',
              if (invoice.propertyName != null) invoice.propertyName!,
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: _infoBlock(
            'Thông tin hóa đơn',
            [
              'Ngày lập: ${formatDate(invoice.issuedAt)}',
              'Hạn thanh toán: ${formatDate(invoice.dueDate)}',
              'Mã hóa đơn: ${invoice.id}',
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _amountTable(Invoice invoice) {
  final rows = <_AmountLine>[
    _AmountLine('Tiền phòng', invoice.rentAmount),
    _AmountLine('Điện', invoice.electricityAmount),
    _AmountLine('Nước', invoice.waterAmount),
    if (invoice.otherAmount > 0) _AmountLine('Khác', invoice.otherAmount),
  ];

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
    columnWidths: const {
      0: pw.FlexColumnWidth(4),
      1: pw.FlexColumnWidth(2),
    },
    children: [
      _tableRow(
        ['Khoản thu', 'Thành tiền'],
        header: true,
      ),
      for (final row in rows)
        _tableRow([row.label, formatCurrencyVnd(row.amount)]),
      _tableRow(
        ['Tổng cộng', formatCurrencyVnd(invoice.totalAmount)],
        strong: true,
      ),
      _tableRow(['Đã thu', formatCurrencyVnd(invoice.paidAmount)]),
      _tableRow(
        ['Còn lại', formatCurrencyVnd(invoice.remainingAmount)],
        strong: true,
        accent:
            invoice.remainingAmount > 0 ? PdfColors.red700 : PdfColors.green700,
      ),
    ],
  );
}

pw.Widget _paymentSummary(Invoice invoice) {
  return pw.Row(
    children: [
      _summaryBox('Trạng thái', invoice.status.label),
      pw.SizedBox(width: 10),
      _summaryBox('Đã thu', formatCurrencyVnd(invoice.paidAmount)),
      pw.SizedBox(width: 10),
      _summaryBox('Còn lại', formatCurrencyVnd(invoice.remainingAmount)),
    ],
  );
}

pw.Widget _paymentHistory(Invoice invoice) {
  final payments = [...invoice.payments]..sort((a, b) {
      final aDate = a.paidAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.paidAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle('Lịch sử thanh toán'),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.5),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(2),
        },
        children: [
          _tableRow(['Ngày', 'Loại', 'Phương thức', 'Số tiền'], header: true),
          for (final payment in payments)
            _tableRow([
              formatDate(payment.paidAt),
              payment.type.label,
              payment.method.label,
              formatCurrencyVnd(payment.amount),
            ]),
        ],
      ),
    ],
  );
}

pw.Widget _note(String title, String value) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: _boxDecoration(),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        pw.SizedBox(height: 6),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
}

pw.Widget _footer() {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    padding: const pw.EdgeInsets.only(top: 16),
    child: pw.Text(
      'Hóa đơn được tạo từ Atrium Living',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
  );
}

pw.Widget _infoBlock(String title, List<String> lines) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(title),
      pw.SizedBox(height: 7),
      for (final line in lines)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(
            line,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ),
    ],
  );
}

pw.Widget _sectionTitle(String title) {
  return pw.Text(
    title,
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blueGrey900,
    ),
  );
}

pw.Widget _summaryBox(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: _boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _statusPill(InvoiceStatus status) {
  final color = switch (status) {
    InvoiceStatus.unpaid => PdfColors.red700,
    InvoiceStatus.partial => PdfColors.orange700,
    InvoiceStatus.paid => PdfColors.green700,
    InvoiceStatus.cancelled => PdfColors.grey600,
  };
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(999),
      border: pw.Border.all(color: color, width: 0.8),
    ),
    child: pw.Text(
      status.label,
      style: pw.TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

pw.TableRow _tableRow(
  List<String> cells, {
  bool header = false,
  bool strong = false,
  PdfColor? accent,
}) {
  return pw.TableRow(
    decoration:
        header ? const pw.BoxDecoration(color: PdfColors.blueGrey50) : null,
    children: [
      for (var index = 0; index < cells.length; index++)
        pw.Container(
          alignment:
              index == cells.length - 1 ? pw.Alignment.centerRight : null,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(
            cells[index],
            style: pw.TextStyle(
              fontSize: header ? 10 : 9.5,
              fontWeight:
                  header || strong ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: accent ?? PdfColors.grey900,
            ),
          ),
        ),
    ],
  );
}

pw.BoxDecoration _boxDecoration() {
  return pw.BoxDecoration(
    border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
    borderRadius: pw.BorderRadius.circular(8),
  );
}

String _safeFilePart(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'phong' : normalized;
}

class _AmountLine {
  const _AmountLine(this.label, this.amount);

  final String label;
  final int amount;
}
