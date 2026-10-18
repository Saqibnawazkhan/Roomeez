import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomeez/core/neu/neu.dart';

void main() {
  testWidgets('tapping buttons, chips and tabs gives haptic feedback', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    var tab = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                NeuButton(label: 'Save', onPressed: () {}),
                NeuChip(label: 'Bills', selected: false, onTap: () {}),
              ],
            ),
            bottomNavigationBar: NeuBottomNav(
              index: tab,
              onTap: (i) => setState(() => tab = i),
              items: const [(Icons.home, 'One', 0), (Icons.list, 'Two', 0)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Bills'));
    await tester.tap(find.text('TWO'));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(3));
    expect(haptics.first, 'HapticFeedbackType.lightImpact');
  });
}
