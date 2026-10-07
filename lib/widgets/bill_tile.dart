import 'package:flutter/material.dart';

import '../models/bill.dart';
import '../utils/formatters.dart';

class BillTile extends StatelessWidget {
  const BillTile({
    super.key,
    required this.bill,
    this.showDate = true,
    this.onTap,
  });

  final Bill bill;
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = bill.type == BillType.income;
    final color = isIncome ? const Color(0xFF198754) : const Color(0xFFD14B47);
    final recordedAt = bill.createdAt;
    final showTime = hasPreciseTime(bill.date, recordedAt);
    final subtitle = [
      if (showDate) formatChineseDate(bill.date),
      if (showTime) _time(recordedAt!),
      bill.category,
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        foregroundColor: color,
        child: _categoryIconWidget(bill.category, color),
      ),
      title: Text(
        bill.remark.isEmpty ? bill.category : bill.remark,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle),
      trailing: Text(
        '${isIncome ? '+' : '-'}¥${formatMoney(bill.amount)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }
}

Widget _categoryIconWidget(String category, Color color) {
  if (category == '运动') {
    return SizedBox.square(
      dimension: 22,
      child: CustomPaint(painter: _ShuttlecockPainter(color)),
    );
  }
  return Icon(_categoryIcon(category), size: 21);
}

class _ShuttlecockPainter extends CustomPainter {
  const _ShuttlecockPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawLine(
      Offset(size.width * .22, size.height * .18),
      Offset(size.width * .43, size.height * .62),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .50, size.height * .12),
      Offset(size.width * .50, size.height * .62),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .78, size.height * .18),
      Offset(size.width * .57, size.height * .62),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .22, size.height * .18),
      Offset(size.width * .78, size.height * .18),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .38,
          size.height * .58,
          size.width * .24,
          size.height * .27,
        ),
        Radius.circular(size.width * .1),
      ),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ShuttlecockPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

IconData _categoryIcon(String category) {
  return switch (category) {
    '餐饮' => Icons.restaurant_outlined,
    '交通' => Icons.directions_subway_outlined,
    '购物' => Icons.shopping_bag_outlined,
    '住房' => Icons.home_outlined,
    '娱乐' => Icons.sports_esports_outlined,
    '医疗' => Icons.medical_services_outlined,
    '补贴' => Icons.payments_outlined,
    '工资' => Icons.account_balance_wallet_outlined,
    '奖金' => Icons.card_giftcard_outlined,
    _ => Icons.more_horiz_rounded,
  };
}
