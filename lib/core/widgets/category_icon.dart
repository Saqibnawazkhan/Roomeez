import 'package:flutter/material.dart';

import '../../data/models/models.dart';

extension ExpenseCategoryVisuals on ExpenseCategory {
  IconData get icon => switch (this) {
    ExpenseCategory.breakfast => Icons.free_breakfast_outlined,
    ExpenseCategory.lunch => Icons.lunch_dining_outlined,
    ExpenseCategory.dinner => Icons.dinner_dining_outlined,
    ExpenseCategory.groceries => Icons.shopping_basket_outlined,
    ExpenseCategory.household => Icons.cleaning_services_outlined,
    ExpenseCategory.bills => Icons.receipt_long_outlined,
    ExpenseCategory.transport => Icons.directions_car_outlined,
    ExpenseCategory.other => Icons.category_outlined,
  };

  Color get color => switch (this) {
    ExpenseCategory.breakfast => const Color(0xFFB45309),
    ExpenseCategory.lunch => const Color(0xFFC2410C),
    ExpenseCategory.dinner => const Color(0xFFBE185D),
    ExpenseCategory.groceries => const Color(0xFF15803D),
    ExpenseCategory.household => const Color(0xFF0369A1),
    ExpenseCategory.bills => const Color(0xFF7C3AED),
    ExpenseCategory.transport => const Color(0xFF0F766E),
    ExpenseCategory.other => const Color(0xFF475467),
  };
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 42, this.muted = false});

  final ExpenseCategory category;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? Theme.of(context).disabledColor : category.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(category.icon, color: color, size: size * 0.5),
    );
  }
}
