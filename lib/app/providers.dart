import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_auth_repository.dart';
import '../data/mock/mock_contribution_repository.dart';
import '../data/mock/mock_expense_repository.dart';
import '../data/mock/mock_group_repository.dart';
import '../data/mock/mock_seed.dart';
import '../data/mock/mock_store.dart';
import '../data/mock/prototype_tools.dart';
import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/contribution_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/services/pdf_report_service.dart';

// -----------------------------------------------------------------------------
// Data wiring. This is the only place that knows the prototype uses mock
// repositories. To connect Supabase, provide Supabase-backed implementations
// of the repository interfaces here; screens do not change.
// -----------------------------------------------------------------------------

/// PROTOTYPE ONLY: in-memory data seeded with sample records.
final mockStoreProvider = Provider<MockStore>((ref) {
  final store = MockStore();
  seedSampleData(store);
  return store;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) => MockAuthRepository(ref.watch(mockStoreProvider)));

final groupRepositoryProvider = Provider<GroupRepository>((ref) => MockGroupRepository(ref.watch(mockStoreProvider)));

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => MockExpenseRepository(ref.watch(mockStoreProvider)),
);

final contributionRepositoryProvider = Provider<ContributionRepository>(
  (ref) => MockContributionRepository(ref.watch(mockStoreProvider)),
);

/// PROTOTYPE ONLY: sample-account switching and simulated approvals.
final prototypeToolsProvider = Provider<PrototypeTools>(
  (ref) => PrototypeTools(ref.watch(mockStoreProvider), ref.watch(groupRepositoryProvider)),
);

final pdfReportServiceProvider = Provider<PdfReportService>((ref) => const PdfReportService());

// -----------------------------------------------------------------------------
// Session
// -----------------------------------------------------------------------------

final authStateProvider = StreamProvider<AppUser?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());

final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.hasValue ? state.value : ref.watch(authRepositoryProvider).currentUser;
});

final currentUserIdProvider = Provider<String?>((ref) => ref.watch(currentUserProvider.select((user) => user?.id)));
