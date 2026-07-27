---
title: 'feat: Flutter web target (Phase 0) — Part 2: runtime gates for web-hostile call sites'
type: feat
date: 2026-07-27
part: 2 of 3
status: ready-for-build
branch: feat/flutter-web-target-part-2
base-branch: feat/flutter-web-target-part-1
pr-target: feat/flutter-web-target-part-1
depends-on: docs/plan/2026-07-27-feat-flutter-web-target-part-1-plan.md
parent-plan: docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md
brainstorm: docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§9 Phase 0 — retargeted to web only)
---

# feat: Flutter web target (Phase 0) — Part 2 of 3: runtime gates for web-hostile call sites

> **Standalone build input.** This file is the complete specification for
> Part 2 — the build stage receives only this file and **does not re-review the
> codebase**. Everything under [Codebase Context](#codebase-context-verified)
> was verified in this repo and is to be trusted. Task IDs (B2–B7, D1–D5, D8)
> are global across the three-part series and match
> `docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`, which remains
> the canonical rationale document. Any task ID not listed here belongs to
> Part 1 (landed) or Part 3 — context only, **never scope for this build**.

## Overview

Part 1 gave the `mobile/` Flutter app a web runner directory, a
`just mobile-build-web` recipe, and one overridable platform seam
(`isWebProvider`). The app now **compiles** for the browser — and crashes in one,
because five call sites reach native MethodChannels that have no web
implementation.

**Part 2 (this plan) makes the web build survive a browser session, and proves
it:**

- **B2** — badge gate in `mobile/lib/app.dart` (`app_badge_plus` has no web
  implementation).
- **B3** — hide the paperclip attach affordance in
  `mobile/lib/features/channels/compose_bar.dart`.
- **B4** — fail-fast capability flag on `MediaUploadService`
  (`mobile/lib/shared/relay/media_upload.dart`) covering
  `pickAndUploadImage()`, `readAndUploadClipboardImage()`, and
  `pickAndUploadVideo()`.
- **B5** — QR-scan gate in `mobile/lib/features/pairing/pairing_page.dart`.
- **B6** — iOS clipboard-probe gate in `compose_bar.dart` (the one the original
  audit missed).
- **B7** — analyze clean.
- **D1–D5, D8** — a test per gate, each asserting **zero platform-channel
  traffic** rather than merely "the widget is gone", and each paired with a
  non-web control so it cannot pass vacuously.

Every gate is a no-op off-web. **Part 2 touches four `lib/` files and six test
files; it touches no storage code and no documentation.** Part 3 adds the
session-only key-value store and the docs.

## Problem Statement / Motivation

The parent plan's revision 2 exists because the original gate list was derived
from a false premise. On Flutter web `defaultTargetPlatform` is **derived from
the browser user agent**, so the pre-existing `TargetPlatform.android` / `iOS`
guards do *not* make native MethodChannel calls unreachable in a browser — they
make them reachable on exactly the user agents most likely to hit them. See
[Correction: `defaultTargetPlatform` on web](#correction-defaulttargetplatform-on-web-is-user-agent-derived),
which is the single most important fact in this plan.

Consequently five call sites must be gated, not three, and — critically — the
proof cannot be "we read the code and it looks unreachable". It has to be a test
that counts method-channel invocations and asserts zero, with a control case that
asserts ≥ 1. That is what Slice D delivers.

## Proposed Solution

Read the Part 1 seam at each hostile call site and branch:

- **Widgets** read `ref.watch(isWebProvider)` into a local named `isWeb` and use
  a collection-`if` to drop the affordance. No new abstraction.
- **`MediaUploadService`** is a plain class with no Riverpod access, so it takes
  a **capability-shaped** constructor flag `bool supportsMediaUpload = true`;
  `mediaUploadServiceProvider` translates `isWebProvider` into it. The default
  `true` is what makes the change invisible to every existing caller and test.
- Media upload is **disabled outright on web**, not de-sanitised — see
  [Media upload on web](#media-upload-on-web-the-chosen-remedy) for why the
  obvious fix is a privacy regression.
- Nothing pure-Dart is gated. `uploadBytes()` and the drop/paste paths keep
  working, so a future web drag-drop backend needs no service change.

## Scope

### In scope for Part 2

- `mobile/lib/app.dart` — badge gate (B2).
- `mobile/lib/features/channels/compose_bar.dart` — paperclip gate (B3) and
  clipboard-probe gate (B6). One shared `isWeb` local.
- `mobile/lib/shared/relay/media_upload.dart` — `supportsMediaUpload` capability,
  three entry-point guards, provider wiring (B4).
- `mobile/lib/features/pairing/pairing_page.dart` — QR-scan gate + subtitle copy
  (B5).
- Tests: new `mobile/test/app_badge_gate_test.dart` (D1); new
  `mobile/test/shared/relay/media_upload_provider_test.dart` (D5); extensions to
  `mobile/test/features/channels/compose_bar_test.dart` (D2),
  `mobile/test/features/pairing/pairing_page_test.dart` (D3),
  `mobile/test/shared/relay/media_upload_test.dart` (D4), and
  `mobile/test/features/home/desktop_shell_test.dart` (D8).

### Out of scope for Part 2 — do not implement

- **The storage seam.** `mobile/lib/shared/storage/key_value_store.dart`,
  `key_value_store_provider.dart`, the `CommunityStorage` rewiring,
  `mobile/test/helpers/fake_key_value_store.dart`, the five migrated test files,
  and tests D6/D7/D9/D10 are **Part 3**. Do not touch
  `mobile/lib/shared/community/` or anything importing
  `package:flutter_secure_storage`.
- **Documentation.** `mobile/README.md`'s "Web (experimental)" section (E1) and
  the full manual verification checklist (E2) are **Part 3**.
- **Anything in `mobile/web/`, `mobile/.metadata`, or `justfile`** — Part 1
  landed those. Do not re-touch them.
- `mobile/lib/shared/platform/is_web.dart` — inherited from Part 1, **read it,
  do not edit it**.
- Gating `uploadBytes()` (`media_upload.dart:235+`), `uploadDroppedFiles`
  (`compose_bar.dart:498-514`), or `uploadPastedImage` (`compose_bar.dart:556+`)
  — all pure Dart and web-safe. Gating them would remove capability that works.
- Weakening or "fixing" the top-level predicates `_shouldSanitizePickedImage`
  (:518), `_shouldTranscodePickedImage` (:451), or
  `_supportsNativeUploadImageProcessing()` (:525-530). They stay correct for
  mobile.
- Removing the `mobile_scanner` import (`pairing_page.dart:5`), `_ScannerPage`,
  or `_openScanner` (:203-214) — they stay for mobile.
- Re-implementing the EXIF scrub in Dart, adding `file_selector`/`media_kit`, or
  any dependency change. `mobile/pubspec.yaml` and `mobile/pubspec.lock` must be
  byte-identical.
- `buzz://` deep links on web — `app_links_web` degrades harmlessly
  (`pendingDeepLinkProvider` just holds `null`). **Leave that code untouched.**
- `.github/workflows/`, secrets, feature flags, deploy/infra manifests
  (guardrail-blocked).

## Dependencies

**Builds on:** Part 1 —
`docs/plan/2026-07-27-feat-flutter-web-target-part-1-plan.md`.

**Base branch:** `feat/flutter-web-target-part-1`, at that branch's merged head
SHA (if Part 1 has already merged to `main`, still branch from the Part 1 head so
the stack stays linear). **Working branch:**
`feat/flutter-web-target-part-2`. **The PR targets
`feat/flutter-web-target-part-1`**, not `main`.

**Inherited from Part 1 (exists on the base branch — do not recreate, do not
edit):**

- `mobile/lib/shared/platform/is_web.dart`:

  ```dart
  import 'package:flutter/foundation.dart';
  import 'package:hooks_riverpod/hooks_riverpod.dart';

  /// Whether the app is running in a browser.
  ///
  /// Wraps [kIsWeb] in a provider so the web branches are testable: [kIsWeb]
  /// is a compile-time constant, so a widget test running on the VM can
  /// never exercise them. Tests override this to `true`.
  final isWebProvider = Provider<bool>((ref) => kIsWeb);
  ```

  **This is the only seam.** Every gate in this part reads it. Import it
  relatively (`import 'shared/platform/is_web.dart';` from `app.dart`,
  `import '../../shared/platform/is_web.dart';` from a feature file,
  `import '../platform/is_web.dart';` from `shared/relay/`). In Part 1 nothing
  read it; after this part, five call sites do.
- `mobile/web/` (six tracked files), the `web` entry in `mobile/.metadata`, and
  the `just mobile-build-web` recipe in `justfile` (immediately after
  `mobile-build-android` at :589-590). `just check` (:94) and `just ci` (:258)
  are unmodified and must stay that way.
- A green `flutter build web --release`.

**Also inherited from `main` (Phase 1 parity shell, PRs #1–#4, commit
`e4622671`):** `mobile/lib/features/home/desktop_shell.dart`,
`mobile/lib/shared/layout/breakpoints.dart`,
`mobile/lib/shared/shell/shell_state_provider.dart`,
`mobile/lib/shared/widgets/adaptive_modal.dart`,
`mobile/lib/features/channels/attachment_drop_region.dart`, and
`mobile/test/features/home/desktop_shell_test.dart` (which D8 extends).

**Consumed by Part 3 — do NOT remove or "clean up":** nothing from this part is
a seam for Part 3. Part 3 depends on Part 2 only for a linear stack; the two
touch disjoint files. That means **no textual merge conflict is expected between
Parts 2 and 3.**

**No new package dependencies.** `pubspec.yaml`/`pubspec.lock` unchanged.

## Branch / PR topology (three-part stack)

| Part | Branch | Base | PR targets |
|---|---|---|---|
| 1 (landed) | `feat/flutter-web-target-part-1` | `main` @ `e4622671` | `main` |
| **2 (this)** | `feat/flutter-web-target-part-2` | `feat/flutter-web-target-part-1` @ merged head SHA | `feat/flutter-web-target-part-1` |
| 3 | `feat/flutter-web-target-part-3` | `feat/flutter-web-target-part-2` @ its head SHA | `feat/flutter-web-target-part-2` |

**Terminal state for this part is an unmerged PR against
`feat/flutter-web-target-part-1`.** Do not merge, do not deploy, do not start
Part 3 from this worktree.

## Codebase Context (verified)

Everything in this section was verified in this repo. **The build stage should
trust this section and not re-review the codebase.**

### Environment and tooling facts

| Fact | Value |
|---|---|
| Flutter / Dart | 3.44.4 stable / Dart 3.12.2 |
| `FLUTTER_ROOT` | `/Users/robertasskiauteris/development/flutter` (derive with `dirname $(dirname $(readlink -f $(which flutter)))`) |
| File-size guard | `mobile/scripts/check-file-sizes.mjs` — 1000 lines, **`lib/` only**, no overrides. `test/` is not scanned |
| Baseline | `flutter analyze` → **No errors**; 60 `*_test.dart` files all pass (61 after Part 2's two new files) |

**Hook/permission constraints for the build stage (hard constraints):**

- `flutter create` / `dart create` → **BLOCKED** by a PreToolUse hook. (Nothing
  in this part needs them; Part 1 hand-authored `mobile/web/`.)
- `flutter test` / `dart test` in Bash → **BLOCKED**. Use the `very_good_cli`
  MCP `test` tool (`directory: mobile`).
- `flutter build web` → **PERMITTED** for this run (a scoped human exception to
  CLAUDE.md's "never run `flutter build`").
- `flutter run` / `flutter clean` / `flutter upgrade` → still **forbidden**.
- `flutter analyze` and `dart format` → permitted.
- Writes to secrets, feature flags, `.github/workflows/`, and deploy/infra
  manifests are **hard-blocked by a guardrail hook**. Do not attempt them.

### Files this part touches (verified line references)

| File | Lines | Current state |
|---|---|---|
| `mobile/lib/app.dart` | 95 | `applyBadge` at :48-56 calls `AppBadgePlus.updateBadge` at :50/:52/:54; invoked from `useEffect` :58-61 and `ref.listen` :62-64. Relative import block at :7-16; other `ref.watch` reads around :26 |
| `mobile/lib/features/channels/compose_bar.dart` | 822 | `class ComposeBar extends HookConsumerWidget` :102, `build` :123. **Clipboard probe `useEffect` :140-168**, guarded only by `if (defaultTargetPlatform != TargetPlatform.iOS) return null;` (:141), calling `clipboardHasImage()`; it is the only writer of `clipboardHasImage.value`, which in turn is the only thing that surfaces the "Paste Image" items at :528/:544. Paperclip `_ComposeAction` at :747 inside the `Row(children: [` at :745; it opens the attach sheet `Column(children:)` ~:756-781 — "Photo" `ListTile` then "Video" `ListTile` (:769-780). `pickAndUpload` helper :472-489 catches and surfaces errors via `_formatUploadError`. `uploadDroppedFiles` :498-514 and `uploadPastedImage` :556+ call `uploadBytes` directly (pure Dart, no MethodChannel — **not** gated). Relative import block :13-25 |
| `mobile/lib/shared/relay/media_upload.dart` | 679 | Message consts :44-49; fields :135-142; ctor :144-166 (params :144-157, initializer list :158-166); `pickAndUploadImage()` :174-199; `readAndUploadClipboardImage()` :192; `pickAndUploadVideo()` :200-233; `uploadBytes()` :235+ (pure Dart); `_prepareUploadImage` :344-357 → `_shouldTranscodePickedImage` call :352; `_sanitizeImageBytesIfNeeded` :383-394 → `_shouldSanitizePickedImage` call :386; `_shouldTranscodePickedImage` :451; `_shouldSanitizePickedImage` :518; the shared predicate `_supportsNativeUploadImageProcessing()` :525-530 (`android \|\| iOS => true`); `mediaUploadServiceProvider` :665-679 |
| `mobile/lib/features/pairing/pairing_page.dart` | 407 | `mobile_scanner` import :5; import block :7-8; other `ref` reads :19-25; subtitle text :74-79; "Scan QR Code" `FilledButton.icon` :85-91; `SizedBox(Grid.sm)` :93; "or paste pairing code" divider `Row` :95-112; `SizedBox(Grid.sm)` :114; paste `TextField` :117; `_openScanner` :203-214. **Path verified — this is the real file** (`mobile/lib/features/pairing/` also holds `pairing_crypto.dart`, `pairing_provider.dart`, `pairing_socket.dart`) |

**Files this part must NOT touch:** `mobile/lib/shared/community/**`,
`mobile/lib/shared/storage/**` (does not exist yet), `mobile/lib/main.dart`,
`mobile/lib/shared/platform/is_web.dart`, `mobile/README.md`, `justfile`,
`mobile/web/**`, `mobile/.metadata`, `mobile/pubspec.*`, `mobile/android/**`,
`mobile/ios/**`.

### Correction: `defaultTargetPlatform` on web is user-agent derived

**This overturns the brainstorm's §3 conclusion and is the single most important
fact in this plan.** Verified in the SDK at
`$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`:

```dart
platform.TargetPlatform get defaultTargetPlatform =>
    platform.debugDefaultTargetPlatformOverride ?? _testPlatform ?? _browserPlatform;

final platform.TargetPlatform _browserPlatform =
    _operatingSystemToTargetPlatform(ui_web.browser.operatingSystem);
// android => android, iOs => iOS, linux => linux, macOs => macOS,
// windows => windows, unknown => android   <-- note the fallback
```

Consequences — all of these are **reachable in a browser**, contrary to the
brainstorm's "already dead on web" claim:

| Browser | `defaultTargetPlatform` | `_supportsNativeUploadImageProcessing()` (:525-530) | `compose_bar.dart:141` iOS guard |
|---|---|---|---|
| Desktop Chrome/Safari on macOS | `macOS` | `false` — safe | blocks — safe |
| Desktop Chrome on Windows/Linux | `windows` / `linux` | `false` — safe | blocks — safe |
| **Android Chrome** | **`android`** | **`true` → `MissingPluginException`** | blocks |
| **iOS Safari** | **`iOS`** | **`true` → `MissingPluginException`** | **falls through → `clipboardHasImage()` → `MissingPluginException`** |
| **Unrecognized UA** | **`android`** (fallback) | **`true` → `MissingPluginException`** | blocks |

So on a mobile-browser or unknown user agent, **every image upload** invokes
`sanitizeImageForUpload` / `transcodeImageToJpeg`, and on iOS Safari the
ComposeBar's clipboard probe fires on mount, on focus, and on every app resume —
from an unawaited future. A manual checklist that only exercises a desktop
browser ≥ 1440px would never catch this.

Two further facts that shape the remedy:

1. **The native "sanitize" step is a metadata scrub, not a nicety.**
   `mobile/android/app/src/main/kotlin/xyz/block/buzz/mobile/MainActivity.kt:189`
   calls `AndroidImageProcessor.encodeAndScrub(bitmap, format)` — it decodes and
   re-encodes, which drops EXIF including GPS. Simply *skipping* it on web
   (the obvious fix) would silently ship images with location metadata intact,
   trading a crash for a privacy regression. See
   [Media upload on web](#media-upload-on-web-the-chosen-remedy).
2. **`flutter_test` sets `debugDefaultTargetPlatformOverride = TargetPlatform.android`**,
   which is why `compose_bar_test.dart:86-102` already installs mock handlers for
   `sanitizeImageForUpload` / `transcodeImageToJpeg` in `setUpAll`. Widget tests
   therefore exercise the android branch by default — useful for the new tests,
   and a reminder that a green suite never proved these paths were web-safe.

**Rule for this part:** `grep -rn "defaultTargetPlatform" mobile/lib` must show
**no newly added uses**. The pre-existing ones remain, now paired with a web-seam
check wherever they guard a MethodChannel (`compose_bar.dart:141` via B6, and the
`media_upload.dart` image pipeline via B4's entry-point guards).

### Findings that override the source plan

These were verified empirically in the brainstorm. **Do not re-litigate them; if
you believe one is wrong, verify it yourself and say so explicitly in the PR.**

1. **`dart:io` compiles fine under dart2js** (mapped via `_dart2js_common` →
   `io_patch.dart`). No conditional-import (`_stub`/`_io`/`_web`) scaffolding is
   needed anywhere. The three `mobile/lib` files that import `dart:io`
   (`channels_page.dart`, `media_upload.dart`, `mp4_fast_start.dart`) stay
   exactly as they are:
   - `channels_page.dart:2` — `SocketException` is used by
     `channels_page/badges.dart:138` (`if (error is SocketException)`); the type
     test evaluates `false` on web and falls through. **Do not remove this
     import** — it is used, and removing it changes mobile error copy.
   - `media_upload.dart` — `HttpStatus.*` are plain int consts (safe); `File` I/O
     is either inside `pickAndUploadVideo()` (gated by B4) or inside a
     `defaultTargetPlatform == TargetPlatform.android` branch.
   - `mp4_fast_start.dart` — only caller is the android-only branch.
2. **`image_picker` and `video_player` keep their endorsed web
   implementations.** The source plan's `file_selector` / `media_kit` swaps are
   native-desktop remedies with no web justification. **Do not perform them.**
3. **`app_badge_plus` is the only dependency with no web implementation** — the
   one guaranteed `MissingPluginException`. `AppBadgePlus.isSupported()` throws
   too, so it cannot be used as a capability probe; **gate at the call site**
   (B2).
4. ~~**Only the video path of the `buzz/media_upload` MethodChannel needs
   gating.**~~ **CORRECTED — this finding was wrong.** The brainstorm (and the
   first revision of the parent plan) claimed the other four methods were
   "already dead on web" behind pre-existing `defaultTargetPlatform` guards. They
   are not: see
   [the correction](#correction-defaulttargetplatform-on-web-is-user-agent-derived).
   **Three** of the five methods are reachable in a browser —
   `sanitizeImageForUpload` and `transcodeImageToJpeg` on any android/iOS/unknown
   UA, and `clipboardHasImage` on iOS Safari. `readClipboardImage` is reachable
   only via `clipboardHasImage`, so gating the probe closes it too.
   The still-true half: `uploadBytes()` and everything under it is pure Dart and
   web-safe, and `image_picker_for_web` never needs `File(path)`.
5. **Relay CORS**: `Access-Control-Allow-Headers: *` does not cover
   `Authorization`, so **cross-origin** dev breaks every avatar, inline image, and
   upload. Mitigated by serving same-origin; the Rust fix is a follow-up
   (documented in Part 3).

### Existing test infrastructure (verified)

- `mobile/test/helpers/widget_helpers.dart` → `WidgetHelpers.testable({child, overrides})`.
- `mobile/test/features/channels/compose_bar_test.dart` (1671 lines) →
  `_buildComposeBar({... List<Override> extraOverrides = const []})` at
  :115-160, with `extraOverrides` at :124 — **already accepts extra overrides,
  no harness change needed**. `_FakeRelayConfigNotifier` at :162-168 shows how to
  fake `relayConfigProvider`. `setUpAll` at :86-102 installs mock handlers for
  `sanitizeImageForUpload` / `transcodeImageToJpeg`. **Eight existing tests tap
  the paperclip**: → `Photo` at :309, :777, :834, :876, :913, :1124, :1194 and
  → `Video` at :1194. They are the mobile control for B3 and **must pass
  unchanged**.
- `mobile/test/features/pairing/pairing_page_test.dart` → the existing first test
  at :11-27 is the non-web control for B5; **leave it unchanged**.
- `mobile/test/features/home/desktop_shell_test.dart` → `useWideSurface(tester)`
  sets `physicalSize = Size(1440, 900)` (:56-57 region),
  `createContainer({UnreadBadgeState? unreadBadge})`, `buildTestable(container)`
  mounting `DesktopShell` in an `UncontrolledProviderScope`.
- `mobile/test/shared/relay/media_upload_test.dart:1091` →
  `group('pickAndUploadVideo', ...)`, constructs `MediaUploadService` directly.
- `mobile/test/widget_test.dart` → mounts `App` with `authProvider` and
  `savedPrefsProvider` overrides; `_FakeAuthNotifier` pattern at :29-34.

Platform channel names needed by this part's tests:

| Plugin | Channel |
|---|---|
| `app_badge_plus` 1.2.10 | `app_badge_plus`, method `updateBadge` with `{'count': int}` |
| Buzz native media helpers | `buzz/media_upload`, methods `sanitizeImageForUpload`, `transcodeImageToJpeg`, `clipboardHasImage`, `readClipboardImage` |

### Conventions the implementation must follow

From `CLAUDE.md` (§ Mobile App) and observed repo practice:

- **Never `StatefulWidget`.** Riverpod (v3) + `flutter_hooks`;
  `HookConsumerWidget` / `ConsumerWidget`.
- **No `print()`** — `debugPrint()` or structured logging.
- Prefer `context.colors` / `context.textTheme` over raw `Theme.of(context)`.
- `Grid` tokens for spacing, `Radii` for radii.
- **Features must not import other features** — only from `shared/`.
  `shared/platform/` is `shared/`, so every gate may import it.
- One public widget per file; **1000-line ceiling on `lib/` files** (enforced by
  `mobile/scripts/check-file-sizes.mjs`; no overrides exist and **none may be
  added**). `compose_bar.dart` is the closest at 822 lines — B3 + B6 add ~5.
  **If you find yourself near 1000, split the file; never bump the limit.**
- Imports: **within `lib/`, use relative imports** (e.g. `app.dart` imports
  `shared/auth/auth.dart`; `compose_bar.dart` imports
  `../../shared/relay/relay.dart`). **In `test/`, use `package:buzz/...`.**
- `Provider` is imported from `package:hooks_riverpod/hooks_riverpod.dart`.
- Tests: prefer **widget tests** over unit tests for UI; inject fakes with
  `ProviderScope(overrides: [...])`; fake notifiers extend the real notifier and
  override `build()`; `WidgetHelpers.testable()` for simple cases.

## Technical Considerations

### Architecture

- **One seam, not an abstraction layer.** `isWebProvider` is a single
  `Provider<bool>` returning `kIsWeb`. A "platform capabilities" abstraction for
  five gates would be over-engineering.
- **Capability-shaped naming at the service boundary only.**
  `MediaUploadService` is a plain class (not Riverpod-aware), so it takes a
  `bool supportsMediaUpload = true` constructor flag rather than an `isWeb` flag.
  The provider translates `isWebProvider` into that capability. This keeps the
  service platform-agnostic and gives every existing caller and test an unchanged
  default. In **widgets**, by contrast, `ref.watch(isWebProvider)` *is* the seam
  and the local is named `isWeb` — introducing `supportsAppBadge` /
  `supportsQrScan` locals there would add a layer of indirection with no boundary
  to cross, and would obscure the actual reason the branch exists (we are in a
  browser), which the adjacent comment has to explain anyway.
- **One `isWeb` local per `build()`.** B3 and B6 both live in
  `ComposeBar.build`; B6 reuses B3's local. Do not add a second `ref.watch`.

### Media upload on web (the chosen remedy)

Three options were considered for the image path once
[the UA correction](#correction-defaulttargetplatform-on-web-is-user-agent-derived)
invalidated "image upload works end to end on web":

| Option | Verdict |
|---|---|
| **(a)** Thread a `supportsNativeImageProcessing` flag and simply **skip** the scrub on web | **Rejected.** It fixes the crash and silently introduces a privacy regression: `encodeAndScrub` is what strips EXIF/GPS, so web uploads would carry location metadata that mobile uploads do not. It also produces a confusing HEIC path — `_prepareUploadImage:352-356` would fall through to `throw Exception('unsupported file type')` for any HEIC pick. |
| **(b)** Re-implement the scrub in pure Dart on web (`ui.instantiateImageCodec` → re-encode) | **Rejected — YAGNI.** New implementation work with real risk (memory, colour profiles, alpha) for a surface that is not user-facing in Phase 0. Deferred. |
| **(c)** **Disable the pick-and-upload affordance entirely on web** ← **chosen** | One capability flag instead of two, no EXIF question, no HEIC edge case, and consistent with every other Phase 0 gate ("disabled, not ported"). Smaller diff than (a): hide the paperclip rather than one tile inside it. |

Chosen shape: a single `supportsMediaUpload` capability that fails **all three**
MethodChannel-reaching entry points fast, plus hiding the paperclip
`_ComposeAction` on web. **`uploadBytes()` is deliberately not gated** — it is
pure Dart, it is what a future web drag-drop backend and the pasted-content path
use, and gating it would remove capability that works.

### Mobile-regression safety (the non-negotiable)

Android/iOS ship today. Every gate must be a no-op off-web:

- `isWebProvider` returns `kIsWeb` → `false` on Android/iOS/VM tests, so every
  `if (isWeb)` / `if (!isWeb)` branch keeps today's behavior.
- `MediaUploadService.supportsMediaUpload` **defaults to `true`**, so every
  existing `MediaUploadService(...)` construction in tests and in the provider
  behaves identically.
- No dependency, `pubspec`, `android/`, or `ios/` changes at all.
- The pre-existing test files are the regression gate. **None may be weakened,
  skipped, or deleted.** The only permitted edits to existing test files in this
  part are **purely additive new cases** (D2, D3, D4, D8) and the one additive
  optional parameter on `createContainer` in D8. In particular the eight
  `paperclip` taps in `compose_bar_test.dart` and the first pairing test
  (:11-27) must pass **byte-unchanged**.

### What this part does *not* prove

State this honestly in the PR body. The tests reach the android/iOS branches only
via `debugDefaultTargetPlatformOverride`; nothing here runs a real browser, so
the actual UA → `TargetPlatform` mapping is verified by **reading the SDK, not by
execution**. `flutter build web` succeeding proves the reachable Dart graph
compiles — it proves nothing about rendering fidelity, font loading,
mouse-wheel/trackpad scroll, a live WebSocket + NIP-42 handshake, or same-origin
image loading.

Additionally, **sign-in material still reaches browser `localStorage` after this
part** — `CommunityStorage` is untouched until Part 3. A browser session opened
against this part's build will survive without `MissingPluginException`, but it
is **not yet safe to pair against a real relay from a browser**. Say so in the
PR body. The full manual browser checklist lands with Part 3 (E2).

## Acceptance Criteria

Every item is mechanically checkable. `<base>` below means
`feat/flutter-web-target-part-1` (this part's base branch).

### Gates and their proofs

- [ ] With `isWebProvider` overridden to `true`, tests assert **zero**
      `app_badge_plus` channel calls (D1), paired with a non-web control that
      produces ≥ 1.
- [ ] With `isWebProvider` overridden to `true`, tests assert **zero**
      `buzz/media_upload` channel calls covering all three browser-reachable
      methods — `sanitizeImageForUpload`, `transcodeImageToJpeg`, and
      `clipboardHasImage` (D2b, D4), paired with non-web controls that produce
      ≥ 1.
- [ ] With `isWebProvider` overridden to `true`, no paperclip attach affordance
      is findable in `ComposeBar` (D2a); the eight existing `paperclip` tests are
      the mobile control and pass unchanged.
- [ ] With `isWebProvider` overridden to `true`, `PairingPage` shows no
      "Scan QR Code" button and no "or paste pairing code" divider, still shows
      exactly one `TextField` and the `Connect` button, and shows the paste-only
      subtitle copy (D3). The existing first test (:11-27) is the control.
- [ ] `MediaUploadService(supportsMediaUpload: false, ...)` makes
      `pickAndUploadImage()`, `readAndUploadClipboardImage()`, and
      `pickAndUploadVideo()` all throw a message containing
      `not supported in the browser`, **with the picker call counters still 0**
      (D4) — proving failure precedes the picker, the channel, and `File`.
- [ ] `mediaUploadServiceProvider` actually threads the capability: with
      `isWebProvider` `true`, `container.read(mediaUploadServiceProvider)`'s
      `pickAndUploadImage()` and `pickAndUploadVideo()` both throw the web message
      (D5).
- [ ] With `isWebProvider` overridden to `true` at 1440×900, `DesktopShell` still
      renders the community rail, the channel list (`general`), and the empty
      message pane (`Select a channel`), and throws no exception (D8).

### Repo-level checks

- [ ] `cd mobile && flutter analyze` reports **zero errors** (no new warnings or
      infos either).
- [ ] The full mobile test suite passes via the `very_good_cli` MCP `test` tool
      (`directory: mobile`), including every new case in
      [Test Plan](#test-plan). No pre-existing test is weakened, skipped, or
      deleted.
- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && node ./scripts/check-file-sizes.mjs` exits 0; every touched
      `lib/` file is < 1000 lines (`compose_bar.dart` stays well under) and **no
      override entry is added** to that script.
- [ ] `just mobile-build-web` still exits 0 and produces
      `mobile/build/web/flutter_bootstrap.js` and `mobile/build/web/main.dart.js`.
- [ ] `git diff --name-only <base>...HEAD -- mobile/lib` returns **exactly these
      four paths**: `mobile/lib/app.dart`,
      `mobile/lib/features/channels/compose_bar.dart`,
      `mobile/lib/shared/relay/media_upload.dart`,
      `mobile/lib/features/pairing/pairing_page.dart`.
- [ ] `git diff --name-only <base>...HEAD -- mobile/lib/shared/community mobile/lib/shared/storage mobile/lib/shared/platform mobile/lib/main.dart mobile/README.md justfile mobile/web mobile/.metadata`
      is **empty** (Part 1 and Part 3 own those).
- [ ] `git diff --stat <base>...HEAD -- mobile/pubspec.yaml mobile/pubspec.lock 'mobile/android/**' 'mobile/ios/**' ':(top).github/**' ':(top)crates/**' ':(top)desktop/**' ':(top)web/**' .env.example`
      is **empty**. Note the `:(top)` prefixes: a bare `web/**` pathspec would
      match `mobile/web/**` and make this check meaningless.
- [ ] `grep -rn "kIsWeb" mobile/lib` returns **exactly one** hit:
      `mobile/lib/shared/platform/is_web.dart`.
- [ ] `grep -rn "defaultTargetPlatform" mobile/lib` shows **no newly added uses**
      versus `<base>`; the pre-existing ones remain, now paired with a web-seam
      check wherever they guard a MethodChannel (`compose_bar.dart:141`,
      `media_upload.dart` image pipeline).
- [ ] `just check` (:94) and `just ci` (:258) are unmodified.
- [ ] The PR body states what the automated gates do and do not prove (see
      [What this part does *not* prove](#what-this-part-does-not-prove)),
      explicitly including that **sign-in material still reaches browser
      `localStorage` until Part 3 lands**.

**Explicitly NOT asserted by this part** (they belong to Part 3 and cannot be
true yet): `keyValueStoreProvider` resolving to `isA<InMemoryKeyValueStore>()`;
zero `plugins.it_nomads.com/flutter_secure_storage` channel traffic; the
`flutter_secure_storage` import fence; the `mobile/README.md` web section; the
full manual verification checklist.

## Implementation Tasks

Ordered. B3 must precede B6 (B6 reuses B3's `isWeb` local). Each D task should
follow its B task so a failure localises immediately.

### Slice B — five runtime gates

- [ ] **B2. Badge gate** — `mobile/lib/app.dart`. Add
      `import 'shared/platform/is_web.dart';` to the relative import block
      (:7-16). Read `final isWeb = ref.watch(isWebProvider);` alongside the other
      watches (after :26). In `applyBadge` (:48-56) return early:

      ```dart
      void applyBadge(UnreadBadgeState state) {
        // app_badge_plus has no web implementation; every call throws
        // MissingPluginException in a browser. isSupported() throws too, so it
        // cannot be used as a probe — gate at the call site.
        if (isWeb) return;
        final count = state.highPriorityCount > 0
            ? state.highPriorityCount
            : (state.generalUnreadCount > 0 ? 1 : 0);
        // Fire-and-forget: some Android launchers reject badge updates, and the
        // returned Future was previously discarded, so a rejection surfaced as
        // an unhandled async error.
        unawaited(
          AppBadgePlus.updateBadge(count).catchError((Object error) {
            debugPrint('Failed to update app badge: $error');
          }),
        );
      }
      ```

      The `count` expression is exactly equivalent to the existing
      if/else-if/else at :49-55. Add `import 'dart:async';` for `unawaited`;
      `debugPrint` is already available via `package:flutter/material.dart`.
      **Do not use `print()`.**
- [ ] **B3. Attach affordance gate** —
      `mobile/lib/features/channels/compose_bar.dart`. Add
      `import '../../shared/platform/is_web.dart';` to the relative import block
      (:13-25). Add `final isWeb = ref.watch(isWebProvider);` near the top of
      `ComposeBar.build` (:123+). Make the **paperclip** `_ComposeAction`
      (:747, inside the `Row(children: [` at :745) conditional — that is the only
      entry point to the attach sheet, so one collection-`if` removes both tiles:

      ```dart
      // Row 2 — action buttons [paperclip, emoji, @, Aa] ... [send].
      Row(
        children: [
          // Both pick-and-upload paths need the native buzz/media_upload
          // channel (video transcode; image EXIF scrub), which has no web
          // implementation — see "Media upload on web" in the plan.
          if (!isWeb)
            _ComposeAction(
              icon: LucideIcons.paperclip,
              onTap: () { ...unchanged... },
            ),
          _ComposeAction(icon: LucideIcons.smilePlus, ...),
          ...
        ],
      )
      ```

      **Leave the sheet's "Photo" and "Video" `ListTile`s exactly as they are**
      (:769-780) — hiding their only entry point is sufficient and keeps the diff
      to one line. **Do not gate** `uploadDroppedFiles` (:498-514) or
      `uploadPastedImage` (:556+): both call `uploadBytes` directly in pure Dart.
- [ ] **B4. Media upload fail-fast** — `mobile/lib/shared/relay/media_upload.dart`.
      One capability covers both media paths; see
      [Media upload on web](#media-upload-on-web-the-chosen-remedy) for why the
      image path is disabled rather than de-sanitized.
      1. Add near the other message consts (:44-49):

         ```dart
         const _unsupportedWebMediaUploadMessage =
             'Media upload is not supported in the browser yet.';
         ```

      2. Add `final bool _supportsMediaUpload;` to the field block (:135-142).
      3. Add `bool supportsMediaUpload = true,` to the constructor parameters
         (:144-157) and `_supportsMediaUpload = supportsMediaUpload,` to the
         initializer list (:158-166). **The default must be `true`** so every
         existing caller and test is unaffected.
      4. Add the same guard as the **first** statement of all three
         MethodChannel-reaching entry points — `pickAndUploadImage()` (:174),
         `readAndUploadClipboardImage()` (:192), and `pickAndUploadVideo()`
         (:200):

         ```dart
         if (!_supportsMediaUpload) {
           throw Exception(_unsupportedWebMediaUploadMessage);
         }
         ```

         It must precede the picker, the `buzz/media_upload` channel, and every
         `File(...)` call — each of which throws an unreadable platform error on
         web. `pickAndUploadImage` is included because its
         `_prepareUploadImage` → `_shouldSanitizePickedImage` /
         `_shouldTranscodePickedImage` path invokes `sanitizeImageForUpload` /
         `transcodeImageToJpeg` on any android/iOS/unknown UA.
      5. **Leave `uploadBytes()` (:235+) ungated** — pure Dart, and the path a
         future web drag-drop backend will use.
      6. **Leave the top-level predicates `_shouldSanitizePickedImage` (:518) and
         `_shouldTranscodePickedImage` (:451) and the shared
         `_supportsNativeUploadImageProcessing()` (:525-530) unchanged.** They
         stay correct for mobile; the entry-point guard is what makes them
         unreachable on web. Do not weaken them.
      7. In `mediaUploadServiceProvider` (:665-679) add
         `supportsMediaUpload: !ref.watch(isWebProvider),` to the
         `MediaUploadService(...)` call, plus
         `import '../platform/is_web.dart';`.
- [ ] **B5. QR-scan gate** — `mobile/lib/features/pairing/pairing_page.dart`.
      Add `import '../../shared/platform/is_web.dart';` (:7-8 block) and
      `final isWeb = ref.watch(isWebProvider);` near the other reads (:19-25).
      1. Subtitle (:74-79): use
         `'Paste a pairing code from your desktop app to connect.'` when `isWeb`,
         otherwise the existing
         `'Scan the QR code from your desktop app\nor paste a pairing code to connect.'`
         string **verbatim**.
      2. Wrap the scan affordance and its divider in a collection-`if`, keeping
         the preceding `SizedBox(height: Grid.lg)` and the paste `TextField`
         (:117) untouched:

         ```dart
         const SizedBox(height: Grid.lg),
         if (!isWeb) ...[
           FilledButton.icon(...),          // :85-91 unchanged
           const SizedBox(height: Grid.sm), // :93
           Row(...),                        // :95-112 "or paste pairing code"
           const SizedBox(height: Grid.sm), // :114
         ],
         // Paste field
         TextField(...)
         ```

      3. **Do not touch** the `mobile_scanner` import (:5), `_ScannerPage`, or
         `_openScanner` (:203-214) — they stay for mobile. `_openScanner` is
         simply unreachable on web, so `mobile_scanner`'s lazy `unpkg.com` fetch
         of `@zxing/library` never happens.
- [ ] **B6. iOS clipboard-probe gate** —
      `mobile/lib/features/channels/compose_bar.dart:140-167`. The probe
      `useEffect` is guarded only by `defaultTargetPlatform`, which resolves to
      `TargetPlatform.iOS` on iOS Safari, so `clipboardHasImage()` fires on
      mount, on focus, and on every app resume. Add the web seam to the existing
      early return (one line):

      ```dart
      useEffect(() {
        // defaultTargetPlatform is user-agent derived on web, so iOS Safari
        // reaches this; the buzz/media_upload channel has no web side.
        if (isWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
        ...unchanged...
      }, [focusNode]);
      ```

      **Leave the dependency list `[focusNode]` unchanged** — `isWeb` is constant
      for the process lifetime. This also closes `readClipboardImage`: the
      "Paste Image" context-menu items at :528 and :544 are gated on
      `clipboardHasImage.value`, and this effect is its only writer, so it stays
      `false` on web. **Reuse the `isWeb` local introduced in B3; do not add a
      second `ref.watch`.**
- [ ] **B7.** `cd mobile && flutter analyze` → zero errors. Then
      `cd mobile && dart format .`, re-run
      `dart format --output=none --set-exit-if-changed .` to confirm clean, and
      run `node ./scripts/check-file-sizes.mjs`.

### Slice D (this part's share) — gate tests

See [Test Plan](#test-plan) for the full case list.

- [ ] **D1.** New `mobile/test/app_badge_gate_test.dart`.
- [ ] **D2.** New `group('web gates', ...)` in
      `mobile/test/features/channels/compose_bar_test.dart` (attach affordance
      **and** clipboard probe).
- [ ] **D3.** New cases in `mobile/test/features/pairing/pairing_page_test.dart`.
- [ ] **D4.** New cases in `mobile/test/shared/relay/media_upload_test.dart`
      (extend `group('pickAndUploadVideo')` at :1091, plus an image-path case).
- [ ] **D5.** New `mobile/test/shared/relay/media_upload_provider_test.dart`.
- [ ] **D8.** New case in `mobile/test/features/home/desktop_shell_test.dart`.

### Verification (run before opening the PR)

- [ ] Full suite via the `very_good_cli` MCP `test` tool (`directory: mobile`) —
      all green, including the eight unchanged `paperclip` tests and the
      unchanged first pairing test.
- [ ] `cd mobile && flutter analyze`, `dart format --output=none
      --set-exit-if-changed .`, `node ./scripts/check-file-sizes.mjs`.
- [ ] `just mobile-build-web` exits 0.
- [ ] Every check in [Acceptance Criteria](#acceptance-criteria).

## Test Plan

All tests run on the VM, where `kIsWeb` is `false`; the web branches are reached
**only** by overriding `isWebProvider`.

| # | File | Cases |
|---|---|---|
| D1 | `mobile/test/app_badge_gate_test.dart` (new) | Install a mock handler on `const MethodChannel('app_badge_plus')` via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`, recording `updateBadge` calls. Pump `App` with `authProvider` faked (copy `_FakeAuthNotifier` from `test/widget_test.dart:29-34`), `savedPrefsProvider` overridden from `SharedPreferences.setMockInitialValues({})`, plus `isWebProvider.overrideWithValue(...)`. **(a)** `false` → ≥ 1 recorded call (the control; proves the test observes the channel). **(b)** `true` → **zero** recorded calls. Clear the handler in `tearDown`. |
| D2 | `mobile/test/features/channels/compose_bar_test.dart` (extend) | New `group('web gates', ...)` using the existing `_buildComposeBar(..., extraOverrides: [isWebProvider.overrideWithValue(true)])` — the helper already accepts `extraOverrides` (:124), so **no harness change is needed**. **(a)** `find.byIcon(LucideIcons.paperclip)` findsNothing on web. **(b)** Clipboard probe: extend the `setUpAll` handler at :86-102 to count `clipboardHasImage` invocations; with `isWebProvider` true and `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` (reset in `tearDown`), pump the ComposeBar, focus the field, and assert the count is **0**; without the web override the same scenario gives ≥ 1 (control). **Do not add a non-web control for the paperclip** — 7 existing tests already tap `paperclip` → `Photo` (:309, :777, :834, :876, :913, :1124, :1194) and one taps `paperclip` → `Video` (:1194); they pass unchanged and are the control. |
| D3 | `mobile/test/features/pairing/pairing_page_test.dart` (extend) | `WidgetHelpers.testable(child: const PairingPage(), overrides: [isWebProvider.overrideWithValue(true)])`: `find.text('Scan QR Code')` findsNothing; `find.text('or paste pairing code')` findsNothing; `find.byType(TextField)` findsOneWidget; `find.text('Connect')` findsOneWidget; subtitle equals the paste-only copy. The existing first test (:11-27) is the non-web control — **leave it unchanged**. |
| D4 | `mobile/test/shared/relay/media_upload_test.dart` (extend `group('pickAndUploadVideo')`, :1091, and add an image case) | Construct `MediaUploadService(supportsMediaUpload: false, ...)` with `pickGalleryVideo` / `pickGalleryImage` closures that increment counters. Assert **both** `pickAndUploadVideo()` and `pickAndUploadImage()` throw a message containing `not supported in the browser`, **and** both counters are still 0 (proves failure precedes the picker, the `buzz/media_upload` channel, and `File`). Also assert `readAndUploadClipboardImage()` throws the same. The existing cases in this group — which omit the new flag and therefore get the `true` default — are the mobile control. |
| D5 | `mobile/test/shared/relay/media_upload_provider_test.dart` (new) | `ProviderContainer(overrides: [relayConfigProvider.overrideWith(() => _FakeRelayConfigNotifier()), isWebProvider.overrideWithValue(true)])`; assert `container.read(mediaUploadServiceProvider).pickAndUploadVideo()` **and** `.pickAndUploadImage()` throw the web message — this is what proves the provider actually threads `supportsMediaUpload`. Copy the 5-line `_FakeRelayConfigNotifier` shape from `compose_bar_test.dart:162-168` (`RelayConfig(baseUrl: 'http://localhost:3000', nsec: nostr.Keys.generate().nsec)`). `addTearDown(container.dispose)`. |
| D8 | `mobile/test/features/home/desktop_shell_test.dart` (extend) | Add an optional `bool isWeb = false` parameter to `createContainer` that appends `isWebProvider.overrideWithValue(isWeb)` to the override list. New case: `useWideSurface(tester)` (1440×900) + `createContainer(isWeb: true)` + `buildTestable(container)` → the community rail items, `find.text('general')`, and `find.text('Select a channel')` all render, and no exception is thrown. This is the "prove one reused screen" check. |

**Not in this part** (Part 3): D6 `key_value_store_test.dart`, D7
`community_storage_web_test.dart`, D9 `secure_key_value_store_test.dart`, D10
`storage_import_fence_test.dart`, and D11 (the final full-suite gate).

**Existing-suite requirement:** all pre-existing test files still pass, with the
only edits being the additive cases above and D8's one optional parameter. In
particular the 7 existing `paperclip → Photo` tests and the 1
`paperclip → Video` test in `compose_bar_test.dart` must pass **unchanged**;
they are the mobile control for B3. The first test in `pairing_page_test.dart`
(:11-27) must pass **unchanged**; it is the control for B5.

## Success Metrics

- Five gates, and a test per gate asserting **zero platform-channel traffic**
  rather than merely "the widget is gone": every disabled-on-web behavior is
  asserted, and each assertion is paired with a non-web control so it cannot pass
  vacuously.
- The three browser-reachable `buzz/media_upload` methods
  (`sanitizeImageForUpload`, `transcodeImageToJpeg`, `clipboardHasImage`) are
  provably unreachable under an `isWebProvider` override — closing the gap the
  original audit missed.
- Zero change to the Android/iOS runtime: no dependency, pubspec, `android/`, or
  `ios/` diff; four `lib/` files touched, each with an additive branch that
  evaluates `false` off-web; a fully green pre-existing test suite.
- `just mobile-build-web` still green.

## Risks & Mitigations

1. **`flutter build web` succeeds but the app crashes on first paint.** The build
   gate cannot catch `MissingPluginException` or `UnsupportedError`.
   *Mitigation:* each gate is asserted by a test, and the residual risk is handed
   to the human checklist in Part 3. **Calibration:** the brainstorm's call-site
   audit was already wrong once — it treated `defaultTargetPlatform` guards as
   web-proof (see
   [the correction](#correction-defaulttargetplatform-on-web-is-user-agent-derived)).
   Treat any remaining "this is unreachable on web" claim as unproven unless a
   test asserts zero channel traffic.
2. **Mobile regression from touching load-bearing shared files.** `compose_bar.dart`
   and `media_upload.dart` are the two most heavily tested files in the app.
   *Mitigation:* every gate is an additive branch that evaluates `false` off-web;
   `supportsMediaUpload` defaults to `true`; the pre-existing test files are the
   gate and none may be weakened. The eight existing `paperclip` tests are a
   particularly sharp control for B3.
3. **B6 is written but never exercised**, because `flutter_test` defaults
   `debugDefaultTargetPlatformOverride` to `android` and the probe's iOS guard
   short-circuits first. *Mitigation:* D2b explicitly sets
   `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` and resets it in
   `tearDown`; without that the web assertion would pass vacuously.
4. **The `app_badge_plus` channel name or payload differs from the audit**,
   making D1 vacuous. *Mitigation:* D1's non-web control must record ≥ 1 call; a
   vacuous assertion fails the control first. If the control fails, fix the
   channel name to whatever the control observes.
5. **Hiding the paperclip removes the one end-to-end Blossom path a human could
   have exercised in the browser.** *Mitigation:* accepted for Phase 0 — the
   upload path also needs the relay CORS follow-up to work cross-origin, and
   `uploadBytes()` remains ungated so a future web drag-drop backend lights it up
   without touching the service again.
6. **A platform-conditional path is missed in a *third-party* package**, the way
   `defaultTargetPlatform` was missed in ours. *Mitigation:* accepted. The plugin
   audit in brainstorm §2 covered all 23 direct dependencies structurally
   (does a web implementation exist?); what it could not cover is behavioural
   divergence inside a package that *does* declare web. That residual surfaces in
   the browser checklist (Part 3), which includes a mobile-browser UA pass.
7. **`compose_bar.dart` grows toward the 1000-line ceiling** (822 today, ~827
   after B3+B6). *Mitigation:* the gates are 1-line and 1-line respectively;
   if a future change pushes the file over, **split it — never bump the limit or
   add an override**.

## Auto-resolved assumptions

This part plan was produced non-interactively by splitting
`docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`. Wherever the
splitting or planning skill would have asked a human, the most YAGNI-aligned
default was taken and recorded here.

1. **The split shape was approved upstream and is implemented as given**: three
   parts, linear dependency chain, stacked PRs. Part 2 = B2–B6, B7 (full),
   D1–D5, D8. It was not re-derived.
2. **Slice D is split along the same seam as the production code**, not kept
   whole. D1–D5 and D8 exercise the gates in this part and ship with them;
   D6/D7/D9/D10 exercise the storage seam and ship with Part 3. Consequence: no
   PR in the series leaves its own production change unverified, and no PR
   carries tests for code that is not in it.
3. **D11 (the final full-suite/analyze/format/file-size gate) stays in Part 3**,
   but an equivalent per-part verification block is included here so this PR is
   independently green. Part 3 re-runs it across the whole stack.
4. **The whole-plan acceptance criteria were re-scoped, not copied.** Every
   criterion asserting a storage property or a README section moved to Part 3,
   and an explicit "NOT asserted by this part" list was added so a reviewer can
   see the omissions are deliberate.
5. **The PR body must state that credentials still reach browser `localStorage`
   until Part 3.** Without that sentence a reviewer could reasonably read "the
   web build no longer crashes" as "the web build is safe to use", which is not
   true until the session-only store lands.
6. **The `defaultTargetPlatform` correction section is copied in full**, not
   summarised. It is the reason B4 and B6 exist at all, and a summary would let
   a build agent conclude the pre-existing guards are sufficient.
7. **Inherited unchanged from the parent plan** (not re-decided here):
   `MediaUploadService` takes `supportsMediaUpload`, not `isWeb`, defaulting to
   `true` (#5); the pairing subtitle copy changes on web and the divider is
   hidden with the button (#6); no test for `isWebProvider` itself (#7); new
   compose-bar and pairing cases go in the existing test files while the
   media-upload **provider** test gets its own file, because
   `media_upload_test.dart` has no `ProviderContainer` scaffolding (#8); media
   upload is disabled outright rather than de-sanitised (#16);
   `readAndUploadClipboardImage()` is gated by the same capability as belt and
   braces (#17); widget locals stay named `isWeb` rather than
   `supportsAppBadge`/`supportsQrScan` (#21); `unawaited(...)` + `debugPrint`
   error handling on `AppBadgePlus.updateBadge` (#22).

## References & Research

- **Parent plan (canonical rationale):**
  `docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`.
- **Sibling parts:** Part 1 —
  `docs/plan/2026-07-27-feat-flutter-web-target-part-1-plan.md` (web runner +
  seam, landed); Part 3 —
  `docs/plan/2026-07-27-feat-flutter-web-target-part-3-plan.md` (session-only
  storage + docs).
- Brainstorm: `docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md`
  (§1 `dart:io` audit, §2 plugin web-support table, §3 MethodChannel call-site
  audit — **§3's conclusion is superseded by the correction above**, §6 deep
  links).
- Source plan: `mobile/DESKTOP_PORT_PLAN.md` §9 Phase 0, §5, §10.1.
- **UA-derived platform:**
  `$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`
  (`_browserPlatform` ← `ui_web.browser.operatingSystem`; `unknown => android`).
- Native EXIF scrub:
  `mobile/android/app/src/main/kotlin/xyz/block/buzz/mobile/MainActivity.kt:189`
  (`AndroidImageProcessor.encodeAndScrub`), handler dispatch at :91-99.
- Relay CORS gap (follow-up, not fixed here):
  `crates/buzz-relay/src/router.rs:397-421`.
- Conventions: `CLAUDE.md` § Mobile App (Flutter), § Quality Gates;
  `mobile/scripts/check-file-sizes.mjs`.
