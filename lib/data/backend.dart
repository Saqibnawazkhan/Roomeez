import 'mock/mock_auth_repository.dart';
import 'mock/mock_contribution_repository.dart';
import 'mock/mock_expense_repository.dart';
import 'mock/mock_group_repository.dart';
import 'mock/mock_store.dart';
import 'mock/prototype_tools.dart';
import 'repositories/auth_repository.dart';
import 'repositories/contribution_repository.dart';
import 'repositories/expense_repository.dart';
import 'repositories/group_repository.dart';

/// The set of repositories the app runs on: the in-memory demo, or Supabase
/// (see `data/supabase/supabase_backend.dart`).
class Backend {
  const Backend({
    required this.auth,
    required this.groups,
    required this.expenses,
    required this.contributions,
    this.prototype,
  });

  factory Backend.mock(MockStore store) {
    final groups = MockGroupRepository(store);
    return Backend(
      auth: MockAuthRepository(store),
      groups: groups,
      expenses: MockExpenseRepository(store),
      contributions: MockContributionRepository(store),
      prototype: PrototypeTools(store, groups),
    );
  }

  final AuthRepository auth;
  final GroupRepository groups;
  final ExpenseRepository expenses;
  final ContributionRepository contributions;

  /// Demo-only shortcuts (switch user, simulate approval). `null` on a real
  /// backend, which hides those controls.
  final PrototypeTools? prototype;
}
