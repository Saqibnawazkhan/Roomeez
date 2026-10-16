import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../neu/neu.dart';

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
    ExpenseCategory.breakfast => const Color(0xFFE08A3C),
    ExpenseCategory.lunch => const Color(0xFFE2725B),
    ExpenseCategory.dinner => const Color(0xFFD2668E),
    ExpenseCategory.groceries => const Color(0xFF3FA36E),
    ExpenseCategory.household => const Color(0xFF3E95CF),
    ExpenseCategory.bills => const Color(0xFF9A6BDB),
    ExpenseCategory.transport => const Color(0xFF2FAFAD),
    ExpenseCategory.other => const Color(0xFF7D8797),
  };
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {super.key, this.size = 42, this.muted = false});

  final ExpenseCategory category;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? NeuPalette.of(context).muted.withValues(alpha: 0.6) : category.color;
    return NeuBox(
      circle: true,
      depth: size / 11,
      width: size,
      height: size,
      child: Icon(category.icon, color: color, size: size * 0.46),
    );
  }
}
