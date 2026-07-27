---
title: 'feat: Flutter web target (Phase 0) — Part 3: session-only key-value store & docs'
type: feat
date: 2026-07-27
part: 3 of 3
status: ready-for-build
branch: feat/flutter-web-target-part-3
base-branch: feat/flutter-web-target-part-2
pr-target: feat/flutter-web-target-part-2
depends-on: docs/plan/2026-07-27-feat-flutter-web-target-part-2-plan.md
parent-plan: docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md
brainstorm: docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§9 Phase 0 — retargeted to web only)
---

# feat: Flutter web target (Phase 0) — Part 3 of 3: session-only key-value store & docs

> **Standalone build input.** This file is the complete specification for
> Part 3 — the build stage receives only this file and **does not re-review the
> codebase**. Everything under [Codebase Context](#codebase-context-verified)
> was verified in this repo and is to be trusted. Task IDs (C1–C6, D6, D7, D9,
> D10, D11, E1, E2) are global across the three-part series and match
> `docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`, which remains
> the canonical rationale document. Any task ID not listed here belongs to
> Part 1 or Part 2 (both landed) — context only, **never scope for this build**.

## Overview

Parts 1 and 2 gave the `mobile/` Flutter app a web runner directory, a
`just mobile-build-web` recipe, one overridable platform seam (`isWebProvider`),
and five runtime gates so a browser session no longer throws
`MissingPluginException`. One problem remains, and it is the security-relevant
one: **on web, `CommunityStorage` still persists the Nostr `nsec` to browser
`localStorage`.**

**Part 3 (this plan) closes that, and finishes the phase:**

- **C1–C4** — replace `CommunityStorage`'s concrete `FlutterSecureStorage`
  dependency with a three-method `KeyValueStore` seam under
  `mobile/lib/shared/storage/`; a named `keyValueStoreProvider` picks
  `InMemoryKeyValueStore` on web and `SecureKeyValueStore` everywhere else.
- **C5–C6** — a `FakeKeyValueStore` test double and the mechanical migration of
  the five existing test files that construct `CommunityStorage`.
- **D6, D7, D9, D10** — round-trip tests, a **structural** provider assertion, a
  **behavioural** zero-secure-storage-channel-traffic assertion with a stateful
  mock channel, a `SecureKeyValueStore` forwarding test, and a standing
  **import-fence invariant**.
- **D11** — the final full-suite / analyze / format / file-size gate across the
  whole stack.
- **E1–E2** — the `mobile/README.md` "Web (experimental)" section and the PR-body
  manual verification checklist.

This part touches **no widget, no gate, and no runner file**. It is deliberately
its own PR so the security-relevant change gets focused review instead of being
buried among widget-visibility diffs.

## Problem Statement / Motivation

`flutter_secure_storage_web` 2.1.1 encrypts values with AES-GCM-256 into
`window.localStorage` and then writes the **extractable AES key into the same
`localStorage`** under the key `FlutterSecureStorage`. Any XSS on the origin
recovers the Nostr `nsec`. The plugin's own README calls the web implementation
"experimental… Use at your own risk".

The repo already has a position on this: `web/src/shared/lib/nostr-signer.ts`,
the shipped browser client, **refuses durable key storage** — it uses a NIP-07
extension or a module-level in-memory ephemeral key. The Flutter web build must
match that posture, or the two browser clients in this repo would disagree about
key custody, with the newer one being the weaker.

`FlutterSecureStorage` appears in **exactly one place** in `mobile/lib` —
`shared/community/community_storage.dart:3` — so this is a small, contained
change. The work is in doing it fail-*closed* (see
[Rejected alternative](#rejected-alternative-inmemorysecurestorage-extends-fluttersecurestorage))
and in proving it two independent ways.

## Proposed Solution

- A three-method `KeyValueStore` interface (`read` / `write` / `delete`, **all
  named parameters**) with two production implementations:
  `SecureKeyValueStore` (wraps `const FlutterSecureStorage()` with default
  options — byte-identical keychain behaviour to today) and
  `InMemoryKeyValueStore` (process-lifetime map, used on web).
- The platform decision is hoisted into its **own named provider**,
  `keyValueStoreProvider`, which `communityStorageProvider` reads. That gives the
  tests a version-independent structural assertion (`isA<InMemoryKeyValueStore>()`)
  that does not depend on a plugin's method-channel name, and it keeps
  `mobile/lib/main.dart` untouched.
- `CommunityStorage` takes a **single** `KeyValueStore? store` parameter. The
  five existing test files migrate mechanically; the migration is
  compile-time-checked, so a missed call site fails `flutter analyze` loudly
  rather than silently changing runtime behaviour.
- The security property becomes a **standing invariant**, not a one-time audit: a
  ~15-line import-fence test asserts that `package:flutter_secure_storage` is
  imported by exactly one file under `mobile/lib`.
- Accepted cost: a page reload on web requires re-entering the pairing code.

## Scope

### In scope for Part 3

- New: `mobile/lib/shared/storage/key_value_store.dart`,
  `mobile/lib/shared/storage/key_value_store_provider.dart`.
- Rewired: `mobile/lib/shared/community/community_storage.dart`,
  `mobile/lib/shared/community/community_provider.dart`.
- New: `mobile/test/helpers/fake_key_value_store.dart`.
- Migrated (mechanically): `mobile/test/shared/community/community_storage_test.dart`,
  `mobile/test/shared/community/community_provider_test.dart`,
  `mobile/test/shared/auth/auth_provider_test.dart`,
  `mobile/test/features/invites/invite_join_provider_test.dart`,
  `mobile/test/features/channels/deep_link_dispatcher_test.dart`.
- New tests: `mobile/test/shared/storage/key_value_store_test.dart`,
  `mobile/test/shared/community/community_storage_web_test.dart`,
  `mobile/test/shared/storage/secure_key_value_store_test.dart`,
  `mobile/test/shared/storage/storage_import_fence_test.dart`.
  (`mobile/test/shared/storage/` does not exist yet — create it.)
- `mobile/README.md` — a `## Web (experimental)` section.
- The PR body — the manual verification checklist for the whole phase.

### Out of scope for Part 3 — do not implement

- **Anything Parts 1 and 2 landed.** Do not touch `mobile/web/**`,
  `mobile/.metadata`, `justfile`, `mobile/lib/shared/platform/is_web.dart`,
  `mobile/lib/app.dart`, `mobile/lib/features/channels/compose_bar.dart`,
  `mobile/lib/shared/relay/media_upload.dart`, or
  `mobile/lib/features/pairing/pairing_page.dart`. Read them; do not edit them.
- **`mobile/lib/main.dart`** — the storage decision lives inside
  `keyValueStoreProvider`, not in a root `ProviderScope` override.
- **`shared_preferences`.** It is a separate, lower-sensitivity surface and is
  deliberately left alone — see [Security](#security). Do **not** migrate the
  channel mutes / stars / sections / read-state storages onto `KeyValueStore` in
  this PR; that is the seam's *likely next* consumer, not its current one.
- **Any new capability on `KeyValueStore`.** Exactly three methods. `readAll`,
  `deleteAll`, `containsKey`, and `registerListener` are precisely what this
  slice exists to keep out.
- Test-only affordances on production `InMemoryKeyValueStore` (the `[]`/`[]=`
  seeding operators live on the test double only).
- NIP-07 signer integration; a "session only" UI banner; renaming `mobile/`.
- The relay CORS fix (`crates/buzz-relay/src/router.rs:397-421`) — Rust, filed
  as a follow-up. **Document it (E1/E2); do not fix it.**
- Any dependency change. `mobile/pubspec.yaml` and `mobile/pubspec.lock` must be
  byte-identical.
- `.github/workflows/`, secrets, feature flags, deploy/infra manifests
  (guardrail-blocked).

## Dependencies

**Builds on:** Part 2 —
`docs/plan/2026-07-27-feat-flutter-web-target-part-2-plan.md` (which itself
builds on Part 1).

**Base branch:** `feat/flutter-web-target-part-2`, at that branch's head SHA.
**Working branch:** `feat/flutter-web-target-part-3`. **The PR targets
`feat/flutter-web-target-part-2`**, not `main`.

**Inherited from Part 1 (exists on the base branch — do not recreate, do not
edit):**

- `mobile/lib/shared/platform/is_web.dart`:

  ```dart
  final isWebProvider = Provider<bool>((ref) => kIsWeb);
  ```

  **This is the only seam.** C3's `keyValueStoreProvider` reads it. Import it
  relatively from `shared/storage/` as `import '../platform/is_web.dart';`.
- `mobile/web/` (six tracked files), the `web` entry in `mobile/.metadata`, and
  the `just mobile-build-web` recipe in `justfile` (immediately after
  `mobile-build-android` at :589-590). `just check` (:94) and `just ci` (:258)
  are unmodified and must stay that way.

**Inherited from Part 2 (exists on the base branch — do not recreate, do not
edit):**

- Five runtime gates reading `isWebProvider`: the app badge (`app.dart`), the
  paperclip attach affordance and the iOS clipboard probe (`compose_bar.dart`),
  `MediaUploadService.supportsMediaUpload` + its three entry-point guards and the
  provider wiring (`media_upload.dart`), and the QR-scan gate
  (`pairing_page.dart`).
- Their tests: `mobile/test/app_badge_gate_test.dart`,
  `mobile/test/shared/relay/media_upload_provider_test.dart`, and additive cases
  in `compose_bar_test.dart`, `pairing_page_test.dart`, `media_upload_test.dart`,
  `desktop_shell_test.dart` (including `createContainer`'s optional
  `bool isWeb = false` parameter). **All must stay green; none may be weakened.**

**Disjoint file sets:** Parts 2 and 3 touch no file in common, so **no textual
merge conflict is expected** when this stacks on Part 2.

**No new package dependencies.** `pubspec.yaml`/`pubspec.lock` unchanged.

## Branch / PR topology (three-part stack)

| Part | Branch | Base | PR targets |
|---|---|---|---|
| 1 (landed) | `feat/flutter-web-target-part-1` | `main` @ `e4622671` | `main` |
| 2 (landed) | `feat/flutter-web-target-part-2` | `feat/flutter-web-target-part-1` @ merged head SHA | `feat/flutter-web-target-part-1` |
| **3 (this)** | `feat/flutter-web-target-part-3` | `feat/flutter-web-target-part-2` @ its head SHA | `feat/flutter-web-target-part-2` |

**Terminal state for this part is an unmerged PR against
`feat/flutter-web-target-part-2`.** Do not merge, do not deploy.

## Codebase Context (verified)

Everything in this section was verified in this repo. **The build stage should
trust this section and not re-review the codebase.**

### Environment and tooling facts

| Fact | Value |
|---|---|
| Flutter / Dart | 3.44.4 stable / Dart 3.12.2 |
| `FLUTTER_ROOT` | `/Users/robertasskiauteris/development/flutter` (derive with `dirname $(dirname $(readlink -f $(which flutter)))`) |
| File-size guard | `mobile/scripts/check-file-sizes.mjs` — 1000 lines, **`lib/` only**, no overrides. `test/` is not scanned |
| Baseline before this series | `flutter analyze` → **No errors**; 60 `*_test.dart` files all pass. Part 2 added 2 files; this part adds 4 more plus a helper |

**Hook/permission constraints for the build stage (hard constraints):**

- `flutter create` / `dart create` → **BLOCKED** by a PreToolUse hook.
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
| `mobile/lib/shared/community/community_storage.dart` | 111 | `import 'package:flutter_secure_storage/flutter_secure_storage.dart';` :3; `final FlutterSecureStorage _secure` :19; ctor :21-22 (`CommunityStorage({FlutterSecureStorage? secure}) : _secure = secure ?? const FlutterSecureStorage();`); `_secure.read/write/delete` at :27, :30, :34, :36-37, :42-46, :60-63, :89, :93, :97, :109 (**14 calls**). Storage key constants :11-17; legacy-migration logic :26-69 |
| `mobile/lib/shared/community/community_provider.dart` | 127 | `communityStorageProvider` :7-9 → `CommunityStorage()`. `Provider` imported from `package:hooks_riverpod/hooks_riverpod.dart` at :1 |
| `mobile/lib/shared/storage/` | — | **Does not exist.** Created by C1/C3 |
| `mobile/test/shared/storage/` | — | **Does not exist.** Created by D6/D9/D10 |
| `mobile/test/helpers/` | — | Contains only `widget_helpers.dart` today → `WidgetHelpers.testable({child, overrides})`. C5 adds `fake_key_value_store.dart` |
| `mobile/README.md` | 66 | Headings: `# Buzz Mobile` :1, `## Setup` :5, `## Run` :12, `## Checks` :22, `## Android release signing` :32, `## Architecture` :50. **E1 inserts a `## Web (experimental)` section immediately before `## Checks` (:22).** |

**`FlutterSecureStorage` appears in exactly one place in `mobile/lib`** —
`community_storage.dart:3`. That single file is the entire persistent-secret
surface; pairing writes credentials through `CommunityStorage.save()`. This is
what makes the D10 fence start green.

Test files that construct `CommunityStorage` (all need the C6 migration):

| Test file | Sites |
|---|---|
| `mobile/test/shared/community/community_storage_test.dart` | defines `FakeSecureStorage` :11-88 (including `[]`/`[]=` operators at :86-87); `late FakeSecureStorage fakeSecure;` :92; `fakeSecure = FakeSecureStorage()` :95; `CommunityStorage(secure: fakeSecure)` :96; `package:flutter_secure_storage/…` import :3. **17 operator sites** at :174-175, :181-183, :187-190, :201-204, :217-218, :229-230 |
| `mobile/test/shared/community/community_provider_test.dart` | imports the above :7; `late FakeSecureStorage fakeSecure;` :10; `fakeSecure = FakeSecureStorage();` :15; constructor :16 |
| `mobile/test/shared/auth/auth_provider_test.dart` | imports :9; :15, :37 |
| `mobile/test/features/invites/invite_join_provider_test.dart` | imports :13; :25, :83, :145, :190 |
| `mobile/test/features/channels/deep_link_dispatcher_test.dart` | imports :15; :131 (also overrides `communityStorageProvider` with a value at :64 — **unaffected, leave it alone**) |

Platform channel name needed by this part's tests:

| Plugin | Channel |
|---|---|
| `flutter_secure_storage` (platform interface default) | `plugins.it_nomads.com/flutter_secure_storage` |

Useful existing test infrastructure:

- `mobile/test/helpers/widget_helpers.dart` → `WidgetHelpers.testable({child, overrides})`.
- `mobile/test/widget_test.dart` → `_FakeAuthNotifier` pattern; mounts `App` with
  `authProvider` and `savedPrefsProvider` overrides.

### Correction: `defaultTargetPlatform` on web is user-agent derived

**This is the single most important fact in the parent plan.** It drove Part 2's
gates; it bears on this part in two narrower ways — the README must document it
(E1), and it explains why the test suite exercises android branches by default.
Verified in the SDK at
`$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`:

```dart
platform.TargetPlatform get defaultTargetPlatform =>
    platform.debugDefaultTargetPlatformOverride ?? _testPlatform ?? _browserPlatform;

final platform.TargetPlatform _browserPlatform =
    _operatingSystemToTargetPlatform(ui_web.browser.operatingSystem);
// android => android, iOs => iOS, linux => linux, macOs => macOS,
// windows => windows, unknown => android   <-- note the fallback
```

Consequences relevant here:

- **Mobile-browser and unknown user agents take the android/iOS code paths on
  web.** E1 must say this in the README, and E2's manual checklist must require
  an iOS Safari and an Android Chrome pass — the automated gates were originally
  blind to exactly this case.
- **`flutter_test` sets `debugDefaultTargetPlatformOverride = TargetPlatform.android`.**
  Widget and unit tests therefore run on the android branch by default. For this
  part that is benign (`flutter_secure_storage`'s channel name is
  platform-independent), but it is the reason D7's mock-channel control works at
  all — and a reminder that a green suite never proved a path was web-safe.

**Rule for this part:** `grep -rn "defaultTargetPlatform" mobile/lib` must show
**no newly added uses**. Neither `key_value_store.dart` nor
`key_value_store_provider.dart` may mention it; the seam is `isWebProvider`.

### Findings that override the source plan (relevant to Part 3)

These were verified empirically in the brainstorm. **Do not re-litigate them; if
you believe one is wrong, verify it yourself and say so explicitly in the PR.**

1. **`dart:io` compiles fine under dart2js.** No conditional-import scaffolding
   is needed anywhere — including in D10's fence test, which uses
   `Directory('lib')` and runs on the VM only.
2. **Relay CORS**: `Access-Control-Allow-Headers: *` does not cover
   `Authorization`, so **cross-origin** dev breaks every avatar, inline image, and
   upload. Mitigated by serving same-origin; the Rust fix is a follow-up.
   **E1 and E2 must state this with the exact file reference.**

### Conventions the implementation must follow

From `CLAUDE.md` (§ Mobile App) and observed repo practice:

- **Never `StatefulWidget`.** Riverpod (v3) + `flutter_hooks`;
  `HookConsumerWidget` / `ConsumerWidget`. (No widgets in this part.)
- **No `print()`** — `debugPrint()` or structured logging.
- Prefer `context.colors` / `context.textTheme` over raw `Theme.of(context)`.
- `Grid` tokens for spacing, `Radii` for radii.
- **Features must not import other features** — only from `shared/`.
  `shared/storage/` is `shared/`, so anything may import it.
- One public widget per file; **1000-line ceiling on `lib/` files** (enforced by
  `mobile/scripts/check-file-sizes.mjs`; no overrides exist and **none may be
  added**). Every file in this part is small.
- Imports: **within `lib/`, use relative imports**; **in `test/`, use
  `package:buzz/...`**.
- `Provider` is imported from `package:hooks_riverpod/hooks_riverpod.dart`
  (see `community_provider.dart:1`).
- Repo convention: Riverpod providers for a primitive live in a sibling
  `*_provider.dart` file so the primitive itself stays framework-free (see
  `shared/community/community_provider.dart` next to `community_storage.dart`).
- Tests: prefer **widget tests** over unit tests for UI; inject fakes with
  `ProviderScope(overrides: [...])`; fake notifiers extend the real notifier and
  override `build()`; `WidgetHelpers.testable()` for simple cases.

## Technical Considerations

### Architecture

- **The storage platform decision is hoisted into its own named provider**,
  `keyValueStoreProvider`, which `communityStorageProvider` reads. That gives the
  tests a version-independent structural assertion
  (`isA<InMemoryKeyValueStore>()`) that does not depend on a plugin's method
  channel name, and it keeps `main.dart` untouched.
- **`InMemoryKeyValueStore` is production code** (it is the web store) and stays
  free of test-only affordances; the test double lives in
  `mobile/test/helpers/fake_key_value_store.dart`.
- **Three methods, named parameters, fail-closed.** Two positional `String`s
  would let a transposed `write(value, key)` compile silently across the 14
  rewritten call sites, defeating the compile-time-checked-refactor safety
  argument this slice rests on.

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
- The security assertion is **testable two ways, and this part requires both**:
  a **structural** assertion (`keyValueStoreProvider` resolves to
  `isA<InMemoryKeyValueStore>()` when `isWebProvider` is `true`) that survives a
  future Pigeon migration inside `flutter_secure_storage`, and a **behavioural**
  one (saving a community produces **zero** method calls on
  `plugins.it_nomads.com/flutter_secure_storage`, validated against a non-web
  control that produces ≥ 1).
- **The property is enforced as an invariant, not a one-time audit.** A ~15-line
  import-fence test (D10) asserts that `package:flutter_secure_storage` is
  imported by exactly one file in `mobile/lib` —
  `shared/storage/key_value_store.dart`. Verified today: it is imported by exactly
  one file (`shared/community/community_storage.dart:3`, which C2 moves), so the
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
  while pubkey-keyed activity metadata persists. **Say so in the README (E1).**

### Rejected alternative: `InMemorySecureStorage extends FlutterSecureStorage`

Technically feasible — `FlutterSecureStorage` is a plain (non-`final`,
non-`base`) class with a `const` constructor — and it would leave all five test
files untouched. **Rejected because it is fail-open on exactly the property this
part exists to guarantee.**

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

**Do not revisit this decision.** If a reviewer proposes the subclass, point at
this section.

### Mobile-regression safety (the non-negotiable)

Android/iOS ship today:

- The `KeyValueStore` migration is a **compile-time-checked** refactor: a missed
  call site fails `flutter analyze` loudly; it cannot silently change runtime
  behavior.
- `SecureKeyValueStore` wraps `const FlutterSecureStorage()` with the **same
  default options**, so the on-device keychain/keystore keys and payloads are
  byte-identical (`buzz_communities`, `buzz_active_community_id`, and all legacy
  migration keys are unchanged). **Do not change any storage key constant and do
  not touch the legacy-migration logic at :26-69.**
- `isWebProvider` returns `kIsWeb` → `false` on Android/iOS/VM tests, so
  `keyValueStoreProvider` resolves to `SecureKeyValueStore` exactly as today.
- No dependency, `pubspec`, `android/`, or `ios/` changes at all.
- The pre-existing test files are the regression gate. **None may be weakened,
  skipped, or deleted.** The only permitted edits are the mechanical
  `CommunityStorage(secure:)` → `CommunityStorage(store:)` migration
  (type names, constructor arguments, and import lines **only**) and purely
  additive new cases. **No assertion in the five migrated files may change** —
  with C5's `[]`/`[]=` operators in place that is achievable; verify it by
  reading the diff.

### What this phase does *not* prove

State this honestly in the PR body (E2). `flutter build web` succeeding proves
the reachable Dart graph compiles and every plugin's web registrant resolves — it
proves **nothing** about `dart:io` runtime safety (those symbols compile and then
throw). Not proven by any automation in this series: rendering fidelity and font
loading, mouse-wheel/trackpad scroll behavior, a live WebSocket + NIP-42 auth
handshake, same-origin image loading, real-window breakpoint feel, and the
usability of session-only sign-in.

**Also not proven: real user-agent behaviour.** The tests reach the android/iOS
branches only via `debugDefaultTargetPlatformOverride`; nothing here runs a real
browser, so the actual UA → `TargetPlatform` mapping is verified by reading the
SDK, not by execution. That is why the manual checklist requires an iOS Safari
and an Android Chrome pass.

## Acceptance Criteria

Every item is mechanically checkable. `<base>` below means
`feat/flutter-web-target-part-2` (this part's base branch); `<series-base>` means
`main` at `e4622671` (used only for the two whole-series checks that are marked
as such).

### Storage seam and its proofs

- [ ] With `isWebProvider` overridden to `true`, `keyValueStoreProvider` resolves
      to `isA<InMemoryKeyValueStore>()`; with `false`, to
      `isA<SecureKeyValueStore>()` (D7, structural half).
- [ ] With `isWebProvider` overridden to `true`, saving a `Community` with a
      non-null `nsec` produces **zero** calls on
      `plugins.it_nomads.com/flutter_secure_storage`, and the community still
      round-trips through the in-memory store within the same container (D7,
      behavioural half). The `isWeb: false` control produces ≥ 1 call **and**
      round-trips.
- [ ] `InMemoryKeyValueStore` round-trips write→read, returns `null` for an
      absent key, removes on `delete`, and **two instances do not share state**
      (D6 — guards against a static/module-level map).
- [ ] `SecureKeyValueStore` forwards named arguments correctly: write→read
      round-trips, absent key is `null`, `delete` removes (D9).
- [ ] The import-fence test passes: `package:flutter_secure_storage` is imported
      by exactly one file under `mobile/lib` —
      `mobile/lib/shared/storage/key_value_store.dart` (D10). Equivalently,
      `grep -rln "package:flutter_secure_storage" mobile/lib` returns exactly
      that one path.
- [ ] `KeyValueStore` declares **exactly three** methods (`read`, `write`,
      `delete`), all with named parameters.
- [ ] `CommunityStorage` has a single `KeyValueStore? store` constructor
      parameter; `grep -n "secure" mobile/lib/shared/community/community_storage.dart`
      returns nothing.
- [ ] `mobile/lib/main.dart` is unmodified.
- [ ] All storage key constants (:11-17) and the legacy-migration logic (:26-69)
      in `community_storage.dart` are unchanged — the diff there touches only the
      import, the field type, the constructor, and the 14 receiver names.
- [ ] The five migrated test files contain **no changed assertion**: the diff
      shows only type names, constructor arguments, and import lines. The 17
      `[]`/`[]=` sites in `community_storage_test.dart` compile **unchanged**.

### Whole-phase gates (this part is the final one, so it asserts the end state)

- [ ] `cd mobile && flutter analyze` reports **zero errors** (no new warnings or
      infos either).
- [ ] The **full** mobile test suite passes via the `very_good_cli` MCP `test`
      tool (`directory: mobile`) — every pre-existing test plus every test added
      by Parts 2 and 3. No test is weakened, skipped, or deleted.
- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && node ./scripts/check-file-sizes.mjs` exits 0; every touched
      `lib/` file is < 1000 lines and **no override entry is added** to that
      script.
- [ ] `cd mobile && flutter build web --release` exits 0 and produces
      `mobile/build/web/flutter_bootstrap.js` and `mobile/build/web/main.dart.js`;
      `just mobile-build-web` runs it. `just check` (:94) and `just ci` (:258)
      are **unmodified**.
- [ ] `grep -rn "kIsWeb" mobile/lib` returns **exactly one** hit:
      `mobile/lib/shared/platform/is_web.dart`.
- [ ] `grep -rn "defaultTargetPlatform" mobile/lib` shows **no newly added uses**
      versus `<series-base>`; the pre-existing ones remain, now paired with a
      web-seam check wherever they guard a MethodChannel.
- [ ] `git diff --name-only <base>...HEAD -- mobile/lib` returns **exactly these
      four paths**: `mobile/lib/shared/storage/key_value_store.dart`,
      `mobile/lib/shared/storage/key_value_store_provider.dart`,
      `mobile/lib/shared/community/community_storage.dart`,
      `mobile/lib/shared/community/community_provider.dart`.
- [ ] `git diff --name-only <base>...HEAD -- mobile/lib/app.dart mobile/lib/features mobile/lib/shared/relay mobile/lib/shared/platform mobile/lib/main.dart justfile mobile/web mobile/.metadata`
      is **empty** (Parts 1 and 2 own those).
- [ ] `git diff --stat <series-base>...HEAD -- mobile/pubspec.yaml mobile/pubspec.lock 'mobile/android/**' 'mobile/ios/**' ':(top).github/**' ':(top)crates/**' ':(top)desktop/**' ':(top)web/**' .env.example`
      is **empty** (whole-series check). Note the `:(top)` prefixes: a bare
      `web/**` pathspec would match `mobile/web/**` and make this check
      meaningless.
- [ ] `mobile/README.md` has a `## Web (experimental)` section between `## Run`
      and `## Checks` containing: the `just mobile-build-web` command, the
      same-origin serve command, the cross-origin CORS caveat with the exact
      relay file reference, the list of capabilities disabled on web, the
      session-only-vs-`shared_preferences` split sentence, and the
      UA-derived-`defaultTargetPlatform` note.
- [ ] The PR body contains the
      [manual verification checklist](#manual-verification-checklist-for-the-pr-body),
      the same-origin run command, the cross-origin CORS caveat, an explicit
      statement of what the automated gates do and do not prove, and the
      follow-ups list.

## Implementation Tasks

Ordered. C5 must land **with** C6, not after it, or the migrated tests will not
compile. Run D11 last.

### Slice C — session-only key-value store on web

- [ ] **C1.** Create `mobile/lib/shared/storage/key_value_store.dart` (a **new
      `shared/storage/` folder** — this is a generic storage primitive, not a
      community concern, and its likely next consumers are the six
      `shared_preferences`-backed storages under `features/channels/`) with three
      public classes. **All three methods take named parameters** — two positional
      `String`s would let a transposed `write(value, key)` compile silently across
      the 14 rewritten call sites, defeating the compile-time-checked-refactor
      safety argument this slice rests on. It also means the
      `community_storage.dart` bodies change only in the receiver name:

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
        :36-37, :42-46, :60-63, :89, :93, :97, :109 (**14 calls**).
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
        **:10 `late FakeSecureStorage fakeSecure;`**, **:15
        `fakeSecure = FakeSecureStorage();`**, :16 constructor.
      - `mobile/test/shared/auth/auth_provider_test.dart` — :9 import, :15, :37.
      - `mobile/test/features/invites/invite_join_provider_test.dart` — :13
        import, :25, :83, :145, :190.
      - `mobile/test/features/channels/deep_link_dispatcher_test.dart` — :15
        import, :131. **Leave the `communityStorageProvider.overrideWithValue(...)`
        at :64 alone.**

      Before deleting each `community_storage_test.dart` import, confirm the file
      uses no other symbol from it. **No assertion in these files may change** —
      with C5 in place that is achievable; verify by diffing that only type names,
      constructor arguments, and import lines moved.

### Slice D (this part's share) — storage tests + the final gate

See [Test Plan](#test-plan) for the full case list.

- [ ] **D6.** New `mobile/test/shared/storage/key_value_store_test.dart`.
- [ ] **D7.** New `mobile/test/shared/community/community_storage_web_test.dart`.
- [ ] **D9.** New `mobile/test/shared/storage/secure_key_value_store_test.dart`.
- [ ] **D10.** New `mobile/test/shared/storage/storage_import_fence_test.dart`.
- [ ] **D11.** Run the full suite with the `very_good_cli` MCP `test` tool
      (`directory: mobile`), `flutter analyze`, `dart format`,
      `node ./scripts/check-file-sizes.mjs`, and `just mobile-build-web`. All
      green. This is the whole-stack gate, not just this part's.

### Slice E — documentation

- [ ] **E1.** Add a `## Web (experimental)` section to `mobile/README.md`
      (after `## Run` at :12, immediately before `## Checks` at :22) covering:
      the build command (`just mobile-build-web`), the **same-origin** serve
      command, the cross-origin CORS caveat with the exact relay file reference,
      and the list of capabilities disabled on web (app badge, **all media upload
      from the compose bar**, QR scan, `buzz://` deep links). Include one sentence
      making the storage split explicit: **"session-only" means sign-in material
      (the `nsec`) is never persisted and must be re-entered after a reload, while
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
      gates do and do not prove, and the follow-ups list (relay CORS fix; CI
      wiring of the web build; `desktop_drop` web drag-drop backend; NIP-07
      signer; Phase 1 visual QA).

### Verification (run before opening the PR)

- [ ] Full suite via the `very_good_cli` MCP `test` tool (`directory: mobile`).
- [ ] `cd mobile && flutter analyze`, `dart format --output=none
      --set-exit-if-changed .`, `node ./scripts/check-file-sizes.mjs`.
- [ ] `just mobile-build-web` exits 0.
- [ ] Every check in [Acceptance Criteria](#acceptance-criteria).

## Test Plan

All tests run on the VM, where `kIsWeb` is `false`; the web branches are reached
**only** by overriding `isWebProvider`.

| # | File | Cases |
|---|---|---|
| D6 | `mobile/test/shared/storage/key_value_store_test.dart` (new) | `InMemoryKeyValueStore`: write→read round-trips; `read` of an absent key is `null`; `delete` removes; two instances do not share state (guards against a static map). |
| D7 | `mobile/test/shared/community/community_storage_web_test.dart` (new) | **Structural half (version-independent):** `ProviderContainer(overrides: [isWebProvider.overrideWithValue(true)])` → `container.read(keyValueStoreProvider)` is `isA<InMemoryKeyValueStore>()`; with `false` → `isA<SecureKeyValueStore>()`. **Behavioural half:** install a **stateful** mock handler on `const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')` that backs `read`/`write`/`delete`/`containsKey` with a real `Map` and counts calls (a recording-only handler that returns `null` makes `loadAll()` return `[]`, so the round-trip half of the control could never pass). Then `read(communityStorageProvider)`, `save(...)` a `Community` with a non-null `nsec`, `loadAll()`. **(a)** `isWeb: false` → ≥ 1 recorded call **and** the community round-trips (control — if this fails, the channel name is wrong; fix it to whatever the control observes). **(b)** `isWeb: true` → **zero** recorded calls, and the community still round-trips through the in-memory store within the same container. `addTearDown(container.dispose)` and clear the mock handler in `tearDown`. |
| D9 | `mobile/test/shared/storage/secure_key_value_store_test.dart` (new, ~20 lines) | After the refactor this is the **only** untested link between the app and Keychain/Keystore. Using the same stateful mock-channel scaffolding as D7 (extract it into the helper file or duplicate the ~15 lines), assert `SecureKeyValueStore` round-trips `write` → `read`, that `read` of an absent key is `null`, and that `delete` removes — i.e. that the wrapper forwards named arguments correctly. Catches a transposed or dropped argument that the type system cannot. |
| D10 | `mobile/test/shared/storage/storage_import_fence_test.dart` (new, ~15 lines) | Walk `Directory('lib')` recursively (`dart:io` is fine on the VM), read every `.dart` file, and collect those whose source contains `package:flutter_secure_storage`. Assert the result is exactly `['lib/shared/storage/key_value_store.dart']`. Turns the security property into a standing invariant instead of a point-in-time audit: a future contributor who reaches for `FlutterSecureStorage` elsewhere breaks the build rather than silently re-persisting to `localStorage` on web. Normalise path separators so the assertion is not host-dependent. |

**Not in this part** (landed in Part 2): D1 `app_badge_gate_test.dart`, D2
compose-bar web gates, D3 pairing-page web cases, D4 media-upload fail-fast
cases, D5 `media_upload_provider_test.dart`, D8 the `DesktopShell` web case. They
must all still pass.

**Existing-suite requirement:** every pre-existing test file still passes. The
only edits permitted in this part are the C6 migration (type names, constructor
arguments, and import lines **only** — see C5/C6) and the additive new files
above. **No assertion in the five migrated files may change.**

### Manual verification checklist (for the PR body)

Only a human with a browser can close these. This is the checklist for the
**whole phase**, since this is the final part.

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
- [ ] With DevTools → Application → Local Storage open, confirm there is **no**
      `FlutterSecureStorage` key and no ciphertext blob after pairing.
- [ ] Mouse-wheel and trackpad scrolling in the message timeline behave sanely.

**Known caveat to state in the PR:** serving the web build **cross-origin** from
the relay will show broken images and failed uploads until the relay names
`Authorization` in `Access-Control-Allow-Headers`
(`crates/buzz-relay/src/router.rs:397-421`; the fix is `AUTHORIZATION` in
`allow_headers` or `AllowHeaders::mirror_request()`). That is a pre-existing
relay bug that also affects the shipped React client's `just web` dev mode, and
it is deliberately not fixed here.

## Success Metrics

- The Nostr `nsec` provably never reaches browser storage — asserted **two
  independent ways** (structural provider assertion + zero secure-storage channel
  traffic), each paired with a non-web control so neither can pass vacuously.
- The property is an **invariant**: the import fence fails the build if anyone
  reaches for `FlutterSecureStorage` outside `shared/storage/key_value_store.dart`.
- The migration deletes ~85 lines of `FlutterSecureStorage` boilerplate from the
  test suite and lets the tests exercise the real web store.
- Zero change to the Android/iOS runtime: no dependency, pubspec, `android/`, or
  `ios/` diff; identical keychain keys and payloads; a fully green pre-existing
  test suite with no changed assertions.
- End of phase: `flutter build web --release` green, `flutter analyze` clean, the
  full suite green, and a README that tells the next person how to run it and
  what is disabled.

## Risks & Mitigations

1. **The `KeyValueStore` migration touches 5 test files / 14 call sites.**
   *Mitigation:* purely mechanical and analyzer-enforced; C5's `[]`/`[]=`
   operators keep the 17 highest-consequence assertion sites compiling
   unchanged. If `flutter analyze` is green and the suite passes with no changed
   assertion, the migration is complete by construction.
2. **The secure-storage channel name may differ under the installed plugin
   version**, making the D7 assertion vacuous. *Mitigation:* D7 includes a
   non-web control case that must record ≥ 1 call **and** round-trip; a vacuous
   assertion fails the control first. If the control fails, fix the channel name
   to whatever the control observes — do not weaken the assertion.
3. **A recording-only mock handler makes the control unpassable.** Returning
   `null` from the mock makes `loadAll()` return `[]`, so the round-trip half
   could never pass. *Mitigation:* D7 and D9 specify a **stateful** handler
   backed by a real `Map`. This is a known trap; do not simplify it away.
4. **Someone "helpfully" adds `containsKey`/`readAll` to `KeyValueStore` later**,
   re-opening the fail-open hole the interface was designed to close.
   *Mitigation:* the interface is documented as deliberately three methods, and
   [Rejected alternative](#rejected-alternative-inmemorysecurestorage-extends-fluttersecurestorage)
   explains the failure mode. The import fence does not catch this — a human
   reviewer must.
5. **`shared_preferences` still persists to `localStorage` on web**, so
   "session-only" is a narrower claim than it sounds. *Mitigation:* stated
   explicitly in the README (E1), in the PR body (E2), and in the manual
   checklist. No key material is stored there — audited.
6. **The web target has no CI protection**, so a later mobile change can silently
   break it. *Mitigation:* accepted and documented; `just mobile-build-web` makes
   local checking one command. CI wiring requires a human edit to
   `.github/workflows/ci.yml` (guardrail-blocked).
7. **Same-origin serving is a documentation-only mitigation for the CORS gap.**
   *Mitigation:* stated prominently in `mobile/README.md` (E1) and the PR body
   (E2), with the exact file/line and fix for the follow-up.
8. **`flutter build web` succeeds but the app misbehaves on first paint.** The
   build gate cannot catch runtime platform errors. *Mitigation:* the residual
   risk is handed to the manual checklist, which now requires a mobile-browser UA
   pass and a DevTools `localStorage` inspection.

## Auto-resolved assumptions

This part plan was produced non-interactively by splitting
`docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`. Wherever the
splitting or planning skill would have asked a human, the most YAGNI-aligned
default was taken and recorded here.

1. **The split shape was approved upstream and is implemented as given**: three
   parts, linear dependency chain, stacked PRs. Part 3 = C1–C6, D6, D7, D9, D10,
   D11, E1, E2. It was not re-derived.
2. **The security-relevant storage change gets its own PR.** That is the whole
   reason this part exists separately: buried among widget-visibility diffs it
   would receive scanning review; alone, with the
   [Security](#security) and
   [Rejected alternative](#rejected-alternative-inmemorysecurestorage-extends-fluttersecurestorage)
   sections in front of the reviewer, it gets focused review.
3. **Slice D is split along the same seam as the production code.** D6/D7/D9/D10
   exercise the storage seam and ship with it; D1–D5 and D8 shipped with the
   gates in Part 2. No PR in the series leaves its own production change
   unverified.
4. **D11 (the final full-suite/analyze/format/file-size/build gate) lives here**
   and is scoped to the *whole stack*, not just this part — this is the last PR,
   so it is the right place to assert the end state. Parts 1 and 2 each ran an
   equivalent per-part block.
5. **Both slice-E documentation tasks land here rather than being spread across
   the stack.** A README describing a web build whose gates or key custody do not
   exist yet would be actively misleading for the lifetime of two PRs. Parts 1
   and 2 each carry only a scope-limited "what this does not prove" statement in
   their PR bodies.
6. **The manual verification checklist is the whole phase's**, not just this
   part's, for the same reason: most of its items only become checkable once all
   three parts are on the branch. One extra item was added beyond the parent
   plan's list — a DevTools `localStorage` inspection — because it is the direct
   human analogue of D7's behavioural assertion and costs nothing.
7. **The `defaultTargetPlatform` correction section is copied in**, even though
   this part adds no gate, because E1 is required to document it and because it
   explains why `flutter_test` runs the android branch (context for D7's control).
8. **Inherited unchanged from the parent plan** (not re-decided here): the storage
   gate lives *inside* `communityStorageProvider`/`keyValueStoreProvider` rather
   than as a root `ProviderScope` override, keeping `main.dart` untouched (#3); a
   single `store:` constructor parameter with the five test files migrated,
   rather than a dual-path `secure:`/`store:` constructor (#4); the `[]`/`[]=`
   seeding operators live on the test double, not on production
   `InMemoryKeyValueStore` (#18); `key_value_store.dart` lives in a new
   `shared/storage/` folder rather than in `shared/community/` (#19); the README
   gets a Web section in addition to the PR-body checklist (#12); brainstorm open
   questions 1–4 keep their defaults — relay CORS fix not in this PR, no
   "session only" UI banner, session-only store rather than NIP-07, `mobile/` not
   renamed (#14); and the named parameters on `KeyValueStore`, the stateful mock
   channel handler for D7's control, the `SecureKeyValueStore` channel test (D9),
   and the `:(top)` pathspec fix (#22).

## References & Research

- **Parent plan (canonical rationale):**
  `docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`.
- **Sibling parts:** Part 1 —
  `docs/plan/2026-07-27-feat-flutter-web-target-part-1-plan.md` (web runner +
  seam, landed); Part 2 —
  `docs/plan/2026-07-27-feat-flutter-web-target-part-2-plan.md` (runtime gates,
  landed).
- Brainstorm: `docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md`
  (§4 secure storage, §5 relay connectivity).
- Source plan: `mobile/DESKTOP_PORT_PLAN.md` §9 Phase 0, §5, §10.1.
- **Plugin extensibility check:**
  `flutter_secure_storage-10.3.0/lib/flutter_secure_storage.dart:22` — plain
  `class` with a `const` constructor and 7 `Future`-returning members, of which
  `CommunityStorage` uses 3.
- **Browser-client key-custody precedent:** `web/src/shared/lib/nostr-signer.ts`;
  same-origin URL helper `web/src/shared/lib/relay-url.ts:12-24`.
- UA-derived platform:
  `$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`
  (`_browserPlatform` ← `ui_web.browser.operatingSystem`; `unknown => android`).
- Relay same-origin serving: `crates/buzz-relay/src/router.rs:145-186`
  (`BUZZ_WEB_DIR`); CORS gap at `crates/buzz-relay/src/router.rs:397-421`.
- Relay URL plumbing for `--dart-define`:
  `mobile/lib/shared/relay/relay_provider.dart:35-38` (`Env.relayUrl`) and
  `:22-27` (`RelayConfig.wsUrl` derives `wss` from `https`).
- Conventions: `CLAUDE.md` § Mobile App (Flutter), § Quality Gates;
  `mobile/scripts/check-file-sizes.mjs`.
