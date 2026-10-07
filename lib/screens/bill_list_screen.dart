import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bill.dart';
import '../utils/formatters.dart';
import '../widgets/bill_tile.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({
    super.key,
    required this.bills,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.onDelete,
  });

  final List<Bill> bills;
  final List<String> expenseCategories;
  final List<String> incomeCategories;
  final Future<void> Function(Bill bill) onDelete;

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  BillFilter _filter = const BillFilter();

  List<Bill> get _filtered => widget.bills.where(_filter.matches).toList();

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<BillFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BillFilterSheet(
        initial: _filter,
        expenseCategories: widget.expenseCategories,
        incomeCategories: widget.incomeCategories,
      ),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final bills = _filtered;
    final groups = <String, List<Bill>>{};
    for (final bill in bills) {
      groups.putIfAbsent(formatDate(bill.date), () => []).add(bill);
    }
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('全部账单'),
          actions: [
            Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: IconButton(
                tooltip: '筛选账单',
                onPressed: _openFilter,
                icon: const Icon(Icons.filter_list),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        if (_filter.activeCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(child: Text('已筛选出 ${bills.length} 笔账单')),
                  TextButton(
                    onPressed: () =>
                        setState(() => _filter = const BillFilter()),
                    child: const Text('清除筛选'),
                  ),
                ],
              ),
            ),
          ),
        if (bills.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(_filter.activeCount == 0 ? '暂无账单记录' : '没有符合条件的账单'),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
            sliver: SliverList.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final entry = groups.entries.elementAt(index);
                final date = DateTime.parse(entry.key);
                final dailyExpense = entry.value
                    .where((bill) => bill.type == BillType.expense)
                    .fold<double>(0, (sum, bill) => sum + bill.amount);
                final dailyIncome = entry.value
                    .where((bill) => bill.type == BillType.income)
                    .fold<double>(0, (sum, bill) => sum + bill.amount);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${date.year}年${date.month}月${date.day}日',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              '收 ¥${formatMoney(dailyIncome)}  支 ¥${formatMoney(dailyExpense)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < entry.value.length; i++) ...[
                              BillTile(
                                bill: entry.value[i],
                                showDate: false,
                                onTap: () =>
                                    _showDetails(context, entry.value[i]),
                              ),
                              if (i < entry.value.length - 1)
                                const Divider(height: 1, indent: 68),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showDetails(BuildContext context, Bill bill) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('账单详情', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              _DetailRow(
                label: '金额',
                value:
                    '${bill.type == BillType.income ? '+' : '-'}¥${formatMoney(bill.amount)}',
              ),
              _DetailRow(label: '收支', value: bill.type.label),
              _DetailRow(label: '分类', value: bill.category),
              _DetailRow(label: '账单日期', value: formatDate(bill.date)),
              if (hasPreciseTime(bill.date, bill.createdAt))
                _DetailRow(
                  label: '记录时间',
                  value: formatDateTime(bill.createdAt!),
                ),
              _DetailRow(
                label: '备注',
                value: bill.remark.isEmpty ? '无' : bill.remark,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _confirmDelete(context, bill),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除这笔账单'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext sheetContext, Bill bill) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        title: const Text('删除账单？'),
        content: const Text('删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    await widget.onDelete(bill);
  }
}

class BillFilter {
  const BillFilter({
    this.date,
    this.type,
    this.category,
    this.minAmount,
    this.maxAmount,
    this.remark = '',
  });

  final DateTime? date;
  final BillType? type;
  final String? category;
  final double? minAmount;
  final double? maxAmount;
  final String remark;

  int get activeCount => [
    date,
    type,
    category,
    minAmount,
    maxAmount,
    if (remark.trim().isNotEmpty) remark,
  ].where((value) => value != null).length;

  bool matches(Bill bill) {
    if (date != null && !isSameDay(bill.date, date!)) return false;
    if (type != null && bill.type != type) return false;
    if (category != null && bill.category != category) return false;
    if (minAmount != null && bill.amount < minAmount!) return false;
    if (maxAmount != null && bill.amount > maxAmount!) return false;
    if (remark.trim().isNotEmpty &&
        !bill.remark.toLowerCase().contains(remark.trim().toLowerCase())) {
      return false;
    }
    return true;
  }
}

class BillFilterSheet extends StatefulWidget {
  const BillFilterSheet({
    super.key,
    required this.initial,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  final BillFilter initial;
  final List<String> expenseCategories;
  final List<String> incomeCategories;

  @override
  State<BillFilterSheet> createState() => _BillFilterSheetState();
}

class _BillFilterSheetState extends State<BillFilterSheet> {
  late DateTime? _date = widget.initial.date;
  late BillType? _type = widget.initial.type;
  late String? _category = widget.initial.category;
  late final TextEditingController _minController = TextEditingController(
    text: widget.initial.minAmount?.toString() ?? '',
  );
  late final TextEditingController _maxController = TextEditingController(
    text: widget.initial.maxAmount?.toString() ?? '',
  );
  late final TextEditingController _remarkController = TextEditingController(
    text: widget.initial.remark,
  );

  List<String> get _categories {
    final values = switch (_type) {
      BillType.expense => widget.expenseCategories.toSet().toList(),
      BillType.income => widget.incomeCategories.toSet().toList(),
      null => {
        ...widget.expenseCategories,
        ...widget.incomeCategories,
      }.toList(),
    };
    values.sort();
    return values;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _apply() {
    Navigator.pop(
      context,
      BillFilter(
        date: _date,
        type: _type,
        category: _category,
        minAmount: double.tryParse(_minController.text.trim()),
        maxAmount: double.tryParse(_maxController.text.trim()),
        remark: _remarkController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final categories = _categories;
    if (_category != null && !categories.contains(_category)) _category = null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '筛选账单',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, const BillFilter()),
                    child: const Text('全部清除'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(_date == null ? '日期' : formatDate(_date!)),
                trailing: _date == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        onPressed: () => setState(() => _date = null),
                        icon: const Icon(Icons.close),
                      ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<BillType?>(
                initialValue: _type,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部收支')),
                  DropdownMenuItem(value: BillType.expense, child: Text('支出')),
                  DropdownMenuItem(value: BillType.income, child: Text('收入')),
                ],
                onChanged: (value) {
                  setState(() {
                    _type = value;
                    _category = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                key: ValueKey(_type),
                initialValue: _category,
                decoration: const InputDecoration(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部分类')),
                  ...categories.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(labelText: '最低金额'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('—'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(labelText: '最高金额'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: '搜索备注',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _apply(),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('应用筛选'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
