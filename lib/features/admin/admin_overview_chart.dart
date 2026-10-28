import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/admin_dashboard.dart';
import 'admin_overview_theme.dart';

class AdminOverviewChart extends StatefulWidget {
  const AdminOverviewChart(
      {super.key, required this.data, required this.metric});

  final List<AdminDailyTrend> data;
  final String metric;

  @override
  State<AdminOverviewChart> createState() => _AdminOverviewChartState();
}

class _AdminOverviewChartState extends State<AdminOverviewChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant AdminOverviewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data || oldWidget.metric != widget.metric) {
      _selected = null;
    }
  }

  String _detail(int index) {
    final row = widget.data[index];
    final value = row.valueFor(widget.metric);
    return '${row.day.day}/${row.day.month}/${row.day.year}: '
        '$value${widget.metric == 'rentalNet' ? ' đ tiền thuê ròng' : ' mới'}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const SizedBox(
          height: 180,
          child: Center(child: Text('Chưa có dữ liệu theo ngày.')));
    }
    final selected = _selected ?? widget.data.length - 1;
    final allZero =
        widget.data.every((row) => row.valueFor(widget.metric) == 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(allZero ? 'Không phát sinh trong kỳ này.' : _detail(selected),
          key: const ValueKey('overview-chart-detail'),
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      SizedBox(
          height: 176,
          child: LayoutBuilder(builder: (context, constraints) {
            void select(double horizontal) {
              final chart = _chartRect(Size(constraints.maxWidth, 176));
              final fraction =
                  ((horizontal - chart.left) / chart.width).clamp(0.0, 1.0);
              setState(() =>
                  _selected = (fraction * (widget.data.length - 1)).round());
            }

            return Semantics(
              label: 'Biểu đồ theo ngày. ${_detail(selected)}',
              value: '${selected + 1}/${widget.data.length} ngày',
              increasedValue: selected < widget.data.length - 1
                  ? _detail(selected + 1)
                  : null,
              decreasedValue: selected > 0 ? _detail(selected - 1) : null,
              onIncrease: selected < widget.data.length - 1
                  ? () => setState(() => _selected = selected + 1)
                  : null,
              onDecrease: selected > 0
                  ? () => setState(() => _selected = selected - 1)
                  : null,
              child: MouseRegion(
                onHover: (event) => select(event.localPosition.dx),
                child: GestureDetector(
                  key: const ValueKey('overview-chart-plot'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (event) => select(event.localPosition.dx),
                  onHorizontalDragUpdate: (event) =>
                      select(event.localPosition.dx),
                  child: CustomPaint(
                    painter: _OverviewTrendPainter(
                        widget.data, widget.metric, selected),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          })),
      Row(children: [
        IconButton(
            tooltip: 'Ngày trước',
            onPressed: selected > 0
                ? () => setState(() => _selected = selected - 1)
                : null,
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Text('Chạm biểu đồ để xem từng ngày',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall)),
        IconButton(
            tooltip: 'Ngày tiếp',
            onPressed: selected < widget.data.length - 1
                ? () => setState(() => _selected = selected + 1)
                : null,
            icon: const Icon(Icons.chevron_right)),
      ]),
    ]);
  }
}

Rect _chartRect(Size size) =>
    Rect.fromLTWH(46, 12, math.max(1, size.width - 58), size.height - 36);

class _OverviewTrendPainter extends CustomPainter {
  _OverviewTrendPainter(this.data, this.metric, this.selected);
  final List<AdminDailyTrend> data;
  final String metric;
  final int selected;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _chartRect(size);
    final values = data.map((row) => row.valueFor(metric).toDouble()).toList();
    final minimum = values.fold<double>(0, math.min);
    final maximum = values.fold<double>(0, math.max);
    final span = maximum - minimum == 0 ? 1.0 : maximum - minimum;
    double heightFor(double value) =>
        chart.bottom - (value - minimum) / span * chart.height;
    final grid = Paint()
      ..color = AdminOverviewTheme.line
      ..strokeWidth = 1;
    void label(String text, Offset offset, {bool centered = false}) {
      final painter = TextPainter(
          text: TextSpan(
              text: text,
              style: const TextStyle(fontSize: 10, color: AdminOverviewTheme.muted)),
          textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(canvas,
          Offset(offset.dx - (centered ? painter.width / 2 : 0), offset.dy));
      painter.dispose();
    }

    for (var tick = 0; tick <= 2; tick++) {
      final value = minimum + span * tick / 2;
      final vertical = heightFor(value);
      canvas.drawLine(
          Offset(chart.left, vertical), Offset(chart.right, vertical), grid);
      label(_compact(value), Offset(0, vertical - 6));
    }
    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
            data.length == 1
                ? chart.center.dx
                : chart.left + chart.width * index / (data.length - 1),
            heightFor(values[index]))
    ];
    final zero = heightFor(0);
    final fill = Path()..moveTo(points.first.dx, zero);
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points) {
      fill.lineTo(point.dx, point.dy);
      line.lineTo(point.dx, point.dy);
    }
    fill
      ..lineTo(points.last.dx, zero)
      ..close();
    canvas.drawPath(
        fill, Paint()..color = AdminOverviewTheme.blue.withValues(alpha: .08));
    canvas.drawPath(
        line,
        Paint()
          ..color = AdminOverviewTheme.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);
    canvas.drawLine(Offset(chart.left, zero), Offset(chart.right, zero), grid);
    final active = points[selected];
    canvas.drawLine(
        Offset(active.dx, chart.top), Offset(active.dx, chart.bottom), grid);
    canvas.drawCircle(active, 6, Paint()..color = Colors.white);
    canvas.drawCircle(active, 4, Paint()..color = AdminOverviewTheme.blue);
    for (final index in <int>{0, data.length ~/ 2, data.length - 1}) {
      final day = data[index].day;
      label('${day.day}/${day.month}',
          Offset(points[index].dx, chart.bottom + 10),
          centered: true);
    }
  }

  @override
  bool shouldRepaint(covariant _OverviewTrendPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.metric != metric ||
      oldDelegate.selected != selected;
}

String _compact(double value) => value.abs() >= 1000000
    ? '${(value / 1000000).toStringAsFixed(1)}M'
    : value.abs() >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}K'
        : value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsFixed(1);
