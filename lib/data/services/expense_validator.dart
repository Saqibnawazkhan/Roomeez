import '../../core/errors/app_exception.dart';
import '../../core/utils/dates.dart';
import '../models/models.dart';

/// Validation shared by the expense form and the repositories.
abstract final class ExpenseValidator {
  static const int maxTitleLength = 80;

  /// Returns a list of problems; empty when the draft is valid.
  static List<String> problems(ExpenseDraft draft, {DateTime? now}) {
    final problems = <String>[];
    final title = draft.title.trim();
    if (title.isEmpty) problems.add('Add a title for the expense.');
    if (title.length > maxTitleLength) {
      problems.add('Keep the title under $maxTitleLength characters.');
    }
    if (dateOnly(draft.date).isAfter(dateOnly(now ?? DateTime.now()))) {
      problems.add('The date can\'t be in the future.');
    }
    if (draft.isItemized) {
      for (final (index, item) in draft.items.indexed) {
        final row = index + 1;
        if (item.name.trim().isEmpty) problems.add('Item $row needs a name.');
        if (item.quantityMilli <= 0) problems.add('Item $row needs a quantity above zero.');
        if (item.unitPricePaisa < 0) problems.add('Item $row has an invalid price.');
      }
    } else if ((draft.quickAmountPaisa ?? 0) < 0) {
      problems.add('The amount can\'t be negative.');
    }
    if (draft.totalPaisa <= 0) problems.add('The total must be more than zero.');
    if (draft.splitAmongUserIds.isEmpty) {
      problems.add('Choose at least one member to share this expense.');
    }
    if (draft.paymentSource == PaymentSource.personal && draft.paidByUserId == null) {
      problems.add('Choose who paid.');
    }
    return problems;
  }

  static void check(ExpenseDraft draft) {
    final found = problems(draft);
    if (found.isNotEmpty) throw ValidationException(found.first);
  }
}
