import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/app/app.dart';
import 'package:roomeez/app/providers.dart';
import 'package:roomeez/app/router.dart';
import 'package:roomeez/app/routes.dart';
import 'package:roomeez/data/mock/mock_store.dart';
import 'package:roomeez/data/models/models.dart';

import '../test_helpers.dart';

/// Hamza's electricity bill in the sample data.
const hamzasExpense = 'e_g_apartment_2';

Future<MockStore> pumpApp(WidgetTester tester, {String? signedInAs, String? location}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = seededStore()..sessionUserId = signedInAs;
  await tester.pumpWidget(
    ProviderScope(
      retry: (retryCount, error) => null,
      overrides: [mockStoreProvider.overrideWithValue(store)],
      child: const RoomeezApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (location != null) {
    final container = ProviderScope.containerOf(tester.element(find.byType(RoomeezApp)));
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }
  return store;
}

void main() {
  testWidgets('signed-out users land on the welcome screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('home lists the signed-in user\'s groups', (tester) async {
    await pumpApp(tester, signedInAs: 'u_ali');
    expect(find.text('Hi, Ali'), findsOneWidget);
    expect(find.text('Gulberg Apartment 4B'), findsOneWidget);
    expect(find.text('Hostel Room 12, Johar Town'), findsOneWidget);
  });

  testWidgets('the creator sees Edit on their expense', (tester) async {
    await pumpApp(tester, signedInAs: 'u_hamza', location: Routes.expense('g_apartment', hamzasExpense));
    expect(find.text('Electricity bill (LESCO)'), findsOneWidget);
    expect(find.text('Edit expense'), findsOneWidget);
  });

  testWidgets('other members, including the manager, cannot edit it', (tester) async {
    for (final viewer in ['u_usman', 'u_ali']) {
      await pumpApp(tester, signedInAs: viewer, location: Routes.expense('g_apartment', hamzasExpense));
      expect(find.text('Electricity bill (LESCO)'), findsOneWidget);
      expect(find.text('Edit expense'), findsNothing);
      expect(find.byTooltip('More'), findsNothing);
      expect(find.text('Only Hamza Khan can edit this expense.'), findsOneWidget);
    }
  });

  testWidgets('opening the edit form directly is refused for non-creators', (tester) async {
    await pumpApp(tester, signedInAs: 'u_usman', location: Routes.editExpense('g_apartment', hamzasExpense));
    expect(find.text('No access'), findsOneWidget);
    expect(find.text('Review & save'), findsNothing);
  });

  testWidgets('adding an itemized expense recalculates totals and saves it', (tester) async {
    final store = await pumpApp(tester, signedInAs: 'u_ali', location: Routes.addExpense('g_apartment'));

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Fruit chaat');
    await tester.enterText(find.widgetWithText(TextFormField, 'Item name'), 'Bananas');
    await tester.enterText(find.widgetWithText(TextFormField, 'Qty'), '2');
    await tester.enterText(find.widgetWithText(TextFormField, 'Price each'), '150');
    await tester.pump();
    expect(find.text('PKR 300'), findsWidgets);

    await tester.ensureVisible(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add item'));
    await tester.pump();
    Future<void> enter(String label, String text) async {
      final field = find.widgetWithText(TextFormField, label).last;
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, text);
    }

    await enter('Item name', 'Apples (kg)');
    await enter('Qty', '1.5');
    await enter('Price each', '240');
    await tester.pump();
    expect(find.text('PKR 660'), findsWidgets);

    await tester.tap(find.text('Review & save'));
    await tester.pumpAndSettle();
    expect(find.text('Review expense'), findsOneWidget);
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final saved = store.expenses.values.where((e) => e.title == 'Fruit chaat').single;
    expect(saved.createdByUserId, 'u_ali');
    expect(saved.items, hasLength(2));
    expect(saved.totalPaisa, 66000);
    expect(saved.paymentSource, PaymentSource.personal);
  });

  testWidgets('the expense list has no swipe or delete controls', (tester) async {
    await pumpApp(
      tester,
      signedInAs: 'u_ali',
      location: Routes.group('g_apartment', tab: GroupTab.expenses),
    );
    expect(find.byType(Dismissible), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.textContaining('Delete'), findsNothing);
  });
}
