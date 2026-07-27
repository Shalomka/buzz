---
title: 'feat: Flutter desktop parity shell — Part 3: Side panel (thread/forum/activity)'
type: feat
date: 2026-07-26
part: 3 of 4
status: ready-for-build
parent-plan: docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md
brainstorm: docs/brainstorm/2026-07-26-flutter-desktop-parity-shell-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§5, §9 Phase 1)
depends-on: docs/plan/2026-07-26-feat-parity-shell-part-2-plan.md
---

# feat: Flutter desktop parity shell — Part 3 of 4: Side panel (T9–T12)

> **Standalone build input.** This file is the complete specification for
> Part 3 — the build receives only this file. It was split from
> `docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md` into 4
> stacked parts. Task numbers T1–T19 are global across the series; any
> reference to a task outside T9–T12 describes another part (T1–T8 landed
> in Parts 1–2 and is available to build on; T13–T19 is Part 4 — context
> only, never scope for this build).

## Overview

Phase 1 of the Flutter desktop port (source: `mobile/DESKTOP_PORT_PLAN.md`
§9 Phase 1) builds a width-adaptive multi-pane shell entirely in portable
Dart under `mobile/lib` + `mobile/test`. Below 840dp the existing mobile UX
renders byte-for-byte unchanged. At ≥ 840dp the `DesktopShell` (Parts 1–2)
already composes `community rail | channel list pane | message pane` with
push-free channel selection.

Phase 0 (desktop platform folders) has **not** landed. Everything here is
verifiable exclusively via `dart format`, `flutter analyze`, and
`flutter test` (wide-surface widget tests are the desktop proxy).

**Part 3 (this plan) adds the right-edge side panel:**

- **T9** — `ThreadView` move-only extraction
- **T10** — thread panel in `ChannelWorkspace` + width-branching at all 4
  thread-open sites (incl. nested-thread head resolution + deep-link
  loader fallback)
- **T11** — `ForumThreadView` extraction + forum-post branching
- **T12** — Activity panel + `SidePanelHost` + Esc-to-close

The side panel is **overlay-only** at every wide width (technical review
S2 — the docked fourth-column variant is deferred to Phase 0 visual QA).
Part 4 converts sheets and adds the input layer (T13–T19).

## Dependencies

**Builds on:** Part 2 —
`docs/plan/2026-07-26-feat-parity-shell-part-2-plan.md` (which builds on
Part 1). Base branch: the Part 2 PR branch (stack the PR on it; if Part 2
has already merged, base is `main`).

**Inherited from Parts 1–2 (exists on the base branch — do not recreate):**

- Part 1: `mobile/lib/shared/layout/breakpoints.dart`
  (`isExpandedLayout(BuildContext)`, `kExpandedLayoutMinWidth` = 840);
  `mobile/lib/shared/shell/shell_state.dart` (immutable `ShellState` with
  `selectedChannelId`, pending initial-message/thread IDs,
  `pendingSelectionNonce`, sealed `ShellSidePanel` — **`ShellSidePanelNone`,
  `ShellSidePanelThread(rootId, {initialMessageId})`,
  `ShellSidePanelForumThread(postEventId)`, `ShellSidePanelActivity`** —
  and `ShellMainContent { channels, pulse }`);
  `mobile/lib/shared/shell/shell_state_provider.dart` (`shellStateProvider`;
  methods `selectChannel`, `clearSelection`, **`openThreadPanel(String
  rootId, {String? initialMessageId})`, `openForumThreadPanel(String
  postEventId)`, `toggleActivityPanel()`, `closeSidePanel()`**, `showPulse`,
  `showChannels`; community-id watch resets state on switch; panels are
  structurally mutually exclusive via the single `sidePanel` field;
  `selectChannel` closes thread/forum panels). The panel methods were
  **unused by UI until this part** — this part wires them.
  Also `mobile/lib/shared/widgets/adaptive_modal.dart` (`showAdaptiveModal`
  — still unused in production until Part 4; leave as is).
- Part 1: `mobile/lib/features/home/home_page.dart` is the adaptive switch
  (`isExpandedLayout ? DesktopShell : _MobileHomeBody`; mobile body in
  `home_page/mobile_home_body.dart`).
- Part 2: `mobile/lib/features/channels/channel_detail_page/detail_view.dart`
  — public `ChannelDetailView` (same constructor as the page), a `part` of
  the channel_detail_page library.
- Part 2: `mobile/lib/features/channels/channel_workspace.dart` —
  `ChannelWorkspace` resolves the selected `Channel` from
  `channelsProvider`, renders `ChannelDetailView` keyed by
  `ValueKey((channelId, initialMessageId, initialThreadRootId,
  pendingSelectionNonce))`, shows an empty state otherwise, and **reserves
  a private right-edge side-panel placeholder slot inside a `Stack` — T10
  fills that slot.**
- Part 2: `mobile/lib/features/home/desktop_shell/community_rail.dart` —
  `CommunityRail` `part` of the desktop_shell library (community avatars,
  `+` add, `ProfileAvatar`→Settings). **T12 adds the activity bell here.**
- Part 2: selection is already width-branched at `channels_page.dart`
  (`openChannel`), `channel_link_navigation.dart`,
  `deep_link_dispatcher.dart` (wide: `popUntil(isFirst)` +
  `selectChannel(id, initialMessageId, initialThreadRootId)` — **the
  pending thread-root this part turns into an open panel**), and
  `invite_join_sheet.dart`.
- Tests on base (all green, keep green): the original 48 files + Part 1's
  `breakpoints_test.dart`, `shell_state_provider_test.dart`,
  `adaptive_modal_test.dart`, `home_page_test.dart` + Part 2's
  `channel_workspace_test.dart`, `desktop_shell_test.dart` (this part
  extends the last two).

**Part 4 consumes from this part — do NOT remove or "clean up" these
seams:**

- `ThreadView` and its extracted reply rows
  (`thread_detail_page/thread_view.dart`): Part 4/T14 adds
  `onSecondaryTapUp` (right-click) to those rows.
- The root `CallbackShortcuts` + `Focus(autofocus: true)` structure in
  `desktop_shell.dart` with the single Esc binding (T12): Part 4/T16 moves
  it into a `shell_shortcuts.dart` part and extends the map — build it as
  a structure ready for more entries, exactly as T12 says.
- `SidePanelHost` and the overlay panel presentation: Part 4 leaves them
  alone but its shortcut layer calls `closeSidePanel()`.
- `ForumThreadPage`'s two `showModalBottomSheet` sites move with the T11
  extraction — keep them as `showModalBottomSheet` (Part 4/T13 converts).

## Hard Constraints (fixed — inherited from the run)

- Pure Dart under `mobile/lib` and `mobile/test` only. No platform folders,
  no `flutter create/run/build/clean/upgrade`, no runner/native code.
- **Zero new pub dependencies** — `mobile/pubspec.yaml` must be unchanged.
- Existing mobile UX unchanged at narrow widths; all pre-existing tests stay
  green. (The full plan's single documented exception — hardware-keyboard
  Enter-to-send at every width — belongs to Part 4/T17. **Part 3 allows no
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

- `mobile/lib/features/channels/thread_detail_page/thread_view.dart` (T9)
- `mobile/lib/features/forum/forum_thread_page/forum_thread_view.dart` (T11)
- `mobile/lib/features/home/desktop_shell/side_panel_host.dart` (T12)
- (only if the line cap requires it) a `part` file for `ActivityView`
  under `mobile/lib/features/activity/` (T12 allows same-file or `part`)

**Modifies:**

- `mobile/lib/features/channels/thread_detail_page.dart` (T9, T10)
- `mobile/lib/features/channels/channel_workspace.dart` (T10, T11)
- `mobile/lib/features/channels/channel_detail_page/message_list.dart` (T10)
- `mobile/lib/features/channels/channel_detail_page/system_rows.dart` (T10)
- `mobile/lib/features/channels/message_actions.dart` (T10)
- `mobile/lib/features/forum/forum_thread_page.dart` (T11)
- `mobile/lib/features/forum/forum_posts_view.dart` (T11)
- `mobile/lib/features/activity/activity_page.dart` (T12)
- `mobile/lib/features/home/desktop_shell/community_rail.dart` (T12)
- `mobile/lib/features/home/desktop_shell.dart` (T12)
- `mobile/test/features/channels/channel_workspace_test.dart` (extend)
- `mobile/test/features/home/desktop_shell_test.dart` (extend)

No other file may change. (Exception, only if the 1000-line cap forces it:
an additional `part` file under the same page's folder, noted in the PR
description.)

## Codebase Context & Conventions (verified — build may trust this and skip its own codebase review)

All facts below were verified against the repo on 2026-07-26 (paths, symbols,
and line numbers) **before Parts 1–2 landed**. Where a bullet conflicts with
the changes listed under Dependencies (e.g. the deep-link dispatcher now
width-branches), the Dependencies section wins. Line numbers are anchors,
not exact contracts — re-locate by symbol if a file shifted.

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
  types — the shell state holds IDs only.
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
  original 48 plus the 6 files Parts 1–2 added.
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

### Verified code seams (subset relevant to Part 3; other parts' seams trimmed)

- `mobile/lib/app.dart` — `App extends HookConsumerWidget`; `MaterialApp`
  with provider-driven auth `switch`: authenticated →
  `DeepLinkDispatcher(child: HomePage())`, else
  `DeepLinkDispatcher(dispatchMessageLinks: false, child: PairingPage())`.
  **Not modified in this plan.**
- `mobile/lib/features/channels/channel_detail_page.dart` (351 lines; parts:
  `channel_detail_page/{message_list,system_rows,message_bubble,banners,app_bar}.dart`,
  plus `detail_view.dart` from Part 2)
  — `ChannelDetailPage({required Channel channel, String? initialMessageId,
  String? initialThreadRootId})`. Renders `ForumPostsView` inline when
  `channel.isForum` (`channel_detail_page.dart:270`;
  `Channel.isForum` at `channel.dart:77`), else message list + `ComposeBar`,
  inside `FrostedScaffold`/`FrostedAppBar`. **Read-state marking** is a
  `useEffect(…, [channel.id, readState.isReady, readTimestamp])` calling
  `deferReadStateUpdate(…)` (`channel_detail_page.dart:170-182`). The
  **deep-link loader fallback pattern** T10 reuses lives at
  `channel_detail_page.dart:52-64` —
  `ref.read(channelMessagesProvider(channelId).notifier)
  .loadEventsById({id})`.
- **All 4 `ThreadDetailPage` push sites** (each must width-branch in T10):
  1. `channel_detail_page/message_list.dart:98-108` — initial-thread
     deep-link effect (inside `addPostFrameCallback`);
  2. `channel_detail_page/system_rows.dart:163-165` — thread summary row tap
     (the primary user path);
  3. `mobile/lib/features/channels/thread_detail_page.dart:328` — nested
     thread from within a thread;
  4. `mobile/lib/features/channels/message_actions.dart:109` — open-thread
     action from the message actions surface.
- `mobile/lib/features/channels/thread_detail_page.dart` (615 lines, no
  parts before T9) — `ThreadDetailPage({required TimelineMessage threadHead,
  required List<TimelineMessage> allMessages, required String channelId,
  required String? currentPubkey, required bool isMember, required bool
  isArchived, String? initialMessageId})`. Watches
  `threadRepliesProvider(ThreadRepliesArgs(channelId, rootId))`; renders
  head + replies + `ComposeBar`; `showMessageActions` via `onLongPress` at
  line 428.
- **Timeline shape (drives T10's nested-thread rule)**: the main timeline
  from `formatTimeline` contains only roots + broadcast replies
  (`timeline_message.dart:376-394`) — a nested-thread open (reply ID as
  root) would never match it.
- `mobile/lib/features/forum/forum_thread_page.dart` (600 lines) —
  `ForumThreadPage({required String channelId, required String postEventId,
  required String? currentPubkey, required bool isMember, required bool
  isArchived})` — **self-sufficient (loads by IDs)**. Pushed from
  `mobile/lib/features/forum/forum_posts_view.dart:161` (single site).
- `mobile/lib/features/channels/deep_link_dispatcher.dart` —
  `MessageDeepLink` carries `channelId`, `messageId`, `threadRootId`.
  **[Part 2 note: at wide the dispatcher already writes
  `selectChannel(channel.id, initialMessageId: link.messageId,
  initialThreadRootId: link.threadRootId)` after `popUntil(isFirst)` — no
  push. This part makes the pending `initialThreadRootId` open the thread
  panel via the workspace/detail-view initial-thread effect.]**
- **`showMessageActions` entry** (`message_actions.dart:23`) — the message
  actions surface is a bottom sheet today; its open-thread action at
  `message_actions.dart:109` is T10's fourth branch site (close the actions
  surface first, then write state). Long-press callers:
  `channel_detail_page/message_bubble.dart:45`,
  `channel_detail_page/system_rows.dart:39`, `thread_detail_page.dart:428`
  (right-click arrives in Part 4/T14 — not here).
- **Communities**: `mobile/lib/shared/community/community_provider.dart` —
  `communityListProvider`, `activeCommunityProvider`, switch via
  `ref.read(communityListProvider.notifier).switchCommunity(id)`. The
  Part 1 `shellStateProvider` resets on community switch (its `build()`
  watches the active community id) — a switch therefore also closes any
  open side panel (asserted in the Part 1 provider test).
- **Unread badge**: `unreadBadgeProvider` →
  `UnreadBadgeState{highPriorityCount, generalUnreadCount}`
  (`mobile/lib/features/channels/unread_badge/unread_badge_provider.dart`;
  usage example in `app.dart:48-56`). T12's bell badge reads this.
- **Chrome**: `mobile/lib/shared/widgets/frosted_app_bar.dart` —
  `frostedAppBarHeight(context) = MediaQuery.paddingOf(context).top + 48`
  (degrades to 48 with no status bar); `FrostedAppBar` auto-shows a back
  button only when `Navigator.canPop(context)` → **embedded panes at the
  shell root get no back button automatically**. `FrostedScaffold` overlays
  the bar in a Stack.
- **Activity**: `mobile/lib/features/activity/activity_page.dart` —
  `ActivityPage extends HookConsumerWidget`; `FrostedScaffold(appBar:
  FrostedAppBar(title: Text('Activity')), …)` at line 112; body built inline
  (needs a move-only `ActivityView` extraction to embed — T12).
- **Keyboard**: zero existing `Shortcuts`/`CallbackShortcuts`/
  `LogicalKeyboardKey` usage in `mobile/lib` at this part's base — the
  shortcut layer is greenfield and **T12 lands its first piece** (root
  `CallbackShortcuts` + `Focus(autofocus: true)` with the single Esc
  binding). Flutter's default `DismissIntent` handling already closes
  dialogs on Esc; the shell only needs Esc for side panels.
- **Push inventory**: 23 `Navigator.of(context).push` call sites across 17
  files (pre-split count). Only the thread/forum seams listed in this
  part's tasks change here; settings, pairing, media viewer, pulse compose
  intentionally remain full-window pushes.

## Technical Approach

The full-phase design context; this part implements the side panel.

### Layout model *(context; the overlay is implemented here)*

```
width < 840              → existing mobile shell (untouched)
width ≥ 840 ("expanded") → | rail 64 | list 280 | messages flex |
                            thread/activity panel = right-edge overlay (360)
```

`isExpandedLayout(context)` (≥ 840, from Part 1) is the single width
predicate. The side panel is a single right-edge **overlay** presentation
at every wide width — the docked fourth-column variant (and with it any
≥ 1200 "large" tier) is cut from Phase 1 per technical review S2 and
deferred to Phase 0 visual QA. No pane resizing/persistence in Phase 1.

### Shell state *(landed in Part 1 — consume, don't reimplement)*

`sidePanel: ShellSidePanel` (sealed: `none | thread(rootId,
initialMessageId?) | forumThread(postEventId) | activity`). Opening any
side panel closes the other kind (single `sidePanel` field makes exclusion
structural). `selectChannel` closes any thread/forum panel. State is
ignored at narrow widths (push navigation remains authoritative there).

### Composition *(this part fills the reserved panel slot)*

- View extractions are move-only `part` files of their existing page
  libraries (`thread_view.dart`, `forum_thread_view.dart`; `ActivityView`
  may stay a same-file public widget if under the line cap); the existing
  pages keep their constructors and delegate. Embedders import the page
  library and use the public View class.
- `ChannelWorkspace` (Part 2) already keys `ChannelDetailView` by
  `ValueKey((channelId, initialMessageId, initialThreadRootId,
  pendingSelectionNonce))` and reserves the panel slot this part fills.
- Panel presentation (all wide widths — **overlay only**, review S2):
  right-aligned `Positioned` width 360 inside a `Stack`, elevated surface
  (`Material` + shadow), messages remain visible beneath. Thread/forum
  panels render inside `ChannelWorkspace`; the Activity panel renders in
  the shell-level `SidePanelHost` (T12).

### Navigation branching (this part's rows)

| Seam | Narrow (< 840) | Wide (≥ 840) | Part |
|---|---|---|---|
| Thread open (4 sites listed in the seams) | push `ThreadDetailPage` (unchanged) | `openThreadPanel(rootId, …)` | **3 (T10)** |
| Forum post open (`forum_posts_view.dart:161`) | push `ForumThreadPage` (unchanged) | `openForumThreadPanel(postEventId)` | **3 (T11)** |
| Channel select / links / deep links / invite | push (unchanged) | `selectChannel(…)` | 2 — done |
| Search hits (3 sites in `search_page.dart`) | push (unchanged) | pop overlay dialog + `selectChannel(…)` | 4 — do not touch |
| Settings, pairing, media viewer, pulse compose | push | push (unchanged — intentionally full-window) | — |

### Sheets → dialogs / full keyboard layer / drag-drop *(Part 4)*

Not part of Part 3 — except the single Esc binding T12 introduces. Sheets
keep rendering as bottom sheets at wide widths until Part 4.

## Acceptance Criteria

### Machine-checkable gates

- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && flutter analyze` reports **zero** issues.
- [ ] `cd mobile && flutter test` passes — including all 48 original test
      files and the 6 Part 1–2 test files, none deleted, skipped, or
      weakened.
- [ ] `mobile/pubspec.yaml` is byte-identical (zero new dependencies).
- [ ] The diff touches only `mobile/lib/**` and `mobile/test/**`, and only
      the files in this part's Declared File Scope.
- [ ] Every file under `mobile/lib` and `mobile/test` is ≤ 1000 lines
      (`thread_view.dart` will carry ~550 moved lines — watch it);
      `mobile/scripts/check-file-sizes.mjs` is untouched and its `overrides`
      map stays empty.
- [ ] No new `StatefulWidget`/`ConsumerStatefulWidget`; no `print()`; single
      quotes per lint.
- [ ] The behavioral tests below exist in the extended
      `mobile/test/features/channels/channel_workspace_test.dart` and
      `mobile/test/features/home/desktop_shell_test.dart`.

### Behavioral gates (each is a named widget test run by `flutter test`)

- [ ] At 1440×900 with a thread open: panel renders as a right-edge
      **overlay** (single presentation — the docked variant is deferred to
      Phase 0).
- [ ] Opening a **nested** thread (a reply ID as root) resolves the head
      from the full message set including replies — no permanent spinner;
      an ID outside the loaded window triggers the deep-link loader
      fallback.
- [ ] Thread panel and activity panel are mutually exclusive; opening one
      closes the other (widget-level, via bell + thread open).
- [ ] Esc closes an open side panel.
- [ ] Close button and channel-switch both clear the thread panel.
- [ ] Deep-link-style selection with `initialThreadRootId` opens the thread
      panel (completes the Part 2 dispatcher path end-to-end).
- [ ] Forum channel: opening a post at wide renders `ForumThreadView` in
      the panel slot (no push); narrow push unchanged.
- [ ] Activity bell toggles the activity panel; the bell badge renders with
      a fake `unreadBadgeProvider` override.
- [ ] Existing thread-related tests, `forum_widgets_test.dart`, and
      `activity_page_test.dart` pass unchanged (proves the extractions are
      move-only).

## Implementation Tasks (ordered)

Every task must leave `dart format` + `flutter analyze` + `flutter test`
green.

### Part C — Side panel (thread / forum / activity)

#### T9. `ThreadView` extraction (move-only)

**Modify** `mobile/lib/features/channels/thread_detail_page.dart`: convert to
a library head with `part 'thread_detail_page/thread_view.dart'`; move the
body (everything inside the current FrostedScaffold body, plus the private
reply-row widgets) into public `ThreadView` with the same seven inputs
(`threadHead`, `allMessages`, `channelId`, `currentPubkey`, `isMember`,
`isArchived`, `initialMessageId`). `ThreadDetailPage` keeps constructor +
FrostedScaffold/app-bar chrome and hosts `ThreadView`.

**Create** `mobile/lib/features/channels/thread_detail_page/thread_view.dart`.
Both files must stay ≤ 1000 lines (615 today — comfortable).

**Tests** — existing thread-related tests must pass unchanged.

#### T10. Thread panel in `ChannelWorkspace` + thread-open branching

**Modify** `mobile/lib/features/channels/channel_workspace.dart`:
- When `sidePanel is ShellSidePanelThread`: derive panel inputs from
  `events = ref.watch(channelMessagesProvider(channelId))` and
  `currentPubkey`, but resolve `threadHead` against the **full formatted
  message set including replies** — the main timeline from `formatTimeline`
  contains only roots + broadcast replies
  (`timeline_message.dart:376-394`), so a nested-thread open (reply ID as
  root) would never match it and would spin forever (review M1). Build the
  lookup over every event (format without the root-only filter, or locate
  the raw event by ID and format it). If `rootId` is still absent from the
  loaded window, trigger the existing deep-link loader fallback —
  `ref.read(channelMessagesProvider(channelId).notifier)
  .loadEventsById({rootId})` (pattern: `channel_detail_page.dart:52-64`) —
  and show a loading state until it lands (no permanent spinner).
  `isMember`/`isArchived` come from the resolved `Channel`. Render
  `ThreadView(key: ValueKey(rootId), …)` with a small panel header (title +
  close `IconButton` → `closeSidePanel()`).
- Panel presentation (all wide widths — **overlay only**, review S2):
  right-aligned `Positioned` width 360 inside a `Stack`, elevated surface
  (`Material` + shadow), messages remain visible beneath. No docked
  variant in Phase 1.

**Modify the 4 thread push sites** to width-branch to
`openThreadPanel(rootId, initialMessageId: …)`:
`channel_detail_page/message_list.dart:98-108` (initial-thread effect),
`channel_detail_page/system_rows.dart:163-165` (summary tap),
`thread_detail_page.dart:328` (nested → replaces panel content by state
write), `message_actions.dart:109` (close the actions surface first, then
write state). Narrow behavior byte-identical.

**Tests** — extend `channel_workspace_test.dart`: thread opens as a
right-edge overlay at 1440×900; **nested-thread open (reply ID as root)
resolves the head and renders** (fake providers seeded so the reply is not
in the main timeline; plus a case exercising the `loadEventsById`
fallback); close button and channel-switch both clear it; deep-link-style
selection with `initialThreadRootId` opens the panel (covers the T8
dispatcher path end-to-end).

#### T11. `ForumThreadView` extraction + forum branching

**Modify** `mobile/lib/features/forum/forum_thread_page.dart`: same pattern —
`part 'forum_thread_page/forum_thread_view.dart'`; public `ForumThreadView`
with the page's five inputs; page keeps chrome + constructor.

**Create** `mobile/lib/features/forum/forum_thread_page/forum_thread_view.dart`.

**Modify** `mobile/lib/features/forum/forum_posts_view.dart` (line ~161):
wide → `openForumThreadPanel(postEventId)`; narrow → existing push.

**Modify** `mobile/lib/features/channels/channel_workspace.dart`: render
`ForumThreadView(key: ValueKey(postEventId), channelId: selectedChannelId,
postEventId: …, …)` in the same panel slot for
`ShellSidePanelForumThread` (member/archived flags from the resolved
channel).

**Tests** — extend `channel_workspace_test.dart` (forum channel selected →
tapping a post opens the panel — or a focused test with fakes); existing
`mobile/test/features/forum/forum_widgets_test.dart` stays green.

#### T12. Activity panel + side-panel host + Esc

**Modify** `mobile/lib/features/activity/activity_page.dart`: extract the
FrostedScaffold body **move-only** into a public `ActivityView` widget
(same file or a `part` — keep under the line cap); `ActivityPage` hosts it.

**Create** `mobile/lib/features/home/desktop_shell/side_panel_host.dart`
(part of desktop_shell) — renders the Activity panel (header + close +
`ActivityView`) as a right-edge overlay (width 360, same overlay-only
presentation as the thread panel, review S2) when
`sidePanel is ShellSidePanelActivity`.

**Modify** `mobile/lib/features/home/desktop_shell/community_rail.dart`: add
the activity bell button with unread badge (counts from
`unreadBadgeProvider`) toggling `toggleActivityPanel()`.

**Modify** `mobile/lib/features/home/desktop_shell.dart`: mount
`SidePanelHost`; add a root `CallbackShortcuts` + `Focus(autofocus: true)`
with the single binding `Esc → closeSidePanel()` (the full shortcut set
arrives in T16; keep the structure ready for more entries).

**Tests** — extend `desktop_shell_test.dart`: bell toggles the activity
panel; opening activity closes an open thread panel and vice versa (mutual
exclusion); Esc closes the open panel; badge renders with a fake
`unreadBadgeProvider` override. Existing
`mobile/test/features/activity/activity_page_test.dart` stays green
(extraction is move-only).

## Green boundary — accepted interim gaps at the end of Part 3

Part 3 must leave `dart format` + `flutter analyze` + `flutter test` fully
green standalone (48 original + 6 Part 1–2 test files, all extended files
included). The following gaps are **accepted and expected** — all invisible
until Phase 0 ships a desktop runtime — and must NOT be "fixed" in this
part:

- **Search is unreachable at wide widths** (the search overlay is
  Part 4/T15).
- **Sheets still render as bottom sheets at wide widths** — including the
  message-actions surface T10 branches out of (Part 4/T13 converts all 21
  sites; `showAdaptiveModal` stays unused in production).
- The keyboard layer is Esc-only (Cmd/Ctrl+K, Cmd/Ctrl+comma, and the
  channel-navigation chords are Part 4/T16); no right-click
  (Part 4/T14), no composer Enter handling (T17), no drag-drop seam (T18),
  no pulse rail entry (T19).
- `ThreadView`'s reply rows keep long-press-only actions until Part 4/T14
  adds `onSecondaryTapUp`.

## Auto-resolved assumptions (relevant to this part)

1. **Skill interactivity resolved silently** (run-level): detail level =
   extensive; no external research; no branch setup by the plan stage
   (orchestrator owns branches; this part stacks on Part 2).
2. **View extractions are `part` files of their existing page libraries**
   (`thread_view.dart`, `forum_thread_view.dart`), so private helpers stay
   accessible without exporting internals; embedders import the page
   library and use the public View class. `ActivityView` may stay a
   same-file public widget if under the line cap.
3. **`ShellSidePanel` has a `forumThread(postEventId)` variant** (channel
   comes from the current selection) — refinement of the brainstorm's
   sealed shape to keep `shared/` ID-only (landed in Part 1; consumed
   here).
4. **All four verified thread-open sites branch** (brainstorm named the
   primary ones; `message_actions.dart:109` and nested-thread
   `thread_detail_page.dart:328` are included for consistency).
5. Brainstorm defaults reaffirmed: no auto-open thread behaviors; the
   1200/docked tier was cut by technical review S2 (overlay-only in
   Phase 1; docked promotion deferred to Phase 0 visual QA).

## Risks & Mitigations (relevant to this part)

1. **Mobile regression from move-only extractions** (thread/forum/activity
   pages are load-bearing): wrappers preserve constructor contracts; the
   full pre-existing suite gates every task.
2. **Nested-thread head resolution** (review M1 — the subtlest new logic in
   this part): the main timeline excludes non-broadcast replies, so the
   head lookup must run over the full event set, with the
   `loadEventsById` fallback for IDs outside the loaded window; dedicated
   tests seed a reply absent from the main timeline and exercise the
   fallback.
3. **1000-line cap pressure** on `thread_view.dart` (~550+ moved lines):
   split along part seams if a file approaches the cap; never touch the
   size-check script.
4. **`CallbackShortcuts` focus dependency**: bindings only fire when focus
   is inside the shell subtree — mitigated with the `Focus(autofocus:
   true)` fallback (T12) and tests that exercise Esc without a focused
   field.
5. **No desktop runtime exists to verify visually**: proof is analyze +
   wide-surface widget tests (1440×900 standard); panel constants (360
   width, overlay elevation) live in shell files for cheap Phase 0
   retuning — including promoting the overlay to a docked column if QA
   wants it.

## Non-Goals / Deferred (do not build in this part)

- Everything in Part 4: sheet-site conversions, right-click, media-viewer
  Esc, search overlay + `SearchView`, global shortcuts beyond Esc,
  channel-order helper, composer key handling, drop seam, pulse rail
  entry.
- No Phase 0 work (platform folders, native code, real drag-drop backend,
  visual QA). No Bucket A/B features. No dependency swaps.
- No windowed/hover media viewer, no custom window chrome, no
  GoRouter/Navigator 2.0, no pane resize/persistence, no quick-switcher, no
  anchored popovers/context menus, no mobile navigation changes.
- No docked side-panel column (overlay-only; review S2), no
  selected-channel highlight, no "large"/1200 breakpoint tier, no
  auto-open thread behaviors.
