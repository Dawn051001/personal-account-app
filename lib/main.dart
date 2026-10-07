import 'package:flutter/material.dart';

import 'data/bill_store.dart';
import 'models/bill.dart';
import 'screens/add_bill_screen.dart';
import 'screens/bill_list_screen.dart';
import 'screens/category_management_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/statistics_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AccountApp());
}

class AccountApp extends StatelessWidget {
  const AccountApp({super.key, this.store});

  final BillStore? store;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3E6C5B),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: '我的记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F5),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: AccountHome(store: store ?? SqliteBillStore.instance),
    );
  }
}

class AccountHome extends StatefulWidget {
  const AccountHome({super.key, required this.store});

  final BillStore store;

  @override
  State<AccountHome> createState() => _AccountHomeState();
}

class _AccountHomeState extends State<AccountHome> {
  int _pageIndex = 0;
  bool _loading = true;
  String? _error;
  List<Bill> _bills = const [];
  List<String> _expenseCategories = const [];
  List<String> _incomeCategories = const [];

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    if (mounted) setState(() => _error = null);
    try {
      final bills = await widget.store.getAll();
      final expenseCategories = await widget.store.getCategories(
        BillType.expense,
      );
      final incomeCategories = await widget.store.getCategories(
        BillType.income,
      );
      if (!mounted) return;
      setState(() {
        _bills = bills;
        _expenseCategories = expenseCategories;
        _incomeCategories = incomeCategories;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '账单读取失败';
      });
    }
  }

  Future<void> _addBill() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddBillScreen(store: widget.store)),
    );
    await _loadBills();
    if (saved == true) {
      if (mounted) {
        setState(() => _pageIndex = 0);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('账单已保存')));
      }
    }
  }

  Future<void> _deleteBill(Bill bill) async {
    if (bill.id == null) return;
    try {
      await widget.store.deleteBill(bill.id!);
      await _loadBills();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('账单已删除')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    }
  }

  Future<void> _manageCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CategoryManagementScreen(store: widget.store),
      ),
    );
    await _loadBills();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _loadBills,
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = [
      DashboardScreen(
        bills: _bills,
        onAdd: _addBill,
        onShowAll: () => setState(() => _pageIndex = 1),
        onManageCategories: _manageCategories,
      ),
      BillListScreen(
        bills: _bills,
        expenseCategories: _expenseCategories,
        incomeCategories: _incomeCategories,
        onDelete: _deleteBill,
      ),
      StatisticsScreen(bills: _bills),
    ];
    return Scaffold(
      body: IndexedStack(index: _pageIndex, children: pages),
      floatingActionButton: _pageIndex == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _addBill,
              icon: const Icon(Icons.add_rounded),
              label: const Text('记一笔'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pageIndex,
        onDestinationSelected: (index) => setState(() => _pageIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '账单',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
        ],
      ),
    );
  }
}
