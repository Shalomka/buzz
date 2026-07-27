---
title: 'feat: Flutter desktop parity shell — Part 1: Foundations'
type: feat
date: 2026-07-26
part: 1 of 4
status: ready-for-build
parent-plan: docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md
brainstorm: docs/brainstorm/2026-07-26-flutter-desktop-parity-shell-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§5, §9 Phase 1)
---

# feat: Flutter desktop parity shell — Part 1 of 4: Foundations (T1–T4)

> **Standalone build input.** This file is the complete specification for
> Part 1 — the build receives only this file. It was split from
> `docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md` into 4
> stacked parts. Task numbers T1–T19 are global across the series; any
> reference to a task outside T1–T4 describes a **later part** and is
> context only, never scope for this build.

## Overview

Phase 1 of the Flutter desktop port (source: `mobile/DESKTOP_PORT_PLAN.md`
§9 Phase 1) builds a width-adaptive multi-pane shell entirely in portable
Dart under `mobile/lib` + `mobile/test`. Below 840dp the existing mobile UX
renders byte-for-byte unchanged. At ≥ 840dp a new `DesktopShell` composes
`community rail | channel list pane | message pane (+ side panel)` from the
existing feature widgets via move-only "View" extractions.

Phase 0 (desktop platform folders) has **not** landed. Everything here is
verifiable exclusively via `dart format`, `flutter analyze`, and
`flutter test` (wide-surface widget tests are the desktop proxy). The shell
is dormant on phones today and activates automatically once Phase 0 adds
desktop targets.

**Part 1 (this plan) delivers the foundations:**

- **T1** — breakpoint helper (`isExpandedLayout`, 840dp boundary)
- **T2** — shell state (`ShellState` + `ShellStateNotifier`, ID-only,
  community-switch reset)
- **T3** — `showAdaptiveModal` helper (bottom sheet at narrow, `Dialog` at
  wide)
- **T4** — adaptive `HomePage` + `DesktopShell` skeleton

Later parts build on these seams: Part 2 (shell panes & channel selection,
T5–T8), Part 3 (thread/forum/activity side panel, T9–T12), Part 4 (sheet
conversions & input layer, T13–T19).

## Dependencies

**Builds on:** nothing — this is the first part of the stack. Base branch:
the repo default branch `main` (the run branch is
`wingspan/desktop-phase1-run`).

**Inherits:** nothing.

**Later parts consume from this part — create these seams exactly as
specified and do NOT remove, rename, or "clean up" symbols that look unused
here:**

- `isExpandedLayout(BuildContext)` + `kExpandedLayoutMinWidth`
  (`mobile/lib/shared/layout/breakpoints.dart`) — every later part
  width-branches on this.
- `shellStateProvider`, `ShellState`, sealed `ShellSidePanel` (all four
  variants), `enum ShellMainContent { channels, pulse }`, and **all**
  notifier methods: `selectChannel`, `clearSelection`, `openThreadPanel`,
  `openForumThreadPanel`, `toggleActivityPanel`, `closeSidePanel`,
  `showPulse`, `showChannels`. Part 2 consumes `selectChannel` + the
  community reset; Part 3 consumes the panel variants/methods; Part 4
  consumes `showPulse`/`showChannels` and selection movement. The
  panel/pulse methods have **no lib/ consumer in Part 1** — they are
  exercised by the Part 1 provider unit tests and must stay.
- `showAdaptiveModal` (`mobile/lib/shared/widgets/adaptive_modal.dart`) —
  Part 4 converts all 21 `showModalBottomSheet` call sites to it and hosts
  the search overlay on it. Zero production call sites exist in Part 1;
  its widget test is the only consumer. Keep it.
- `DesktopShell` (`mobile/lib/features/home/desktop_shell.dart`) skeleton
  structure — Part 2 swaps the rail placeholder for a `CommunityRail`
  `part` file and the message-pane placeholder for `ChannelWorkspace`;
  Part 3 mounts a `SidePanelHost` part and the Esc shortcut scaffold;
  Part 4 adds a `shell_shortcuts.dart` part. Keep the skeleton `Row`
  slots recognizable (rail | list | expanded content).
- `_MobileHomeBody` (`mobile/lib/features/home/home_page/mobile_home_body.dart`)
  — permanent home of the mobile shell; never folded back.

## Hard Constraints (fixed — inherited from the run)

- Pure Dart under `mobile/lib` and `mobile/test` only. No platform folders,
  no `flutter create/run/build/clean/upgrade`, no runner/native code.
- **Zero new pub dependencies** — `mobile/pubspec.yaml` must be unchanged.
- Existing mobile UX unchanged at narrow widths; all pre-existing tests stay
  green. (The full plan's single documented exception — hardware-keyboard
  Enter-to-send at every width — belongs to Part 4/T17. **Part 1 allows no
  narrow-width behavior change at all.**)
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

- `mobile/lib/shared/layout/breakpoints.dart` (T1)
- `mobile/lib/shared/shell/shell_state.dart` (T2)
- `mobile/lib/shared/shell/shell_state_provider.dart` (T2)
- `mobile/lib/shared/widgets/adaptive_modal.dart` (T3)
- `mobile/lib/features/home/home_page/mobile_home_body.dart` (T4)
- `mobile/lib/features/home/desktop_shell.dart` (T4)
- `mobile/test/shared/layout/breakpoints_test.dart` (T1)
- `mobile/test/shared/shell/shell_state_provider_test.dart` (T2)
- `mobile/test/shared/widgets/adaptive_modal_test.dart` (T3)
- `mobile/test/features/home/home_page_test.dart` (T4)

**Modifies:**

- `mobile/lib/features/home/home_page.dart` (T4)

No other file may change. (Exception, only if the 1000-line cap forces it:
an additional `part` file under the same page's folder, noted in the PR
description.)

## Codebase Context & Conventions (verified — build may trust this and skip its own codebase review)

All facts below were verified against the repo on 2026-07-26 (paths, symbols,
and line numbers). Line numbers are anchors, not exact contracts — re-locate
by symbol if a file shifted.

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
  `pairing`, `invites`. Leaf features may import `shared/shell` (new) since
  it is `shared/`. `shared/` must **not** import feature types — the shell
  state holds IDs only.
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

- 48 existing `*_test.dart` files under `mobile/test/` plus
  `mobile/test/helpers/widget_helpers.dart`. All must stay green — this is
  the mobile-regression gate.
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

### Verified code seams (subset relevant to Part 1; later-part-only seams trimmed)

- `mobile/lib/app.dart` — `App extends HookConsumerWidget`; `MaterialApp`
  with provider-driven auth `switch`: authenticated →
  `DeepLinkDispatcher(child: HomePage())`, else
  `DeepLinkDispatcher(dispatchMessageLinks: false, child: PairingPage())`.
  **Not modified in this plan.**
- `mobile/lib/features/home/home_page.dart` (329 lines, only file in
  `features/home/`) — `HomePage extends HookConsumerWidget`; tab index is
  local `useState(0)`; `IndexedStack` over
  `[ChannelsPage(), ActivityPage(), SearchPage()]`; private `_FloatingTabBar`,
  `_FloatingTabDestination`, `_HomeDestination`,
  `_mediaQueryWithFloatingTabBarClearance`, and layout constants
  (`_tabBarHeight` etc.) all live in this file.
- `mobile/lib/features/channels/channels_page.dart` (283 lines; parts:
  `channels_page/{body,sections,channel_tile,sheets,badges,community}.dart`) —
  `ChannelsPage.build` defines `openChannel(Channel)` (pushes
  `ChannelDetailPage`), `openQuickActions()` (bottom sheet returning private
  `_QuickAction`, then `_CreateChannelSheet` / `_NewDirectMessageSheet`, then
  `openChannel(created)`), a `FloatingActionButton` (`heroTag:
  'channels-fab'`) invoking `openQuickActions`, `FrostedAppBar` with leading
  `_CommunityIndicator` (opens `_CommunitySwitcherSheet`) and trailing
  `ProfileAvatar` (pushes `SettingsPage`). Body is private `_ChannelsBody`
  (in `channels_page/body.dart`) taking `onSelectChannel`; the channel
  ordering/visibility computation (`isMember && !isArchived`, stars,
  sections, mutes) lives in `_SliverChannelsList.build`
  (`channels_page/body.dart:84+`) watching `readStateProvider`,
  `channelSectionsProvider`, `channelMutesProvider`, `channelStarsProvider`.
- `mobile/lib/features/channels/channel_detail_page.dart` (351 lines; parts:
  `channel_detail_page/{message_list,system_rows,message_bubble,banners,app_bar}.dart`)
  — `ChannelDetailPage({required Channel channel, String? initialMessageId,
  String? initialThreadRootId})`. Renders `ForumPostsView` inline when
  `channel.isForum` (`channel_detail_page.dart:270`;
  `Channel.isForum` at `channel.dart:77`), else message list + `ComposeBar`,
  inside `FrostedScaffold`/`FrostedAppBar`. **Read-state marking** is a
  `useEffect(…, [channel.id, readState.isReady, readTimestamp])` calling
  `deferReadStateUpdate(context, () { ref.read(readStateProvider.notifier)
  .markContextRead(channel.id, readTimestamp); ref.read(channelsProvider
  .notifier).clearObservedUnreadCoveredByRead(channel.id, readTimestamp); })`
  (`channel_detail_page.dart:170-182`;
  `deferReadStateUpdate` is a free function in
  `read_state/deferred_read_state_update.dart` using
  `addPostFrameCallback` + cancel closure). Because the effect is keyed on
  `channel.id` and hooks re-run on remount, **remounting the view per
  selection reproduces route-lifecycle read-state semantics exactly.** (This
  is why `ShellState` carries a `pendingSelectionNonce` — see T2.)
- `mobile/lib/features/channels/deep_link_dispatcher.dart` —
  `DeepLinkDispatcher` (ConsumerStatefulWidget) with optional
  `destinationBuilder` and `dispatchMessageLinks`. `_maybeDispatch` consumes
  `pendingDeepLinkProvider`, resolves the channel, and **always pushes**
  (`destinationBuilder` only swaps the pushed widget — the wide path must
  branch *before* the push; that branching is Part 2/T8). `MessageDeepLink`
  carries `channelId`, `messageId`, `threadRootId` — the reason `ShellState`
  stores pending initial-message/thread IDs. Existing test:
  `mobile/test/features/channels/deep_link_dispatcher_test.dart`.
- **Sheets — all 21 `showModalBottomSheet` call sites by file (count)**
  (conversion itself is Part 4/T13; listed here because T3's helper contract
  must cover their parameters):
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
- **Communities**: `mobile/lib/shared/community/community_provider.dart` —
  `communityListProvider`
  (`AsyncNotifierProvider<CommunityListNotifier, List<Community>>`),
  `activeCommunityProvider` (`FutureProvider<Community?>`), switch via
  `ref.read(communityListProvider.notifier).switchCommunity(id)`. Switching
  invalidates `authProvider` (`community_provider.dart:64/78`), which
  remounts the authenticated *widget* subtree — but widget remounts do
  **not** reset root providers held by the app-level `ProviderScope`
  (`main.dart`), so the new `shellStateProvider` must reset itself on
  community change (see T2). Add-community flow (mirror
  `channels_page/community.dart:~97-110`): `ref.read(pairingProvider
  .notifier).reset()` then push `PairingPage`.
- **Chrome**: `mobile/lib/shared/widgets/frosted_app_bar.dart` —
  `frostedAppBarHeight(context) = MediaQuery.paddingOf(context).top + 48`
  (degrades to 48 with no status bar); `FrostedAppBar` auto-shows a back
  button only when `Navigator.canPop(context)` → **embedded panes at the
  shell root get no back button automatically**. `FrostedScaffold` overlays
  the bar in a Stack.
- **Pulse**: `mobile/lib/features/pulse/pulse_page.dart` — `PulsePage`
  (FrostedScaffold + FAB pushing the compose page). **Orphaned**: zero
  references outside `lib/features/pulse/` — the desktop rail is its first
  entry point (Part 4/T19; the `ShellMainContent.pulse` enum value exists
  for it); mobile navigation stays unchanged.
- **Keyboard**: zero existing `Shortcuts`/`CallbackShortcuts`/
  `LogicalKeyboardKey` usage in `mobile/lib` — the shortcut layer is
  greenfield (Parts 3–4). Flutter's default `DismissIntent` handling already
  closes dialogs on Esc — relevant to T3: adaptive-modal dialogs self-dismiss
  on Esc with no extra code.
- **Breakpoints**: no breakpoint code exists anywhere in `mobile/lib` (only
  media-sizing `LayoutBuilder`s). T1 creates the first one.
- **Push inventory**: 23 `Navigator.of(context).push` call sites across 17
  files. **None of them change in Part 1.** Later parts branch specific
  seams; settings, pairing, media viewer, pulse compose intentionally remain
  full-window pushes forever in Phase 1.

## Technical Approach

The full-phase design is included so Part 1's seams are built for their real
consumers. Subsections marked *(later part)* are context only — do **not**
implement them here.

### Layout model *(context for all parts; T1 implements the predicate)*

```
width < 840              → existing mobile shell (untouched)
width ≥ 840 ("expanded") → | rail 64 | list 280 | messages flex |
                            thread/activity panel = right-edge overlay (360)
```

One pure helper reads `MediaQuery.sizeOf`: `isExpandedLayout(context)`
(≥ 840, Material 3 "expanded" boundary). The side panel is a single
right-edge **overlay** presentation at every wide width — the docked
fourth-column variant (and with it any ≥ 1200 "large" tier) is cut from
Phase 1 per technical review S2 and deferred to Phase 0 visual QA. No pane
resizing/persistence in Phase 1.

### Shell state (IDs only — `shared/` stays feature-type-free) *(implemented here: T2)*

`ShellState` (immutable, `copyWith`): `selectedChannelId: String?`,
`pendingInitialMessageId: String?`, `pendingInitialThreadRootId: String?`,
`pendingSelectionNonce: int` (bumped when a selection carries pending IDs so
a repeated *identical* deep link still remounts the workspace),
`sidePanel: ShellSidePanel` (sealed: `none | thread(rootId,
initialMessageId?) | forumThread(postEventId) | activity`), `mainContent:
ShellMainContent` (`channels | pulse`).

`ShellStateNotifier extends Notifier<ShellState>` rules:

 **[BUILD CORRECTION (part 1, commit 372ba9e6): the shipped watch deliberately OMITS `unwrapPrevious()` — with it, same-community reloads (e.g. rename) would spuriously reset shell state. Verified correct in review; do NOT "restore" the literal expression below.]** 
- **Reset on community change**: `build()` watches the active community
  identity (e.g. `activeCommunityProvider.select((v) =>
  v.unwrapPrevious().value?.id)`) and returns the initial state — a
  community switch therefore clears selection, pending IDs, and any open
  panel. Widget remounts alone would NOT do this: `shellStateProvider`
  lives in the root `ProviderScope` and survives subtree remounts.
- `selectChannel(id, {initialMessageId, initialThreadRootId})` closes any
  thread/forum panel, sets `mainContent = channels`, and bumps
  `pendingSelectionNonce` when initial IDs are provided.
- Opening any side panel closes the other kind (single `sidePanel` field
  makes exclusion structural).
- State is simply ignored at narrow widths (push navigation remains
  authoritative there).

### Composition *(Part 1 delivers the HomePage switch + skeleton; Parts 2–3 complete it)*

- `HomePage` becomes the adaptive switch; the current mobile body moves
  move-only into a `part` file (T4, this part).
- `DesktopShell` (+ parts under `features/home/desktop_shell/` added by
  later parts) composes: community rail (Part 2, from `shared/community`
  providers), `ChannelsPage` embedded as the list pane (embedding lands in
  T4; width-branched selection + header `+` instead of FAB is Part 2/T8),
  `ChannelWorkspace` as the message pane (Part 2), and a side-panel host
  for Activity (Part 3).
- *(later parts)* Pages get thin-wrapper treatment: `ChannelDetailView`,
  `ThreadView`, `ForumThreadView`, `ActivityView`, `SearchView` are
  move-only extractions; the existing pages keep their constructors and
  delegate. Extractions live as new `part` files of the existing page
  libraries; embedders import the page library and use the public View
  class.
- *(later part — Part 2/T6)* `ChannelWorkspace` keys `ChannelDetailView` by
  a record key — `ValueKey((channelId, initialMessageId,
  initialThreadRootId, pendingSelectionNonce))` — fresh state per
  selection, matching today's fresh-route-per-navigation behavior (the
  nonce makes even a repeated *identical* deep link remount), which also
  reproduces read-state semantics via the existing keyed `useEffect`. This
  is why T2's state carries the nonce.

### Navigation branching *(later parts — Part 2/T8, Part 3/T10–T11, Part 4/T15; no seam changes in Part 1)*

| Seam | Narrow (< 840) | Wide (≥ 840) | Part |
|---|---|---|---|
| Channel select (`channels_page.dart` `openChannel`) | push `ChannelDetailPage` (unchanged) | `shellState.selectChannel(id)` | 2 |
| `openChannelLink` | push (unchanged) | `selectChannel(id)` | 2 |
| Deep link (`deep_link_dispatcher.dart`) | push (unchanged) | `popUntil(isFirst)` then `selectChannel(id, initialMessageId, initialThreadRootId)` | 2 |
| Invite post-join open (`invite_join_sheet.dart`) | push (unchanged) | `popUntil(isFirst)` then `selectChannel(id)` | 2 |
| Search hits (3 sites in `search_page.dart`) | push (unchanged) | pop overlay dialog + `selectChannel(…)` | 4 |
| Thread open (4 sites) | push `ThreadDetailPage` (unchanged) | `openThreadPanel(rootId, …)` | 3 |
| Forum post open (`forum_posts_view.dart:161`) | push `ForumThreadPage` (unchanged) | `openForumThreadPanel(postEventId)` | 3 |
| Settings, pairing, media viewer, pulse compose | push | push (unchanged — intentionally full-window) | — |

### Sheets → dialogs *(helper implemented here: T3; the 21 call-site conversions are Part 4/T13)*

`Future<T?> showAdaptiveModal<T>(BuildContext context, {required
WidgetBuilder builder, bool isScrollControlled = false, bool showDragHandle =
true, double maxWidth = 480})` — narrow: delegates to `showModalBottomSheet`
preserving today's exact look/params; wide: `showDialog` with a `Dialog`
(`Radii.dialog` corners) constrained to `maxWidth`. All 21 call sites convert
mechanically in Part 4; sheet content widgets are unchanged.

### Keyboard & input *(later parts — Part 3/T12 Esc, Part 4/T16–T17)*

Not part of Part 1. The shell skeleton needs no shortcut layer yet.

### Drag-drop seam *(later part — Part 4/T18)*

Not part of Part 1.

## Acceptance Criteria

### Machine-checkable gates

- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && flutter analyze` reports **zero** issues.
- [ ] `cd mobile && flutter test` passes — including all 48 pre-existing test
      files, none deleted, skipped, or weakened.
- [ ] `mobile/pubspec.yaml` is byte-identical (zero new dependencies).
- [ ] The diff touches only `mobile/lib/**` and `mobile/test/**`, and only
      the files in this part's Declared File Scope.
- [ ] Every file under `mobile/lib` and `mobile/test` is ≤ 1000 lines;
      `mobile/scripts/check-file-sizes.mjs` is untouched and its `overrides`
      map stays empty.
- [ ] No new `StatefulWidget`/`ConsumerStatefulWidget`; no `print()`; single
      quotes per lint.
- [ ] These new test files exist and contain the behavioral tests mapped to
      them in the tasks:
      `mobile/test/shared/layout/breakpoints_test.dart`,
      `mobile/test/shared/shell/shell_state_provider_test.dart`,
      `mobile/test/shared/widgets/adaptive_modal_test.dart`,
      `mobile/test/features/home/home_page_test.dart`.

### Behavioral gates (each is a named widget/unit test run by `flutter test`)

- [ ] At 800×600 (default surface): `HomePage` renders the mobile tab shell
      (floating tab bar present) and no `DesktopShell`.
- [ ] At 1440×900: `HomePage` renders `DesktopShell` and no floating tab
      bar. (In Part 1 the shell is the T4 skeleton: rail placeholder +
      embedded channel list + empty-state message pane — the gate asserts
      `DesktopShell` presence and tab-bar absence.)
- [ ] `isExpandedLayout` is false at 800×600, true at 1440×900, and correct
      at the 840 boundary.
- [ ] Provider-level: community switch resets shell state — changing the
      watched community id resets selection, pending IDs, and any open side
      panel to initial. (End-to-end via the rail is asserted in Part 2.)
- [ ] Provider-level: channel change closes the thread panel; thread/forum/
      activity panels are mutually exclusive; `selectChannel` forces
      `channels` content; pending IDs stored; nonce bumps on a repeated
      identical deep-link selection.
- [ ] `showAdaptiveModal`: bottom sheet at narrow, `Dialog` at wide; a
      returned value round-trips in both modes.

## Implementation Tasks (ordered)

Every task must leave `dart format` + `flutter analyze` + `flutter test`
green.

### Part A — Foundations

#### T1. Breakpoint helpers

**Create** `mobile/lib/shared/layout/breakpoints.dart`:
`const double kExpandedLayoutMinWidth = 840;` and
`bool isExpandedLayout(BuildContext)` reading
`MediaQuery.sizeOf(context).width`. Doc comments (public API rule). **No
"large"/1200 tier** — the side panel is overlay-only in Phase 1 (review
S2), so a second breakpoint would be dead code.

**Tests** — **create** `mobile/test/shared/layout/breakpoints_test.dart`:
widget-pumped checks at 800×600 (false) and 1440×900 (true), plus the 840
boundary.

#### T2. Shell state

**Create** `mobile/lib/shared/shell/shell_state.dart` — immutable
`ShellState` (incl. `pendingSelectionNonce: int`) + sealed `ShellSidePanel`
(`ShellSidePanelNone`, `ShellSidePanelThread(rootId, {initialMessageId})`,
`ShellSidePanelForumThread(postEventId)`, `ShellSidePanelActivity`) +
`enum ShellMainContent { channels, pulse }`, with `==`/`hashCode` or
equivalent value semantics for testability.

**Create** `mobile/lib/shared/shell/shell_state_provider.dart` —
`ShellStateNotifier extends Notifier<ShellState>`. **`build()` must watch
the active community identity** (e.g. `activeCommunityProvider.select((v)
=> v.unwrapPrevious().value?.id)` from `shared/community/`) and return the
initial state — a community switch rebuilds that chain (it invalidates
`authProvider`), and this watch is the **only** thing that resets shell
state: root providers are NOT reset by widget remounts (critical review
C1). Methods: `selectChannel(String id, {String? initialMessageId, String?
initialThreadRootId})` (closes thread/forum panel, sets
`mainContent = channels`, bumps `pendingSelectionNonce` when initial IDs
are provided), `clearSelection()`, `openThreadPanel(String rootId,
{String? initialMessageId})`, `openForumThreadPanel(String postEventId)`,
`toggleActivityPanel()`, `closeSidePanel()`, `showPulse()`/`showChannels()`;
`final shellStateProvider = NotifierProvider<ShellStateNotifier, ShellState>(…)`.
No feature imports — `shared/community` is `shared/`, so the watch keeps
the layering rule intact; state holds IDs only.

**Tests** — **create**
`mobile/test/shared/shell/shell_state_provider_test.dart`: pure
`ProviderContainer` unit tests for every rule (channel change closes thread
panel; panels mutually exclusive; selectChannel forces channels content;
pending IDs stored; nonce bumps on a repeated identical deep-link
selection; **changing the watched community id resets selection + pending
IDs + open panel to initial**).

#### T3. Adaptive modal helper

**Create** `mobile/lib/shared/widgets/adaptive_modal.dart` —
`Future<T?> showAdaptiveModal<T>(BuildContext context, {required
WidgetBuilder builder, bool isScrollControlled = false, bool showDragHandle =
true, double maxWidth = 480})`. Narrow → `showModalBottomSheet<T>` passing
the params through (preserve current visual defaults). Wide → `showDialog<T>`
with `Dialog(shape: RoundedRectangleBorder(borderRadius:
BorderRadius.circular(Radii.dialog)))` and `ConstrainedBox(constraints:
BoxConstraints(maxWidth: maxWidth))`. If a converted call site needs another
`showModalBottomSheet` parameter (e.g. `backgroundColor`), add it to the
helper rather than bypassing it.

**Tests** — **create**
`mobile/test/shared/widgets/adaptive_modal_test.dart`: at 800×600 finds
`BottomSheet` and no `Dialog`; at 1440×900 finds `Dialog` and no
`BottomSheet`; popping with a value returns it in both modes.

#### T4. Adaptive `HomePage` + `DesktopShell` skeleton

**Modify** `mobile/lib/features/home/home_page.dart`: move the current body
(the `Scaffold`/`IndexedStack`/tab-bar tree plus `_FloatingTabBar`,
`_FloatingTabDestination`, `_HomeDestination`,
`_mediaQueryWithFloatingTabBarClearance` and the tab `useState`) **move-only**
into a new private `_MobileHomeBody` widget in a new part file, keeping the
layout constants accessible; `HomePage.build` becomes
`isExpandedLayout(context) ? const DesktopShell() : const _MobileHomeBody()`.

**Create** `mobile/lib/features/home/home_page/mobile_home_body.dart`
(`part of` the home_page library).

**Create** `mobile/lib/features/home/desktop_shell.dart` — `DesktopShell
extends HookConsumerWidget`; skeleton `Row`: rail placeholder
(`SizedBox(width: Grid.xxl)`), list column `SizedBox(width: 280, child:
ChannelsPage())` (embedding works today; selection still pushes until T8),
`Expanded` message-pane placeholder (centered icon + 'Select a channel'
empty-state styling with `context.colors` / `context.textTheme`). Declare the
`desktop_shell/` part structure as parts are added in later tasks.

**Tests** — **create** `mobile/test/features/home/home_page_test.dart`:
narrow → mobile tab bar present, no `DesktopShell`; wide (1440×900) →
`DesktopShell` present, no tab bar. Use provider overrides for
channels/session/profile as done in
`mobile/test/features/channels/channels_page_test.dart`.

## Green boundary — accepted interim gaps at the end of Part 1

Part 1 must leave `dart format` + `flutter analyze` + `flutter test` fully
green standalone (all 48 pre-existing test files + the 4 new ones). The
following gaps are **accepted and expected** — all invisible until Phase 0
ships a desktop runtime — and must NOT be "fixed" in this part:

- At wide widths, selecting a channel in the embedded list still **pushes**
  a full-window `ChannelDetailPage` (selection branching is Part 2/T8).
- The rail is a placeholder `SizedBox`; the message pane always shows the
  empty state (Part 2 fills both).
- `showAdaptiveModal` has zero production call sites; sheets still render
  as bottom sheets at wide widths (conversions are Part 4/T13).
- `ShellStateNotifier`'s panel/pulse methods and the `ShellSidePanel`
  thread/forum/activity variants have no UI consumers (Parts 3–4). They are
  covered by the T2 provider unit tests — do not delete as dead code.
- No side panel, no keyboard layer, no search at wide, no right-click, no
  drag-drop (Parts 3–4).

## Auto-resolved assumptions (relevant to this part)

1. **Skill interactivity resolved silently** (run-level): detail level =
   extensive; no external research (strong local context — pure
   Flutter/Dart layout work, no new dependencies, no security surface); no
   user-flow-analysis agent run (flow coverage derives from the verified
   seam inventory); no branch setup performed (orchestrator owns the
   branch: `wingspan/desktop-phase1-run`).
2. **Workspace keying is a record key including a selection nonce**
   (`ValueKey((channelId, initialMessageId, initialThreadRootId,
   pendingSelectionNonce))`; the nonce bumps whenever a selection carries
   pending IDs), so even a *repeated identical* deep link remounts —
   matching today's push-a-fresh-route behavior. Plain re-selection of the
   current channel (no pending IDs) keeps the key stable and does not
   remount. (T2 supplies the nonce; Part 2/T6 consumes it.)
3. **`ShellSidePanel` gains a `forumThread(postEventId)` variant** (channel
   comes from the current selection) — refinement of the brainstorm's sealed
   shape to keep `shared/` ID-only.
4. **Test-count correction**: the regression gate is the 48 existing
   `*_test.dart` files (the brainstorm's "49" counted the
   `widget_helpers.dart` helper).
5. Brainstorm defaults reaffirmed without re-opening: expanded breakpoint
   840; sheets → centered dialogs uniformly (`maxWidth` 480);
   settings/pairing/media-viewer/pulse compose stay pushed routes; no
   resize-crossing state migration (dormant selection at narrow, stacked
   route at wide — documented, accepted). The brainstorm's 1200/docked
   tier was cut by technical review S2 (overlay-only in Phase 1; docked
   promotion deferred to Phase 0 visual QA).
6. **Technical-review fix-cycle defaults (2026-07-26)**: C1 shell-state
   reset implemented by watching the *active community id* rather than raw
   `authProvider` (narrower — avoids spurious resets from unrelated auth
   emissions while still catching switches, which invalidate that chain);
   the repeated-identical-deep-link remount gap is closed with the
   monotonic `pendingSelectionNonce` (chosen over documenting it as a known
   exception).

## Risks & Mitigations (relevant to this part)

1. **Mobile regression from the move-only home-body extraction** (`HomePage`
   is load-bearing): the extraction preserves the exact tree; the 48
   existing test files gate the task; the narrow-width shell test added in
   T4 pins the mobile path.
2. **No desktop runtime exists to verify visually**: proof is analyze +
   wide-surface widget tests (1440×900 standard); all layout constants live
   in `breakpoints.dart` + shell files for cheap retuning during Phase 0 QA.
3. **Two navigation models + resize edge cases**: crossing wide→narrow
   leaves shell selection dormant; narrow→wide leaves a pushed detail route
   stacked over the shell until popped; breakpoint-crossing also resets
   `_MobileHomeBody` tab state. Accepted for Phase 1, documented here — no
   auto-pop machinery (YAGNI).
4. **`showAdaptiveModal` snapshots width at open time**: a window resized
   across the breakpoint while a sheet/dialog is open keeps the stale
   presentation until dismissed. Accepted for Phase 1 (unreachable before
   Phase 0 ships a resizable window); flagged for Phase 0 visual QA.

## Non-Goals / Deferred (do not build in this part)

- Everything in Parts 2–4: selection branching, `ChannelWorkspace`,
  community rail, view extractions, side panels, sheet-site conversions,
  shortcuts, composer key handling, drop seam, pulse rail entry.
- No Phase 0 work (platform folders, `flutter create`, native code, real
  drag-drop backend, visual QA).
- No Bucket A/B features (home inbox/feed, onboarding, workflows, OS
  notifications, reminders, moderation, members admin, channel templates,
  agent-memory, agents, projects, mesh-compute, local-archive, huddle,
  avatar studio).
- No dependency swaps (`image_picker`→`file_selector`,
  `video_player`→`media_kit`, `desktop_drop`, `window_manager`,
  `super_clipboard`).
- No windowed/hover media viewer, no custom window chrome, no
  GoRouter/Navigator 2.0, no pane resize/persistence, no quick-switcher, no
  anchored popovers/context menus, no mobile navigation changes.
- No docked side-panel column (overlay-only; review S2), no
  selected-channel highlight, no drop-target hover/highlight visuals
  (review S1), no "large"/1200 breakpoint tier.
