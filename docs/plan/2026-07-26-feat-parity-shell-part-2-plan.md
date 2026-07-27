---
title: 'feat: Flutter desktop parity shell — Part 2: Shell panes & selection'
type: feat
date: 2026-07-26
part: 2 of 4
status: ready-for-build
parent-plan: docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md
brainstorm: docs/brainstorm/2026-07-26-flutter-desktop-parity-shell-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§5, §9 Phase 1)
depends-on: docs/plan/2026-07-26-feat-parity-shell-part-1-plan.md
---

# feat: Flutter desktop parity shell — Part 2 of 4: Shell panes & selection (T5–T8)

> **Standalone build input.** This file is the complete specification for
> Part 2 — the build receives only this file. It was split from
> `docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md` into 4
> stacked parts. Task numbers T1–T19 are global across the series; any
> reference to a task outside T5–T8 describes another part (T1–T4 landed in
> Part 1 and is available to build on; T9–T19 are later parts — context
> only, never scope for this build).

## Overview

Phase 1 of the Flutter desktop port (source: `mobile/DESKTOP_PORT_PLAN.md`
§9 Phase 1) builds a width-adaptive multi-pane shell entirely in portable
Dart under `mobile/lib` + `mobile/test`. Below 840dp the existing mobile UX
renders byte-for-byte unchanged. At ≥ 840dp the `DesktopShell` (skeleton
landed in Part 1) composes `community rail | channel list pane | message
pane` from the existing feature widgets via move-only "View" extractions.

Phase 0 (desktop platform folders) has **not** landed. Everything here is
verifiable exclusively via `dart format`, `flutter analyze`, and
`flutter test` (wide-surface widget tests are the desktop proxy). The shell
is dormant on phones today.

**Part 2 (this plan) makes the shell functional:**

- **T5** — `ChannelDetailView` move-only extraction
- **T6** — `ChannelWorkspace` (empty state + keyed embed + read-state)
- **T7** — community rail (switch/add community, settings avatar)
- **T8** — channel-selection branching at every seam (list tap, channel
  links, deep links, invite post-join)

Part 3 adds the thread/forum/activity side panel (T9–T12); Part 4 converts
sheets and adds the input layer (T13–T19).

## Dependencies

**Builds on:** Part 1 —
`docs/plan/2026-07-26-feat-parity-shell-part-1-plan.md`. Base branch: the
Part 1 PR branch (stack the PR on it; if Part 1 has already merged, base is
`main`).

**Inherited from Part 1 (exists on the base branch — do not recreate):**

- `mobile/lib/shared/layout/breakpoints.dart` —
  `isExpandedLayout(BuildContext)`, `kExpandedLayoutMinWidth` (840). This
  supersedes the seam note below that "no breakpoint code exists".
- `mobile/lib/shared/shell/shell_state.dart` — immutable `ShellState`
  (`selectedChannelId`, `pendingInitialMessageId`,
  `pendingInitialThreadRootId`, `pendingSelectionNonce`, `sidePanel:
  ShellSidePanel` sealed (`none | thread | forumThread | activity`),
  `mainContent: ShellMainContent { channels, pulse }`).
- `mobile/lib/shared/shell/shell_state_provider.dart` —
  `shellStateProvider` + `ShellStateNotifier` with `selectChannel(id,
  {initialMessageId, initialThreadRootId})` (closes panels, forces
  `channels` content, bumps the nonce when initial IDs are provided),
  `clearSelection()`, `openThreadPanel`, `openForumThreadPanel`,
  `toggleActivityPanel`, `closeSidePanel`, `showPulse`/`showChannels`;
  `build()` watches the active community id and resets on community switch.
- `mobile/lib/shared/widgets/adaptive_modal.dart` — `showAdaptiveModal`
  (unused in production until Part 4; leave as is).
- `mobile/lib/features/home/home_page.dart` — now the adaptive switch:
  `isExpandedLayout(context) ? const DesktopShell() : const
  _MobileHomeBody()`; the mobile body lives move-only in
  `mobile/lib/features/home/home_page/mobile_home_body.dart`.
- `mobile/lib/features/home/desktop_shell.dart` — `DesktopShell` skeleton
  `Row`: rail placeholder (`SizedBox(width: Grid.xxl)`), list column
  `SizedBox(width: 280, child: ChannelsPage())`, `Expanded` message-pane
  placeholder with 'Select a channel' empty state. **This part replaces the
  rail placeholder (T7) and the message-pane placeholder (T6).**
- Tests: `mobile/test/shared/layout/breakpoints_test.dart`,
  `mobile/test/shared/shell/shell_state_provider_test.dart`,
  `mobile/test/shared/widgets/adaptive_modal_test.dart`,
  `mobile/test/features/home/home_page_test.dart` — all green on base; they
  must stay green.

**Later parts consume from this part — do NOT remove or "clean up" these
seams:**

- `ChannelDetailView` (T5): Part 3's thread-panel work leaves it untouched,
  but Part 3 renders `ThreadView`/`ForumThreadView` beside it inside
  `ChannelWorkspace`.
- `ChannelWorkspace` (T6) **must reserve the side-panel slot** (right-edge
  overlay) as a private placeholder — Part 3/T10–T11 fills it. Keep the
  `Stack` structure and the record-key remount mechanism.
- `CommunityRail` (T7): Part 3/T12 adds the activity-bell button; Part 4/T19
  adds the pulse destination. Leave layout room (placeholder slots are
  allowed but must not wire behavior early).
- `mobile/test/features/home/desktop_shell_test.dart` (T7): grows in Parts
  3 and 4 — keep its fakes/harness reusable.
- The selection seams branched in T8 are final — Parts 3–4 branch *other*
  seams (threads, forum, search) using the same pattern.

## Hard Constraints (fixed — inherited from the run)

- Pure Dart under `mobile/lib` and `mobile/test` only. No platform folders,
  no `flutter create/run/build/clean/upgrade`, no runner/native code.
- **Zero new pub dependencies** — `mobile/pubspec.yaml` must be unchanged.
- Existing mobile UX unchanged at narrow widths; all pre-existing tests stay
  green. (The full plan's single documented exception — hardware-keyboard
  Enter-to-send at every width — belongs to Part 4/T17. **Part 2 allows no
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

- `mobile/lib/features/channels/channel_detail_page/detail_view.dart` (T5)
- `mobile/lib/features/channels/channel_workspace.dart` (T6)
- `mobile/lib/features/home/desktop_shell/community_rail.dart` (T7)
- `mobile/test/features/channels/channel_workspace_test.dart` (T6)
- `mobile/test/features/home/desktop_shell_test.dart` (T7)

**Modifies:**

- `mobile/lib/features/channels/channel_detail_page.dart` (T5)
- `mobile/lib/features/home/desktop_shell.dart` (T6, T7)
- `mobile/lib/features/channels/channels_page.dart` (T8)
- `mobile/lib/features/channels/channel_link_navigation.dart` (T8)
- `mobile/lib/features/channels/deep_link_dispatcher.dart` (T8)
- `mobile/lib/features/invites/invite_join_sheet.dart` (T8)
- `mobile/test/features/channels/channels_page_test.dart` (T8, extend)
- `mobile/test/features/channels/deep_link_dispatcher_test.dart` (T8, extend)

No other file may change. (Exception, only if the 1000-line cap forces it:
an additional `part` file under the same page's folder, noted in the PR
description.)

## Codebase Context & Conventions (verified — build may trust this and skip its own codebase review)

All facts below were verified against the repo on 2026-07-26 (paths, symbols,
and line numbers) **before Part 1 landed**. Where a bullet conflicts with the
Part 1 changes listed under Dependencies (e.g. `home_page.dart` is now the
adaptive switch and no longer the only file in `features/home/`), the
Dependencies section wins. Line numbers are anchors, not exact contracts —
re-locate by symbol if a file shifted.

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
  original 48 plus the 4 files Part 1 added.
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

### Verified code seams (subset relevant to Part 2; later-part-only seams trimmed)

- `mobile/lib/app.dart` — `App extends HookConsumerWidget`; `MaterialApp`
  with provider-driven auth `switch`: authenticated →
  `DeepLinkDispatcher(child: HomePage())`, else
  `DeepLinkDispatcher(dispatchMessageLinks: false, child: PairingPage())`.
  **Not modified in this plan.**
- `mobile/lib/features/home/home_page.dart` — pre-split: 329 lines,
  `HomePage extends HookConsumerWidget`; tab index local `useState(0)`;
  `IndexedStack` over `[ChannelsPage(), ActivityPage(), SearchPage()]`.
  **[Part 1 note: now the adaptive switch; the mobile body lives in
  `home_page/mobile_home_body.dart`. Not modified in Part 2.]**
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
  selection reproduces route-lifecycle read-state semantics exactly.**
- `mobile/lib/features/channels/channel_link_navigation.dart` —
  `openChannelLink({required BuildContext context, required WidgetRef ref,
  required String channelId, required String currentChannelId})`; no-op when
  same channel; else resolves from `channelsProvider` and pushes
  `ChannelDetailPage`.
- `mobile/lib/features/channels/deep_link_dispatcher.dart` —
  `DeepLinkDispatcher` (ConsumerStatefulWidget) with optional
  `destinationBuilder` and `dispatchMessageLinks`. `_maybeDispatch` consumes
  `pendingDeepLinkProvider`, resolves the channel, and **always pushes**
  (`destinationBuilder` only swaps the pushed widget — the wide path must
  branch *before* the push). `MessageDeepLink` carries `channelId`,
  `messageId`, `threadRootId`. Existing test:
  `mobile/test/features/channels/deep_link_dispatcher_test.dart`.
- **Sheets** (conversion is Part 4; listed because T8 touches
  `invite_join_sheet.dart`): entry helper `showInviteJoinSheet(BuildContext,
  WidgetRef)` (`invite_join_sheet.dart:9`) — one `showModalBottomSheet` site
  in that file; the post-join `ChannelDetailPage` push inside the sheet is
  the T8 target. Leave the `showModalBottomSheet` call itself untouched
  (Part 4/T13 converts it).
- **Communities**: `mobile/lib/shared/community/community_provider.dart` —
  `communityListProvider`
  (`AsyncNotifierProvider<CommunityListNotifier, List<Community>>`),
  `activeCommunityProvider` (`FutureProvider<Community?>`), switch via
  `ref.read(communityListProvider.notifier).switchCommunity(id)`. Switching
  invalidates `authProvider` (`community_provider.dart:64/78`), which
  remounts the authenticated *widget* subtree — but widget remounts do
  **not** reset root providers held by the app-level `ProviderScope`
  (`main.dart`); the Part 1 `shellStateProvider` resets itself by watching
  the active community id. Add-community flow (mirror
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
  references outside `lib/features/pulse/` — the rail is its first entry
  point (Part 4/T19); a placeholder slot on the rail is allowed now but
  must not wire behavior early.
- **Push inventory**: 23 `Navigator.of(context).push` call sites across 17
  files. Only the seams listed in this part's tasks change here; settings,
  pairing, media viewer, pulse compose intentionally remain full-window
  pushes.

## Technical Approach

The full-phase design context; this part implements the **Composition** and
**Navigation branching** rows marked Part 2.

### Layout model *(context)*

```
width < 840              → existing mobile shell (untouched)
width ≥ 840 ("expanded") → | rail 64 | list 280 | messages flex |
                            thread/activity panel = right-edge overlay (360)
```

`isExpandedLayout(context)` (≥ 840, from Part 1) is the single width
predicate. The side panel is a right-edge **overlay** at every wide width
(docked variant cut per review S2 — Part 3 implements the overlay). No pane
resizing/persistence in Phase 1.

### Shell state *(landed in Part 1 — consume, don't reimplement)*

`ShellState` holds IDs only. `selectChannel(id, {initialMessageId,
initialThreadRootId})` closes any thread/forum panel, sets
`mainContent = channels`, and bumps `pendingSelectionNonce` when initial IDs
are provided. `build()` watches the active community identity and resets on
switch. State is simply ignored at narrow widths (push navigation remains
authoritative there).

### Composition *(implemented here: T5–T7)*

- `DesktopShell` composes: community rail (T7, from `shared/community`
  providers), `ChannelsPage` embedded as the list pane (width-branched
  select + header `+` instead of FAB — T8), `ChannelWorkspace` as the
  message pane (T6), and — in Part 3 — a side-panel host for Activity.
- Pages get thin-wrapper treatment: `ChannelDetailView` (T5) is a move-only
  extraction; `ChannelDetailPage` keeps its constructor and delegates.
  Extractions live as new `part` files of the existing page libraries (so
  private helpers stay accessible); embedders import the page library and
  use the public View class. (Part 3 repeats this pattern for
  `ThreadView`/`ForumThreadView`/`ActivityView`; Part 4 for `SearchView`.)
- `ChannelWorkspace` keys `ChannelDetailView` by a record key —
  `ValueKey((channelId, initialMessageId, initialThreadRootId,
  pendingSelectionNonce))` — fresh state per selection, matching today's
  fresh-route-per-navigation behavior (the nonce makes even a repeated
  *identical* deep link remount), which also reproduces read-state
  semantics via the existing keyed `useEffect`.

### Navigation branching (one decision point per seam)

| Seam | Narrow (< 840) | Wide (≥ 840) | Part |
|---|---|---|---|
| Channel select (`channels_page.dart` `openChannel`) | push `ChannelDetailPage` (unchanged) | `shellState.selectChannel(id)` | **2 (T8)** |
| `openChannelLink` | push (unchanged) | `selectChannel(id)` | **2 (T8)** |
| Deep link (`deep_link_dispatcher.dart`) | push (unchanged) | `popUntil(isFirst)` then `selectChannel(id, initialMessageId, initialThreadRootId)` | **2 (T8)** |
| Invite post-join open (`invite_join_sheet.dart`) | push (unchanged) | `popUntil(isFirst)` then `selectChannel(id)` | **2 (T8)** |
| Search hits (3 sites in `search_page.dart`) | push (unchanged) | pop overlay dialog + `selectChannel(…)` | 4 — do not touch |
| Thread open (4 sites) | push `ThreadDetailPage` (unchanged) | `openThreadPanel(rootId, …)` | 3 — do not touch |
| Forum post open (`forum_posts_view.dart:161`) | push `ForumThreadPage` (unchanged) | `openForumThreadPanel(postEventId)` | 3 — do not touch |
| Settings, pairing, media viewer, pulse compose | push | push (unchanged — intentionally full-window) | — |

### Sheets → dialogs / Keyboard & input / Drag-drop *(later parts — 4, 3–4, 4)*

Not part of Part 2. Sheets keep rendering as bottom sheets at wide widths
until Part 4; no shortcut layer yet (Part 3 adds Esc).

## Acceptance Criteria

### Machine-checkable gates

- [ ] `cd mobile && dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `cd mobile && flutter analyze` reports **zero** issues.
- [ ] `cd mobile && flutter test` passes — including all 48 original test
      files and the 4 Part 1 test files, none deleted, skipped, or weakened.
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
      `mobile/test/features/channels/channel_workspace_test.dart`,
      `mobile/test/features/home/desktop_shell_test.dart`.

### Behavioral gates (each is a named widget test run by `flutter test`)

- [ ] At 1440×900: `HomePage` renders `DesktopShell` with rail + list +
      message pane (no longer placeholders) and no floating tab bar; at
      800×600 the mobile tab shell renders unchanged (Part 1 tests still
      pass).
- [ ] Wide: tapping a channel in the list swaps `ChannelWorkspace` content
      **without a route push** (no back button appears; workspace shows the
      channel view).
- [ ] Wide: selecting a channel triggers mark-read
      (`markContextRead`-equivalent observed via fake/override), and
      switching channels re-marks for the new channel.
- [ ] `ChannelWorkspace` with a `selectedChannelId` that matches no loaded
      channel renders the empty state (and with no selection at all).
- [ ] Community switch resets shell state end-to-end: tapping another
      community on the rail calls `switchCommunity` and selection/pending
      IDs/panel state return to initial (T2's provider watch, asserted here
      or covered by the Part 1 provider test).
- [ ] A deep link arriving at wide width while a full-window route (e.g.
      Settings) is stacked pops back to the shell and selects the channel.
- [ ] Deep link at wide writes channel + message + thread-root into shell
      state (no push); the existing narrow deep-link push test still
      passes. (The thread panel actually *opening* from the pending
      thread-root is Part 3's gate.)

## Implementation Tasks (ordered)

Every task must leave `dart format` + `flutter analyze` + `flutter test`
green.

### Part B — Shell panes & selection

#### T5. `ChannelDetailView` extraction (move-only)

**Modify** `mobile/lib/features/channels/channel_detail_page.dart`: add
`part 'channel_detail_page/detail_view.dart'`; move the entire current
`build` (FrostedScaffold chrome included — `FrostedAppBar` shows no back
button at the shell root because `Navigator.canPop` is false there) into a
new public `ChannelDetailView` with the identical constructor
(`channel`, `initialMessageId`, `initialThreadRootId`). `ChannelDetailPage`
keeps its constructor and returns `ChannelDetailView(…)`.

**Create** `mobile/lib/features/channels/channel_detail_page/detail_view.dart`.

Watch the 1000-line cap on the new part file; if the move lands near it,
split along existing part seams instead of exceeding it.

**Tests** — existing
`mobile/test/features/channels/channel_detail_page_test.dart` must pass
unchanged (proves move-only).

#### T6. `ChannelWorkspace` (empty state + keyed embed + read-state)

**Create** `mobile/lib/features/channels/channel_workspace.dart` —
`ChannelWorkspace extends HookConsumerWidget`:
- `selectedChannelId == null` (or `channelsProvider` has no matching
  channel) → empty state.
- Else resolve the `Channel` from `channelsProvider` and render
  `ChannelDetailView(key: ValueKey((channelId, initialMessageId,
  initialThreadRootId, pendingSelectionNonce)), channel: …,
  initialMessageId: …, initialThreadRootId: …)` — record key; the nonce
  remounts even a repeated identical deep link.
- Reserve the thread-panel slot (right-edge overlay) as a private
  placeholder — filled in T10.

**Modify** `mobile/lib/features/home/desktop_shell.dart`: replace the
message-pane placeholder with `ChannelWorkspace`.

**Tests** — **create**
`mobile/test/features/channels/channel_workspace_test.dart` (wide surface,
fake channels/messages/read-state notifiers extending the real ones):
empty state renders with no selection **and** when `selectedChannelId`
matches no loaded channel; writing `selectChannel` swaps in the channel
view without any route push; switching selection remounts (new key);
mark-read fires per selection and re-fires on switch (assert via fake
read-state notifier recording `markContextRead` calls).

#### T7. Community rail

**Create** `mobile/lib/features/home/desktop_shell/community_rail.dart`
(part of the desktop_shell library) — vertical rail (width `Grid.xxl`):
- Community avatar buttons from `communityListProvider` +
  `activeCommunityProvider`; tap inactive → `communityListProvider.notifier
  .switchCommunity(id)`; tap active → `shellState.showChannels()`. Active
  indicator styling via `context.colors`.
- `+` (add community): `ref.read(pairingProvider.notifier).reset()` + push
  `PairingPage` (mirror `channels_page/community.dart` add flow).
- Bottom: `ProfileAvatar(onTap: push SettingsPage)`.
- Placeholder slots for the activity bell (T12) and pulse destination (T19)
  may land now or with their tasks — do not wire behaviors early.

**Modify** `mobile/lib/features/home/desktop_shell.dart`: swap the rail
placeholder for `CommunityRail` (declared as `part`).

**Tests** — **create** `mobile/test/features/home/desktop_shell_test.dart`
(wide surface; fake community/channels notifiers): rail lists communities
with the active one indicated; tapping another community calls
`switchCommunity` (fake records it), and shell selection/panel state resets
on the switch (the T2 watch, asserted end-to-end here or covered by the T2
provider test). (This file grows in T12/T19.)

#### T8. Channel-selection branching at every seam

**Modify** `mobile/lib/features/channels/channels_page.dart`:
- `openChannel`: wide → `ref.read(shellStateProvider.notifier)
  .selectChannel(channel.id); return;` narrow → existing push (unchanged).
  (This automatically covers the create-channel / new-DM post-create opens.)
- FAB: render only at narrow. At wide append a `+` `IconButton`
  (`LucideIcons.plus`, tooltip 'Create or start conversation', invoking the
  same `openQuickActions`) to the `FrostedAppBar` `actions` before
  `ProfileAvatar`.
- No selected-channel highlight in Phase 1 (cut per technical review —
  plan-invented cosmetic scope; Phase 0 visual QA owns list-selection
  affordances).

**Modify** `mobile/lib/features/channels/channel_link_navigation.dart`: wide
→ `selectChannel(channelId)` (keep the same-channel no-op guard); narrow
unchanged.

**Modify** `mobile/lib/features/channels/deep_link_dispatcher.dart`: in
`_maybeDispatch`, after resolving the channel and consuming the link, branch:
wide → first `Navigator.of(context).popUntil((r) => r.isFirst)` (a stacked
full-window route — settings/pairing/media/pulse-compose — would otherwise
hide the selection entirely; review M2), then
`ref.read(shellStateProvider.notifier).selectChannel(channel.id,
initialMessageId: link.messageId, initialThreadRootId: link.threadRootId)`
(no push); narrow → existing push. `destinationBuilder` behavior at narrow
is untouched.

**Modify** `mobile/lib/features/invites/invite_join_sheet.dart`: the
post-join `ChannelDetailPage` push branches the same way, including the
`popUntil((r) => r.isFirst)` at wide.

**Tests** — extend
`mobile/test/features/channels/channels_page_test.dart` (wide: tap channel →
shell state written, no push; narrow: existing push tests unchanged); extend
`mobile/test/features/channels/deep_link_dispatcher_test.dart` (wide: state
written incl. message/thread IDs, no route pushed; **wide with a
full-window route stacked (e.g. Settings): route popped and channel
selected**; narrow tests unchanged); extend
`mobile/test/features/channels/channel_workspace_test.dart` if needed
for end-to-end select-through-list coverage.

## Green boundary — accepted interim gaps at the end of Part 2

Part 2 must leave `dart format` + `flutter analyze` + `flutter test` fully
green standalone (48 original + 4 Part 1 + 2 new test files). The following
gaps are **accepted and expected** — all invisible until Phase 0 ships a
desktop runtime — and must NOT be "fixed" in this part:

- **Threads at wide widths still open as full-window pushes** (all 4 thread
  push sites branch in Part 3/T10). The same applies to forum posts
  (Part 3/T11).
- The pending `initialThreadRootId` written by the T8 deep-link branch is
  passed into `ChannelDetailView`, which handles it exactly as the pushed
  page does today; the side-panel presentation of that thread arrives in
  Part 3.
- **Search is unreachable at wide widths** (no tab bar in the shell; the
  search overlay is Part 4/T15).
- **Activity is unreachable at wide widths** (bell + panel are Part 3/T12).
- Sheets still render as bottom sheets at wide widths (Part 4/T13).
- No keyboard layer (Esc lands in Part 3; the rest in Part 4), no
  right-click, no drag-drop, no pulse rail entry.
- The `ChannelWorkspace` side-panel slot is an empty private placeholder —
  Part 3 fills it; do not remove it.

## Auto-resolved assumptions (relevant to this part)

1. **Skill interactivity resolved silently** (run-level): detail level =
   extensive; no external research; no branch setup by the plan stage
   (orchestrator owns branches; this part stacks on Part 1).
2. **Channel list pane = width-branching inside `ChannelsPage` itself**, not
   a separate pane widget — same outcome the brainstorm specified (body
   reuse, select-into-state, header `+` replacing FAB) with less new
   surface; `_ChannelsBody` is private to the channels_page library, which
   makes in-library branching the smallest correct change.
3. **View extractions are `part` files of their existing page libraries**
   (`detail_view.dart` here), so private helpers stay accessible without
   exporting internals; embedders import the page library and use the
   public View class.
4. **Workspace keying is a record key including a selection nonce**
   (`ValueKey((channelId, initialMessageId, initialThreadRootId,
   pendingSelectionNonce))`; the nonce bumps whenever a selection carries
   pending IDs), so even a *repeated identical* deep link remounts —
   matching today's push-a-fresh-route behavior. Plain re-selection of the
   current channel (no pending IDs) keeps the key stable and does not
   remount.
5. **Selected-channel highlight: cut** (was plan-invented cosmetic scope
   crossing three widget layers; removed per technical review — Phase 0
   visual QA owns list-selection affordances).
6. Brainstorm defaults reaffirmed: settings/pairing/media-viewer/pulse
   compose stay pushed routes; no resize-crossing state migration (dormant
   selection at narrow, stacked route at wide — documented, accepted).
7. **Technical-review fix-cycle defaults (2026-07-26)**: M2 resolved by
   `popUntil((r) => r.isFirst)` before wide deep-link/invite selection; C1
   community-reset is the Part 1 provider watch, asserted end-to-end here.

## Risks & Mitigations (relevant to this part)

1. **Mobile regression from the move-only `ChannelDetailView` extraction**
   (the channel page is load-bearing): the wrapper preserves the
   constructor contract; `channel_detail_page_test.dart` and the full
   pre-existing suite gate the task.
2. **Read-state correctness in embedded mode** (subtlest logic touched;
   DESKTOP_PORT_PLAN §8.2 warns here): reproduced structurally by remount
   semantics (keyed `useEffect` on `channel.id`) rather than new code
   paths; dedicated workspace tests assert mark-read on select and on
   switch.
3. **Two navigation models + resize edge cases**: crossing wide→narrow
   leaves shell selection dormant; narrow→wide leaves a pushed detail route
   stacked over the shell until popped. Accepted for Phase 1, documented —
   no auto-pop machinery (YAGNI). The deep-link `popUntil` (T8) is the one
   deliberate pop.
4. **1000-line cap pressure** on `detail_view.dart` (~300+ lines moved):
   split along existing part seams if it approaches the cap; never touch
   the size-check script.
5. **No desktop runtime exists to verify visually**: proof is analyze +
   wide-surface widget tests (1440×900 standard).

## Non-Goals / Deferred (do not build in this part)

- Everything in Parts 3–4: thread/forum/activity views and panels, Esc/
  shortcuts, sheet-site conversions, right-click, media-viewer Esc, search
  overlay, composer key handling, drop seam, pulse rail entry.
- No Phase 0 work (platform folders, native code, real drag-drop backend,
  visual QA). No Bucket A/B features. No dependency swaps.
- No windowed/hover media viewer, no custom window chrome, no
  GoRouter/Navigator 2.0, no pane resize/persistence, no quick-switcher, no
  anchored popovers/context menus, no mobile navigation changes.
- No docked side-panel column (overlay-only; review S2), no
  selected-channel highlight, no "large"/1200 breakpoint tier.
