import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// A file handed to the app by an OS drag-and-drop gesture.
@immutable
class DroppedFileData {
  /// File name as reported by the OS, including its extension.
  ///
  /// Callers infer the mime type from the extension — the drop backend does
  /// not classify content.
  final String name;

  /// Raw file contents.
  final Uint8List bytes;

  const DroppedFileData({required this.name, required this.bytes});
}

/// Platform seam for OS drag-and-drop.
///
/// Phase 1 ships no implementation: [attachmentDropBackendProvider] defaults
/// to `null` and [AttachmentDropRegion] renders its child untouched. Phase 0
/// (desktop platform folders) overrides the provider with a `desktop_drop`
/// backed implementation — and adds drop-target visuals at the same time,
/// since there is nothing to highlight until a real backend exists.
abstract class AttachmentDropBackend {
  /// Wraps [child] in a platform drop target that reports dropped files
  /// through [onDropped].
  Widget wrap({
    required Widget child,
    required ValueChanged<List<DroppedFileData>> onDropped,
  });
}

/// The active drag-and-drop backend, or `null` when the platform has none.
///
/// Kept in `shared/` so no feature owns the seam; Phase 0 overrides it at the
/// app root.
final attachmentDropBackendProvider = Provider<AttachmentDropBackend?>(
  (ref) => null,
);

/// Makes [child] a drop target for OS file drags when a backend is available.
///
/// With the default `null` backend the region is fully transparent — [child]
/// is returned unchanged, with no extra widget, hover state, or highlight.
class AttachmentDropRegion extends ConsumerWidget {
  /// The subtree that accepts drops.
  final Widget child;

  /// Called with the dropped files when the OS completes a drop.
  final ValueChanged<List<DroppedFileData>> onFilesDropped;

  const AttachmentDropRegion({
    super.key,
    required this.child,
    required this.onFilesDropped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.watch(attachmentDropBackendProvider);
    if (backend == null) return child;
    return backend.wrap(child: child, onDropped: onFilesDropped);
  }
}
