import 'dart:typed_data';

import 'package:buzz/shared/widgets/attachment_drop_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';

/// Stand-in for the Phase 0 `desktop_drop` backend: renders a button that
/// hands a fixed file list to the region.
class _FakeDropBackend implements AttachmentDropBackend {
  final List<DroppedFileData> files;

  const _FakeDropBackend(this.files);

  @override
  Widget wrap({
    required Widget child,
    required ValueChanged<List<DroppedFileData>> onDropped,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => onDropped(files),
          child: const Text('drop'),
        ),
        child,
      ],
    );
  }
}

void main() {
  Widget buildTestable({
    required List<Override> overrides,
    required ValueChanged<List<DroppedFileData>> onFilesDropped,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: AttachmentDropRegion(
            onFilesDropped: onFilesDropped,
            child: const Text('composer'),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the child unchanged with the default null backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestable(overrides: const [], onFilesDropped: (_) {}),
    );

    expect(find.text('composer'), findsOneWidget);
    expect(find.text('drop'), findsNothing);
  });

  testWidgets('delivers dropped files to the callback when a backend exists', (
    tester,
  ) async {
    final dropped = <DroppedFileData>[];
    final file = DroppedFileData(
      name: 'photo.png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    await tester.pumpWidget(
      buildTestable(
        overrides: [
          attachmentDropBackendProvider.overrideWithValue(
            _FakeDropBackend([file]),
          ),
        ],
        onFilesDropped: dropped.addAll,
      ),
    );

    expect(find.text('composer'), findsOneWidget);
    await tester.tap(find.text('drop'));
    await tester.pump();

    expect(dropped, [file]);
  });
}
