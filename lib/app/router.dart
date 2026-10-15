import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/dates.dart';
import '../features/auth/screens/phone_entry_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/auth/screens/verify_code_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/contributions/screens/add_contribution_screen.dart';
import '../features/expenses/screens/expense_detail_screen.dart';
import '../features/expenses/screens/expense_form_screen.dart';
import '../features/groups/screens/create_group_screen.dart';
import '../features/groups/screens/group_created_screen.dart';
import '../features/groups/screens/group_settings_screen.dart';
import '../features/groups/screens/group_shell_screen.dart';
import '../features/groups/screens/join_group_screen.dart';
import '../features/groups/screens/join_status_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/members/screens/add_member_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/reports/screens/report_preview_screen.dart';
import 'providers.dart';
import 'routes.dart';

const _signedOutRoutes = {Routes.welcome, Routes.signUp, Routes.logIn, '/verify'};

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _StreamRefresh(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = auth.currentUser;
      final location = state.matchedLocation;
      if (user == null) {
        return _signedOutRoutes.contains(location) ? null : Routes.welcome;
      }
      if (!user.hasCompletedProfile) {
        return location == Routes.profileSetup ? null : Routes.profileSetup;
      }
      if (_signedOutRoutes.contains(location) || location == Routes.profileSetup) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: Routes.signUp, builder: (context, state) => const PhoneEntryScreen(isSignUp: true)),
      GoRoute(path: Routes.logIn, builder: (context, state) => const PhoneEntryScreen(isSignUp: false)),
      GoRoute(
        path: '/verify',
        builder: (context, state) => VerifyCodeScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          isSignUp: state.uri.queryParameters['mode'] == 'signup',
        ),
      ),
      GoRoute(path: Routes.profileSetup, builder: (context, state) => const ProfileSetupScreen()),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(path: 'profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: 'create-group', builder: (context, state) => const CreateGroupScreen()),
          GoRoute(
            path: 'group-created/:groupId',
            builder: (context, state) => GroupCreatedScreen(groupId: state.pathParameters['groupId']!),
          ),
          GoRoute(path: 'join', builder: (context, state) => const JoinGroupScreen()),
          GoRoute(
            path: 'join-status/:requestId',
            builder: (context, state) => JoinStatusScreen(requestId: state.pathParameters['requestId']!),
          ),
          GoRoute(
            path: 'g/:groupId',
            builder: (context, state) => GroupShellScreen(
              groupId: state.pathParameters['groupId']!,
              initialTab: GroupTab.values.asNameMap()[state.uri.queryParameters['tab']] ?? GroupTab.dashboard,
            ),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => GroupSettingsScreen(groupId: state.pathParameters['groupId']!),
              ),
              GoRoute(
                path: 'expenses/new',
                builder: (context, state) => ExpenseFormScreen(groupId: state.pathParameters['groupId']!),
              ),
              GoRoute(
                path: 'expenses/:expenseId',
                builder: (context, state) => ExpenseDetailScreen(
                  groupId: state.pathParameters['groupId']!,
                  expenseId: state.pathParameters['expenseId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => ExpenseFormScreen(
                      groupId: state.pathParameters['groupId']!,
                      expenseId: state.pathParameters['expenseId'],
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'members/add',
                builder: (context, state) => AddMemberScreen(groupId: state.pathParameters['groupId']!),
              ),
              GoRoute(
                path: 'contributions/new',
                builder: (context, state) => AddContributionScreen(groupId: state.pathParameters['groupId']!),
              ),
              GoRoute(
                path: 'report',
                builder: (context, state) {
                  final start = AppDates.tryParseIso(state.uri.queryParameters['start']);
                  final end = AppDates.tryParseIso(state.uri.queryParameters['end']);
                  final now = today();
                  final range = start != null && end != null && !end.isBefore(start)
                      ? DateRange(start, end)
                      : DateRange(DateTime(now.year, now.month), now);
                  return ReportPreviewScreen(groupId: state.pathParameters['groupId']!, range: range);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Re-runs the router's redirect whenever the auth state changes.
class _StreamRefresh extends ChangeNotifier {
  _StreamRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
