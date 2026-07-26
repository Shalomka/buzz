import 'package:buzz/shared/layout/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool> probeAt(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    late bool expanded;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expanded = isExpandedLayout(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return expanded;
  }

  testWidgets('is false at the default mobile surface (800x600)', (
    tester,
  ) async {
    expect(await probeAt(tester, const Size(800, 600)), isFalse);
  });

  testWidgets('is true at the standard wide surface (1440x900)', (
    tester,
  ) async {
    expect(await probeAt(tester, const Size(1440, 900)), isTrue);
  });

  testWidgets('is true exactly at the 840 boundary', (tester) async {
    expect(
      await probeAt(tester, const Size(kExpandedLayoutMinWidth, 600)),
      isTrue,
    );
  });

  testWidgets('is false just below the 840 boundary', (tester) async {
    expect(
      await probeAt(tester, const Size(kExpandedLayoutMinWidth - 1, 600)),
      isFalse,
    );
  });
}
