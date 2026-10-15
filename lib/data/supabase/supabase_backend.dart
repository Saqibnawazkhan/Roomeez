import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend.dart';
import 'live_query.dart';
import 'supabase_auth_repository.dart';
import 'supabase_contribution_repository.dart';
import 'supabase_expense_repository.dart';
import 'supabase_group_repository.dart';

/// Connects to Supabase and restores any saved session.
Future<Backend> connectSupabase({required String url, required String key}) async {
  await Supabase.initialize(url: url, publishableKey: key);
  final client = Supabase.instance.client;
  final bus = RefreshBus();
  final auth = SupabaseAuthRepository(client);
  await auth.init();
  return Backend(
    auth: auth,
    groups: SupabaseGroupRepository(client, bus),
    expenses: SupabaseExpenseRepository(client, bus),
    contributions: SupabaseContributionRepository(client, bus),
  );
}
