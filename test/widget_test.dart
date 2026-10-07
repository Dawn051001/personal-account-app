import 'package:account/data/bill_store.dart';
import 'package:account/main.dart';
import 'package:account/models/bill.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryBillStore implements BillStore {
  final List<Bill> bills = [];
  final Map<BillType, List<String>> categories = {
    BillType.expense: ['餐饮', '运动', '交通', '购物'],
    BillType.income: ['补贴', '工资', '奖金'],
  };

  @override
  Future<void> addCategory(BillType type, String name) async {
    if (!categories[type]!.contains(name)) categories[type]!.add(name);
  }

  @override
  Future<void> deleteCategory(BillType type, String name) async {
    categories[type]!.remove(name);
  }

  @override
  Future<void> deleteBill(int id) async {
    bills.removeWhere((bill) => bill.id == id);
  }

  @override
  Future<List<String>> getCategories(BillType type) async =>
      List.unmodifiable(categories[type]!);

  @override
  Future<List<Bill>> getAll() async => List.unmodifiable(bills.reversed);

  @override
  Future<int> insert(Bill bill) async {
    bills.add(bill);
    return bills.length;
  }
}

void main() {
  testWidgets('shows the empty dashboard and opens add form', (tester) async {
    await tester.pumpWidget(AccountApp(store: MemoryBillStore()));
    await tester.pumpAndSettle();

    expect(find.text('我的记账'), findsOneWidget);
    expect(find.text('还没有账单，记下第一笔吧'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addBillButton')));
    await tester.pumpAndSettle();
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.byKey(const Key('amountField')), findsOneWidget);
  });
}
