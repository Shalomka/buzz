---
title: 'feat: Flutter web target (Phase 0) — Part 1: web runner scaffold, build recipe & platform seam'
type: feat
date: 2026-07-27
part: 1 of 3
status: ready-for-build
branch: feat/flutter-web-target-part-1
base-branch: main
base-commit: e4622671
pr-target: main
depends-on: none
parent-plan: docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md
brainstorm: docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§9 Phase 0 — retargeted to web only)
predecessor: docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md (Phase 1, landed)
---

# feat: Flutter web target (Phase 0) — Part 1 of 3: web runner scaffold, build recipe & platform seam

> **Standalone build input.** This file is the complete specification for
> Part 1 — the build stage receives only this file and **does not re-review the
> codebase**. Everything under [Codebase Context](#codebase-context-verified)
> was verified in this repo and is to be trusted. Task IDs (A1–A7, B1, B7) are
> global across the three-part series and match
> `docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`, which remains
> the canonical rationale document. Any task ID not listed here belongs to
> Part 2 or Part 3 — context only, **never scope for this build**.

## Overview

Add a **web platform target** to the existing `mobile/` Flutter app, strictly
additively, so the already-landed Phase 1 desktop shell (`DesktopShell`,
`breakpoints.dart`, `shell_state_provider.dart`) has a runtime where width ≥ 840
is reachable. The "desktop" surface for this phase is a **Flutter web build
viewed in a browser window at desktop width** — macOS/Windows/Linux are out of
scope.

**Part 1 (this plan) makes `flutter build web` compile, and nothing else:**

- **A1–A3, A6–A7** — a hand-authored `mobile/web/` runner directory
  (`index.html`, `manifest.json`, `favicon.png`, four icons) plus the matching
  `mobile/.metadata` platform entry. `flutter create` is blocked by a hook, so
  this is authored by hand against the Flutter 3.44.4 SDK template.
- **A4** — a `just mobile-build-web` recipe.
- **A5** — the first green `flutter build web --release`.
- **B1** — the single web-platform seam file
  `mobile/lib/shared/platform/is_web.dart` (`isWebProvider`), so Part 2's gates
  are testable.
- **B7 (scoped)** — `flutter analyze` clean for this slice.

**There is no behavioral change in this part.** Exactly one file under
`mobile/lib` is added (`is_web.dart`); no existing `lib/` file is edited, and
**no test file is added or edited at all**. Part 2 adds the five runtime gates
that consume `isWebProvider`; Part 3 adds the session-only storage seam and the
docs.

## Problem Statement / Motivation

Phase 1 landed a responsive multi-pane parity shell on `main`, but it is
**dormant**: `mobile/` targets `android` + `ios` only, so no runtime exists where
the desktop layout is reachable. `flutter build web` currently fails with
`This project is not configured for the web`.

`WebProject.existsSync()` in the Flutter tool requires exactly `web/` **and**
`web/index.html` to exist. Creating that directory is therefore the single
unblocking change, and it is worth landing on its own: it is a pure scaffold with
no `lib/` behavior change, it is reviewable in one pass, and it makes the "does
the whole reachable Dart graph compile under dart2js?" question — a previously
untested property of ~35.6k LOC across 172 lib files — answerable by one command.

## Proposed Solution

**Minimal additive web target** (Approach A in the brainstorm; B and C were
rejected there with evidence — do not revisit).

- Reproduce the Flutter 3.44.4 SDK web runner template by hand at `mobile/web/`.
- Introduce exactly one seam, `isWebProvider`, and nothing that reads it yet.
  `kIsWeb` is a compile-time constant, so a widget test on the VM can never
  exercise a web branch — wrapping it in a `Provider<bool>` is what makes Part
  2's gates provable.
- Add `just mobile-build-web`. Do **not** wire it into `just ci` or `just check`.

## Scope

### In scope for Part 1

- `mobile/web/index.html`, `mobile/web/manifest.json`, `mobile/web/favicon.png`,
  `mobile/web/icons/{Icon-192,Icon-512,Icon-maskable-192,Icon-maskable-512}.png`.
- `mobile/.metadata` — one `web` entry in `migration.platforms`.
- `justfile` — one new recipe (`mobile-build-web`), placed immediately after
  `mobile-build-android`.
- `mobile/lib/shared/platform/is_web.dart` — new, ~10 lines.

### Out of scope for Part 1 — do not implement

- **Any runtime gate.** The badge gate, attach-affordance gate, media-upload
  fail-fast, QR-scan gate, and clipboard-probe gate are **Part 2**. Do not touch
  `mobile/lib/app.dart`, `mobile/lib/features/channels/compose_bar.dart`,
  `mobile/lib/shared/relay/media_upload.dart`, or
  `mobile/lib/features/pairing/pairing_page.dart` in this part.
- **The storage seam.** `mobile/lib/shared/storage/`, `CommunityStorage`
  rewiring, and the test-helper migration are **Part 3**.
- **Any test file.** Part 1 adds and edits zero files under `mobile/test/`. The
  60 existing test files must pass **unmodified** — that is this part's
  regression gate.
- `mobile/README.md` — the "Web (experimental)" section is **Part 3** (E1).
- Native desktop platform folders (`mobile/macos`, `mobile/windows`,
  `mobile/linux`).
- **Any dependency change**: no additions, removals, or version bumps.
  `mobile/pubspec.yaml` and `mobile/pubspec.lock` must be byte-identical at the
  end. Specifically **no** `file_selector`, `media_kit`, `desktop_drop`,
  `window_manager`, `super_clipboard`, or an `app_badge_plus` replacement.
- The relay CORS fix (`crates/buzz-relay/src/router.rs:397-421`) — Rust, filed
  as a follow-up.
- `.github/workflows/` changes (guardrail-blocked).
- Any `.gitignore` edit.
- Any change to secrets, feature flags, CI, or deploy/infra manifests.

## Dependencies

**Builds on:** nothing in this series. Part 1 is the base of the stack.

**Base branch:** `main` at run-start commit `e4622671`
("feat: Implement Part 4 of Flutter desktop parity shell — Sheets & input
layer"). **Working branch:** `feat/flutter-web-target-part-1`. **The PR targets
`main`.**

**Inherited from `main` (exists on the base branch — do not recreate):**

- Phase 1 parity shell: `mobile/lib/features/home/desktop_shell.dart`,
  `mobile/lib/shared/layout/breakpoints.dart`,
  `mobile/lib/shared/shell/shell_state_provider.dart`,
  `mobile/lib/shared/widgets/adaptive_modal.dart`,
  `mobile/lib/features/channels/attachment_drop_region.dart` (PRs #1–#4).
  Part 1 does not touch any of them; they are the reason a web runtime is worth
  having.
- 60 green `*_test.dart` files under `mobile/test`.
- `mobile/.gitignore` already ignores `/build/`, so `mobile/build/web/` is
  ignored — **no `.gitignore` change is needed or permitted**.

**Consumed by later parts — do NOT remove or "clean up" this seam:**

- `mobile/lib/shared/platform/is_web.dart` → `isWebProvider`. In Part 1 nothing
  reads it. **This is expected and is not dead code to be deleted.** Part 2's
  five gates and Part 3's `keyValueStoreProvider` all read it. `isWebProvider` is
  a public top-level declaration, so `flutter analyze` will not flag it as
  unused.

**Toolchain:** Flutter 3.44.4 stable must be the active SDK (the runner
directory is authored against that version's template) and `sips` must be
available (macOS) for A3.

**Not blocked by, and does not block:** the relay CORS follow-up, CI wiring of
the web build, `desktop_drop`, NIP-07. All are explicitly deferred.

## Branch / PR topology (three-part stack)

| Part | Branch | Base | PR targets |
|---|---|---|---|
| **1 (this)** | `feat/flutter-web-target-part-1` | `main` @ `e4622671` | `main` |
| 2 | `feat/flutter-web-target-part-2` | `feat/flutter-web-target-part-1` @ its merged head SHA | `feat/flutter-web-target-part-1` |
| 3 | `feat/flutter-web-target-part-3` | `feat/flutter-web-target-part-2` @ its head SHA | `feat/flutter-web-target-part-2` |

**Terminal state for this part is an unmerged PR against `main`.** Do not merge,
do not deploy, do not start Part 2 from this worktree.

## Codebase Context (verified)

Everything in this section was verified in this repo. **The build stage should
trust this section and not re-review the codebase.**

### Environment and tooling facts

| Fact | Value |
|---|---|
| Flutter / Dart | 3.44.4 stable / Dart 3.12.2 |
| `FLUTTER_ROOT` | `/Users/robertasskiauteris/development/flutter` (derive with `dirname $(dirname $(readlink -f $(which flutter)))`) |
| Flutter 3.44.4 SDK revision | `ad70ec4617166f1c38e5d2bfd388af71fda14f06` (from `git -C $FLUTTER_ROOT rev-parse HEAD`) |
| SDK web template | `$FLUTTER_ROOT/packages/flutter_tools/templates/app/web/` → `index.html.tmpl`, `manifest.json.tmpl`, `favicon.png.copy.tmpl`, `icons/` |
| Web enablement | `flutter config` already reports `enable-web: true` — **no config change needed** |
| Web-project gate | `WebProject.existsSync()` requires exactly `web/` **and** `web/index.html` (`flutter_tools/lib/src/project.dart:1132-1133`) |
| `mobile/web/` today | **does not exist**; `git check-ignore mobile/web/index.html` → not ignored, so it is committable |
| Build output | `mobile/.gitignore` already ignores `/build/`, so `mobile/build/web/` is ignored — **no .gitignore change needed** |
| Icon source | `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` (1024², exists). `assets/images/buzz-icon.png` is 294×197 — **not** usable |
| `sips` | available at `/usr/bin/sips` |
| File-size guard | `mobile/scripts/check-file-sizes.mjs` — 1000 lines, **`lib/` only**, no overrides. `test/` is not scanned |
| Baseline | `flutter analyze` → **No errors**; 60 `*_test.dart` files all pass |

**Hook/permission constraints for the build stage (hard constraints):**

- `flutter create` / `dart create` → **BLOCKED** by a PreToolUse hook.
  `mobile/web/` is hand-authored. Do not try to work around the hook.
- `flutter test` / `dart test` in Bash → **BLOCKED**. Use the `very_good_cli`
  MCP `test` tool (`directory: mobile`).
- `flutter build web` → **PERMITTED** for this run (a scoped human exception to
  CLAUDE.md's "never run `flutter build`").
- `flutter run` / `flutter clean` / `flutter upgrade` → still **forbidden**.
- `flutter analyze` and `dart format` → permitted.
- Writes to secrets, feature flags, `.github/workflows/`, and deploy/infra
  manifests are **hard-blocked by a guardrail hook**. Do not attempt them.

### Files this part touches (verified line references)

| File | Lines today | Current state |
|---|---|---|
| `mobile/web/**` | — | **Does not exist.** Created wholesale by A1–A3. |
| `mobile/.metadata` | 33 | Tracked. `version.revision: "db50e20168db8fee486b9abf32fc912de3bc5b6a"`, `project_type: app`, `migration.platforms` lists exactly `root`, `android`, `ios`, all at revision `db50e20168db8fee486b9abf32fc912de3bc5b6a`. A trailing `# User provided section` with `unmanaged_files: ['lib/main.dart', 'ios/Runner.xcodeproj/project.pbxproj']` follows the platform list — **insert the new entry before that comment block, at the end of `platforms`.** |
| `justfile` | — | `mobile_dir := "mobile"` at :566; `mobile-build-android` at :589-590 (`unset GIT_DIR GIT_WORK_TREE; cd {{mobile_dir}} && flutter build apk --debug --no-pub`); `check:` at :94; `ci:` at :258. `mobile-check` at :581-582 runs `dart format --output=none --set-exit-if-changed . && flutter analyze && node ./scripts/check-file-sizes.mjs` |
| `mobile/lib/shared/platform/` | — | **Does not exist.** Created by B1. Sibling single-file folders `shared/layout/` and `shared/shell/` show the no-barrel-file pattern to follow |
| `mobile/pubspec.yaml` | — | `description:` on :2 is `Buzz mobile client` — the string A1/A2 substitute for `{{description}}` |
| `mobile/lib/shared/theme/color_scheme.dart` | — | `:8` app primary `#8839EF` (Catppuccin Latte Mauve); `:9` base `#EFF1F5` (Latte Base) — the two `manifest.json` colours |

### Why the seam exists (context for B1)

`kIsWeb` is a `const bool`. Under `flutter test` on the VM it is `false` and
dart2js-style tree shaking is not involved, so **a widget test can never take a
`if (kIsWeb)` branch** — the branch is provably dead in the test binary. Part 2's
deliverable is *proving the gates fire*, which requires an overridable seam.
Hence one `Provider<bool>` returning `kIsWeb`, read by every gate, overridden to
`true` in tests.

This also drives a standing rule enforced by an acceptance check in all three
parts: **`kIsWeb` may appear in exactly one file under `mobile/lib`** —
`shared/platform/is_web.dart`. Anything else re-introduces an untestable branch.

### One correction carried from the parent plan

`defaultTargetPlatform` on Flutter web is **derived from the browser user
agent** (`$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`),
not fixed to a desktop value; an unrecognised UA falls back to
`TargetPlatform.android`. This is the single most important fact in the parent
plan, but it bears on **Part 2's gates**, not on Part 1 — it is noted here only
so the build agent does not "helpfully" add `defaultTargetPlatform` logic to the
seam. **`is_web.dart` must contain `kIsWeb` and nothing else.** No
`defaultTargetPlatform`, no capability enums, no barrel file.

### Findings that override the source plan (relevant to Part 1)

These were verified empirically in the brainstorm. **Do not re-litigate them; if
you believe one is wrong, verify it yourself and say so explicitly in the PR.**

1. **`dart:io` compiles fine under dart2js** (mapped via `_dart2js_common` →
   `io_patch.dart`). No conditional-import (`_stub`/`_io`/`_web`) scaffolding is
   needed anywhere. The three `mobile/lib` files that import `dart:io`
   (`channels_page.dart`, `media_upload.dart`, `mp4_fast_start.dart`) stay
   exactly as they are. In particular **do not remove `channels_page.dart:2`** —
   `SocketException` is used by `channels_page/badges.dart:138` and removing it
   changes mobile error copy. If A5's build surfaces a `dart:io` error, report
   it; do not start adding conditional imports.
2. **`image_picker` and `video_player` keep their endorsed web
   implementations.** The source plan's `file_selector` / `media_kit` swaps are
   native-desktop remedies with no web justification. **Do not perform them.**
3. **`app_badge_plus` is the only dependency with no web implementation.** It is
   a *runtime* `MissingPluginException`, not a build failure, so it will **not**
   break A5's build — its gate is Part 2's B2.

### Conventions the implementation must follow

From `CLAUDE.md` (§ Mobile App) and observed repo practice:

- **Never `StatefulWidget`.** Riverpod (v3) + `flutter_hooks`;
  `HookConsumerWidget` / `ConsumerWidget`.
- **No `print()`** — `debugPrint()` or structured logging.
- Prefer `context.colors` / `context.textTheme` over raw `Theme.of(context)`.
- `Grid` tokens for spacing, `Radii` for radii.
- **Features must not import other features** — only from `shared/`.
  `shared/platform/` is `shared/`, so every future gate may import it.
- One public widget per file; **1000-line ceiling on `lib/` files** (enforced by
  `mobile/scripts/check-file-sizes.mjs`; no overrides exist and **none may be
  added**).
- Imports: **within `lib/`, use relative imports**; **in `test/`, use
  `package:buzz/...`**.
- `Provider` is imported from `package:hooks_riverpod/hooks_riverpod.dart`
  (see `mobile/lib/shared/community/community_provider.dart:1`).
- Tests: prefer **widget tests** over unit tests for UI; inject fakes with
  `ProviderScope(overrides: [...])`. (Not exercised in Part 1 — no test changes.)

## Technical Considerations

### Architecture

- **One seam, not an abstraction layer.** `isWebProvider` is a single
  `Provider<bool>` returning `kIsWeb`. A "platform capabilities" abstraction for
  a handful of gates would be over-engineering. Resist adding
  `PlatformCapabilities`, an enum, or a barrel file.
- **The runner directory is a template reproduction, not a design.** Every
  deviation from the SDK template must be one of the three deliberate ones listed
  in A2. A hand-written `flutter_bootstrap.js`, a `serviceWorkerVersion`
  variable, or a `_flutter.loader.loadEntrypoint` call are all pre-3.22 patterns
  that Flutter 3.44 generates for you — writing them by hand is the single most
  likely way to break this file across SDK upgrades.

### Mobile-regression safety (the non-negotiable)

Android/iOS ship today. Part 1 is designed to be provably inert on them:

- The only `lib/` addition is an unreferenced provider.
- No dependency, `pubspec`, `android/`, or `ios/` changes at all.
- Adding `mobile/web/` does not change the Android or iOS build inputs.
- The 60 existing test files are the regression gate. **None may be weakened,
  skipped, edited, or deleted in this part.** Part 1's expected `mobile/test`
  diff is **empty**.

### What this part does *not* prove

State this honestly in the PR body. `flutter build web` succeeding proves the
reachable Dart graph compiles and every plugin's web registrant resolves — it
proves **nothing** about `dart:io` runtime safety (those symbols compile and then
throw), and **nothing** about the five web-hostile call sites, which are still
ungated until Part 2 lands. A browser opened against this part's build **will**
throw `MissingPluginException` on the app badge and on media upload. That is
expected and is exactly what Part 2 fixes.

Also not proven here: rendering fidelity, font loading, scroll behaviour, a live
WebSocket + NIP-42 handshake, same-origin image loading, or real-window
breakpoint feel. The full manual browser checklist lands with **Part 3**.

## Acceptance Criteria

Every item is mechanically checkable. `<base>` below means the merge-base with
`main` (`e4622671`).

- [ ] `cd mobile && flutter build web --release` exits 0 and produces
      `mobile/build/web/flutter_bootstrap.js` and `mobile/build/web/main.dart.js`.
- [ ] `just mobile-build-web` exists in `justfile`, sits immediately after
      `mobile-build-android` (:589-590), and runs that build. `just check` (:94)
      and `just ci` (:258) are **unmodified**.
- [ ] `cd mobile && flutter analyze` reports **zero errors** (no new warnings or
      infos either).
- [ ] The full mobile test suite passes via the `very_good_cli` MCP `test` tool
      (`directory: mobile`), with **all 60 test files unmodified**.
      `git diff --name-only <base>...HEAD -- mobile/test` is **empty**.
- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && node ./scripts/check-file-sizes.mjs` exits 0, and **no
      override entry is added** to that script.
- [ ] `git diff --name-only <base>...HEAD -- mobile/lib` returns **exactly one
      path**: `mobile/lib/shared/platform/is_web.dart`.
- [ ] `git diff --stat <base>...HEAD -- mobile/pubspec.yaml mobile/pubspec.lock 'mobile/android/**' 'mobile/ios/**' ':(top).github/**' ':(top)crates/**' ':(top)desktop/**' ':(top)web/**' .env.example`
      is **empty**. Note the `:(top)` prefixes: a bare `web/**` pathspec would
      match the newly added `mobile/web/**` and make this check meaningless.
- [ ] `grep -rn "kIsWeb" mobile/lib` returns **exactly one** hit:
      `mobile/lib/shared/platform/is_web.dart`.
- [ ] `grep -rn "defaultTargetPlatform" mobile/lib` shows **no newly added
      uses** versus `<base>`; `is_web.dart` does not mention it.
- [ ] `mobile/web/` contains `index.html`, `manifest.json`, `favicon.png`, and
      `icons/{Icon-192,Icon-512,Icon-maskable-192,Icon-maskable-512}.png`, and all
      six are tracked by git (`git ls-files mobile/web` lists all six).
- [ ] `mobile/web/index.html` contains the literal string `$FLUTTER_BASE_HREF`
      and `<script src="flutter_bootstrap.js" async></script>`, and the repo does
      **not** contain a hand-written `mobile/web/flutter_bootstrap.js`, a
      `serviceWorkerVersion` variable, or a `_flutter.loader.loadEntrypoint` call.
- [ ] `mobile/web/index.html` contains the provenance comment naming the SDK
      version (3.44.4) and the template path.
- [ ] `mobile/.metadata` lists a `web` entry under `migration.platforms` at
      revision `ad70ec4617166f1c38e5d2bfd388af71fda14f06` — **or**, if A7's
      fallback was taken, the omission is recorded in `index.html`'s provenance
      comment. One or the other, not neither.
- [ ] No `.gitignore` anywhere in the repo is modified.
- [ ] The PR body states what the build gate does and does not prove (see
      [What this part does *not* prove](#what-this-part-does-not-prove)), notes
      the maskable-icon limitation from A3, and says that the runtime gates land
      in Part 2.

**Explicitly NOT asserted by this part** (they belong to Part 2 / Part 3 and
cannot be true yet): any zero-channel-traffic assertion for `app_badge_plus` or
`buzz/media_upload`; the absence of the paperclip or "Scan QR Code" affordances;
`keyValueStoreProvider` resolving to `InMemoryKeyValueStore`; the
`flutter_secure_storage` import fence; `DesktopShell` rendering under an
`isWebProvider` override.

## Implementation Tasks

Ordered. Do A1–A3 before A5; B1 is independent of the A tasks and may be done at
any point before B7.

### Slice A — web runner directory + build recipe

No behavioral `lib/` changes.

- [ ] **A1.** Create `mobile/web/index.html` by copying
      `$FLUTTER_ROOT/packages/flutter_tools/templates/app/web/index.html.tmpl`
      and substituting `{{projectName}}` → `Buzz` (3 occurrences:
      `apple-mobile-web-app-title`, `<title>`) and `{{description}}` →
      `Buzz mobile client` (from `mobile/pubspec.yaml:2`).
      **Keep verbatim**: `<base href="$FLUTTER_BASE_HREF">` (the literal token —
      `flutter build` replaces it at build time) and
      `<script src="flutter_bootstrap.js" async></script>`.
      **Do not hand-write `flutter_bootstrap.js`** — it is generated at build
      time. Add one HTML comment near the top recording provenance, e.g.

      ```html
      <!-- Authored by hand against the Flutter 3.44.4 SDK template at
           packages/flutter_tools/templates/app/web/index.html.tmpl
           (flutter create is blocked in this repo's agent environment).
           Diff against that file after an SDK upgrade. -->
      ```

- [ ] **A2.** Create `mobile/web/manifest.json` from `manifest.json.tmpl` with:
      `name` / `short_name` → `Buzz`; `description` → `Buzz mobile client`;
      `background_color` → `#EFF1F5` (Catppuccin Latte Base, see
      `mobile/lib/shared/theme/color_scheme.dart:9`); `theme_color` → `#8839EF`
      (Latte Mauve, the app primary, `color_scheme.dart:8`); `orientation` →
      `any` (the target is a desktop-width browser window, not the template's
      `portrait-primary`). Keep `start_url`, `display`,
      `prefer_related_applications`, and the four-entry `icons` array exactly as
      the template has them. **These three values are the only permitted
      deviations from the template.**
- [ ] **A3.** Generate the icons from
      `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
      with `sips -z <n> <n> <src> --out <dest>`:
      - `mobile/web/favicon.png` (32×32)
      - `mobile/web/icons/Icon-192.png` (192×192)
      - `mobile/web/icons/Icon-512.png` (512×512)
      - `mobile/web/icons/Icon-maskable-192.png` (192×192)
      - `mobile/web/icons/Icon-maskable-512.png` (512×512)

      The maskable variants are the same square artwork (no safe-zone padding).
      Note that limitation in the PR body; **do not author new artwork.**
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
      Fix any compile error surfaced here **inside this part**; if a fix would
      require a dependency change, a Rust change, or a gate that belongs to
      Part 2, **stop and report** rather than expanding scope.
- [ ] **A6.** Confirm `mobile/build/web/` is git-ignored (it is, via
      `mobile/.gitignore`'s `/build/`) and that `mobile/web/**` is staged — all
      six files, including the binary PNGs. **Do not modify any `.gitignore`.**
- [ ] **A7.** Add the `web` platform entry to `mobile/.metadata`'s
      `migration.platforms` list (the file is tracked and currently lists only
      `root`, `android`, `ios`, all at revision
      `db50e20168db8fee486b9abf32fc912de3bc5b6a`). This is what
      `flutter create --platforms=web` would have written; since that command is
      blocked, add it by hand using the **current** SDK revision, appended after
      the `ios` entry and before the `# User provided section` comment:

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
      `flutter migrate` silently blind to the web runner. **Do not** change the
      existing `version.revision` or the three existing platform entries. If the
      build agent judges the hand-edit unsafe, the fallback is to omit it and
      record the omission in A1's provenance comment instead — but do one or the
      other, not neither.

### Slice B (partial) — the web platform seam

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
      `shared/shell/` follow the same pattern). **Nothing reads this provider in
      Part 1** — Part 2's five gates and Part 3's `keyValueStoreProvider` do.
      Do not add a consumer, a test, or extra members to make it "look used".
- [ ] **B7 (scoped to this part).** `cd mobile && flutter analyze` → zero errors,
      warnings, and infos. Then `cd mobile && dart format .`, re-run
      `dart format --output=none --set-exit-if-changed .` to confirm clean, and
      run `node ./scripts/check-file-sizes.mjs`.

### Verification (run before opening the PR)

- [ ] Full suite via the `very_good_cli` MCP `test` tool (`directory: mobile`) —
      60 files, all green, **none edited**.
- [ ] `just mobile-build-web` (the recipe, not the raw command) exits 0.
- [ ] Every check in [Acceptance Criteria](#acceptance-criteria).

## Test Plan

**Part 1 adds no tests.** This is deliberate and is the one place in the series
where "no PR leaves the codebase unverified" is satisfied by something other than
a new test:

- The deliverable is *compilability of the web target*, and the verification for
  that is `flutter build web --release` exiting 0 (A5) plus the
  `just mobile-build-web` recipe that reproduces it (A4). A widget test cannot
  assert it.
- The only `lib/` addition is `isWebProvider`, a one-line provider returning
  `kIsWeb`. Per the parent plan's decision (assumption #7), it gets no dedicated
  test; Part 2's five gate tests exercise it via overrides, which is a stronger
  assertion than `expect(container.read(isWebProvider), isFalse)` would be.
- The regression assertion for this part is **the 60 existing test files passing
  with an empty `mobile/test` diff**.

If the build agent finds itself wanting to add a test here, that is a signal it
has pulled Part 2 scope forward. Stop instead.

## Success Metrics

- `flutter build web --release` goes from "not configured for the web" to a green
  build of ~35.6k LOC across 172 lib files — a previously untested property.
- Zero change to the Android/iOS runtime: no dependency, pubspec, `android/`, or
  `ios/` diff, an empty `mobile/test` diff, and a fully green pre-existing suite.
- Exactly one new `lib/` file, ~10 lines, unreferenced by design — the smallest
  possible seam for Parts 2 and 3 to build on.

## Risks & Mitigations

1. **First `flutter build web` surfaces compile errors this audit did not
   reach.** *Mitigation:* the build is permitted in this run, so failures surface
   now rather than in Part 3. If a fix would need a dependency change, a Rust
   change, or a Part 2 gate, **stop and report** — do not expand scope.
2. **`mobile/web/index.html` drifts from the SDK template** across Flutter
   upgrades (as happened industry-wide at the 3.22 `flutter_bootstrap.js`
   transition). *Mitigation:* the A1 provenance comment records the SDK version
   and the template path to diff against, and an acceptance check forbids the
   pre-3.22 patterns.
3. **Reviewer sees an unused provider and asks for its removal.** *Mitigation:*
   the PR body must state that `isWebProvider` is the seam Parts 2 and 3 consume,
   and link this plan. This is the known cost of splitting the seam out of the
   gates, and it is worth paying: it keeps Part 2's diff purely behavioral.
4. **Hand-editing `.metadata` is contrary to its own header.** *Mitigation:* A7
   documents why, restricts the edit to appending one entry, and provides an
   explicit fallback (omit + document) so the build agent is never stuck.
5. **The web target has no CI protection**, so a later mobile change can silently
   break it. *Mitigation:* accepted and documented; `just mobile-build-web` makes
   local checking one command. CI wiring requires a human edit to
   `.github/workflows/ci.yml` (guardrail-blocked).
6. **`sips` is macOS-only**, so A3 is not reproducible on a Linux runner.
   *Mitigation:* accepted — the icons are committed binaries, generated once.

## Auto-resolved assumptions

This part plan was produced non-interactively by splitting
`docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`. Wherever the
splitting or planning skill would have asked a human, the most YAGNI-aligned
default was taken and recorded here.

1. **The split shape was approved upstream and is implemented as given**: three
   parts, linear dependency chain, stacked PRs. Part 1 = A1–A7 + B1 + the
   analyze-clean portion of B7 scoped to this slice. It was not re-derived.
2. **B1 (`is_web.dart`) is pulled into Part 1 rather than left with the gates.**
   It is the shared prerequisite of both Part 2 and Part 3, and moving it here
   makes the dependency chain strictly linear (2 depends on 1; 3 depends on 2)
   instead of diamond-shaped. Cost: Part 1 ships an unreferenced provider,
   flagged in the PR body and in Risk 3.
3. **Part 1 ships no tests.** Justified at length in [Test Plan](#test-plan). The
   alternative — a trivial `expect(isWebProvider, isFalse)` test — would assert
   the VM constant, not the seam, and would be deleted on sight in review.
4. **The whole-plan acceptance criteria were re-scoped, not copied.** Every
   criterion asserting a gate, a storage property, or a README section was moved
   to Part 2 or Part 3, and an explicit "NOT asserted by this part" list was added
   so a reviewer can see the omissions are deliberate.
5. **`flutter build web --release` is asserted in this part even though the app
   will crash at runtime in a browser.** Compilability is the deliverable; the
   PR body must say plainly that a browser session will still throw
   `MissingPluginException` until Part 2. Deferring the build assertion to Part 2
   was rejected — it would leave Part 1 with no gate at all.
6. **The manual browser verification checklist is deferred to Part 3's PR body**
   (task E2), since most of its items cannot pass until the gates and the
   session-only store land. Part 1's PR body carries only the
   "what this does not prove" statement.
7. **`mobile/README.md` is not touched in Part 1.** Documenting a web build whose
   gates do not exist yet would ship a misleading README for the lifetime of two
   PRs. E1 stays in Part 3.
8. **Inherited unchanged from the parent plan** (not re-decided here): the
   three-value `manifest.json` deviation (#9), the 32×32 favicon and
   padding-free maskable icons (#10), omitting `--no-pub` from the recipe and
   keeping it out of `just ci`/`just check` (#11), the hand-edited `.metadata`
   entry with a documented fallback (#20), and all four brainstorm overrides
   about `dart:io`, `image_picker`/`video_player`, and `app_badge_plus` (#13).

## References & Research

- **Parent plan (canonical rationale):**
  `docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md`.
- **Sibling parts:** Part 2 —
  `docs/plan/2026-07-27-feat-flutter-web-target-part-2-plan.md` (runtime gates);
  Part 3 — `docs/plan/2026-07-27-feat-flutter-web-target-part-3-plan.md`
  (session-only storage + docs).
- Brainstorm: `docs/brainstorm/2026-07-27-flutter-web-desktop-phase-0-brainstorm.md`
  (§1 `dart:io` audit, §2 plugin web-support table, §5 relay connectivity).
- Source plan: `mobile/DESKTOP_PORT_PLAN.md` §9 Phase 0, §5, §10.1.
- Predecessor plan (landed):
  `docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md`; merged
  PRs #1–#4; commit `e4622671`.
- SDK template:
  `$FLUTTER_ROOT/packages/flutter_tools/templates/app/web/{index.html.tmpl,manifest.json.tmpl,icons/}`;
  web-project gate at `flutter_tools/lib/src/project.dart:1132-1133`.
- UA-derived platform (context for Part 2):
  `$FLUTTER_ROOT/packages/flutter/lib/src/foundation/_platform_web.dart`.
- Relay same-origin serving: `crates/buzz-relay/src/router.rs:145-186`
  (`BUZZ_WEB_DIR`); CORS gap at `crates/buzz-relay/src/router.rs:397-421`
  (both documented in Part 3).
- Conventions: `CLAUDE.md` § Mobile App (Flutter), § Quality Gates;
  `mobile/scripts/check-file-sizes.mjs`.
