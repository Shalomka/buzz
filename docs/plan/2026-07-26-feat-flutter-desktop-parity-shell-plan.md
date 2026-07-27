---
title: 'feat: Flutter desktop parity shell (Phase 1)'
type: feat
date: 2026-07-26
status: ready-for-build
brainstorm: docs/brainstorm/2026-07-26-flutter-desktop-parity-shell-brainstorm.md
source-plan: mobile/DESKTOP_PORT_PLAN.md (§5, §9 Phase 1)
---

# feat: Flutter desktop parity shell (Phase 1)

## Split note (2026-07-26)

The plan-splitting review approved splitting this plan into **4 stacked
parts** matching Parts A–D below. Each part was written as a standalone
plan, and **those part plans — not this file — are the build source of
truth**:

1. [Part 1 — Foundations (T1–T4)](2026-07-26-feat-parity-shell-part-1-plan.md) — base: `main`
2. [Part 2 — Shell panes & selection (T5–T8)](2026-07-26-feat-parity-shell-part-2-plan.md) — depends on Part 1
3. [Part 3 — Side panel: thread/forum/activity (T9–T12)](2026-07-26-feat-parity-shell-part-3-plan.md) — depends on Part 2
4. [Part 4 — Sheets & input layer (T13–T19)](2026-07-26-feat-parity-shell-part-4-plan.md) — depends on Part 3

This document remains the full-phase reference (context, approach,
complete acceptance criteria); if it and a part plan disagree, the part
plan wins for that part's build.

## Overview

Build the width-adaptive multi-pane shell described in
`mobile/DESKTOP_PORT_PLAN.md` §9 Phase 1, entirely in portable Dart under
`mobile/lib` + `mobile/test`. Below 840dp the existing mobile UX renders
byte-for-byte unchanged. At ≥ 840dp a new `DesktopShell` composes
`community rail | channel list pane | message pane (+ thread/side panel)` from
the existing feature widgets via move-only "View" extractions. All 21
`showModalBottomSheet` surfaces become centered dialogs at wide widths through
one `showAdaptiveModal` helper. A minimal desktop keyboard layer, composer
hardware-key handling (Enter sends / Shift+Enter newline), and a pure-Dart
drag-drop seam feeding the existing upload pipeline complete the phase.

Phase 0 (desktop platform folders) has **not** landed. Everything here is
verifiable exclusively via `dart format`, `flutter analyze`, and
`flutter test` (wide-surface widget tests are the desktop proxy). The shell is
dormant on phones today and activates automatically once Phase 0 adds desktop
targets.

Approach and all design decisions were settled in the brainstorm
(`docs/brainstorm/2026-07-26-flutter-desktop-parity-shell-brainstorm.md`,
Approach A). This plan turns them into ordered, buildable tasks. Every code
seam named below was re-verified against the repo on 2026-07-26.

## Problem Statement

The Flutter mobile app is a complete Nostr client in portable Dart, but its UI
shell is touch-and-full-screen: a 3-tab floating bottom bar over an
`IndexedStack`, 23 full-screen `Navigator.of(context).push` drill-downs, and
21 `showModalBottomSheet` surfaces across 14 files. At desktop window widths
this is unusable — a channel list filling a 1440px window, bottom sheets
stretched across it, no thread-beside-messages, no keyboard-driven flow, no
drag-drop. Phase 1 closes exactly that gap without touching platform folders
or changing mobile behavior.

## Hard Constraints (fixed — inherited from the run)

- Pure Dart under `mobile/lib` and `mobile/test` only. No platform folders,
  no `flutter create/run/build/clean/upgrade`, no runner/native code.
- **Zero new pub dependencies** — `mobile/pubspec.yaml` must be unchanged.
- Existing mobile UX unchanged at narrow widths; all pre-existing tests stay
  green. One deliberate, documented exception: hardware-keyboard Enter now
  sends at every width (see T17 and Auto-resolved assumption 7);
  touch/soft-keyboard behavior is untouched.
- Verification commands available to the build: `flutter test`,
  `flutter analyze`, `dart format` (run from `mobile/`).

## Declared File Scope

The build may create/modify files **only** under:

- `mobile/lib/**`
- `mobile/test/**`

Nothing else. Explicitly out of bounds: `mobile/pubspec.yaml`,
`mobile/analysis_options.yaml`, `mobile/scripts/**`, `mobile/android/**`,
`mobile/ios/**`, all repo-root files, `desktop/**`, `crates/**`, `docs/**`
(this plan is not to be edited by the build).

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

### Verified code seams (the exact surfaces this plan touches)

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
  selection reproduces route-lifecycle read-state semantics exactly.**
- **All 4 `ThreadDetailPage` push sites** (each must width-branch):
  1. `channel_detail_page/message_list.dart:98-108` — initial-thread
     deep-link effect (inside `addPostFrameCallback`);
  2. `channel_detail_page/system_rows.dart:163-165` — thread summary row tap
     (the primary user path);
  3. `mobile/lib/features/channels/thread_detail_page.dart:328` — nested
     thread from within a thread;
  4. `mobile/lib/features/channels/message_actions.dart:109` — open-thread
     action from the message actions surface.
- `mobile/lib/features/channels/thread_detail_page.dart` (615 lines, no
  parts) — `ThreadDetailPage({required TimelineMessage threadHead, required
  List<TimelineMessage> allMessages, required String channelId, required
  String? currentPubkey, required bool isMember, required bool isArchived,
  String? initialMessageId})`. Watches
  `threadRepliesProvider(ThreadRepliesArgs(channelId, rootId))`; renders
  head + replies + `ComposeBar`; `showMessageActions` via `onLongPress` at
  line 428.
- `mobile/lib/features/forum/forum_thread_page.dart` (600 lines) —
  `ForumThreadPage({required String channelId, required String postEventId,
  required String? currentPubkey, required bool isMember, required bool
  isArchived})` — **self-sufficient (loads by IDs)**. Pushed from
  `mobile/lib/features/forum/forum_posts_view.dart:161` (single site).
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
- **Search**: `mobile/lib/features/search/search_page.dart` — `SearchPage
  extends HookConsumerWidget` wrapping `FrostedScaffold`; private
  `_SearchBody` (line 108) and section widgets; **3 `ChannelDetailPage` push
  sites** (channel hit ~line 217, people/DM hit ~line 258, message hit
  ~lines 384-398, the latter passing initial message context).
- **Sheets — all 21 `showModalBottomSheet` call sites by file (count)**:
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
- **`showMessageActions` long-press callers** (right-click targets):
  `channel_detail_page/message_bubble.dart:45`,
  `channel_detail_page/system_rows.dart:39`,
  `thread_detail_page.dart:428`.
- **Composer**: `mobile/lib/features/channels/compose_bar.dart` (725 lines) —
  `TextField` at lines 620-647 with `textInputAction: TextInputAction.send`,
  `onSubmitted: (_) => send()`, `minLines: 1, maxLines: 5`. This is
  soft-keyboard-only; hardware Enter inserts a newline in a multiline field,
  so desktop send requires explicit key handling. Attachment pipeline:
  `attachments` (useState of `BlobDescriptor` list), `uploadingCount`,
  `uploadError` states; `pickAndUpload(Future<BlobDescriptor?> Function()
  pick)` at line 420; service via `mediaUploadServiceProvider`.
- **Upload service**: `mobile/lib/shared/relay/media_upload.dart` —
  `MediaUploadService` (line 131) exposes
  `Future<BlobDescriptor> uploadBytes(Uint8List bytes, {required String
  mimeType})` (line 235) which validates size/mime — the natural drop-seam
  entry. Allowed mime sets are internal to that file; unsupported types
  throw (surface via the composer's existing `uploadError`).
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
- **Unread badge**: `unreadBadgeProvider` →
  `UnreadBadgeState{highPriorityCount, generalUnreadCount}`
  (`mobile/lib/features/channels/unread_badge/unread_badge_provider.dart`;
  usage example in `app.dart:48-56`).
- **Chrome**: `mobile/lib/shared/widgets/frosted_app_bar.dart` —
  `frostedAppBarHeight(context) = MediaQuery.paddingOf(context).top + 48`
  (degrades to 48 with no status bar); `FrostedAppBar` auto-shows a back
  button only when `Navigator.canPop(context)` → **embedded panes at the
  shell root get no back button automatically**. `FrostedScaffold` overlays
  the bar in a Stack.
- **Activity**: `mobile/lib/features/activity/activity_page.dart` —
  `ActivityPage extends HookConsumerWidget`; `FrostedScaffold(appBar:
  FrostedAppBar(title: Text('Activity')), …)` at line 112; body built inline
  (needs a move-only `ActivityView` extraction to embed).
- **Pulse**: `mobile/lib/features/pulse/pulse_page.dart` — `PulsePage`
  (FrostedScaffold + FAB pushing the compose page). **Orphaned**: zero
  references outside `lib/features/pulse/` — the rail is its first entry
  point; mobile navigation stays unchanged.
- **Keyboard**: zero existing `Shortcuts`/`CallbackShortcuts`/
  `LogicalKeyboardKey` usage in `mobile/lib` — the shortcut layer is
  greenfield. Flutter's default `DismissIntent` handling already closes
  dialogs on Esc; the shell only needs Esc for side panels.
- **Breakpoints**: no breakpoint code exists anywhere in `mobile/lib` (only
  media-sizing `LayoutBuilder`s).
- **Push inventory**: 23 `Navigator.of(context).push` call sites across 17
  files. Only the seams listed in tasks below change; settings, pairing,
  media viewer, pulse compose intentionally remain full-window pushes.

## Technical Approach

### Layout model

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

### Shell state (IDs only — `shared/` stays feature-type-free)

`ShellState` (immutable, `copyWith`): `selectedChannelId: String?`,
`pendingInitialMessageId: String?`, `pendingInitialThreadRootId: String?`,
`pendingSelectionNonce: int` (bumped when a selection carries pending IDs so
a repeated *identical* deep link still remounts the workspace),
`sidePanel: ShellSidePanel` (sealed: `none | thread(rootId,
initialMessageId?) | forumThread(postEventId) | activity`), `mainContent:
ShellMainContent` (`channels | pulse`).

 **[BUILD CORRECTION (part 1, commit 372ba9e6): the shipped watch deliberately OMITS `unwrapPrevious()` — with it, same-community reloads (e.g. rename) would spuriously reset shell state. Verified correct in review; do NOT "restore" the literal expression below.]** 
`ShellStateNotifier extends Notifier<ShellState>` rules:
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

### Composition

- `HomePage` becomes the adaptive switch; the current mobile body moves
  move-only into a `part` file.
- `DesktopShell` (+ parts under `features/home/desktop_shell/`) composes:
  community rail (from `shared/community` providers), `ChannelsPage`
  embedded as the list pane (width-branched select + header `+` instead of
  FAB), `ChannelWorkspace` as the message pane, and a side-panel host for
  Activity.
- Pages get thin-wrapper treatment: `ChannelDetailView`, `ThreadView`,
  `ForumThreadView`, `ActivityView`, `SearchView` are move-only extractions;
  the existing pages keep their constructors and delegate. Extractions live
  as new `part` files of the existing page libraries (so private helpers
  stay accessible); embedders import the page library and use the public
  View class.
- `ChannelWorkspace` keys `ChannelDetailView` by a record key —
  `ValueKey((channelId, initialMessageId, initialThreadRootId,
  pendingSelectionNonce))` — fresh state per selection, matching today's
  fresh-route-per-navigation behavior (the nonce makes even a repeated
  *identical* deep link remount), which also reproduces read-state
  semantics via the existing keyed `useEffect`.

### Navigation branching (one decision point per seam)

| Seam | Narrow (< 840) | Wide (≥ 840) |
|---|---|---|
| Channel select (`channels_page.dart` `openChannel`) | push `ChannelDetailPage` (unchanged) | `shellState.selectChannel(id)` |
| `openChannelLink` | push (unchanged) | `selectChannel(id)` |
| Deep link (`deep_link_dispatcher.dart`) | push (unchanged) | `popUntil(isFirst)` then `selectChannel(id, initialMessageId, initialThreadRootId)` |
| Invite post-join open (`invite_join_sheet.dart`) | push (unchanged) | `popUntil(isFirst)` then `selectChannel(id)` |
| Search hits (3 sites in `search_page.dart`) | push (unchanged) | pop overlay dialog + `selectChannel(…)` |
| Thread open (4 sites listed above) | push `ThreadDetailPage` (unchanged) | `openThreadPanel(rootId, …)` |
| Forum post open (`forum_posts_view.dart:161`) | push `ForumThreadPage` (unchanged) | `openForumThreadPanel(postEventId)` |
| Settings, pairing, media viewer, pulse compose | push | push (unchanged — intentionally full-window) |

### Sheets → dialogs

`Future<T?> showAdaptiveModal<T>(BuildContext context, {required
WidgetBuilder builder, bool isScrollControlled = false, bool showDragHandle =
true, double maxWidth = 480})` — narrow: delegates to `showModalBottomSheet`
preserving today's exact look/params; wide: `showDialog` with a `Dialog`
(`Radii.dialog` corners) constrained to `maxWidth`. All 21 call sites convert
mechanically; sheet content widgets are unchanged. Message rows additionally
gain `onSecondaryTapUp` (right-click) invoking the same actions surface.

### Keyboard & input

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

### Drag-drop seam (OS boundary only)

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
- [ ] `cd mobile && flutter test` passes — including all 48 pre-existing test
      files, none deleted, skipped, or weakened.
- [ ] `mobile/pubspec.yaml` is byte-identical (zero new dependencies).
- [ ] The diff touches only `mobile/lib/**` and `mobile/test/**`.
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
      `mobile/test/shared/widgets/attachment_drop_region_test.dart`,
      `mobile/test/features/home/home_page_test.dart`,
      `mobile/test/features/home/desktop_shell_test.dart`,
      `mobile/test/features/home/shell_shortcuts_test.dart`,
      `mobile/test/features/channels/channel_workspace_test.dart`,
      `mobile/test/features/channels/channel_list_order_test.dart`,
      `mobile/test/features/search/search_overlay_test.dart`.

### Behavioral gates (each is a named widget test run by `flutter test`)

- [ ] At 800×600 (default surface): `HomePage` renders the mobile tab shell
      (floating tab bar present) and no `DesktopShell`.
- [ ] At 1440×900: `HomePage` renders `DesktopShell` (rail + list + message
      pane) and no floating tab bar.
- [ ] Wide: tapping a channel in the list swaps `ChannelWorkspace` content
      **without a route push** (no back button appears; workspace shows the
      channel view).
- [ ] Wide: selecting a channel triggers mark-read
      (`markContextRead`-equivalent observed via fake/override), and
      switching channels re-marks for the new channel.
- [ ] At 1440×900 with a thread open: panel renders as a right-edge
      **overlay** (single presentation — the docked variant is deferred to
      Phase 0).
- [ ] Opening a **nested** thread (a reply ID as root) resolves the head
      from the full message set including replies — no permanent spinner;
      an ID outside the loaded window triggers the deep-link loader
      fallback.
- [ ] Community switch resets shell state: selection, pending IDs, and any
      open side panel return to initial.
- [ ] A deep link arriving at wide width while a full-window route (e.g.
      Settings) is stacked pops back to the shell and selects the channel.
- [ ] `ChannelWorkspace` with a `selectedChannelId` that matches no loaded
      channel renders the empty state.
- [ ] Thread panel and activity panel are mutually exclusive; opening one
      closes the other.
- [ ] Esc closes an open side panel.
- [ ] `showAdaptiveModal`: bottom sheet at narrow, `Dialog` at wide; a
      returned value round-trips in both modes.
- [ ] Wide: message actions open as a `Dialog` (representative sheet
      conversion test); right-click (secondary tap) on a message row opens
      the same surface.
- [ ] Cmd/Ctrl+K at wide opens the search overlay; choosing a result closes
      the overlay and selects the channel in shell state; a repeat Cmd/Ctrl+K
      while open does not stack a second overlay, and repeated Cmd/Ctrl+,
      does not stack a second `SettingsPage`.
- [ ] Cmd/Ctrl+Alt+ArrowDown / Cmd/Ctrl+Alt+ArrowUp move the selected
      channel to next/previous in the visible ordered list — asserted
      **with the composer text field focused**.
- [ ] Composer: hardware Enter **and numpad Enter** send (send path observed
      via fake), Shift+Enter does not send; existing soft-submit test still
      passes.
- [ ] Drop region: with a fake backend override, dropped files reach the
      attachment pipeline (attachment strip shows the upload / fake
      `uploadBytes` called); with the default null backend the child renders
      unchanged.
- [ ] Media viewers: Esc pops the route on both `MediaImageViewerPage` and
      `MediaVideoViewerPage`.
- [ ] Deep link at wide writes channel + message + thread-root into shell
      state (no push) and the thread panel opens; the existing narrow
      deep-link push test still passes.
- [ ] Pulse: rail toggle swaps the main content region to `PulsePage`;
      selecting a channel returns content to channels.

## Implementation Tasks (ordered)

Tasks are grouped into four parts (A–D) matching the suggested PR slicing.
Every task must leave `dart format` + `flutter analyze` + `flutter test`
green.

---

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

---

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

---

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

---

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
widths" (assumption 7).

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

---

## Suggested PR Slicing (input to the plan-splitting review)

Linear dependency chain, each part independently green and mergeable:

1. **Part A — Foundations** (T1–T4): breakpoints, shell state, adaptive
   modal helper, adaptive HomePage with skeleton shell. No behavior change
   for mobile; shell visible only in wide tests.
2. **Part B — Shell panes & selection** (T5–T8): detail-view extraction,
   workspace, community rail, selection branching at all channel-open seams,
   embedded read-state.
3. **Part C — Side panel** (T9–T12): thread/forum/activity views, the
   right-edge overlay panel (overlay-only per review S2), thread-open
   branching incl. nested-thread head resolution, Esc-close.
4. **Part D — Sheets & input layer** (T13–T19): 21 sheet conversions,
   right-click, media-viewer Esc, search overlay, shortcuts, composer keys,
   drop seam, pulse destination.

Interim gaps (accepted, invisible until Phase 0 ships a desktop runtime):
after Part B, threads at wide widths still open as full-window pushes (until
Part C); search is unreachable at wide widths (until Part D's overlay);
sheets still render as bottom sheets at wide widths (until Part D).

## Auto-resolved assumptions

Decisions this plan stage made non-interactively (brainstorm decisions were
followed; these are refinements within them):

1. **Skill interactivity resolved silently**: detail level = extensive; no
   external research (strong local context — pure Flutter/Dart layout work,
   no new dependencies, no security surface); no user-flow-analysis agent run
   (flow coverage derives from the verified seam inventory: every existing
   navigation entry point is enumerated in the branching table); no branch
   setup performed (orchestrator owns the branch:
   `wingspan/desktop-phase1-run`).
2. **Channel list pane = width-branching inside `ChannelsPage` itself**, not
   a separate pane widget — same outcome the brainstorm specified (body
   reuse, select-into-state, header `+` replacing FAB) with less new
   surface; `_ChannelsBody` is private to the channels_page library, which
   makes in-library branching the smallest correct change.
3. **View extractions are `part` files of their existing page libraries**
   (`detail_view.dart`, `thread_view.dart`, `forum_thread_view.dart`), so
   private helpers stay accessible without exporting internals; embedders
   import the page library and use the public View class. `ActivityView` /
   `SearchView` may stay same-file public widgets if under the line cap.
4. **Workspace keying is a record key including a selection nonce**
   (`ValueKey((channelId, initialMessageId, initialThreadRootId,
   pendingSelectionNonce))`; the nonce bumps whenever a selection carries
   pending IDs), so even a *repeated identical* deep link remounts —
   matching today's push-a-fresh-route behavior. Plain re-selection of the
   current channel (no pending IDs) keeps the key stable and does not
   remount.
5. **Drop region wraps the ComposeBar subtree** (composer region), not the
   whole message pane — keeps attachment state local with an identical seam
   API; Phase 0 can lift the region without API change.
6. **Selected-channel highlight: cut** (was plan-invented cosmetic scope
   crossing three widget layers; removed per technical review — Phase 0
   visual QA owns list-selection affordances).
7. **Composer Enter-to-send applies to hardware key events at all widths —
   a deliberate, documented narrow-width behavior change**: hardware/BT
   keyboards on phones DO emit key events, so external-keyboard users on
   mobile gain Enter-sends (aligned with the existing
   `TextInputAction.send` intent). Touch/soft-keyboard behavior is
   byte-identical; this is the single accepted exception to "mobile UX
   unchanged at narrow widths".
8. **`ShellSidePanel` gains a `forumThread(postEventId)` variant** (channel
   comes from the current selection) — refinement of the brainstorm's sealed
   shape to keep `shared/` ID-only.
9. **All four verified thread-open sites branch** (brainstorm named the
   primary ones; `message_actions.dart:109` and nested-thread
   `thread_detail_page.dart:328` are included for consistency).
10. **Test-count correction**: the regression gate is the 48 existing
    `*_test.dart` files (the brainstorm's "49" counted the
    `widget_helpers.dart` helper).
11. Brainstorm defaults reaffirmed without re-opening: expanded breakpoint
    840; sheets → centered dialogs uniformly (`maxWidth` 480);
    settings/pairing/media-viewer/pulse compose stay pushed routes;
    Cmd/Ctrl+K opens full search; no auto-open thread behaviors; no
    resize-crossing state migration (dormant selection at narrow, stacked
    route at wide — documented, accepted). The brainstorm's 1200/docked
    tier was cut by technical review S2 (overlay-only in Phase 1; docked
    promotion deferred to Phase 0 visual QA).
12. **Technical-review fix-cycle defaults (2026-07-26)**: C1 shell-state
    reset implemented by watching the *active community id* rather than raw
    `authProvider` (narrower — avoids spurious resets from unrelated auth
    emissions while still catching switches, which invalidate that chain);
    M3 resolved with the recommended non-conflicting chord
    (Cmd/Ctrl+Alt+Arrows); the repeated-identical-deep-link remount gap is
    closed with the monotonic `pendingSelectionNonce` (chosen over
    documenting it as a known exception); the Cmd+K / Cmd+, no-stack guard
    mechanism (flag-around-await vs route-aware check) is left to the
    builder.

## Risks & Mitigations

1. **Mobile regression from move-only extractions** (channel/thread/forum/
   activity/search pages are load-bearing): wrappers preserve constructor
   contracts; the 48 existing test files gate every task; narrow-width shell
   test added in T4.
2. **No desktop runtime exists to verify visually**: proof is analyze +
   wide-surface widget tests (1440×900 standard); all layout constants live
   in `breakpoints.dart` + shell files for cheap retuning during Phase 0
   QA — including promoting the overlay side panel to a docked column if
   QA wants it.
3. **Read-state correctness in embedded mode** (subtlest logic touched;
   DESKTOP_PORT_PLAN §8.2 warns here): reproduced structurally by remount
   semantics (keyed `useEffect` on `channel.id`) rather than new code paths;
   dedicated workspace tests assert mark-read on select and on switch.
4. **Two navigation models + resize edge cases**: crossing wide→narrow
   leaves shell selection dormant; narrow→wide leaves a pushed detail route
   stacked over the shell until popped; breakpoint-crossing also resets
   `_MobileHomeBody` tab state. Accepted for Phase 1, documented here — no
   auto-pop machinery (YAGNI).
5. **1000-line cap pressure** on extractions (`thread_view.dart` ~550+,
   `detail_view.dart` ~300+): split along part seams if a file approaches
   the cap; never touch the size-check script.
6. **`CallbackShortcuts` focus dependency**: bindings only fire when focus
   is inside the shell subtree — mitigated with `Focus(autofocus: true)`
   fallback and tests that exercise shortcuts without a focused field.
7. **Dialog-ified sheets look phone-shaped at 480px**: cosmetic, accepted
   for parity scope; per-surface polish deferred to Phase 2.
8. **`showAdaptiveModal` snapshots width at open time**: a window resized
   across the breakpoint while a sheet/dialog is open keeps the stale
   presentation until dismissed. Accepted for Phase 1 (unreachable before
   Phase 0 ships a resizable window); flagged for Phase 0 visual QA.

## Non-Goals / Deferred

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
- No docked side-panel column (overlay-only; docked variant deferred to
  Phase 0 visual QA — review S2), no selected-channel highlight, no
  drop-target hover/highlight visuals (they arrive with the real Phase 0
  backend — review S1).

## Alternative Approaches Considered

Settled in the brainstorm (see `docs/brainstorm/2026-07-26-flutter-desktop-parity-shell-brainstorm.md`,
"Explored Approaches"): platform-gated separate desktop shell (rejected —
unverifiable before Phase 0, ships dead code) and nested-navigator /
router-driven panes (rejected — precludes the docked side-by-side parity
layout, complicates deep links and dialog scoping, violates the Navigator
1.0 convention in its router variant).
