// Renders key screens with demo data to PNGs for design review.
//
//   flutter test test/screenshots --dart-define=SCREENSHOTS=true --update-goldens
//
// Images are written to test/screenshots/goldens/ (git-ignored). Skipped in
// normal test runs.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:roomeez/app/app.dart';
import 'package:roomeez/app/providers.dart';
import 'package:roomeez/app/router.dart';
import 'package:roomeez/app/routes.dart';

import '../test_helpers.dart';

const bool _enabled = bool.fromEnvironment('SCREENSHOTS');

Future<void> _loadFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<GoRouter> _pump(WidgetTester tester, {String? user}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = seededStore()..sessionUserId = user;
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [mockStoreProvider.overrideWithValue(store)],
      child: const RoomeezApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(RoomeezApp))).read(routerProvider);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(RoomeezApp), matchesGoldenFile('goldens/$name.png'));
}

void main() {
  setUpAll(_loadFonts);

  final screens = <String, (String?, String?)>{
    '01_welcome': (null, null),
    '02_email': (null, Routes.email),
    '03_home': ('u_ali', Routes.home),
    '04_dashboard': ('u_ali', Routes.group('g_apartment')),
    '05_expenses': ('u_ali', Routes.group('g_apartment', tab: GroupTab.expenses)),
    '06_reports': ('u_ali', Routes.group('g_apartment', tab: GroupTab.reports)),
    '07_members': ('u_ali', Routes.group('g_apartment', tab: GroupTab.members)),
    '08_expense_detail': ('u_hamza', Routes.expense('g_apartment', 'e_g_apartment_3')),
    '09_add_expense': ('u_ali', Routes.addExpense('g_apartment')),
    '10_settings': ('u_ali', Routes.groupSettings('g_apartment')),
    '11_profile': ('u_ali', Routes.profile),
    '12_create_group': ('u_ali', Routes.createGroup),
    '13_report_preview': ('u_ali', '/g/g_apartment/report?start=2026-10-01&end=2026-10-15'),
  };

  for (final MapEntry(key: name, value: (user, location)) in screens.entries) {
    testWidgets(name, (tester) async {
      final router = await _pump(tester, user: user);
      if (location != null) router.go(location);
      await _shot(tester, name);
    }, skip: !_enabled);
  }
}
