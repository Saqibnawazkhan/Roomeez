import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backend.dart';
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
// Data wiring. Screens only see the repository interfaces. By default the app
// runs on the in-memory demo; main.dart overrides [backendProvider] with the
// Supabase backend when it is configured.
// -----------------------------------------------------------------------------

/// Demo data, used when no backend is configured.
final mockStoreProvider = Provider<MockStore>((ref) {
  final store = MockStore();
  seedSampleData(store);
  return store;
});

final backendProvider = Provider<Backend>((ref) => Backend.mock(ref.watch(mockStoreProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) => ref.watch(backendProvider).auth);

final groupRepositoryProvider = Provider<GroupRepository>((ref) => ref.watch(backendProvider).groups);

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) => ref.watch(backendProvider).expenses);

final contributionRepositoryProvider = Provider<ContributionRepository>(
  (ref) => ref.watch(backendProvider).contributions,
);

/// Demo-only shortcuts; `null` on a real backend.
final prototypeToolsProvider = Provider<PrototypeTools?>((ref) => ref.watch(backendProvider).prototype);

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
