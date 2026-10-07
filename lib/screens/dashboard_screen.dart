import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../utils/formatters.dart';
import '../widgets/bill_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.bills,
    required this.onAdd,
    required this.onShowAll,
    required this.onManageCategories,
  });

  final List<Bill> bills;
  final VoidCallback onAdd;
  final VoidCallback onShowAll;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = bills.where((bill) => isSameDay(bill.date, now)).toList();
    final income = today
        .where((bill) => bill.type == BillType.income)
        .fold<double>(0, (sum, bill) => sum + bill.amount);
    final expense = today
        .where((bill) => bill.type == BillType.expense)
        .fold<double>(0, (sum, bill) => sum + bill.amount);
    final recent = bills.take(6).toList(growable: false);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('我的记账'),
          actions: [
            IconButton(
              tooltip: '管理分类',
              onPressed: onManageCategories,
              icon: const Icon(Icons.category_outlined),
            ),
            IconButton(
              tooltip: '查看全部账单',
              onPressed: onShowAll,
              icon: const Icon(Icons.receipt_long_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          sliver: SliverList.list(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: .2),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: colors.onPrimary),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${now.year}年${now.month}月${now.day}日 · 今日收支'),
                      const SizedBox(height: 8),
                      Text(
                        '¥ ${formatMoney(income - expense)}',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _TodaySummary(
                              label: '今日收入',
                              value: income,
                              icon: Icons.south_west_rounded,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 42,
                            color: colors.onPrimary.withValues(alpha: .25),
                          ),
                          Expanded(
                            child: _TodaySummary(
                              label: '今日支出',
                              value: expense,
                              icon: Icons.north_east_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('addBillButton'),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('记一笔'),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: Text('最近记录', style: theme.textTheme.titleLarge),
                  ),
                  if (bills.length > recent.length)
                    TextButton(onPressed: onShowAll, child: const Text('查看全部')),
                ],
              ),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 38),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 46,
                        color: colors.outline,
                      ),
                      const SizedBox(height: 12),
                      const Text('还没有账单，记下第一笔吧'),
                    ],
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var index = 0; index < recent.length; index++) ...[
                        BillTile(bill: recent[index]),
                        if (index < recent.length - 1)
                          const Divider(height: 1, indent: 68),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 3),
              FittedBox(
                child: Text(
                  '¥ ${formatMoney(value)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
