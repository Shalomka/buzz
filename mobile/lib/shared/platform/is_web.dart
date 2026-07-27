import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Whether the app is running in a browser.
///
/// Wraps [kIsWeb] in a provider so the web branches are testable: [kIsWeb]
/// is a compile-time constant, so a widget test running on the VM can
/// never exercise them. Tests override this to `true`.
final isWebProvider = Provider<bool>((ref) => kIsWeb);
