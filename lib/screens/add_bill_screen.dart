import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/bill_store.dart';
import '../models/bill.dart';
import '../utils/formatters.dart';
import 'category_management_screen.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key, required this.store});

  final BillStore store;

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();
  BillType _type = BillType.expense;
  List<String> _categories = const [];
  String? _category;
  DateTime _date = DateTime.now();
  bool _loadingCategories = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    final categories = await widget.store.getCategories(_type);
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _category = categories.contains(_category)
          ? _category
          : (categories.isEmpty ? null : categories.first);
      _loadingCategories = false;
    });
  }

  Future<void> _manageCategories() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CategoryManagementScreen(store: widget.store, initialType: _type),
      ),
    );
    await _loadCategories();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先添加一个分类')));
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final isToday = isSameDay(_date, now);
    final billDate = isToday
        ? DateTime(
            _date.year,
            _date.month,
            _date.day,
            now.hour,
            now.minute,
            now.second,
          )
        : DateTime(_date.year, _date.month, _date.day);
    try {
      await widget.store.insert(
        Bill(
          amount: double.parse(_amountController.text.trim()),
          type: _type,
          category: _category!,
          date: billDate,
          createdAt: isToday ? now : billDate,
          remark: _remarkController.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('记一笔')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text('金额', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('amountField'),
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,9}(\.\d{0,2})?'),
                  ),
                ],
                style: theme.textTheme.headlineMedium,
                decoration: const InputDecoration(
                  prefixText: '¥ ',
                  hintText: '0.00',
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0 ? '请输入大于 0 的金额' : null;
                },
              ),
              const SizedBox(height: 26),
              Text('收支', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<BillType>(
                key: const Key('typeSelector'),
                segments: const [
                  ButtonSegment(
                    value: BillType.expense,
                    icon: Icon(Icons.arrow_upward_rounded),
                    label: Text('支出'),
                  ),
                  ButtonSegment(
                    value: BillType.income,
                    icon: Icon(Icons.arrow_downward_rounded),
                    label: Text('收入'),
                  ),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (selected) {
                  _type = selected.first;
                  _category = null;
                  _loadCategories();
                },
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text('分类', style: theme.textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: _manageCategories,
                    child: const Text('管理'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_loadingCategories)
                const Center(child: CircularProgressIndicator())
              else if (_categories.isEmpty)
                OutlinedButton.icon(
                  onPressed: _manageCategories,
                  icon: const Icon(Icons.add),
                  label: const Text('暂无分类，点击添加'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 26),
              Text('账单日期', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(formatDate(_date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
              const SizedBox(height: 26),
              Text('备注（选填）', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarkController,
                maxLength: 50,
                decoration: const InputDecoration(hintText: '例如：朋友聚餐'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('saveBillButton'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? '正在保存…' : '保存账单'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
