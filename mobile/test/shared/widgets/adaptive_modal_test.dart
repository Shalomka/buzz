import 'package:buzz/shared/widgets/adaptive_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void setSurface(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Widget buildHost(void Function(String?) onResult) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showAdaptiveModal<String>(
                  context,
                  builder: (modalContext) => TextButton(
                    onPressed: () => Navigator.of(modalContext).pop('picked'),
                    child: const Text('Pick'),
                  ),
                );
                onResult(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows a bottom sheet and no dialog at narrow widths', (
    tester,
  ) async {
    setSurface(tester, const Size(800, 600));
    await tester.pumpWidget(buildHost((_) {}));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('shows a dialog and no bottom sheet at expanded widths', (
    tester,
  ) async {
    setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(buildHost((_) {}));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('round-trips a result from the bottom sheet', (tester) async {
    setSurface(tester, const Size(800, 600));
    String? result;
    await tester.pumpWidget(buildHost((value) => result = value));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();

    expect(result, 'picked');
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('round-trips a result from the dialog', (tester) async {
    setSurface(tester, const Size(1440, 900));
    String? result;
    await tester.pumpWidget(buildHost((value) => result = value));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();

    expect(result, 'picked');
    expect(find.byType(Dialog), findsNothing);
  });
}
