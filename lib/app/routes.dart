import '../core/utils/dates.dart';

enum GroupTab { dashboard, expenses, reports, members }

/// Every location in the app, in one place.
abstract final class Routes {
  static const welcome = '/welcome';
  static const email = '/email';
  static const profileSetup = '/profile-setup';

  static String verify({required String email}) => Uri(path: '/verify', queryParameters: {'email': email}).toString();

  static const home = '/';
  static const profile = '/profile';
  static const createGroup = '/create-group';
  static const joinGroup = '/join';

  static String groupCreated(String groupId) => '/group-created/$groupId';
  static String joinStatus(String requestId) => '/join-status/$requestId';

  static String group(String groupId, {GroupTab? tab}) =>
      tab == null || tab == GroupTab.dashboard ? '/g/$groupId' : '/g/$groupId?tab=${tab.name}';
  static String groupSettings(String groupId) => '/g/$groupId/settings';
  static String addExpense(String groupId) => '/g/$groupId/expenses/new';
  static String expense(String groupId, String expenseId) => '/g/$groupId/expenses/$expenseId';
  static String editExpense(String groupId, String expenseId) => '/g/$groupId/expenses/$expenseId/edit';
  static String addMember(String groupId) => '/g/$groupId/members/add';
  static String addContribution(String groupId) => '/g/$groupId/contributions/new';
  static String report(String groupId, DateRange range) => Uri(
    path: '/g/$groupId/report',
    queryParameters: {'start': AppDates.iso(range.start), 'end': AppDates.iso(range.end)},
  ).toString();
}
