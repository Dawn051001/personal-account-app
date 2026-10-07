import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../utils/formatters.dart';

enum StatisticsRangeMode { week, month, custom }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, required this.bills});

  final List<Bill> bills;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatisticsRangeMode _mode = StatisticsRangeMode.month;
  DateTime _anchor = DateTime.now();
  late DateTimeRange _customRange = DateTimeRange(
    start: startOfDay(DateTime.now().subtract(const Duration(days: 6))),
    end: endOfDay(DateTime.now()),
  );
  BillType _chartType = BillType.expense;

  DateTimeRange get _range {
    switch (_mode) {
      case StatisticsRangeMode.week:
        final start = startOfDay(
          _anchor.subtract(Duration(days: _anchor.weekday - 1)),
        );
        return DateTimeRange(
          start: start,
          end: endOfDay(start.add(const Duration(days: 6))),
        );
      case StatisticsRangeMode.month:
        final start = DateTime(_anchor.year, _anchor.month);
        return DateTimeRange(
          start: start,
          end: endOfDay(DateTime(_anchor.year, _anchor.month + 1, 0)),
        );
      case StatisticsRangeMode.custom:
        return _customRange;
    }
  }

  void _moveRange(int delta) {
    setState(() {
      _anchor = _mode == StatisticsRangeMode.week
          ? _anchor.add(Duration(days: delta * 7))
          : DateTime(_anchor.year, _anchor.month + delta);
    });
  }

  Future<void> _pickCustomRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: startOfDay(_customRange.start),
        end: startOfDay(_customRange.end),
      ),
    );
    if (result == null) return;
    setState(() {
      _customRange = DateTimeRange(
        start: startOfDay(result.start),
        end: endOfDay(result.end),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final selected = widget.bills.where((bill) {
      return !bill.date.isBefore(range.start) && !bill.date.isAfter(range.end);
    }).toList();
    final income = selected
        .where((bill) => bill.type == BillType.income)
        .fold<double>(0, (sum, bill) => sum + bill.amount);
    final expense = selected
        .where((bill) => bill.type == BillType.expense)
        .fold<double>(0, (sum, bill) => sum + bill.amount);
    final chartBills = selected.where((bill) => bill.type == _chartType);
    final categoryTotals = <String, double>{};
    for (final bill in chartBills) {
      categoryTotals.update(
        bill.category,
        (value) => value + bill.amount,
        ifAbsent: () => bill.amount,
      );
    }
    final sections = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(title: Text('数据统计')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
          sliver: SliverList.list(
            children: [
              SegmentedButton<StatisticsRangeMode>(
                segments: const [
                  ButtonSegment(
                    value: StatisticsRangeMode.week,
                    label: Text('周'),
                    icon: Icon(Icons.view_week_outlined),
                  ),
                  ButtonSegment(
                    value: StatisticsRangeMode.month,
                    label: Text('月'),
                    icon: Icon(Icons.calendar_month_outlined),
                  ),
                  ButtonSegment(
                    value: StatisticsRangeMode.custom,
                    label: Text('日期段'),
                    icon: Icon(Icons.date_range_outlined),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (value) {
                  setState(() => _mode = value.first);
                  if (value.first == StatisticsRangeMode.custom) {
                    _pickCustomRange();
                  }
                },
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_mode != StatisticsRangeMode.custom)
                    IconButton(
                      tooltip: '上一时间段',
                      onPressed: () => _moveRange(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _mode == StatisticsRangeMode.custom
                        ? _pickCustomRange
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        _rangeLabel(range),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (_mode != StatisticsRangeMode.custom)
                    IconButton(
                      tooltip: '下一时间段',
                      onPressed: () => _moveRange(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: '收入',
                      value: income,
                      color: const Color(0xFF198754),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      label: '支出',
                      value: expense,
                      color: const Color(0xFFD14B47),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MetricCard(
                label: '结余',
                value: income - expense,
                color: Theme.of(context).colorScheme.primary,
                wide: true,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '分类占比',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  SegmentedButton<BillType>(
                    segments: const [
                      ButtonSegment(value: BillType.expense, label: Text('支出')),
                      ButtonSegment(value: BillType.income, label: Text('收入')),
                    ],
                    selected: {_chartType},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) {
                      setState(() => _chartType = value.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (sections.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  alignment: Alignment.center,
                  child: Text('该时间段暂无${_chartType.label}'),
                )
              else
                _PieChartCard(sections: sections, type: _chartType),
            ],
          ),
        ),
      ],
    );
  }

  String _rangeLabel(DateTimeRange range) {
    if (_mode == StatisticsRangeMode.month) {
      return '${range.start.year}年${range.start.month}月';
    }
    return '${formatShortDate(range.start)} — ${formatShortDate(range.end)}';
  }
}

class _PieChartCard extends StatelessWidget {
  const _PieChartCard({required this.sections, required this.type});

  final List<MapEntry<String, double>> sections;
  final BillType type;

  static const colors = [
    Color(0xFF587568),
    Color(0xFFC99559),
    Color(0xFFBE7773),
    Color(0xFF6F829D),
    Color(0xFF89788F),
    Color(0xFF6F9992),
    Color(0xFFAD8065),
    Color(0xFF95A66E),
  ];

  @override
  Widget build(BuildContext context) {
    final total = sections.fold<double>(0, (sum, item) => sum + item.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox.square(
              dimension: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(190),
                    painter: _PiePainter(
                      values: sections.map((entry) => entry.value).toList(),
                      colors: colors,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${type.label}合计'),
                      const SizedBox(height: 4),
                      Text(
                        '¥${formatMoney(total)}',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < sections.length; i++) ...[
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(sections[i].key)),
                  Text(
                    '${(sections[i].value / total * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 76,
                    child: Text(
                      '¥${formatMoney(sections[i].value)}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              if (i < sections.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 4);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final ratio = values[i] / total;
      final sweep = ratio * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      if (ratio >= .08) {
        final angle = start + sweep / 2;
        final labelCenter = Offset(
          center.dx + math.cos(angle) * radius * .76,
          center.dy + math.sin(angle) * radius * .76,
        );
        final label = TextPainter(
          text: TextSpan(
            text: '${(ratio * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final background = Rect.fromCenter(
          center: labelCenter,
          width: label.width + 8,
          height: label.height + 4,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(background, const Radius.circular(6)),
          Paint()..color = Colors.black.withValues(alpha: .32),
        );
        label.paint(
          canvas,
          Offset(
            labelCenter.dx - label.width / 2,
            labelCenter.dy - label.height / 2,
          ),
        );
      }
      start += sweep;
    }
    canvas.drawCircle(center, radius * .52, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  final String label;
  final double value;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(wide ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '¥ ${formatMoney(value)}',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
