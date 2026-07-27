import 'package:buzz/features/channels/media_viewer_page.dart';
import 'package:buzz/shared/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The media viewers are pushed routes rather than dialogs, so Flutter's
/// built-in Esc dismissal does not reach them — each viewer carries its own
/// binding, and these tests are the only proof it is wired up.
void main() {
  Future<void> pumpOpener(
    WidgetTester tester,
    void Function(BuildContext context) open,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => open(context),
                child: const Text('open viewer'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open viewer'));
    await tester.pumpAndSettle();
  }

  testWidgets('Esc pops MediaImageViewerPage', (tester) async {
    const viewerKey = ValueKey('message-media-image-viewer');

    await pumpOpener(
      tester,
      (context) => openImageViewer(
        context,
        imageUrl: 'https://example.com/photo.png',
        heroTag: 'photo-hero',
      ),
    );
    expect(find.byKey(viewerKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(viewerKey), findsNothing);
    expect(find.text('open viewer'), findsOneWidget);
  });

  testWidgets('Esc pops MediaVideoViewerPage', (tester) async {
    const viewerKey = ValueKey('message-media-video-viewer');

    await pumpOpener(
      tester,
      (context) =>
          openVideoViewer(context, videoUrl: 'https://example.com/clip.mp4'),
    );
    expect(find.byKey(viewerKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(viewerKey), findsNothing);
    expect(find.text('open viewer'), findsOneWidget);
  });
}
