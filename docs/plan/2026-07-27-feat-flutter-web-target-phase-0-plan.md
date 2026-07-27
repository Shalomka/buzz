---
title: "feat: add a Flutter web target to the mobile app (Phase 0)"
type: feat
date: 2026-07-27
branch: feat/flutter-web-desktop-phase-0
brainstorm: docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§9 Phase 0 — retargeted to web only)
predecessor: docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md (Phase 1, landed)
revision: 2 — revised after plan-technical-review (2 Critical, 5 Major resolved; see Auto-resolved assumptions #15-#21)
split-into:
  - docs/plan/2026-07-27-feat-flutter-web-target-part-1-plan.md
  - docs/plan/2026-07-27-feat-flutter-web-target-part-2-plan.md
  - docs/plan/2026-07-27-feat-flutter-web-target-part-3-plan.md
status: split — build from the part plans, not from this file
---

# feat: add a Flutter web target to the mobile app (Phase 0)

> ## ⚠️ This plan has been split into three stacked PRs
>
> **Do not build from this file.** It remains the **canonical rationale
> document** — the evidence, the corrections, the rejected alternatives, and the
> reasoning behind every decision live here and are referenced by all three part
> plans. But each part plan below is a **standalone build input** carrying the
> codebase context, conventions, tasks, and acceptance criteria for its own
> slice.
>
> | Part | Plan | Scope | Branch → PR target |
> |---|---|---|---|
> | 1 | [`…-part-1-plan.md`](2026-07-27-feat-flutter-web-target-part-1-plan.md) | Web runner scaffold + build recipe + platform seam — **A1–A7, B1**, analyze-clean for that slice | `feat/flutter-web-target-part-1` → `main` (@ `e4622671`) |
> | 2 | [`…-part-2-plan.md`](2026-07-27-feat-flutter-web-target-part-2-plan.md) | Runtime gates for web-hostile call sites + their tests — **B2–B7, D1–D5, D8** | `feat/flutter-web-target-part-2` → `feat/flutter-web-target-part-1` |
> | 3 | [`…-part-3-plan.md`](2026-07-27-feat-flutter-web-target-part-3-plan.md) | Session-only storage seam (security) + docs — **C1–C6, D6, D7, D9, D10, D11, E1, E2** | `feat/flutter-web-target-part-3` → `feat/flutter-web-target-part-2` |
>
> Linear dependency chain: 2 builds on 1 (needs `is_web.dart`), 3 builds on 2.
> Parts 2 and 3 touch disjoint files, so no textual conflict is expected within
> the stack.
>
> **Why this shape:** the security-relevant storage change gets its own PR so it
> receives focused review rather than being buried among widget-visibility
> changes; and Slice D's tests travel with the production code they exercise
> (D1–D5/D8 with the gates, D6/D7/D9/D10 with the storage seam), so no PR leaves
> the codebase unverified.
>
> Task IDs (A1–A7, B1–B7, C1–C6, D1–D11, E1–E2) are global across the series and
> keep the numbering used below. Acceptance criteria in this file describe the
> **end state after all three parts**; each part plan carries a re-scoped subset
> plus an explicit list of what it does *not* assert.

## Overview

Add a **web platform target** to the existing `mobile/` Flutter app, strictly
additively, so the already-landed Phase 1 desktop shell (`DesktopShell`,
`breakpoints.dart`, `shell_state_provider.dart`) has a runtime where width ≥ 840
is reachable. The "desktop" surface for this phase is a **Flutter web build
viewed in a browser window at desktop width** — macOS/Windows/Linux are out of
scope.

The changes, all no-ops on Android/iOS:

1. A hand-authored `mobile/web/` runner directory (`flutter create` is blocked).
2. One overridable web-platform seam (`isWebProvider`) so the gates are testable.
3. **Five** runtime gates for web-hostile call sites: the app badge, the whole
   attach (paperclip) affordance, the `MediaUploadService` pick-and-upload
   entry points, the iOS clipboard-image probe, and QR-scan pairing.
4. A session-only key-value store on web so the Nostr `nsec` is never written to
   browser `localStorage`.
5. A `just mobile-build-web` recipe.

> **Revision 2 note.** Plan technical review found that the original gate list
> was derived from a false premise: on Flutter web `defaultTargetPlatform` is
> **derived from the browser user agent**, so the pre-existing
> `TargetPlatform.android`/`iOS` guards do *not* make the native MethodChannel
> calls unreachable in a browser. Two gates were added (media upload, clipboard
> probe) and one brainstorm finding was corrected. See
> [Correction: `defaultTargetPlatform` on web](#correction-defaulttargetplatform-on-web-is-user-agent-derived).

This is a **compile-and-gate** phase, not a feature phase. No dependency
changes, no Rust changes, no CI changes.

## Problem Statement / Motivation

Phase 1 landed a responsive multi-pane parity shell on `main`, but it is
**dormant**: `mobile/` targets `android` + `ios` only, so no runtime exists where
the desktop layout is reachable. `flutter build web` currently fails with
`This project is not configured for the web`.

`DESKTOP_PORT_PLAN.md` §9's Phase 0 task list was written for *native* desktop and
is partly invalid for web. The brainstorm re-derived it from evidence
(see [Findings that override the source plan](#findings-that-override-the-source-plan)).
Four web-specific risks the source plan never considered — browser CORS, browser
key storage, `MissingPluginException` for plugins without a web implementation,
and `dart:io` symbols that compile then throw — drive everything below.

## Proposed Solution

**Minimal additive web target** (Approach A in the brainstorm; B and C rejected
there with evidence — do not revisit).

- Reproduce the Flutter 3.44.4 SDK web runner template by hand at `mobile/web/`.
- Introduce exactly one seam, `isWebProvider`, and read it at every gate.
  `kIsWeb` is a compile-time constant, so a widget test on the VM can never
  exercise the web branch — proving the gates work is the deliverable.
- Gate the five call sites that crash or misbehave in a browser.
- Replace `CommunityStorage`'s concrete `FlutterSecureStorage` dependency with a
  three-method `KeyValueStore` seam in `mobile/lib/shared/storage/`; a named
  `keyValueStoreProvider` picks the in-memory implementation on web.
- Add `just mobile-build-web`. Do **not** wire it into `just ci` or `just check`.
- Serve the build same-origin from the relay for manual QA (documentation only —
  no relay changes).

## Scope

### In scope

- `mobile/web/` runner directory (index.html, manifest.json, favicon, 4 icons)
  and the matching `mobile/.metadata` platform entry.
- `mobile/lib/shared/platform/is_web.dart` (new seam).
- Five runtime gates in `app.dart`, `compose_bar.dart` (×2), `media_upload.dart`,
  `pairing_page.dart`.
- `mobile/lib/shared/storage/key_value_store.dart` and
  `mobile/lib/shared/storage/key_value_store_provider.dart` (new) +
  `CommunityStorage` and `communityStorageProvider` rewiring, plus
  `mobile/test/helpers/fake_key_value_store.dart` and the migration of the five
  test files that construct `CommunityStorage`.
- New and extended widget/unit tests covering every gate.
- `justfile`: one new recipe.
- `mobile/README.md`: a short "Web (experimental)" section.

### Out of scope — do not implement

- Native desktop platform folders (`mobile/macos`, `mobile/windows`,
  `mobile/linux`).
- **Any dependency change**: no additions, removals, or version bumps.
  `pubspec.yaml` and `pubspec.lock` must be byte-identical at the end.
  Specifically **no** `file_selector`, `media_kit`, `desktop_drop`,
  `window_manager`, `super_clipboard`, or an `app_badge_plus` replacement.
- The relay CORS fix (`crates/buzz-relay/src/router.rs:397-421`) — Rust, filed
  as a follow-up.
- `.github/workflows/` changes (guardrail-blocked).
- `desktop_drop` drag-drop backend for `attachmentDropBackendProvider`.
- NIP-07 signer integration.
- Phase 1 visual QA (breakpoint retuning, docked side panel, drop-target
  hover visuals, list-selection polish).
- `DESKTOP_PORT_PLAN.md` Phases 2–3, huddle, mesh-compute, avatar studio.
- `buzz://` deep links on web — `app_links_web` degrades harmlessly
  (`pendingDeepLinkProvider` just holds `null`). **Leave that code untouched.**
- Any change to secrets, feature flags, CI, or deploy/infra manifests.

## Codebase Context (verified)

Everything in this section was verified in this repo on
`feat/flutter-web-desktop-phase-0`. **The build stage should trust this section
and not re-review the codebase.**

### Environment and tooling facts

| Fact | Value |
|---|---|
| Flutter / Dart | 3.44.4 stable / Dart 3.12.2 |
| `FLUTTER_ROOT` | `/Users/robertasskiauteris/development/flutter` (derive with `dirname $(dirname $(readlink -f $(which flutter)))`) |
| SDK web template | `$FLUTTER_ROOT/packages/flutter_tools/templates/app/web/` → `index.html.tmpl`, `manifest.json.tmpl`, `favicon.png.copy.tmpl`, `icons/` |
| Web enablement | `flutter config` already reports `enable-web: true` — **no config change needed** |
| Web-project gate | `WebProject.existsSync()` requires exactly `web/` **and** `web/index.html` |
| `mobile/web/` today | **does not exist**; `git check-ignore mobile/web/index.html` → not ignored, so it is committable |
| Build output | `mobile/.gitignore` already ignores `/build/`, so `mobile/build/web/` is ignored — **no .gitignore change needed** |
| Icon source | `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` (1024², exists). `assets/images/buzz-icon.png` is 294×197 — **not** usable |
| `sips` | available at `/usr/bin/sips` |
| File-size guard | `mobile/scripts/check-file-sizes.mjs` — 1000 lines, **`lib/` only**, no overrides. `test/` is not scanned |
| Baseline | `flutter analyze` → **No errors**; 60 `*_test.dart` files all pass |

**Hook/permission constraints for the build stage:**

- `flutter create` / `dart create` → **BLOCKED**. `mobile/web/` is hand-authored.
- `flutter test` / `dart test` in Bash → **BLOCKED**. Use the `very_good_cli` MCP
  `test` tool (`directory: mobile`).
- `flutter build web` → **PERMITTED** for this run (scoped exception to
  CLAUDE.md's "never run `flutter build`").
- `flutter run` / `flutter clean` / `flutter upgrade` → still forbidden.
- `flutter analyze` and `dart format` → permitted.

### Files this plan touches (verified line references)

| File | Lines | Current state |
|---|---|---|
| `mobile/lib/app.dart` | 95 | `applyBadge` at :48-56 calls `AppBadgePlus.updateBadge` at :50/:52/:54; invoked from `useEffect` :58-61 and `ref.listen` :62-64 |
| `mobile/lib/features/channels/compose_bar.dart` | 822 | `class ComposeBar extends HookConsumerWidget` :102, `build` :123. **Clipboard probe `useEffect` :140-168**, guarded only by `if (defaultTargetPlatform != TargetPlatform.iOS) return null;` (:141), calling `clipboardHasImage()`; it is the only writer of `clipboardHasImage.value`, which in turn is the only thing that surfaces the "Paste Image" items at :528/:544. Paperclip `_ComposeAction` at ~:748-786 opens the attach sheet `Column(children:)` ~:756-781 — "Photo" `ListTile` then "Video" `ListTile` (:769-780). `pickAndUpload` helper :472-489 catches and surfaces errors via `_formatUploadError`. `uploadDroppedFiles` :498-514 and `uploadPastedImage` :556+ call `uploadBytes` directly (pure Dart, no MethodChannel — **not** gated) |
| `mobile/lib/shared/relay/media_upload.dart` | 679 | Message consts :44-49; fields :135-142; ctor :144-166; `pickAndUploadImage()` :174-199; `pickAndUploadVideo()` :200-233; `uploadBytes()` :235+ (pure Dart); `_prepareUploadImage` :344-357 → `_shouldTranscodePickedImage` call :352; `_sanitizeImageBytesIfNeeded` :383-394 → `_shouldSanitizePickedImage` call :386; the shared predicate `_supportsNativeUploadImageProcessing()` :525-530 (`android \|\| iOS => true`); `mediaUploadServiceProvider` :665-679 |
| `mobile/lib/features/pairing/pairing_page.dart` | 407 | `mobile_scanner` import :5; subtitle text :74-79; "Scan QR Code" `FilledButton.icon` :85-91; `SizedBox(Grid.sm)` :93; "or paste pairing code" divider `Row` :95-112; `SizedBox(Grid.sm)` :114; paste `TextField` :117; `_openScanner` :203-214 |
| `mobile/lib/shared/community/community_storage.dart` | 111 | `final FlutterSecureStorage _secure` :19; ctor :21-22; `_secure.read/write/delete` at :27, :30, :34, :36-37, :42-46, :60-63, :89, :93, :97, :109 |
| `mobile/lib/shared/community/community_provider.dart` | 127 | `communityStorageProvider` :7-9 → `CommunityStorage()` |
| `justfile` | — | `mobile_dir := "mobile"` :566; `mobile-build-android` :589-590; `check` :94; `ci` :258 |
| `mobile/README.md` | 66 | headings: Setup, Run, Checks, Android release signing, Architecture |

**`FlutterSecureStorage` appears in exactly one place in `mobile/lib`** —
`community_storage.dart`. That single file is the entire persistent-secret
surface; pairing writes credentials through `CommunityStorage.save()`.

Test files that construct `CommunityStorage` (all will need the mechanical
migration in Slice C):

| Test file | Sites |
|---|---|
| `mobile/test/shared/community/community_storage_test.dart` | defines `FakeSecureStorage` :11-~95; `CommunityStorage(secure: fakeSecure)` :96 |
| `mobile/test/shared/community/community_provider_test.dart` | imports the above :7; :16 |
| `mobile/test/shared/auth/auth_provider_test.dart` | imports :9; :15, :37 |
| `mobile/test/features/invites/invite_join_provider_test.dart` | imports :13; :25, :83, :145, :190 |
| `mobile/test/features/channels/deep_link_dispatcher_test.dart` | imports :15; :131 (also overrides `communityStorageProvider` with a value at :64 — unaffected) |

Useful existing test infrastructure:

- `mobile/test/helpers/widget_helpers.dart` → `WidgetHelpers.testable({child, overrides})`.
- `mobile/test/features/channels/compose_bar_test.dart:115-160` →
  `_buildComposeBar({... List<Override> extraOverrides = const []})` — **already
  accepts extra overrides, no harness change needed**. `_FakeRelayConfigNotifier`
  at :162-168 shows how to fake `relayConfigProvider`.
- `mobile/test/features/home/desktop_shell_test.dart` → `useWideSurface(tester)`
  sets `physicalSize = Size(1440, 900)` (:56-57 region), `createContainer({UnreadBadgeState? unreadBadge})`,
  `buildTestable(container)` mounting `DesktopShell` in an
  `UncontrolledProviderScope`.
- `mobile/test/shared/relay/media_upload_test.dart:1091` →
  `group('pickAndUploadVideo', ...)`, constructs `MediaUploadService` directly.
- `mobile/test/widget_test.dart` → mounts `App` with `authProvider` and
  `savedPrefsProvider` overrides; `_FakeAuthNotifier` pattern.

Platform channel names needed by the tests:

| Plugin | Channel |
|---|---|
| `app_badge_plus` 1.2.10 | `app_badge_plus`, method `updateBadge` with `{'count': int}` |
| `flutter_secure_storage` (platform interface default) | `plugins.it_nomads.com/flutter_secure_storage` |

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
from an unawaited future. The plan's original manual checklist only exercises a
desktop browser ≥ 1440px, so nothing in it would have caught this.

Two further facts that shape the remedy:

1. **The native "sanitize" step is a metadata scrub, not a nicety.**
   `android/app/src/main/kotlin/xyz/block/buzz/mobile/MainActivity.kt:189` calls
   `AndroidImageProcessor.encodeAndScrub(bitmap, format)` — it decodes and
   re-encodes, which drops EXIF including GPS. Simply *skipping* it on web
   (the obvious fix) would silently ship images with location metadata intact,
   trading a crash for a privacy regression. See
   [Media upload on web](#media-upload-on-web-the-remedy-for-c1).
2. **`flutter_test` sets `debugDefaultTargetPlatformOverride = TargetPlatform.android`**,
   which is why `compose_bar_test.dart:86-102` already installs mock handlers for
   `sanitizeImageForUpload` / `transcodeImageToJpeg` in `setUpAll`. Widget tests
   therefore exercise the android branch by default — useful for the new tests,
   and a reminder that a green suite never proved these paths were web-safe.

### Findings that override the source plan

These were verified empirically in the brainstorm. **Do not re-litigate them; if
you believe one is wrong, verify it yourself and say so explicitly in the PR.**

1. **`dart:io` compiles fine under dart2js** (mapped via `_dart2js_common` →
   `io_patch.dart`). No conditional-import (`_stub`/`_io`/`_web`) scaffolding is
   needed anywhere. The three `mobile/lib` files that import `dart:io`
   (`channels_page.dart`, `media_upload.dart`, `mp4_fast_start.dart`) stay
   exactly as they are:
   - `channels_page.dart:2` — `SocketException` is used by `channels_page/badges.dart:138`
     (`if (error is SocketException)`); the type test evaluates `false` on web and
     falls through. **Do not remove this import** — it is used, and removing it
     changes mobile error copy.
   - `media_upload.dart` — `HttpStatus.*` are plain int consts (safe); `File` I/O
     is either inside `pickAndUploadVideo()` (gated by this plan) or inside a
     `defaultTargetPlatform == TargetPlatform.android` branch (unreachable on web).
   - `mp4_fast_start.dart` — only caller is the android-only branch.
2. **`image_picker` and `video_player` keep their endorsed web implementations.**
   The source plan's `file_selector` / `media_kit` swaps are native-desktop
   remedies with no web justification. **Do not perform them.**
3. **`app_badge_plus` is the only dependency with no web implementation** — the
   one guaranteed `MissingPluginException`. `AppBadgePlus.isSupported()` throws
   too, so it cannot be used as a capability probe; gate at the call site.
4. ~~**Only the video path of the `buzz/media_upload` MethodChannel needs
   gating.**~~ **CORRECTED — this finding was wrong.** The brainstorm (and the
   first revision of this plan) claimed the other four methods were "already dead
   on web" behind pre-existing `defaultTargetPlatform` guards. They are not: see
   [Correction: `defaultTargetPlatform` on web](#correction-defaulttargetplatform-on-web-is-user-agent-derived).
   **Three** of the five methods are reachable in a browser —
   `sanitizeImageForUpload` and `transcodeImageToJpeg` on any android/iOS/unknown
   UA, and `clipboardHasImage` on iOS Safari. `readClipboardImage` is reachable
   only via `clipboardHasImage`, so gating the probe closes it too.
   The still-true half: `uploadBytes()` and everything under it is pure Dart and
   web-safe, and `image_picker_for_web` never needs `File(path)`.
5. **Relay CORS**: `Access-Control-Allow-Headers: *` does not cover
   `Authorization`, so **cross-origin** dev breaks every avatar, inline image, and
   upload. Mitigated by serving same-origin; the Rust fix is a follow-up.

### Conventions the implementation must follow

From `CLAUDE.md` (§ Mobile App) and observed repo practice:

- **Never `StatefulWidget`.** Riverpod + `flutter_hooks`; `HookConsumerWidget` /
  `ConsumerWidget`.
- **No `print()`** — `debugPrint()` or structured logging.
- Prefer `context.colors` / `context.textTheme` over raw `Theme.of(context)`.
- `Grid` tokens for spacing, `Radii` for radii.
- **Features must not import other features** — only from `shared/`.
  `shared/platform/` and `shared/storage/` are `shared/`, so every gate may
  import them.
- One public widget per file; **1000-line ceiling on `lib/` files** (enforced by
  `mobile/scripts/check-file-sizes.mjs`; no overrides exist and none may be
  added). `compose_bar.dart` is the closest at 822 lines — the gate adds ~3.
- Imports: **within `lib/`, use relative imports** (e.g. `app.dart` imports
  `shared/auth/auth.dart`; `compose_bar.dart` imports `../../shared/relay/relay.dart`).
  **In `test/`, use `package:buzz/...`.**
- `Provider` is imported from `package:hooks_riverpod/hooks_riverpod.dart`
  (see `community_provider.dart:1`).
- Tests: prefer **widget tests** over unit tests for UI; inject fakes with
  `ProviderScope(overrides: [...])`; fake notifiers extend the real notifier and
  override `build()`; `WidgetHelpers.testable()` for simple cases.

## Technical Considerations

### Architecture

- **One seam, not an abstraction layer.** `isWebProvider` is a single
  `Provider<bool>` returning `kIsWeb`. A "platform capabilities" abstraction for
  a handful of gates would be over-engineering.
- **Capability-shaped naming at the service boundary.** `MediaUploadService` is a
  plain class (not Riverpod-aware), so it takes a `bool supportsMediaUpload = true`
  constructor flag rather than an `isWeb` flag. The provider translates
  `isWebProvider` into that capability. This keeps the service platform-agnostic
  and gives every existing caller and test an unchanged default. In **widgets**,
  by contrast, `ref.watch(isWebProvider)` *is* the seam and the local is named
  `isWeb` — introducing `supportsAppBadge` / `supportsQrScan` locals there would
  add a layer of indirection with no boundary to cross, and would obscure the
  actual reason the branch exists (see Auto-resolved assumptions #21).
- **The storage platform decision is hoisted into its own named provider**,
  `keyValueStoreProvider`, which `communityStorageProvider` reads. That gives the
  tests a version-independent structural assertion
  (`isA<InMemoryKeyValueStore>()`) that does not depend on a plugin's method
  channel name, and it keeps `main.dart` untouched.
- **`InMemoryKeyValueStore` is production code** (it is the web store) and stays
  free of test-only affordances; the test double lives in
  `mobile/test/helpers/fake_key_value_store.dart`.

### Media upload on web (the remedy for C1)

Three options were considered for the image path once
[the UA correction](#correction-defaulttargetplatform-on-web-is-user-agent-derived)
invalidated "image upload works end to end on web":

| Option | Verdict |
|---|---|
| **(a)** Thread a `supportsNativeImageProcessing` flag and simply **skip** the scrub on web | **Rejected.** It fixes the crash and silently introduces a privacy regression: `encodeAndScrub` is what strips EXIF/GPS, so web uploads would carry location metadata that mobile uploads do not. It also produces a confusing HEIC path — `_prepareUploadImage:352-356` would fall through to `throw Exception('unsupported file type')` for any HEIC pick. |
| **(b)** Re-implement the scrub in pure Dart on web (`ui.instantiateImageCodec` → re-encode) | **Rejected — YAGNI.** New implementation work with real risk (memory, colour profiles, alpha) for a surface that is not user-facing in Phase 0. Deferred. |
| **(c)** **Disable the pick-and-upload affordance entirely on web** ← **chosen** | One capability flag instead of two, no EXIF question, no HEIC edge case, and consistent with every other Phase 0 gate ("disabled, not ported"). Smaller diff than (a): hide the paperclip rather than one tile inside it. |

Chosen shape: a single `supportsMediaUpload` capability that fails **both**
`pickAndUploadImage()` and `pickAndUploadVideo()` fast, plus hiding the paperclip
`_ComposeAction` on web. **`uploadBytes()` is deliberately not gated** — it is
pure Dart, it is what a future web drag-drop backend and the pasted-content path
use, and gating it would remove capability that works.

### Rejected alternative: `InMemorySecureStorage extends FlutterSecureStorage`

Technically feasible — `FlutterSecureStorage` is a plain (non-`final`,
non-`base`) class with a `const` constructor — and it would leave all five test
files untouched. **Rejected because it is fail-open on exactly the property this
slice exists to guarantee.**

`FlutterSecureStorage` exposes **7** `Future`-returning members; `CommunityStorage`
uses **3**. A subclass overriding `read`/`write`/`delete` inherits `readAll`,
`deleteAll`, `containsKey`, and `registerListener`, all of which delegate to
`FlutterSecureStoragePlatform.instance` — i.e. to `flutter_secure_storage_web`,
i.e. to `localStorage`. Today nothing calls them, so it happens to be safe; the
day someone adds a `containsKey` call, or the plugin adds a method in a minor
version, the browser build starts persisting again **with no compile error and no
failing test**. The `KeyValueStore` interface is fail-closed: its surface is
exactly three methods and any new capability must be added deliberately.

Secondary reason: overriding requires reproducing the plugin's full named-option
signature (`AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions?
lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions?
wOptions`) in **production** code — the same ~85 lines of boilerplate that
`FakeSecureStorage` carries today, now load-bearing and version-coupled.

### Security

- **Credentials must never reach browser storage.** `flutter_secure_storage_web`
  2.1.1 encrypts values with AES-GCM-256 into `window.localStorage` and then
  writes the **extractable AES key into the same `localStorage`** under
  `FlutterSecureStorage`. Any XSS on the origin recovers the Nostr `nsec`. Its own
  README calls the implementation "experimental… Use at your own risk".
- **In-repo precedent**: `web/src/shared/lib/nostr-signer.ts` (the shipped browser
  client) refuses durable key storage — it uses a NIP-07 extension or a
  module-level in-memory ephemeral key. This plan matches that posture.
- Accepted cost: a page reload on web requires re-entering the pairing code.
- The security assertion is **testable two ways**, and this plan requires both:
  a **structural** assertion (`keyValueStoreProvider` resolves to
  `isA<InMemoryKeyValueStore>()` when `isWebProvider` is `true`) that survives a
  future Pigeon migration inside `flutter_secure_storage`, and a **behavioural**
  one (saving a community produces **zero** method calls on
  `plugins.it_nomads.com/flutter_secure_storage`, validated against a non-web
  control that produces ≥ 1).
- **The property is enforced as an invariant, not a one-time audit.** A ~15-line
  import-fence test asserts that `package:flutter_secure_storage` is imported by
  exactly one file in `mobile/lib` — `shared/storage/key_value_store.dart`.
  Verified today: it is imported by exactly one file
  (`shared/community/community_storage.dart:3`, which this plan moves), so the
  fence starts green.
- **`shared_preferences` is a separate, lower-sensitivity surface and is
  deliberately left alone.** Audited: 10 lib files use it — `main.dart`,
  `shared/theme/theme_provider.dart`, and the channel mutes / stars / sections /
  read-state storages and managers under `features/channels/`. Everything written
  is either a theme preference or a **pubkey-keyed** JSON blob of channel
  metadata (`channelMutesKey(pubkey)`, `channelStarsKey(pubkey)`,
  `channelSectionsKey(pubkey)`, `localReadStateKey(pubkey)`, `slotIdKey(pubkey)`,
  plus two `setString` calls in `channels_provider.dart:642,646`).
  **No key material is stored there** — `nsec` reaches persistent storage only
  through `CommunityStorage`. On web these become `localStorage` entries that
  *do* survive a reload, so "session-only" means *credentials* are session-only
  while pubkey-keyed activity metadata persists. Say so in the README (E1).

### Mobile-regression safety (the non-negotiable)

Android/iOS ship today. Every gate must be a no-op off-web:

- `isWebProvider` returns `kIsWeb` → `false` on Android/iOS/VM tests, so every
  `if (isWeb)` / `if (!isWeb)` branch keeps today's behavior.
- `MediaUploadService.supportsMediaUpload` **defaults to `true`**, so every
  existing `MediaUploadService(...)` construction in tests and in the provider
  behaves identically.
- The `KeyValueStore` migration is a **compile-time-checked** refactor: a missed
  call site fails `flutter analyze` loudly; it cannot silently change runtime
  behavior. `SecureKeyValueStore` wraps `const FlutterSecureStorage()` with the
  same default options, so the on-device keychain/keystore keys and payloads are
  byte-identical (`buzz_communities`, `buzz_active_community_id`, and all legacy
  migration keys are unchanged).
- No dependency, `pubspec`, `android/`, or `ios/` changes at all.
- The 60 existing test files are the regression gate. **None may be weakened,
  skipped, or deleted.** The only permitted edits to existing tests are the
  mechanical `CommunityStorage(secure:)` → `CommunityStorage(store:)` migration
  and purely additive new cases.

### What this plan does *not* prove

State this honestly in the PR body. `flutter build web` succeeding proves the
reachable Dart graph compiles and every plugin's web registrant resolves — it
proves **nothing** about `dart:io` runtime safety (those symbols compile and then
throw). Not proven by any automation here: rendering fidelity and font loading,
mouse-wheel/trackpad scroll behavior, a live WebSocket + NIP-42 auth handshake,
same-origin image loading, real-window breakpoint feel, and the usability of
session-only sign-in.

**Also not proven: real user-agent behaviour.** The tests reach the android/iOS
branches only via `debugDefaultTargetPlatformOverride`; nothing here runs a real
browser, so the actual UA → `TargetPlatform` mapping is verified by reading the
SDK, not by execution. That is why the manual checklist now requires an iOS
Safari and an Android Chrome pass.

## Acceptance Criteria

Every item is mechanically checkable.

- [ ] `cd mobile && flutter build web --release` exits 0 and produces
      `mobile/build/web/flutter_bootstrap.js` and `mobile/build/web/main.dart.js`.
- [ ] `just mobile-build-web` exists in `justfile` and runs that build.
      `just check` (:94) and `just ci` (:258) are **unmodified**.
- [ ] `cd mobile && flutter analyze` reports **zero errors** (no new warnings or
      infos either).
- [ ] The full mobile test suite passes via the `very_good_cli` MCP `test` tool
      (`directory: mobile`), including every new test listed in
      [Test Plan](#test-plan).
- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && node ./scripts/check-file-sizes.mjs` exits 0; every touched
      `lib/` file is < 1000 lines and **no override entry is added** to that script.
- [ ] `git diff --stat -- mobile/pubspec.yaml mobile/pubspec.lock 'mobile/android/**' 'mobile/ios/**' ':(top).github/**' ':(top)crates/**' ':(top)desktop/**' ':(top)web/**' .env.example`
      is **empty**. Note the `:(top)` prefixes: a bare `web/**` pathspec would
      match the newly added `mobile/web/**` and make this check meaningless.
- [ ] `grep -rn "kIsWeb" mobile/lib` returns **exactly one** hit:
      `mobile/lib/shared/platform/is_web.dart`.
- [ ] `mobile/web/` contains `index.html`, `manifest.json`, `favicon.png`, and
      `icons/{Icon-192,Icon-512,Icon-maskable-192,Icon-maskable-512}.png`, and all
      are tracked by git.
- [ ] `mobile/web/index.html` contains the literal string `$FLUTTER_BASE_HREF`
      and `<script src="flutter_bootstrap.js" async></script>`, and does **not**
      contain a hand-written `flutter_bootstrap.js` file, `serviceWorkerVersion`,
      or `_flutter.loader.loadEntrypoint`.
- [ ] With `isWebProvider` overridden to `true`, tests assert: **zero**
      `app_badge_plus` channel calls; **zero** `buzz/media_upload` channel calls
      (covering all three browser-reachable methods —
      `sanitizeImageForUpload`, `transcodeImageToJpeg`, `clipboardHasImage`); no
      paperclip attach affordance; no "Scan QR Code" button; both
      `pickAndUploadImage()` and `pickAndUploadVideo()` throw the readable web
      message before touching the picker; `keyValueStoreProvider` resolves to
      `isA<InMemoryKeyValueStore>()`; and saving a community produces **zero**
      `plugins.it_nomads.com/flutter_secure_storage` calls. Every channel-count
      assertion is paired with a non-web control case that produces ≥ 1 call.
- [ ] The import-fence test passes: `package:flutter_secure_storage` is imported
      by exactly one file under `mobile/lib` —
      `mobile/lib/shared/storage/key_value_store.dart`.
- [ ] `grep -rn "defaultTargetPlatform" mobile/lib` shows no *newly added* uses;
      the pre-existing ones remain, now paired with a web-seam check wherever they
      guard a MethodChannel (`compose_bar.dart:141`, `media_upload.dart` image
      pipeline).
- [ ] With `isWebProvider` overridden to `true` at 1440×900, `DesktopShell` still
      renders the community rail, the channel list (`general`), and the empty
      message pane (`Select a channel`).
- [ ] The PR body contains the
      [manual verification checklist](#manual-verification-checklist-for-the-pr-body)
      and the same-origin run command, and states the cross-origin CORS caveat.

## Implementation Tasks

Ordered. The three slices map to the brainstorm's natural seams and are cleanly
separable (Slice B and Slice C both depend on Slice A only for the seam file in
task B1 — see [Dependencies](#dependencies)).

### Slice A — web runner directory + build recipe

No `lib/` changes. Independently valuable and reviewable.

- [ ] **A1.** Create `mobile/web/index.html` by copying
      `$FLUTTER_ROOT/packages/flutter_tools/templates/app/web/index.html.tmpl`
      and substituting `{{projectName}}` → `Buzz` (3 occurrences:
      `apple-mobile-web-app-title`, `<title>`) and `{{description}}` →
      `Buzz mobile client` (from `mobile/pubspec.yaml:2`).
      **Keep verbatim**: `<base href="$FLUTTER_BASE_HREF">` (the literal token —
      `flutter build` replaces it) and
      `<script src="flutter_bootstrap.js" async></script>`.
      **Do not hand-write `flutter_bootstrap.js`** — it is generated at build time.
      Add one HTML comment near the top recording provenance, e.g.
      `<!-- Authored by hand against the Flutter 3.44.4 SDK template at packages/flutter_tools/templates/app/web/index.html.tmpl. Diff against that file after an SDK upgrade. -->`
- [ ] **A2.** Create `mobile/web/manifest.json` from `manifest.json.tmpl` with:
      `name` / `short_name` → `Buzz`; `description` → `Buzz mobile client`;
      `background_color` → `#EFF1F5` (Catppuccin Latte Base, see
      `mobile/lib/shared/theme/color_scheme.dart:9`); `theme_color` → `#8839EF`
      (Latte Mauve, the app primary, `color_scheme.dart:8`); `orientation` →
      `any` (the target is a desktop-width browser window, not the template's
      `portrait-primary`). Keep `start_url`, `display`, `prefer_related_applications`,
      and the four-entry `icons` array exactly as the template has them.
- [ ] **A3.** Generate the icons from
      `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
      with `sips -z <n> <n> <src> --out <dest>`:
      - `mobile/web/favicon.png` (32×32)
      - `mobile/web/icons/Icon-192.png` (192×192)
      - `mobile/web/icons/Icon-512.png` (512×512)
      - `mobile/web/icons/Icon-maskable-192.png` (192×192)
      - `mobile/web/icons/Icon-maskable-512.png` (512×512)

      The maskable variants are the same square artwork (no safe-zone padding).
      Note that limitation in the PR body; do not author new artwork.
- [ ] **A4.** Add to `justfile`, immediately after `mobile-build-android`
      (:589-590), matching that recipe's style:

      ```just
      # Compile the Flutter web build (release)
      mobile-build-web:
          unset GIT_DIR GIT_WORK_TREE; cd {{mobile_dir}} && flutter build web --release
      ```

      Omit `--no-pub` (unlike `mobile-build-android`): the first web build must
      resolve web plugin registrants. **Do not** add this recipe to `check` (:94)
      or `ci` (:258).
- [ ] **A5.** Run `cd mobile && flutter build web --release`. It must exit 0.
      Fix any compile error surfaced here **inside this run**; if a fix would
      require a dependency change or a Rust change, stop and report instead.
- [ ] **A6.** Confirm `mobile/build/web/` is git-ignored (it is, via
      `mobile/.gitignore`'s `/build/`) and that `mobile/web/**` is staged.
      **Do not modify any `.gitignore`.**
- [ ] **A7.** Add the `web` platform entry to `mobile/.metadata`'s
      `migration.platforms` list (the file is tracked and currently lists only
      `root`, `android`, `ios`, all at revision
      `db50e20168db8fee486b9abf32fc912de3bc5b6a`). This is what
      `flutter create --platforms=web` would have written; since that command is
      blocked, add it by hand using the **current** SDK revision:

      ```yaml
          - platform: web
            create_revision: ad70ec4617166f1c38e5d2bfd388af71fda14f06
            base_revision: ad70ec4617166f1c38e5d2bfd388af71fda14f06
      ```

      (Flutter 3.44.4 = `ad70ec4617166f1c38e5d2bfd388af71fda14f06`, from
      `git -C $FLUTTER_ROOT rev-parse HEAD`.) The file's header says it "should
      not be manually edited"; that warning exists because `flutter create`
      normally maintains it, and it only feeds the optional `flutter migrate`
      tool, which this repo does not use. Leaving the entry out would make
      `flutter migrate` silently blind to the web runner. If the build agent
      judges the hand-edit unsafe, the fallback is to omit it and record the
      omission in A1's provenance comment instead — but do one or the other, not
      neither.

### Slice B — web platform seam + five runtime gates

- [ ] **B1.** Create `mobile/lib/shared/platform/is_web.dart`:

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

      No barrel file (the folder has one file; `shared/layout/` and
      `shared/shell/` follow the same pattern).
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
- [ ] **B3. Attach affordance gate** — `mobile/lib/features/channels/compose_bar.dart`.
      Add `import '../../shared/platform/is_web.dart';` to the relative import
      block (:13-25). Add `final isWeb = ref.watch(isWebProvider);` near the top
      of `ComposeBar.build` (:123+). Make the **paperclip** `_ComposeAction`
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

      **Leave the sheet's "Photo" and "Video" `ListTile`s exactly as they are** —
      hiding their only entry point is sufficient and keeps the diff to one line.
      **Do not gate** `uploadDroppedFiles` (:498-514) or `uploadPastedImage`
      (:556+): both call `uploadBytes` directly in pure Dart.
- [ ] **B4. Media upload fail-fast** — `mobile/lib/shared/relay/media_upload.dart`.
      One capability covers both media paths; see
      [Media upload on web](#media-upload-on-web-the-remedy-for-c1) for why the
      image path is disabled rather than de-sanitized.
      1. Add near the other message consts (:44-49):
         ```dart
         const _unsupportedWebMediaUploadMessage =
             'Media upload is not supported in the browser yet.';
         ```
      2. Add `final bool _supportsMediaUpload;` to the field block (:135-142).
      3. Add `bool supportsMediaUpload = true,` to the constructor (:144-157) and
         `_supportsMediaUpload = supportsMediaUpload,` to the initializer list
         (:158-166). **The default must be `true`** so every existing caller and
         test is unaffected.
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
         string verbatim.
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
- [ ] **B6. iOS clipboard-probe gate** — `mobile/lib/features/channels/compose_bar.dart:140-167`.
      The probe `useEffect` is guarded only by `defaultTargetPlatform`, which
      resolves to `TargetPlatform.iOS` on iOS Safari, so
      `clipboardHasImage()` fires on mount, on focus, and on every app resume.
      Add the web seam to the existing early return (one line):

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
      `false` on web. Reuse the `isWeb` local introduced in B3; do not add a
      second `ref.watch`.
- [ ] **B7.** `cd mobile && flutter analyze` → zero errors.

### Slice C — session-only key-value store on web

- [ ] **C1.** Create `mobile/lib/shared/storage/key_value_store.dart` (a **new
      `shared/storage/` folder** — this is a generic storage primitive, not a
      community concern, and its likely next consumers are the six
      `shared_preferences`-backed storages under `features/channels/`) with three
      public classes. **All three methods take named parameters** — two positional
      `String`s would let a transposed `write(value, key)` compile silently across
      the ~14 rewritten call sites, defeating the compile-time-checked-refactor
      safety argument this slice rests on. It also means the `community_storage.dart`
      bodies change only in the receiver name:

      ```dart
      import 'package:flutter_secure_storage/flutter_secure_storage.dart';

      /// Minimal key-value contract behind [CommunityStorage].
      abstract class KeyValueStore {
        Future<String?> read({required String key});
        Future<void> write({required String key, required String value});
        Future<void> delete({required String key});
      }

      /// Platform-keychain backed store (iOS Keychain / Android Keystore).
      class SecureKeyValueStore implements KeyValueStore { ... }

      /// Process-lifetime store used on web.
      ///
      /// The only durable browser storage available to
      /// flutter_secure_storage_web is localStorage — and it persists its own
      /// extractable AES key next to the ciphertext, so any XSS on the origin
      /// recovers the Nostr nsec. Web therefore keeps sign-in material in memory
      /// only; a reload requires re-pairing. Matches the posture of the shipped
      /// browser client (web/src/shared/lib/nostr-signer.ts).
      class InMemoryKeyValueStore implements KeyValueStore { ... }
      ```

      `SecureKeyValueStore` wraps `const FlutterSecureStorage()` with **default
      options** — identical to today's `community_storage.dart:22` — and forwards
      each call unchanged. `InMemoryKeyValueStore` is backed by a
      `final _values = <String, String>{}` **instance** field (not a static or
      module-level map, so instances are isolated) and carries **no test-only
      affordances** — the seeding double lives in `test/helpers/` (C5).
      This file must be the **only** file under `mobile/lib` that imports
      `package:flutter_secure_storage` (enforced by the D10 fence test).
- [ ] **C2.** Rewire `mobile/lib/shared/community/community_storage.dart`:
      - Drop `import 'package:flutter_secure_storage/flutter_secure_storage.dart';`
        (:3); add `import '../storage/key_value_store.dart';`.
      - Replace `final FlutterSecureStorage _secure;` (:19) with
        `final KeyValueStore _store;`.
      - Replace the constructor (:21-22) with a **single** parameter:
        `CommunityStorage({KeyValueStore? store}) : _store = store ?? SecureKeyValueStore();`
      - Rewrite every call site by changing **only the receiver** — the named
        parameters are identical, so `_secure.read(key: k)` → `_store.read(key: k)`,
        `_secure.write(key: k, value: v)` → `_store.write(key: k, value: v)`,
        `_secure.delete(key: k)` → `_store.delete(key: k)`. Sites: :27, :30, :34,
        :36-37, :42-46, :60-63, :89, :93, :97, :109 (14 calls).
      - **All storage key constants and the legacy-migration logic (:11-17,
        :26-69) are unchanged.**
- [ ] **C3.** Create `mobile/lib/shared/storage/key_value_store_provider.dart` —
      the platform decision gets its **own named provider** so tests can assert it
      structurally, independent of any plugin's method-channel name:

      ```dart
      /// The store backing anything that must persist sign-in material.
      ///
      /// Web gets a process-lifetime store: see [InMemoryKeyValueStore].
      final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
        return ref.watch(isWebProvider)
            ? InMemoryKeyValueStore()
            : SecureKeyValueStore();
      });
      ```

      Imports: `package:hooks_riverpod/hooks_riverpod.dart`,
      `../platform/is_web.dart`, `key_value_store.dart`. Separate file (not
      inside `key_value_store.dart`) so the storage primitives stay
      Riverpod-free, matching the repo's `*_provider.dart` convention.
- [ ] **C4.** Rewire `mobile/lib/shared/community/community_provider.dart:7-9`:

      ```dart
      final communityStorageProvider = Provider<CommunityStorage>((ref) {
        return CommunityStorage(store: ref.watch(keyValueStoreProvider));
      });
      ```

      Add `import '../storage/key_value_store_provider.dart';`.
      **Do not** touch `mobile/lib/main.dart`.
- [ ] **C5.** Create `mobile/test/helpers/fake_key_value_store.dart` — a
      `KeyValueStore` over a `Map<String, String>` that **also exposes the
      synchronous seeding operators** the existing tests rely on:

      ```dart
      class FakeKeyValueStore implements KeyValueStore {
        final Map<String, String> _data = {};
        // ...async read/write/delete over _data...

        // Convenience for setting up test data (mirrors the FakeSecureStorage
        // operators this replaces).
        String? operator [](String key) => _data[key];
        void operator []=(String key, String value) => _data[key] = value;
      }
      ```

      This is what keeps C6 genuinely mechanical: `community_storage_test.dart`
      uses `fakeSecure['buzz_workspaces'] = …` / `expect(fakeSecure['buzz_nsec'],
      isNull)` at **17 sites** (:174-175, :181-183, :187-190, :201-204, :217-218,
      :229-230) to seed legacy keys and assert post-migration cleanup. Without the
      operators, every one of those becomes an `await` expression — a changed
      assertion in the highest-consequence tests in the file. The operators live
      in `test/helpers/`, **not** on the production `InMemoryKeyValueStore`.
- [ ] **C6.** Migrate the five existing test files (mechanical, compile-checked).
      In each: replace the `FakeSecureStorage` type and constructor with
      `FakeKeyValueStore`, replace `CommunityStorage(secure: …)` with
      `CommunityStorage(store: …)`, and swap the
      `import '…/community_storage_test.dart';` for
      `import '…/helpers/fake_key_value_store.dart';`.
      - `mobile/test/shared/community/community_storage_test.dart` — **delete**
        the `FakeSecureStorage` class (:11-88, including the `[]`/`[]=` operators
        at :86-87) and the `package:flutter_secure_storage/…` import (:3);
        `late FakeSecureStorage fakeSecure;` (:92) → `FakeKeyValueStore`;
        `fakeSecure = FakeSecureStorage()` (:95) and
        `CommunityStorage(secure: fakeSecure)` (:96) updated. The 17 operator
        sites listed in C5 then compile **unchanged**.
      - `mobile/test/shared/community/community_provider_test.dart` — :7 import,
        **:10 `late FakeSecureStorage fakeSecure;`**, **:15 `fakeSecure = FakeSecureStorage();`**,
        :16 constructor. (The first revision of this plan listed only ":7, :16" —
        that was incomplete.)
      - `mobile/test/shared/auth/auth_provider_test.dart` — :9 import, :15, :37.
      - `mobile/test/features/invites/invite_join_provider_test.dart` — :13 import,
        :25, :83, :145, :190.
      - `mobile/test/features/channels/deep_link_dispatcher_test.dart` — :15
        import, :131. Leave the `communityStorageProvider.overrideWithValue(...)`
        at :64 alone.

      Before deleting each `community_storage_test.dart` import, confirm the file
      uses no other symbol from it. **No assertion in these files may change** —
      with C5 in place that is achievable; verify by diffing that only type names,
      constructor arguments, and import lines moved.

### Slice D — tests

See [Test Plan](#test-plan) for the full case list.

- [ ] **D1.** New `mobile/test/app_badge_gate_test.dart`.
- [ ] **D2.** New group in `mobile/test/features/channels/compose_bar_test.dart`
      (attach affordance **and** clipboard probe).
- [ ] **D3.** New cases in `mobile/test/features/pairing/pairing_page_test.dart`.
- [ ] **D4.** New cases in `mobile/test/shared/relay/media_upload_test.dart`
      (`group('pickAndUploadVideo')`, :1091, plus an image-path case).
- [ ] **D5.** New `mobile/test/shared/relay/media_upload_provider_test.dart`.
- [ ] **D6.** New `mobile/test/shared/storage/key_value_store_test.dart`.
- [ ] **D7.** New `mobile/test/shared/community/community_storage_web_test.dart`.
- [ ] **D8.** New case in `mobile/test/features/home/desktop_shell_test.dart`.
- [ ] **D9.** New `mobile/test/shared/storage/secure_key_value_store_test.dart`.
- [ ] **D10.** New `mobile/test/shared/storage/storage_import_fence_test.dart`.
- [ ] **D11.** Run the full suite with the `very_good_cli` MCP `test` tool
      (`directory: mobile`), `flutter analyze`, `dart format`, and
      `node ./scripts/check-file-sizes.mjs`. All green.

### Slice E — documentation

- [ ] **E1.** Add a `## Web (experimental)` section to `mobile/README.md` (after
      `## Run`, before `## Checks`) covering: the build command
      (`just mobile-build-web`), the **same-origin** serve command, the
      cross-origin CORS caveat with the exact relay file reference, and the list
      of capabilities disabled on web (app badge, **all media upload from the
      compose bar**, QR scan, `buzz://` deep links). Include one sentence making
      the storage split explicit: **"session-only" means sign-in material (the
      `nsec`) is never persisted and must be re-entered after a reload, while
      pubkey-keyed channel preferences kept in `shared_preferences` — read state,
      mutes, stars, sections — do persist to `localStorage` and survive a
      reload.** Also note that `defaultTargetPlatform` is user-agent derived on
      web, so mobile-browser UAs take the android/iOS code paths.

      ```bash
      # Build, then serve same-origin from the relay (avoids the CORS gap):
      just mobile-build-web
      BUZZ_WEB_DIR=mobile/build/web cargo run -p buzz-relay
      # Point the build at a non-default relay:
      cd mobile && flutter build web --release --dart-define=BUZZ_RELAY_URL=https://relay.example
      ```

      `--dart-define` works identically for web (`Env.relayUrl` at
      `mobile/lib/shared/relay/relay_provider.dart:35-38`; `RelayConfig.wsUrl`
      derives `wss` from `https` at :22-27, so mixed content is correct by
      construction).
- [ ] **E2.** Put the
      [manual verification checklist](#manual-verification-checklist-for-the-pr-body)
      in the PR body, along with an explicit statement of what the automated
      gates do and do not prove, and the follow-ups list.

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
| D6 | `mobile/test/shared/storage/key_value_store_test.dart` (new) | `InMemoryKeyValueStore`: write→read round-trips; `read` of an absent key is `null`; `delete` removes; two instances do not share state (guards against a static map). |
| D7 | `mobile/test/shared/community/community_storage_web_test.dart` (new) | **Structural half (version-independent):** `ProviderContainer(overrides: [isWebProvider.overrideWithValue(true)])` → `container.read(keyValueStoreProvider)` is `isA<InMemoryKeyValueStore>()`; with `false` → `isA<SecureKeyValueStore>()`. **Behavioural half:** install a **stateful** mock handler on `const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')` that backs `read`/`write`/`delete`/`containsKey` with a real `Map` and counts calls (a recording-only handler that returns `null` makes `loadAll()` return `[]`, so the round-trip half of the control could never pass). Then `read(communityStorageProvider)`, `save(...)` a `Community` with a non-null `nsec`, `loadAll()`. **(a)** `isWeb: false` → ≥ 1 recorded call **and** the community round-trips (control — if this fails, the channel name is wrong; fix it to whatever the control observes). **(b)** `isWeb: true` → **zero** recorded calls, and the community still round-trips through the in-memory store within the same container. |
| D8 | `mobile/test/features/home/desktop_shell_test.dart` (extend) | Add an optional `bool isWeb = false` parameter to `createContainer` that appends `isWebProvider.overrideWithValue(isWeb)` to the override list. New case: `useWideSurface(tester)` (1440×900) + `createContainer(isWeb: true)` + `buildTestable(container)` → the community rail items, `find.text('general')`, and `find.text('Select a channel')` all render, and no exception is thrown. This is the "prove one reused screen" check. |

| D9 | `mobile/test/shared/storage/secure_key_value_store_test.dart` (new, ~20 lines) | After the refactor this is the **only** untested link between the app and Keychain/Keystore. Using the same stateful mock-channel scaffolding as D7 (extract it into the helper file or duplicate the ~15 lines), assert `SecureKeyValueStore` round-trips `write` → `read`, that `read` of an absent key is `null`, and that `delete` removes — i.e. that the wrapper forwards named arguments correctly. Catches a transposed or dropped argument that the type system cannot. |
| D10 | `mobile/test/shared/storage/storage_import_fence_test.dart` (new, ~15 lines) | Walk `Directory('lib')` recursively (`dart:io` is fine on the VM), read every `.dart` file, and collect those whose source contains `package:flutter_secure_storage`. Assert the result is exactly `['lib/shared/storage/key_value_store.dart']`. Turns the security property into a standing invariant instead of a point-in-time audit: a future contributor who reaches for `FlutterSecureStorage` elsewhere breaks the build rather than silently re-persisting to `localStorage` on web. |

Existing-suite requirement: all 60 pre-existing test files still pass, with the
only edits being the Slice C migration (type/constructor/import lines only — see
C5/C6) and the additive cases above. In particular the 7 existing
`paperclip → Photo` tests and the 1 `paperclip → Video` test in
`compose_bar_test.dart` must pass **unchanged**; they are the mobile control for
B3.

### Manual verification checklist (for the PR body)

Only a human with a browser can close these:

- [ ] `just mobile-build-web && BUZZ_WEB_DIR=mobile/build/web cargo run -p buzz-relay`,
      then open the relay origin in a desktop browser at ≥ 1440px wide.
- [ ] The app paints; Inter and GeistMono load; no console `MissingPluginException`
      or `Unsupported operation`.
- [ ] `DesktopShell` shows the community rail, channel list, and message pane;
      pane widths and breakpoints look right when the window is resized.
- [ ] Pasting a pairing code connects; the WebSocket upgrades and NIP-42 auth
      completes; **no** "Scan QR Code" button is present.
- [ ] Avatars and inline images load (same-origin).
- [ ] **No paperclip/attach button is offered** in the compose bar (media upload
      is disabled on web in Phase 0).
- [ ] **Repeat the load, pair, and compose-bar steps in a mobile-browser user
      agent** — iOS Safari (or desktop Safari with Develop → User Agent → iOS)
      and Android Chrome. This is the case the automated gates were originally
      blind to: `defaultTargetPlatform` is UA-derived, so these UAs take the
      android/iOS branches. Watch the console for `MissingPluginException`
      on `buzz/media_upload` while focusing and blurring the message field.
- [ ] Reloading the page returns to pairing (sign-in material is session-only —
      this is intended). Note that channel read-state/mutes/stars **do** survive
      the reload; they live in `shared_preferences` → `localStorage`.
- [ ] Mouse-wheel and trackpad scrolling in the message timeline behave sanely.

**Known caveat to state in the PR:** serving the web build **cross-origin** from
the relay will show broken images and failed uploads until the relay names
`Authorization` in `Access-Control-Allow-Headers`
(`crates/buzz-relay/src/router.rs:397-421`; the fix is `AUTHORIZATION` in
`allow_headers` or `AllowHeaders::mirror_request()`). That is a pre-existing
relay bug that also affects the shipped React client's `just web` dev mode, and
it is deliberately not fixed here.

## Success Metrics

- `flutter build web --release` goes from "not configured for the web" to a green
  build of ~35.6k LOC across 172 lib files — a previously untested property.
- Zero change to the Android/iOS runtime: no dependency, pubspec, `android/`, or
  `ios/` diff, and a fully green pre-existing test suite.
- Six gates, and a test per gate asserting **zero platform-channel traffic**
  rather than merely "the widget is gone": every disabled-on-web behavior is
  asserted, and each assertion is paired with a non-web control so it cannot pass
  vacuously.
- The Nostr `nsec` provably never reaches browser storage (zero secure-storage
  channel traffic in web mode).

## Dependencies

- **Phase 1 (parity shell) must be on the branch base.** It is: `DesktopShell`,
  `breakpoints.dart`, `shell_state_provider.dart`, `adaptive_modal.dart`, and
  `attachment_drop_region.dart` landed on `main` (PRs #1–#4, commit `e4622671`).
  D8 extends `test/features/home/desktop_shell_test.dart`, which already exists.
- **Branch**: `feat/flutter-web-desktop-phase-0` (already checked out, clean).
- **Brainstorm**: `docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md`
  — its evidence overrides `mobile/DESKTOP_PORT_PLAN.md` §9/§5.
- **Toolchain**: Flutter 3.44.4 stable must be the active SDK (the runner
  directory is authored against that version's template) and `sips` must be
  available (macOS) for A3.
- **No new package dependencies.** `pubspec.yaml`/`pubspec.lock` unchanged.
- **Internal slice ordering**: Slice B task B1 (`is_web.dart`) is required by
  B2–B6 and by C3. Slice A is independent of B and C. Slice C depends on B1 only.
  Slice D depends on B and C — in particular C5 (`fake_key_value_store.dart`)
  must land with C6, not after it, or the migrated tests will not compile.
  Slice E depends on A.
- **Not blocked by**, and does not block: the relay CORS follow-up, CI wiring of
  the web build, `desktop_drop`, NIP-07. All are explicitly deferred.

## Risks & Mitigations

1. **`flutter build web` succeeds but the app crashes on first paint.** The build
   gate cannot catch `MissingPluginException` or `UnsupportedError`. *Mitigation:*
   each gate is asserted by a test, and the residual risk is handed to the human
   checklist. **Calibration:** the brainstorm's call-site audit was already wrong
   once — it treated `defaultTargetPlatform` guards as web-proof (see
   [the correction](#correction-defaulttargetplatform-on-web-is-user-agent-derived)),
   which is why the manual checklist now requires a **mobile-browser UA** pass,
   not just a desktop window. Treat any remaining "this is unreachable on web"
   claim as unproven unless a test asserts zero channel traffic.
2. **Mobile regression from touching load-bearing shared files.** *Mitigation:*
   every gate is an additive branch that evaluates `false` off-web;
   `supportsMediaUpload` defaults to `true`; the `KeyValueStore` migration is
   compile-checked; the 60 existing test files are the gate and none may be
   weakened.
3. **The `KeyValueStore` migration touches 5 test files / 9 call sites.**
   *Mitigation:* purely mechanical and analyzer-enforced; it also deletes ~85
   lines of `FlutterSecureStorage` boilerplate and lets the tests exercise the
   real web store. If `flutter analyze` is green and the suite passes, the
   migration is complete by construction.
4. **The secure-storage channel name may differ under the installed plugin
   version**, making the D7 assertion vacuous. *Mitigation:* D7 includes a
   non-web control case that must record ≥ 1 call; a vacuous assertion fails the
   control first.
5. **First `flutter build web` may surface compile errors this audit did not
   reach.** *Mitigation:* the build is permitted in this run, so failures surface
   now. If a fix would need a dependency or Rust change, stop and report — do not
   expand scope.
6. **The web target has no CI protection**, so a later mobile change can silently
   break it. *Mitigation:* accepted and documented; `just mobile-build-web` makes
   local checking one command. CI wiring requires a human edit to
   `.github/workflows/ci.yml` (guardrail-blocked).
7. **`mobile/web/index.html` drifts from the SDK template** across Flutter
   upgrades (as happened industry-wide at the 3.22 `flutter_bootstrap.js`
   transition). *Mitigation:* the provenance comment from A1 records the SDK
   version and the template path to diff against.
8. **Same-origin serving is a documentation-only mitigation for the CORS gap.**
   *Mitigation:* stated prominently in `mobile/README.md` (E1) and the PR body
   (E2), with the exact file/line and fix for the follow-up.
9. **A platform-conditional path is missed in a *third-party* package**, the way
   `defaultTargetPlatform` was missed in ours. *Mitigation:* accepted. The plugin
   audit in brainstorm §2 covered all 23 direct dependencies structurally
   (does a web implementation exist?); what it could not cover is behavioural
   divergence inside a package that *does* declare web. That residual surfaces in
   the browser checklist, now including a mobile-browser UA pass.
10. **Disabling media upload on web removes the one end-to-end Blossom path a
    human could have exercised in the browser.** *Mitigation:* accepted for
    Phase 0 — the upload path also needs the relay CORS follow-up to work
    cross-origin, and `uploadBytes()` remains ungated so a future web drag-drop
    backend lights it up without touching the service again.

## Auto-resolved assumptions

This plan was produced non-interactively. Wherever the `/plan` skill would have
asked a human, the most YAGNI-aligned default was taken and recorded here.

1. **Skill interactivity**: brainstorm doc supplied, so idea refinement was
   skipped; `codebase-review-agent` **not** re-run (per the skill, context comes
   from the brainstorm) — targeted Glob/Grep/Read verification was done instead
   and is captured in [Codebase Context](#codebase-context-verified); external
   research skipped (strong local context; the one security-sensitive decision was
   already researched in the brainstorm with in-repo precedent);
   `user-flow-analysis-agent` not run (this is a compile-and-gate phase with no
   new user flow — the only flow change is *removing* affordances on one
   platform); no branch setup (the orchestrator owns
   `feat/flutter-web-desktop-phase-0`).
2. **Detail level = Standard, extended.** The Standard template is the base;
   Codebase Context, Conventions, Test Plan, and an ordered per-file task list
   were added because the build stage trusts this plan and does not re-review the
   codebase.
3. **Storage gate lives *inside* `communityStorageProvider`**, not as an override
   applied at the root `ProviderScope` in `main.dart`. The brainstorm said
   "override `communityStorageProvider`"; selecting the store inside the provider
   body preserves the intent, keeps `main.dart` untouched, keeps all five gates
   reading the same seam, and is testable with a plain `ProviderContainer`.
4. **Single `store:` constructor parameter on `CommunityStorage`**, migrating the
   five existing test files, rather than keeping `secure:` alongside a new
   `store:` (which would have touched zero test files). Rationale: a dual-path
   constructor is a lasting smell and the migration is compile-checked, so it
   cannot silently regress runtime behavior. The *stronger* alternative — a
   production `InMemorySecureStorage extends FlutterSecureStorage`, which is
   technically feasible and would also touch zero test files — is analysed and
   rejected in
   [Rejected alternative](#rejected-alternative-inmemorysecurestorage-extends-fluttersecurestorage):
   it is fail-open on precisely the property this slice guarantees.
5. **`MediaUploadService` takes `supportsMediaUpload`, not `isWeb`.** Capability
   naming keeps the service platform-agnostic; the provider does the translation.
   Defaulting to `true` is what makes the change invisible to existing callers.
6. **The pairing subtitle copy changes on web.** The brainstorm only said "hide
   the Scan QR Code button", but leaving
   `'Scan the QR code from your desktop app…'` above a page with no scanner ships
   a lie. One conditional string (`'Paste a pairing code from your desktop app to
   connect.'`), no-op on mobile. The "or paste pairing code" divider is hidden
   with the button since it is meaningless alone.
7. **No test for `isWebProvider` itself.** A one-line provider returning `kIsWeb`
   needs no dedicated test; the five gate tests exercise it via overrides.
8. **New compose-bar and pairing cases go in the existing test files** rather than
   new ones, to reuse `_buildComposeBar` (which already supports `extraOverrides`)
   instead of duplicating a large harness. The 1000-line guard covers `lib/` only,
   so the 1671-line `compose_bar_test.dart` growing further is allowed. The
   media-upload **provider** test gets its own file because the existing
   `media_upload_test.dart` has no `ProviderContainer` scaffolding.
9. **`manifest.json` deviates from the SDK template in three values only**:
   `theme_color`/`background_color` (Catppuccin instead of `#0175C2`, per the
   brainstorm) and `orientation: "any"` (the target is a desktop-width browser
   window, not a portrait phone PWA).
10. **`favicon.png` is generated at 32×32** and the maskable icons reuse the same
    square artwork without safe-zone padding. Authoring proper maskable artwork is
    design work with no Phase 0 value; the limitation is noted in the PR.
11. **`just mobile-build-web` omits `--no-pub`** (unlike `mobile-build-android`)
    so the first web build resolves web plugin registrants cleanly. It is **not**
    added to `just ci`/`just check` — CI enforcement needs a guardrail-blocked
    workflow edit, so adding it locally would only slow developers without
    enforcing anything.
12. **`mobile/README.md` gets a Web section** in addition to the PR-body checklist
    the brainstorm asked for. PR bodies are not discoverable six months later; the
    CORS caveat and the same-origin run command need a durable home. This is the
    only file outside `mobile/web/`, `mobile/lib/`, `mobile/test/`, and `justfile`
    that this plan touches.
13. **Three of the brainstorm's four evidence-based overrides of
    `DESKTOP_PORT_PLAN.md` are accepted as-is** (`dart:io` compiles under dart2js
    so no conditional-import scaffolding; no `file_selector`/`media_kit` swaps;
    `app_badge_plus` is the only dependency with no web implementation).
    Spot-checks confirmed them: `mobile/lib` has exactly the three `dart:io`
    importers described, `channels_page.dart`'s import is indeed used by
    `channels_page/badges.dart`, and `FlutterSecureStorage` appears in exactly one
    lib file. **The fourth override — "only the video path of `buzz/media_upload`
    needs gating" — is wrong and is corrected in this revision** (see #15).
14. **Open questions 1–4 from the brainstorm keep their defaults**: relay CORS fix
    not in this PR; no "session only" UI banner; session-only store rather than
    NIP-07; `mobile/` is not renamed.

### Revision 2 — decisions taken during plan technical review

15. **The `defaultTargetPlatform` correction was verified independently before
    acting on it**, in
    `$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`. The
    review's claim understated it: `ui_web.OperatingSystem.unknown` also maps to
    `TargetPlatform.android`, so an unrecognised user agent takes the android
    branch too. The brainstorm's §3 has been annotated with a short correction
    note rather than rewritten.
16. **Media upload is disabled on web outright** rather than de-sanitised. The
    review proposed threading a `supportsNativeImageProcessing` flag; that fixes
    the crash but silently drops the EXIF/GPS scrub that
    `AndroidImageProcessor.encodeAndScrub` performs on mobile, and leaves a
    confusing HEIC failure path. One `supportsMediaUpload` capability plus hiding
    the paperclip is simpler, safer, and consistent with every other Phase 0
    gate. This goes **further** than the review asked; the reasoning is in
    [Media upload on web](#media-upload-on-web-the-remedy-for-c1).
    `uploadBytes()` stays ungated so nothing that works today is removed.
17. **`readAndUploadClipboardImage()` is gated by the same capability**, in
    addition to the `compose_bar.dart:141` probe gate. The probe gate alone is
    sufficient in practice (it is the only writer of `clipboardHasImage.value`),
    but the service method is public API and reaches a MethodChannel, so both are
    gated — belt and braces, one extra `if`.
18. **The `[]`/`[]=` seeding operators live on a test double
    (`test/helpers/fake_key_value_store.dart`), not on production
    `InMemoryKeyValueStore`.** This is what makes the C6 migration honest: 17
    existing assertion/seeding sites in `community_storage_test.dart` compile
    unchanged. The alternative — putting the operators on the production class —
    would ship test-only affordances in the web store.
19. **`key_value_store.dart` lives in a new `shared/storage/` folder**, not in
    `shared/community/`. It is a generic primitive; the likely next consumers are
    the six `shared_preferences`-backed storages under `features/channels/`.
20. **`.metadata` gets the `web` platform entry by hand** (A7) despite the file's
    "should not be manually edited" header, because `flutter create` is blocked
    and the alternative is a tracked file that silently misdescribes the project.
    The build agent may instead document the omission in A1's provenance comment
    — but must do one of the two.
21. **Rejected minor:** deriving `supportsAppBadge` / `supportsQrScan` locals from
    `isWebProvider` "for naming consistency". Capability naming earns its keep at
    the `MediaUploadService` boundary because that class has no Riverpod access
    and must receive a flag. Inside a widget, `ref.watch(isWebProvider)` *is* the
    seam; renaming the local to `supportsAppBadge` would add indirection and
    obscure the real reason the branch exists (we are in a browser), which the
    adjacent comment has to explain anyway. Kept `isWeb`.
22. **Accepted minors:** `unawaited(...)` + `debugPrint` error handling on
    `AppBadgePlus.updateBadge` (B2 — a real latent unhandled-async-error bug on
    Android launchers that reject badges); named parameters on `KeyValueStore`
    (C1); the stateful mock channel handler for D7's control (D7); the
    `SecureKeyValueStore` channel test (D9); the `:(top)` pathspec fix in the
    acceptance criteria; the README storage-split sentence (E1); and checking
    `compose_bar_test.dart` for existing coverage first — which found 8 existing
    `paperclip` taps, so D2 needs only the web-negative case, not a new control.

## References & Research

- Brainstorm: `docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md`
  (§1 `dart:io` audit, §2 plugin web-support table, §3 MethodChannel call-site
  audit, §4 secure storage, §5 relay connectivity, §6 deep links).
- Source plan: `mobile/DESKTOP_PORT_PLAN.md` §9 Phase 0, §5, §10.1.
- Predecessor plan (landed): `docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md`;
  merged PRs #1–#4; commit `e4622671`.
- SDK template: `$FLUTTER_ROOT/packages/flutter_tools/templates/app/web/{index.html.tmpl,manifest.json.tmpl,icons/}`;
  web-project gate at `flutter_tools/lib/src/project.dart:1132-1133`.
- **UA-derived platform (revision 2)**:
  `$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`
  (`_browserPlatform` ← `ui_web.browser.operatingSystem`; `unknown => android`).
  Native EXIF scrub:
  `mobile/android/app/src/main/kotlin/xyz/block/buzz/mobile/MainActivity.kt:189`
  (`AndroidImageProcessor.encodeAndScrub`), handler dispatch at :91-99.
- Plugin extensibility check (revision 2):
  `flutter_secure_storage-10.3.0/lib/flutter_secure_storage.dart:22` — plain
  `class` with a `const` constructor and 7 `Future`-returning members, of which
  `CommunityStorage` uses 3.
- Relay same-origin serving: `crates/buzz-relay/src/router.rs:145-186`
  (`BUZZ_WEB_DIR`); CORS gap at `crates/buzz-relay/src/router.rs:397-421`.
- Browser-client key-custody precedent: `web/src/shared/lib/nostr-signer.ts`;
  same-origin URL helper `web/src/shared/lib/relay-url.ts:12-24`.
- Conventions: `CLAUDE.md` § Mobile App (Flutter), § Quality Gates;
  `mobile/scripts/check-file-sizes.mjs`.
