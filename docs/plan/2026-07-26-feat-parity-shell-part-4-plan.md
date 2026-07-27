---
title: 'feat: Flutter desktop parity shell — Part 4: Sheets & input layer'
type: feat
date: 2026-07-26
part: 4 of 4
status: ready-for-build
parent-plan: docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md
brainstorm: docs/brainstorm/2026-07-26-flutter-desktop-parity-shell-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§5, §9 Phase 1)
depends-on: docs/plan/2026-07-26-feat-parity-shell-part-3-plan.md
---

# feat: Flutter desktop parity shell — Part 4 of 4: Sheets & input layer (T13–T19)

> **Standalone build input.** This file is the complete specification for
> Part 4 — the build receives only this file. It was split from
> `docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md` into 4
> stacked parts. Task numbers T1–T19 are global across the series; T1–T12
> landed in Parts 1–3 and is available to build on (see Dependencies).
> This part finishes Phase 1.

## Overview

Phase 1 of the Flutter desktop port (source: `mobile/DESKTOP_PORT_PLAN.md`
§9 Phase 1) builds a width-adaptive multi-pane shell entirely in portable
Dart under `mobile/lib` + `mobile/test`. Below 840dp the existing mobile UX
renders byte-for-byte unchanged. At ≥ 840dp the `DesktopShell` (Parts 1–3)
already composes `community rail | channel list | message pane` with
push-free selection and a right-edge overlay side panel for
thread/forum/activity.

Phase 0 (desktop platform folders) has **not** landed. Everything here is
verifiable exclusively via `dart format`, `flutter analyze`, and
`flutter test` (wide-surface widget tests are the desktop proxy).

**Part 4 (this plan) completes the phase — sheet conversions and the input
layer:**

- **T13** — all 21 `showModalBottomSheet` call sites → `showAdaptiveModal`
- **T14** — right-click message actions + media-viewer Esc
- **T15** — search overlay + `SearchView` extraction + search-hit branching
- **T16** — global shortcuts (Cmd/Ctrl+K, Cmd/Ctrl+comma, Esc,
  Cmd/Ctrl+Alt+Arrow channel navigation) + channel-order helper
- **T17** — composer hardware-key handling (Enter sends / Shift+Enter
  newline)
- **T18** — pure-Dart drag-drop seam feeding the existing upload pipeline
- **T19** — Pulse rail destination

## Dependencies

**Builds on:** Part 3 —
`docs/plan/2026-07-26-feat-parity-shell-part-3-plan.md` (which builds on
Parts 1–2). Base branch: the Part 3 PR branch (stack the PR on it; if
Part 3 has already merged, base is `main`).

**Inherited from Parts 1–3 (exists on the base branch — do not recreate):**

- Part 1: `mobile/lib/shared/layout/breakpoints.dart`
  (`isExpandedLayout(BuildContext)`, `kExpandedLayoutMinWidth` = 840).
- Part 1: `mobile/lib/shared/shell/shell_state.dart` +
  `mobile/lib/shared/shell/shell_state_provider.dart` —
  `shellStateProvider` with `selectChannel`, `clearSelection`,
  `openThreadPanel`, `openForumThreadPanel`, `toggleActivityPanel`,
  `closeSidePanel`, **`showPulse()`/`showChannels()`** (consumed here by
  T19) and `ShellMainContent { channels, pulse }`; `selectChannel` already
  forces `channels` content and resets on community switch.
- Part 1: `mobile/lib/shared/widgets/adaptive_modal.dart` —
  `Future<T?> showAdaptiveModal<T>(BuildContext, {required WidgetBuilder
  builder, bool isScrollControlled = false, bool showDragHandle = true,
  double maxWidth = 480})`: narrow → `showModalBottomSheet` passthrough;
  wide → `Dialog` (`Radii.dialog` corners, `ConstrainedBox(maxWidth)`).
  **T13/T15 finally give it production call sites.** If a converted call
  site needs another `showModalBottomSheet` parameter (e.g.
  `backgroundColor`), add it to the helper rather than bypassing it.
- Part 1: `mobile/lib/features/home/home_page.dart` is the adaptive switch;
  mobile body in `home_page/mobile_home_body.dart`.
- Part 2: `ChannelDetailView`
  (`channel_detail_page/detail_view.dart`), `ChannelWorkspace`
  (`mobile/lib/features/channels/channel_workspace.dart`), `CommunityRail`
  (`mobile/lib/features/home/desktop_shell/community_rail.dart` — T19 adds
  the pulse destination to it), and selection branching at
  `channels_page.dart` (`openChannel` wide → `selectChannel`; FAB narrow-
  only + wide `+` app-bar action), `channel_link_navigation.dart`,
  `deep_link_dispatcher.dart` (wide: `popUntil(isFirst)` + selectChannel,
  no push), `invite_join_sheet.dart`.
- Part 3: `ThreadView` (`thread_detail_page/thread_view.dart` — **T14 adds
  right-click to its reply rows**; the long-press `showMessageActions` call
  formerly at `thread_detail_page.dart:428` now lives here),
  `ForumThreadView` (`forum_thread_page/forum_thread_view.dart`),
  `ActivityView`, `SidePanelHost`
  (`desktop_shell/side_panel_host.dart`), thread/forum open branching at
  all sites, and — important for T16 — **the root `CallbackShortcuts` +
  `Focus(autofocus: true)` in `desktop_shell.dart` with the single
  `Esc → closeSidePanel()` binding, built to be extended.** T16 moves that
  binding into the new `shell_shortcuts.dart` part and extends the map.
- Tests on base (all green, keep green): the original 48 files + Part 1's
  `breakpoints_test.dart`, `shell_state_provider_test.dart`,
  `adaptive_modal_test.dart`, `home_page_test.dart` + Part 2's
  `channel_workspace_test.dart`, `desktop_shell_test.dart` (extended in
  Part 3; extended again here by T19).

**Downstream consumers (Phase 0 — future work, not in this repo run):**

- `attachmentDropBackendProvider` (T18) is the seam Phase 0 overrides with
  a `desktop_drop`-backed implementation. Its default **must stay `null`**
  and `AttachmentDropRegion` must render the child unchanged in that case.
- All layout/shortcut constants stay in the shell/breakpoints files for
  Phase 0 visual QA retuning.

## Hard Constraints (fixed — inherited from the run)

- Pure Dart under `mobile/lib` and `mobile/test` only. No platform folders,
  no `flutter create/run/build/clean/upgrade`, no runner/native code.
- **Zero new pub dependencies** — `mobile/pubspec.yaml` must be unchanged.
- Existing mobile UX unchanged at narrow widths; all pre-existing tests stay
  green. One deliberate, documented exception: hardware-keyboard Enter now
  sends at every width (see T17 and Auto-resolved assumption 5);
  touch/soft-keyboard behavior is untouched.
- Verification commands available to the build: `flutter test`,
  `flutter analyze`, `dart format` (run from `mobile/`).
- Agents may only run `flutter test`, `flutter analyze`, and `dart format`
  — never `flutter run`, `flutter build`, `flutter clean`, or
  `flutter upgrade`.

## Declared File Scope (this part)

The build may create/modify files **only** under `mobile/lib/**` and
`mobile/test/**`, and within that only the files below. Explicitly out of
bounds: `mobile/pubspec.yaml`, `mobile/analysis_options.yaml`,
`mobile/scripts/**`, `mobile/android/**`, `mobile/ios/**`, all repo-root
files, `desktop/**`, `crates/**`, `docs/**` (this plan is not to be edited
by the build).

**Creates:**

- `mobile/lib/features/search/search_overlay.dart` (T15)
- `mobile/lib/features/channels/channel_list_order.dart` (T16)
- `mobile/lib/features/home/desktop_shell/shell_shortcuts.dart` (T16)
- `mobile/lib/shared/widgets/attachment_drop_region.dart` (T18)
- `mobile/test/features/search/search_overlay_test.dart` (T15)
- `mobile/test/features/channels/channel_list_order_test.dart` (T16)
- `mobile/test/features/home/shell_shortcuts_test.dart` (T16)
- `mobile/test/shared/widgets/attachment_drop_region_test.dart` (T18)
- (optional, per T14) one small new test file under
  `mobile/test/features/channels/` for right-click + media-viewer Esc if
  not added to an existing channels test file
- (optional, per T15) a `part` file for `SearchView` under
  `mobile/lib/features/search/` if the line cap requires it

**Modifies (lib):**

- T13 sheet conversions (mechanical, content widgets unchanged):
  `mobile/lib/features/channels/channel_detail_page.dart`,
  `mobile/lib/features/channels/channel_detail_page/app_bar.dart`,
  `mobile/lib/features/channels/channels_page.dart`,
  `mobile/lib/features/channels/channels_page/channel_tile.dart`,
  `mobile/lib/features/channels/compose_bar.dart`,
  `mobile/lib/features/channels/emoji_picker.dart`,
  `mobile/lib/features/channels/members_sheet.dart`,
  `mobile/lib/features/channels/message_actions.dart`,
  `mobile/lib/features/channels/reaction_row.dart`,
  `mobile/lib/features/forum/forum_post_card.dart`,
  `mobile/lib/features/forum/forum_thread_page.dart`,
  `mobile/lib/features/invites/invite_join_sheet.dart`,
  `mobile/lib/features/profile/set_status_sheet.dart`,
  `mobile/lib/features/profile/user_profile_sheet.dart`
- T14: `mobile/lib/features/channels/channel_detail_page/message_bubble.dart`,
  `mobile/lib/features/channels/channel_detail_page/system_rows.dart`,
  `mobile/lib/features/channels/thread_detail_page/thread_view.dart`,
  `mobile/lib/features/channels/media_viewer_page.dart`
- T15: `mobile/lib/features/search/search_page.dart`
- T16: `mobile/lib/features/channels/channels_page/body.dart`,
  `mobile/lib/features/home/desktop_shell.dart`
- T17/T18: `mobile/lib/features/channels/compose_bar.dart`
- T19: `mobile/lib/features/home/desktop_shell/community_rail.dart`,
  `mobile/lib/features/home/desktop_shell.dart`

**Modifies (test):**

- `mobile/test/features/channels/compose_bar_test.dart` (T17, T18)
- `mobile/test/features/channels/channel_detail_page_test.dart` and/or
  `mobile/test/features/channels/channels_page_test.dart` and/or
  `mobile/test/shared/widgets/adaptive_modal_test.dart` (T13 wide-mode
  representative tests)
- `mobile/test/features/home/desktop_shell_test.dart` (T19)

No other file may change. (Exception, only if the 1000-line cap forces it:
an additional `part` file under the same page's folder, noted in the PR
description.)

## Codebase Context & Conventions (verified — build may trust this and skip its own codebase review)

All facts below were verified against the repo on 2026-07-26 (paths, symbols,
and line numbers) **before Parts 1–3 landed**. Where a bullet conflicts with
the changes listed under Dependencies (e.g. thread rows now live in
`thread_view.dart`), the Dependencies section wins. Line numbers are
anchors, not exact contracts — re-locate by symbol if a file shifted.

### Repo conventions (binding)

- **State**: Riverpod 3 (`hooks_riverpod ^3.0.3`) + `flutter_hooks`. New
  widgets are `HookConsumerWidget` / `ConsumerWidget` (or plain
  `StatelessWidget` for pure presentation). **Never** `StatefulWidget`.
  Five pre-existing exceptions exist and must not be "fixed":
  `MediaImageViewerPage` (`mobile/lib/features/channels/media_viewer_page.dart`,
  comment says "StatefulWidget retained: imperative gesture/animation
  controllers … allowed exception"), `MediaVideoViewerPage`
  (`media_viewer_page.dart:331`), `DeepLinkDispatcher`
  (`ConsumerStatefulWidget`), `EmojiPickerSheet`
  (`mobile/lib/features/channels/emoji_picker.dart:192`,
  `ConsumerStatefulWidget`), and `AvatarImageContent`
  (`mobile/lib/shared/widgets/avatar_image.dart:44`).
- **No code-gen** (no Freezed/build_runner). Hand-written notifiers. Riverpod
  3 API in use: `Notifier`/`AsyncNotifier` + `NotifierProvider` /
  `AsyncNotifierProvider` (see
  `mobile/lib/shared/community/community_provider.dart`).
- **Navigation**: Navigator 1.0, no named routes, no GoRouter. Pushes are
  `Navigator.of(context).push(MaterialPageRoute<T>(builder: …))`.
- **Feature isolation**: features import only from `shared/` — with two
  verified precedents this plan relies on: `features/home` is the de-facto
  composition root (already imports `channels`, `activity`, `search`), and
  `features/channels` already imports `forum`, `profile`, `settings`,
  `pairing`, `invites`. Leaf features may import `shared/shell` (from
  Part 1) since it is `shared/`. `shared/` must **not** import feature
  types — the shell state holds IDs only, and T18's drop seam in
  `shared/widgets` must not import feature types either.
- **File size**: hard cap 1000 lines/file, enforced by
  `mobile/scripts/check-file-sizes.mjs` (`MAX_LINES = 1000`; the `overrides`
  map is **empty** — do not add to it; split files instead). Grow via `part`
  files under a `<page>/` folder (existing precedent:
  `channel_detail_page/` with 5 parts, `channels_page/` with 6 parts).
- **Theme/tokens**: `Grid` spacing scale in `mobile/lib/shared/theme/grid.dart`
  (`quarter`=2, `half`=4, `xxs`=8, `twelve`=12, `xs`=16, `gutter`=20, `sm`=24,
  `md`=32, `lg`=40, `xl`=48, `xxl`=64, `xxxl`=80). `Radii` in
  `mobile/lib/shared/theme/app_theme.dart` (`lg`=10, `md`=8, `sm`=6,
  `dialog`=24). Use `context.colors` / `context.textTheme` extensions (from
  `shared/theme/theme.dart`), never raw `Theme.of(context)`.
- **Lints**: `flutter_lints` + `custom_lint`/`riverpod_lint`;
  `prefer_single_quotes: true`. No `print()` — use `debugPrint()`.
- Icons: `lucide_icons_flutter` (`LucideIcons.*`).

### Testing conventions (verified)

- 48 pre-plan `*_test.dart` files under `mobile/test/` plus
  `mobile/test/helpers/widget_helpers.dart`. All must stay green — this is
  the mobile-regression gate. **Stacked-parts note:** "pre-existing tests"
  for this part means every test file present on the base branch — the
  original 48 plus the 6 files Parts 1–3 added/extended.
- `WidgetHelpers.testable({required Widget child, List<Override> overrides})`
  wraps in `ProviderScope(overrides) > MaterialApp(theme: AppTheme.light()) >
  Scaffold(body: child)`. For page/shell-level tests that need their own
  Scaffold/routes, build a custom `ProviderScope` + `MaterialApp` instead
  (see `mobile/test/features/channels/channels_page_test.dart` for the
  pattern).
- Fake notifiers **extend the real notifier class and override `build()`**;
  mocktail for mocks.
- Default test surface is 800×600 → `isExpandedLayout` is false, so **all
  existing tests exercise the narrow/mobile path unchanged**. Wide tests use:
  `await tester.binding.setSurfaceSize(const Size(1440, 900));`
  `addTearDown(() => tester.binding.setSurfaceSize(null));`
  (1440×900 is the standard wide surface).
- Quality commands (run from `mobile/`):
  `dart format --output=none --set-exit-if-changed .`, `flutter analyze`,
  `flutter test`.

### Verified code seams (subset relevant to Part 4; other parts' completed seams trimmed)

- `mobile/lib/app.dart` — `App extends HookConsumerWidget`; `MaterialApp`
  with provider-driven auth `switch`: authenticated →
  `DeepLinkDispatcher(child: HomePage())`, else
  `DeepLinkDispatcher(dispatchMessageLinks: false, child: PairingPage())`.
  **Not modified in this plan.**
- `mobile/lib/features/channels/channels_page.dart` (283 lines pre-split;
  parts: `channels_page/{body,sections,channel_tile,sheets,badges,community}.dart`) —
  `ChannelsPage.build` defines `openChannel(Channel)` (**[Part 2 note:
  already width-branched — wide writes `selectChannel`]**),
  `openQuickActions()` (bottom sheet returning private `_QuickAction`, then
  `_CreateChannelSheet` / `_NewDirectMessageSheet`, then
  `openChannel(created)`), the narrow-only `FloatingActionButton`
  (`heroTag: 'channels-fab'`) + wide `+` app-bar action (Part 2), and a
  `FrostedAppBar` with leading `_CommunityIndicator` (opens
  `_CommunitySwitcherSheet`) and trailing `ProfileAvatar` (pushes
  `SettingsPage`). The channel ordering/visibility computation
  (`isMember && !isArchived`, stars, sections, mutes) lives in
  `_SliverChannelsList.build` (`channels_page/body.dart:84+`) watching
  `readStateProvider`, `channelSectionsProvider`, `channelMutesProvider`,
  `channelStarsProvider` — **T16 extracts this into
  `channel_list_order.dart`.**
- `mobile/lib/features/channels/channel_detail_page.dart` (351 lines
  pre-split; parts:
  `channel_detail_page/{message_list,system_rows,message_bubble,banners,app_bar}.dart`
  + `detail_view.dart` from Part 2) — renders `ForumPostsView` inline when
  `channel.isForum`, else message list + `ComposeBar`, inside
  `FrostedScaffold`/`FrostedAppBar`. One `showModalBottomSheet` site in the
  library head, one in `app_bar.dart` (T13 targets).
- **Search**: `mobile/lib/features/search/search_page.dart` — `SearchPage
  extends HookConsumerWidget` wrapping `FrostedScaffold`; private
  `_SearchBody` (line 108) and section widgets; **3 `ChannelDetailPage` push
  sites** (channel hit ~line 217, people/DM hit ~line 258, message hit
  ~lines 384-398, the latter passing initial message context) — T15
  branches all three at wide.
- **Sheets — all 21 `showModalBottomSheet` call sites by file (count)**
  (T13 converts every one):
  `channels/channel_detail_page.dart` (1), `channels/channel_detail_page/app_bar.dart` (1),
  `channels/channels_page.dart` (4: quick-actions, create-channel, new-DM,
  community-switcher), `channels/channels_page/channel_tile.dart` (2),
  `channels/compose_bar.dart` (1: attach), `channels/emoji_picker.dart` (1),
  `channels/members_sheet.dart` (2), `channels/message_actions.dart` (2),
  `channels/reaction_row.dart` (1), `forum/forum_post_card.dart` (1),
  `forum/forum_thread_page.dart` (2), `invites/invite_join_sheet.dart` (1),
  `profile/set_status_sheet.dart` (1), `profile/user_profile_sheet.dart` (1).
  Entry helpers: `showMessageActions(…)` (`message_actions.dart:23`),
  `showEmojiPicker(…)` (`emoji_picker.dart:11`),
  `showUserProfileSheet(BuildContext, String pubkey)`
  (`user_profile_sheet.dart:19`), `showSetStatusSheet(BuildContext,
  {UserStatus? currentStatus})` (`set_status_sheet.dart:32`),
  `showInviteJoinSheet(BuildContext, WidgetRef)` (`invite_join_sheet.dart:9`).
  `MembersSheet` / `ManageChannelSheet` are widget classes shown by callers.
  **[Part 3 note: the two `forum_thread_page.dart` sites may now live in
  the extracted `forum_thread_page/forum_thread_view.dart` part — same
  library, same count.]**
- **`showMessageActions` long-press callers** (T14's right-click targets):
  `channel_detail_page/message_bubble.dart:45`,
  `channel_detail_page/system_rows.dart:39`,
  `thread_detail_page.dart:428` **[Part 3 note: this third caller now lives
  in the extracted `thread_detail_page/thread_view.dart`]**.
- **Composer**: `mobile/lib/features/channels/compose_bar.dart` (725 lines) —
  `TextField` at lines 620-647 with `textInputAction: TextInputAction.send`,
  `onSubmitted: (_) => send()`, `minLines: 1, maxLines: 5`. This is
  soft-keyboard-only; hardware Enter inserts a newline in a multiline field,
  so desktop send requires explicit key handling (T17). Attachment pipeline:
  `attachments` (useState of `BlobDescriptor` list), `uploadingCount`,
  `uploadError` states; `pickAndUpload(Future<BlobDescriptor?> Function()
  pick)` at line 420; service via `mediaUploadServiceProvider` (T18 hooks
  in here).
- **Upload service**: `mobile/lib/shared/relay/media_upload.dart` —
  `MediaUploadService` (line 131) exposes
  `Future<BlobDescriptor> uploadBytes(Uint8List bytes, {required String
  mimeType})` (line 235) which validates size/mime — the natural drop-seam
  entry. Allowed mime sets are internal to that file; unsupported types
  throw (surface via the composer's existing `uploadError`).
- **Communities**: `mobile/lib/shared/community/community_provider.dart` —
  `communityListProvider`, `activeCommunityProvider`; the Part 1
  `shellStateProvider` resets on community switch. (Context for the rail
  T19 extends.)
- **Chrome**: `mobile/lib/shared/widgets/frosted_app_bar.dart` —
  `frostedAppBarHeight(context) = MediaQuery.paddingOf(context).top + 48`;
  `FrostedAppBar` auto-shows a back button only when
  `Navigator.canPop(context)`; `FrostedScaffold` overlays the bar in a
  Stack.
- **Pulse**: `mobile/lib/features/pulse/pulse_page.dart` — `PulsePage`
  (FrostedScaffold + FAB pushing the compose page). **Orphaned**: zero
  references outside `lib/features/pulse/` — the rail is its first entry
  point (T19); mobile navigation stays unchanged.
- **Keyboard**: pre-plan `mobile/lib` had zero `Shortcuts`/
  `CallbackShortcuts`/`LogicalKeyboardKey` usage. **[Part 3 note: the root
  `CallbackShortcuts` + `Focus(autofocus: true)` with the single
  `Esc → closeSidePanel()` binding now exists in `desktop_shell.dart` —
  T16 moves it into `shell_shortcuts.dart` and extends the map.]**
  Flutter's default `DismissIntent` handling already closes dialogs on Esc;
  the shell only needs Esc for side panels — but the media viewer routes
  need explicit Esc handling (T14).
- **Push inventory**: 23 `Navigator.of(context).push` call sites across 17
  files (pre-split count). This part branches only the 3 search-hit sites
  (T15); settings, pairing, media viewer, pulse compose intentionally
  remain full-window pushes.

## Technical Approach

The full-phase design context; this part implements the **Sheets →
dialogs**, **Keyboard & input**, and **Drag-drop seam** subsections plus
the search row of the branching table and the Pulse rail destination.

### Layout model *(context — landed in Parts 1–3)*

```
width < 840              → existing mobile shell (untouched)
width ≥ 840 ("expanded") → | rail 64 | list 280 | messages flex |
                            thread/activity panel = right-edge overlay (360)
```

`isExpandedLayout(context)` (≥ 840, from Part 1) is the single width
predicate. No pane resizing/persistence in Phase 1.

### Navigation branching (this part's remaining row)

| Seam | Narrow (< 840) | Wide (≥ 840) | Part |
|---|---|---|---|
| Search hits (3 sites in `search_page.dart`) | push (unchanged) | pop overlay dialog + `selectChannel(…)` | **4 (T15)** |
| Channel select / links / deep links / invite | push (unchanged) | `selectChannel(…)` | 2 — done |
| Thread open (4 sites) / forum post open | push (unchanged) | `openThreadPanel` / `openForumThreadPanel` | 3 — done |
| Settings, pairing, media viewer, pulse compose | push | push (unchanged — intentionally full-window) | — |

### Sheets → dialogs *(implemented here: T13)*

`showAdaptiveModal` (Part 1) — narrow: delegates to `showModalBottomSheet`
preserving today's exact look/params; wide: `showDialog` with a `Dialog`
(`Radii.dialog` corners) constrained to `maxWidth` (default 480). All 21
call sites convert mechanically; sheet content widgets are unchanged.
Message rows additionally gain `onSecondaryTapUp` (right-click) invoking
the same actions surface (T14).

### Keyboard & input *(implemented here: T16–T17)*

`CallbackShortcuts` (+ `Focus(autofocus)` fallback so bindings work with no
focused text field) above the shell: Cmd/Ctrl+K → search overlay,
Cmd/Ctrl+, → settings, Esc → close side panel (dialogs already self-dismiss
via Flutter's built-in Esc handling), **Cmd/Ctrl+Alt+ArrowUp/Down** →
previous/next channel in the visible ordered list — plain Alt+Arrow is not
used because it collides with `DefaultTextEditingShortcuts` when the
composer is focused (the common desktop state), so the chord test must run
with the composer focused. Cmd+K / Cmd+, are guarded against stacking:
a repeat press while the overlay/route is open must not push another.
Composer: `Focus(onKeyEvent)` around the TextField — Enter (and numpad
Enter) without Shift sends; Shift+Enter falls through to insert a newline;
soft-keyboard `TextInputAction.send` path untouched.

### Drag-drop seam (OS boundary only) *(implemented here: T18)*

Bare-minimum plumbing seam only (per technical review S1 — the backend is
null until Phase 0, so visual polish would be dead UI):
`AttachmentDropRegion(child, onFilesDropped)` with
`attachmentDropBackendProvider` (`Provider<AttachmentDropBackend?>`, default
`null` — the region returns `child` unchanged). **No hover/highlight visual
state in Phase 1.** `ComposeBar` wraps its compose container with the
region and adds `uploadDroppedFiles` →
`MediaUploadService.uploadBytes(bytes, mimeType:
inferred-from-extension)` → existing `attachments`/`uploadError` states.
Phase 0 wires `desktop_drop` as the backend (and adds drop-target visuals)
in one small change; nothing platform-dependent ships now.

## Acceptance Criteria

### Machine-checkable gates

- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && flutter analyze` reports **zero** issues.
- [ ] `cd mobile && flutter test` passes — including all 48 original test
      files and the Part 1–3 test files, none deleted, skipped, or
      weakened.
- [ ] `mobile/pubspec.yaml` is byte-identical (zero new dependencies).
- [ ] The diff touches only `mobile/lib/**` and `mobile/test/**`, and only
      the files in this part's Declared File Scope.
- [ ] Every file under `mobile/lib` and `mobile/test` is ≤ 1000 lines;
      `mobile/scripts/check-file-sizes.mjs` is untouched and its `overrides`
      map stays empty.
- [ ] No new `StatefulWidget`/`ConsumerStatefulWidget`; no `print()`; single
      quotes per lint.
- [ ] **Zero `showModalBottomSheet` references remain outside
      `mobile/lib/shared/widgets/adaptive_modal.dart`** (T13 exit
      criterion).
- [ ] These new test files exist and contain the behavioral tests mapped to
      them in the tasks:
      `mobile/test/features/search/search_overlay_test.dart`,
      `mobile/test/features/channels/channel_list_order_test.dart`,
      `mobile/test/features/home/shell_shortcuts_test.dart`,
      `mobile/test/shared/widgets/attachment_drop_region_test.dart`.

### Behavioral gates (each is a named widget test run by `flutter test`)

- [ ] `showAdaptiveModal` conversions: all existing sheet-exercising tests
      stay green (narrow default surface → sheet path). Wide: message
      actions open as a `Dialog` (representative sheet conversion test) and
      returned values round-trip.
- [ ] Right-click (secondary tap) on a message row opens the same actions
      surface as long-press.
- [ ] Media viewers: Esc pops the route on both `MediaImageViewerPage` and
      `MediaVideoViewerPage`.
- [ ] Cmd/Ctrl+K at wide opens the search overlay; choosing a result closes
      the overlay and selects the channel in shell state; a repeat Cmd/Ctrl+K
      while open does not stack a second overlay, and repeated Cmd/Ctrl+,
      does not stack a second `SettingsPage`.
- [ ] Cmd/Ctrl+Alt+ArrowDown / Cmd/Ctrl+Alt+ArrowUp move the selected
      channel to next/previous in the visible ordered list — asserted
      **with the composer text field focused**.
- [ ] Esc closes an open side panel via the shared shortcut map (regression
      of the Part 3 binding after the T16 move).
- [ ] Composer: hardware Enter **and numpad Enter** send (send path observed
      via fake), Shift+Enter does not send; existing soft-submit test still
      passes.
- [ ] Drop region: with a fake backend override, dropped files reach the
      attachment pipeline (attachment strip shows the upload / fake
      `uploadBytes` called); with the default null backend the child renders
      unchanged; an unsupported extension surfaces `uploadError`.
- [ ] Pulse: rail toggle swaps the main content region to `PulsePage`;
      selecting a channel returns content to channels; the narrow mobile
      shell still has no pulse entry (Part 1's narrow test still passes).
- [ ] `channel_list_order` pure-function ordering matches the rendered list
      (stars/sections/mutes cases), and `channels_page_test.dart` proves
      the body refactor is behavior-neutral.

## Implementation Tasks (ordered)

Every task must leave `dart format` + `flutter analyze` + `flutter test`
green.

### Part D — Sheet conversions & input layer

#### T13. Convert all 21 bottom-sheet call sites to `showAdaptiveModal`

**Modify** (mechanical, content widgets unchanged; preserve each site's
`isScrollControlled`/`showDragHandle`/generic type):
- `mobile/lib/features/channels/channel_detail_page.dart` (1)
- `mobile/lib/features/channels/channel_detail_page/app_bar.dart` (1)
- `mobile/lib/features/channels/channels_page.dart` (4)
- `mobile/lib/features/channels/channels_page/channel_tile.dart` (2)
- `mobile/lib/features/channels/compose_bar.dart` (1)
- `mobile/lib/features/channels/emoji_picker.dart` (1)
- `mobile/lib/features/channels/members_sheet.dart` (2)
- `mobile/lib/features/channels/message_actions.dart` (2)
- `mobile/lib/features/channels/reaction_row.dart` (1)
- `mobile/lib/features/forum/forum_post_card.dart` (1)
- `mobile/lib/features/forum/forum_thread_page.dart` (2)
- `mobile/lib/features/invites/invite_join_sheet.dart` (1)
- `mobile/lib/features/profile/set_status_sheet.dart` (1)
- `mobile/lib/features/profile/user_profile_sheet.dart` (1)

After conversion, zero `showModalBottomSheet` references remain outside
`mobile/lib/shared/widgets/adaptive_modal.dart`.

**Tests** — all existing sheet-exercising tests stay green (narrow default
surface → sheet path). Add wide-mode representative tests: message actions
and quick-actions render as `Dialog` at 1440×900 and returned values
round-trip (extend `channel_detail_page_test.dart` / `channels_page_test.dart`
or add cases to `adaptive_modal_test.dart` pumping the real entry helpers).

#### T14. Right-click message actions + media viewer Esc

**Modify** `mobile/lib/features/channels/channel_detail_page/message_bubble.dart`
(line ~45), `mobile/lib/features/channels/channel_detail_page/system_rows.dart`
(line ~39), and the extracted thread rows in
`mobile/lib/features/channels/thread_detail_page/thread_view.dart` (formerly
`thread_detail_page.dart:428`): add `onSecondaryTapUp` to the existing
`GestureDetector`/`InkWell` invoking the same `showMessageActions` call as
`onLongPress`.

**Modify** `mobile/lib/features/channels/media_viewer_page.dart`: wrap the
page content of **both** viewer pages — `MediaImageViewerPage` and
`MediaVideoViewerPage` (line ~331) — in `CallbackShortcuts` (+ autofocus
`Focus`) binding Esc → `Navigator.of(context).maybePop()`. Do **not**
convert either StatefulWidget (documented allowed exceptions).

**Tests** — widget test: secondary-button tap (`tester.tap(…, buttons:
kSecondaryButton)`) on a message row opens the actions surface; Esc pops
on **both** viewer pages (add to an existing channels test file or a small
new one under `mobile/test/features/channels/`).

#### T15. Search overlay + `SearchView` extraction + search-hit branching

**Modify** `mobile/lib/features/search/search_page.dart`: extract the
scaffold body (search field + `_SearchBody` host) move-only into a public
`SearchView` (same file or `part` — respect the line cap); `SearchPage`
hosts it unchanged.

**Create** `mobile/lib/features/search/search_overlay.dart` —
`Future<void> showSearchOverlay(BuildContext context)`: delegates to
`showAdaptiveModal` (whose wide branch already produces the
`Radii.dialog`-cornered `Dialog`) with `maxWidth: 640`, hosting
`SearchView` — no bespoke `showDialog` copy.

**Modify** the 3 `ChannelDetailPage` push sites in `search_page.dart`
(~lines 217, 258, 384-398): wide → `Navigator.of(context).pop()` (dismiss
the overlay dialog) + `selectChannel(channel.id, …)` carrying the same
initial-message context the push passes today; narrow unchanged.

**Tests** — **create**
`mobile/test/features/search/search_overlay_test.dart` (wide surface, fake
search providers): overlay opens as a Dialog; choosing a channel hit closes
it and writes shell state.

#### T16. Global shortcuts + channel-order helper

**Create** `mobile/lib/features/channels/channel_list_order.dart` — extract
the visible-order computation currently inline in `_SliverChannelsList`
(`channels_page/body.dart:84+`) into a pure, documented function (inputs:
channels + sections/stars/mutes state + current pubkey; output: the ordered
visible channel list exactly as rendered). **Modify**
`mobile/lib/features/channels/channels_page/body.dart` to consume it
(behavior-neutral — existing `channels_page_test.dart` guards this).

**Create** `mobile/lib/features/home/desktop_shell/shell_shortcuts.dart`
(part of desktop_shell) — extends the T12 `CallbackShortcuts` map:
- Cmd+K / Ctrl+K → `showSearchOverlay(context)` — guarded so a repeat press
  while the overlay is open does not stack a second one (e.g. an is-open
  flag around the awaited future, or a route-aware check).
- Cmd+, / Ctrl+, → push `SettingsPage` — same guard: repeated presses must
  not stack a second settings route.
- Esc → `closeSidePanel()` (moved here from T12's inline binding)
- **Cmd/Ctrl+Alt+ArrowDown / Cmd/Ctrl+Alt+ArrowUp** → compute the ordered
  list via `channel_list_order` + the same providers, find
  `selectedChannelId`, and `selectChannel` the next/previous entry (no-op
  at list edges; selects the first channel when nothing is selected).
  Plain Alt+Arrow is **not** used — it collides with
  `DefaultTextEditingShortcuts` when the composer is focused (review M3).
Register both Meta and Control variants for K, comma, and the arrow chords.

**Tests** — **create**
`mobile/test/features/channels/channel_list_order_test.dart` (pure
function: stars/sections/mutes ordering cases) and
`mobile/test/features/home/shell_shortcuts_test.dart` (wide surface with
fakes: Cmd+K opens the overlay and a repeat press does not stack a second;
Cmd+, pushes settings exactly once across repeated presses;
Cmd/Ctrl+Alt+arrows move selection **with the composer text field
focused** — the regression the chord choice exists for; Esc closes the
panel via the shared map).

#### T17. Composer hardware-key handling

**Modify** `mobile/lib/features/channels/compose_bar.dart`: wrap the message
`TextField` (lines ~620-647) in `Focus(onKeyEvent: …)`: on `KeyDownEvent` of
`LogicalKeyboardKey.enter` or `numpadEnter` without
`HardwareKeyboard.instance.isShiftPressed` → invoke the existing `send()`
and return `KeyEventResult.handled`; otherwise `ignored` (Shift+Enter falls
through and inserts a newline). Leave `textInputAction: TextInputAction.send`
/ `onSubmitted` untouched (soft-keyboard path).

Note: this applies at **all** widths — hardware/BT keyboards on mobile do
emit key events, so narrow-width behavior changes deliberately for
external-keyboard users only (aligned with the existing
`TextInputAction.send` intent; touch/soft-keyboard flows are untouched).
This is the single documented exception to "mobile UX unchanged at narrow
widths" (assumption 5 below).

**Tests** — extend `mobile/test/features/channels/compose_bar_test.dart`:
type text + `sendKeyEvent(LogicalKeyboardKey.enter)` → send observed (fake
send-message notifier) and field cleared; same for
`LogicalKeyboardKey.numpadEnter`; Shift+Enter → no send; existing submit
tests unchanged.

#### T18. Drag-drop seam + upload-pipeline entry

**Create** `mobile/lib/shared/widgets/attachment_drop_region.dart` —
bare-minimum seam (review S1: no visual polish while the backend is null):
- `class DroppedFileData { final String name; final Uint8List bytes; … }`
- `abstract class AttachmentDropBackend` with a single
  `Widget wrap({required Widget child, required
  ValueChanged<List<DroppedFileData>> onDropped})`.
- `final attachmentDropBackendProvider =
  Provider<AttachmentDropBackend?>((_) => null);`
- `AttachmentDropRegion extends HookConsumerWidget({required Widget child,
  required ValueChanged<List<DroppedFileData>> onFilesDropped})`: with a
  null backend returns `child` unchanged; with a backend, returns
  `backend.wrap(child: child, onDropped: onFilesDropped)`. **No hover
  state, no highlight** — Phase 0 adds drop-target visuals together with
  the real backend. Doc comment stating Phase 0 supplies the
  `desktop_drop`-backed implementation.

**Modify** `mobile/lib/features/channels/compose_bar.dart`: wrap the compose
container with `AttachmentDropRegion`; `onFilesDropped` → new
`uploadDroppedFiles(List<DroppedFileData>)` mirroring `pickAndUpload`
(line ~420): per file, infer mime type from the filename extension
(png/jpg/jpeg/gif/webp/mp4/mov …), call
`ref.read(mediaUploadServiceProvider).uploadBytes(bytes, mimeType: …)`,
append the returned `BlobDescriptor` to `attachments`, drive
`uploadingCount`, and route failures (including unsupported types thrown by
`uploadBytes`) into the existing `uploadError` state.

**Tests** — **create**
`mobile/test/shared/widgets/attachment_drop_region_test.dart` (null backend
= passthrough; fake backend delivers files → callback fires) and extend
`compose_bar_test.dart` (fake backend + fake upload service: dropped file
lands in the attachment strip; unsupported extension surfaces
`uploadError`).

#### T19. Pulse rail destination

**Modify** `mobile/lib/features/home/desktop_shell/community_rail.dart`: add
the Pulse destination icon button → `shellState.showPulse()` (active-state
styling when `mainContent == pulse`).

**Modify** `mobile/lib/features/home/desktop_shell.dart`: when
`mainContent == ShellMainContent.pulse`, the content region right of the
rail renders `PulsePage()` (its FAB pushes the compose page full-window —
unchanged); otherwise the list + workspace row. `selectChannel` already
forces `channels` content (T2 rule), so deep links and channel picks exit
Pulse automatically.

**Tests** — extend `desktop_shell_test.dart`: pulse toggle swaps content;
`selectChannel` returns to channels; mobile narrow rendering still has no
pulse entry (unchanged mobile shell test from T4 still passes).

## Green boundary — accepted gaps at the end of Part 4 (Phase 1 complete)

Part 4 must leave `dart format` + `flutter analyze` + `flutter test` fully
green standalone. **No interim Phase 1 gaps remain after this part** — the
phase is complete. What remains is deliberately deferred beyond Phase 1:

- The drop seam's backend is `null` until Phase 0 wires `desktop_drop`
  into `attachmentDropBackendProvider` (and adds drop-target visuals).
- The side panel stays overlay-only; docked promotion, selected-channel
  highlight, and all visual retuning belong to Phase 0 visual QA.
- The shell remains dormant on phones (no desktop runtime exists until
  Phase 0 adds platform folders).
- Hardware-keyboard Enter-to-send at narrow widths is the single accepted
  mobile behavior change (documented in T17).

## Auto-resolved assumptions (relevant to this part)

1. **Skill interactivity resolved silently** (run-level): detail level =
   extensive; no external research; no branch setup by the plan stage
   (orchestrator owns branches; this part stacks on Part 3).
2. **View extractions are `part` files of their existing page libraries**;
   `SearchView` may stay a same-file public widget if under the line cap.
3. **Drop region wraps the ComposeBar subtree** (composer region), not the
   whole message pane — keeps attachment state local with an identical seam
   API; Phase 0 can lift the region without API change.
4. Brainstorm defaults reaffirmed: sheets → centered dialogs uniformly
   (`maxWidth` 480; search overlay 640); Cmd/Ctrl+K opens full search;
   settings/pairing/media-viewer/pulse compose stay pushed routes.
5. **Composer Enter-to-send applies to hardware key events at all widths —
   a deliberate, documented narrow-width behavior change**: hardware/BT
   keyboards on phones DO emit key events, so external-keyboard users on
   mobile gain Enter-sends (aligned with the existing
   `TextInputAction.send` intent). Touch/soft-keyboard behavior is
   byte-identical; this is the single accepted exception to "mobile UX
   unchanged at narrow widths".
6. **Technical-review fix-cycle defaults (2026-07-26)**: M3 resolved with
   the recommended non-conflicting chord (Cmd/Ctrl+Alt+Arrows); the
   Cmd+K / Cmd+, no-stack guard mechanism (flag-around-await vs
   route-aware check) is left to the builder; S1 keeps the drop seam
   bare-minimum (no hover/highlight visuals while the backend is null).

## Risks & Mitigations (relevant to this part)

1. **Mobile regression from the 21 mechanical conversions and the
   `SearchView` extraction**: content widgets unchanged; every existing
   sheet-exercising test runs the narrow path by default and gates the
   conversion; `channels_page_test.dart` guards the T16 body refactor.
2. **`CallbackShortcuts` focus dependency**: bindings only fire when focus
   is inside the shell subtree — mitigated with `Focus(autofocus: true)`
   fallback and tests that exercise shortcuts without a focused field,
   plus the chord test that runs **with** the composer focused (the
   `DefaultTextEditingShortcuts` collision case, review M3).
3. **Dialog-ified sheets look phone-shaped at 480px**: cosmetic, accepted
   for parity scope; per-surface polish deferred to Phase 2.
4. **`showAdaptiveModal` snapshots width at open time**: a window resized
   across the breakpoint while a sheet/dialog is open keeps the stale
   presentation until dismissed. Accepted for Phase 1 (unreachable before
   Phase 0 ships a resizable window); flagged for Phase 0 visual QA.
5. **1000-line cap pressure**: `compose_bar.dart` is 725 lines and gains
   T17 + T18 changes; `search_page.dart` gains the `SearchView` split —
   split along part seams if any file approaches the cap; never touch the
   size-check script.
6. **No desktop runtime exists to verify visually**: proof is analyze +
   wide-surface widget tests (1440×900 standard).

## Non-Goals / Deferred (do not build in this part)

- No Phase 0 work (platform folders, `flutter create`, native code, real
  drag-drop backend, visual QA) — Phase 0 wires `desktop_drop` into
  `attachmentDropBackendProvider` and retunes chrome.
- No Bucket A/B features (home inbox/feed, onboarding, workflows, OS
  notifications, reminders, moderation, members admin, channel templates,
  agent-memory, agents, projects, mesh-compute, local-archive, huddle,
  avatar studio).
- No dependency swaps (`image_picker`→`file_selector`,
  `video_player`→`media_kit`, `desktop_drop`, `window_manager`,
  `super_clipboard`) — recorded as Phase 0/2 items.
- No windowed/hover media viewer (Esc-to-close only), no custom window
  chrome, no GoRouter/Navigator 2.0, no pane resize/persistence, no
  quick-switcher, no anchored popovers/context menus, no mobile navigation
  changes (Pulse stays desktop-shell-only).
- No docked side-panel column (overlay-only; review S2), no
  selected-channel highlight, no drop-target hover/highlight visuals (they
  arrive with the real Phase 0 backend — review S1), no "large"/1200
  breakpoint tier.
