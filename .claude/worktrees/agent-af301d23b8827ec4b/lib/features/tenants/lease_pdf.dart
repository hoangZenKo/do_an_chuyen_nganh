import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/format.dart';
import '../../models/lease.dart';
import '../../models/tenant.dart';

Future<Uint8List> buildLeasePdf({
  required Lease lease,
  required Tenant tenant,
}) async {
  final document = pw.Document();
  final theme = await _buildTheme();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: theme,
      build: (_) => [
        pw.Center(
          child: pw.Text(
            'HOP DONG THUE PHONG',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 24),
        _section('Thong tin phong', [
          'Phong: ${lease.roomName ?? lease.roomId}',
          'Ngay bat dau: ${formatDate(lease.startDate)}',
          'Ngay ket thuc: ${formatDate(lease.endDate)}',
          'Trang thai: ${lease.status.label}',
        ]),
        pw.SizedBox(height: 14),
        _section('Thong tin khach thue', [
          'Ho ten: ${tenant.fullName}',
          if (tenant.phone != null) 'So dien thoai: ${tenant.phone}',
          if (tenant.idNumber != null) 'CCCD/CMND: ${tenant.idNumber}',
        ]),
        pw.SizedBox(height: 14),
        _section('Tai chinh', [
          'Tien thue hang thang: ${formatCurrencyVnd(lease.monthlyRent)}',
          'Tien coc: ${formatCurrencyVnd(lease.deposit)}',
        ]),
        pw.SizedBox(height: 18),
        pw.Text(
          'Dieu khoan co ban',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Khach thue thanh toan tien thue dung han, bao quan tai san trong phong, '
          'thong bao cho chu tro khi can sua chua va tuan thu noi quy khu tro. '
          'Cac dieu khoan chi tiet co the duoc bo sung bang phu luc rieng.',
        ),
        pw.SizedBox(height: 42),
        pw.Row(
          children: [
            _signature('Chu tro'),
            pw.SizedBox(width: 36),
            _signature('Khach thue'),
          ],
        ),
      ],
    ),
  );

  return document.save();
}

Future<pw.ThemeData> _buildTheme() async {
  try {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    return pw.ThemeData.withFont(base: regular, bold: bold);
  } catch (_) {
    return pw.ThemeData.base();
  }
}

Future<void> shareLeasePdf({
  required Lease lease,
  required Tenant tenant,
}) async {
  final bytes = await buildLeasePdf(lease: lease, tenant: tenant);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'hop-dong-${_safe(lease.roomName ?? lease.roomId)}.pdf',
  );
}

pw.Widget _section(String title, List<String> rows) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        for (final row in rows) pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Text(row),
        ),
      ],
    ),
  );
}

pw.Widget _signature(String label) {
  return pw.Expanded(
    child: pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 54),
        pw.Container(height: 1, color: PdfColors.grey500),
      ],
    ),
  );
}

String _safe(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '-');
