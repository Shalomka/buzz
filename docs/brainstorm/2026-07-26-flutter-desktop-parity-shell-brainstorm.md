---
date: 2026-07-26
topic: flutter-desktop-parity-shell
source-plan: mobile/DESKTOP_PORT_PLAN.md (§9 Phase 1, §5, §3, §8)
---

# Flutter Desktop Parity Shell (Phase 1)

## Problem Statement

`mobile/DESKTOP_PORT_PLAN.md` establishes that the Flutter mobile app is a complete
Nostr client in portable Dart — relay stack, crypto, event models, feature logic,
and theme all reuse as-is on desktop. What does **not** reuse is the UI shell: the
app is built for touch and full-screen navigation. `home_page.dart` is a 3-tab
floating bottom bar over an `IndexedStack`; every drill-down is a full-screen
`Navigator.push` (23 call sites); every secondary surface is a
`showModalBottomSheet` (21 call sites across ~14 files). At desktop window widths
this is unusable: a channel list that fills a 1440px window, bottom sheets
stretched across it, no thread-beside-messages, no keyboard-driven flow, no
drag-drop.

Phase 1 ("Parity shell") closes exactly that gap: a **responsive multi-pane
navigation shell** (community rail + channel list + message pane + thread/side
panel) that lights up the §3 reuse inventory — channels, messages, forum, pulse,
profile view/basic edit, search, settings, presence, user-status, custom-emoji,
communities, activity, invites — converts bottom sheets to desktop dialogs/panels,
and adds drag-drop upload plumbing plus desktop keyboard shortcuts.

Constraint that shapes everything: **Phase 0 has not landed.** `mobile/` has only
`android/` and `ios/` platform folders. This phase is pure Dart under `mobile/lib`
and `mobile/test`, verifiable only via `dart format`, `flutter analyze`, and
`flutter test`. The shell must be breakpoint-driven so it is exercised today by
wide-surface widget tests (and tablets), and activates fully the moment Phase 0
adds desktop targets — while the existing mobile UX stays byte-for-byte unchanged
at narrow widths.

## What We're Building

A width-adaptive shell: below the expanded breakpoint the app renders today's
`HomePage` (bottom tabs + push navigation) untouched; at and above it, a
`DesktopShell` renders `community rail | channel list pane | message pane
(+ docked/overlay thread panel)`. Channel selection becomes shared state instead
of a route push at wide widths. One `showAdaptiveModal` helper converts all
bottom-sheet surfaces to centered dialogs at wide widths. A `CallbackShortcuts`
layer adds a minimal desktop shortcut set, the composer gets hardware-keyboard
Enter-to-send / Shift+Enter-newline, and a pure-Dart drop-region seam feeds
dropped files into the existing attachment-upload pipeline (OS wiring lands with
Phase 0).

## Goals

1. Multi-pane shell at width ≥ 840dp: community rail, channel list pane, message
   pane, thread/side panel (docked at ≥ 1200dp, overlay at 840–1199dp).
2. Every §3 reuse-inventory feature reachable and functional inside the shell.
3. All `showModalBottomSheet` surfaces render as desktop dialogs at wide widths
   via one shared adaptive helper; content widgets unchanged.
4. Desktop keyboard shortcuts (minimal set) + composer hardware-key handling.
5. Drag-drop upload path built up to the OS boundary (pluggable backend seam,
   no-op until Phase 0), wired into the existing upload pipeline.
6. Zero regression at narrow widths: existing 49 test files stay green; no
   behavior change to the mobile UX.
7. Everything verifiable by `dart format` / `flutter analyze` / `flutter test`
   (wide-surface widget tests are the desktop proxy).

## Non-Goals

- No Phase 0 work: no `flutter create --platforms=…`, no platform folders, no
  `flutter run/build/clean/upgrade`, no runner/native code.
- No Bucket A features: no home inbox/feed, onboarding flows, workflows, OS
  notifications, reminders, moderation, community-members admin,
  channel-templates, agent-memory viewer.
- No Bucket B/native: no agents, projects/git, mesh-compute, local-archive,
  huddle, animated-avatar studio.
- No dependency swaps: `image_picker`→`file_selector`, `video_player`→`media_kit`,
  `desktop_drop`, `window_manager`, `super_clipboard` are Phase 0/2 items —
  recorded as deferred, not touched here.
- No windowed/hover media viewer rebuild (Esc-to-close only), no custom window
  chrome / traffic lights, no Navigator 2.0 / GoRouter migration, no new
  pane-resize/drag persistence machinery.
- No mobile navigation changes (Pulse stays unwired on mobile — see decisions).

## Codebase Context (grounding facts)

Verified against the repo on 2026-07-26; the plan stage can trust these paths.

- `mobile/lib/app.dart` — `App extends HookConsumerWidget`; `MaterialApp` with a
  provider-driven auth `switch`: authenticated → `DeepLinkDispatcher(child:
  HomePage())`, otherwise `PairingPage`. Navigator 1.0, no named routes.
- `mobile/lib/features/home/home_page.dart` (329 lines, the only file in
  `features/home/`) — 3 destinations (Channels labeled "Home", Activity, Search)
  in an `IndexedStack` behind a custom frosted `_FloatingTabBar`; tab index is
  local `useState`. `features/home` already imports `channels`, `activity`,
  `search` — it is the de-facto composition root, so a desktop shell here follows
  existing precedent (strict feature isolation applies between leaf features).
- Core navigation flow: `ChannelsPage` (`FrostedScaffold`, community-switcher
  sheet, profile avatar → pushes `SettingsPage`, FAB → quick-actions sheet) →
  `Navigator.push(ChannelDetailPage(channel))` → pushes `ThreadDetailPage` /
  `ForumThreadPage` / `MediaViewerPage`. 23 `Navigator.push` call sites total.
- `ChannelDetailPage(channel, initialMessageId, initialThreadRootId)` renders
  `ForumPostsView` inline when `channel.isForum` (`channel.dart:77`), else the
  message list + `ComposeBar`; split across 5 `part` files under
  `channel_detail_page/`.
- `ThreadDetailPage(threadHead, allMessages, channelId, currentPubkey, isMember,
  isArchived, initialMessageId)` — full-screen; its inputs come from the channel
  timeline state, so thread-beside-messages composition belongs inside the
  channels feature.
- Bottom sheets: 21 `showModalBottomSheet` call sites in ~14 files. Entry pattern
  is free functions (`showUserProfileSheet`, `showSetStatusSheet`,
  `showEmojiPicker`, `showMessageActions`, `showInviteJoinSheet`) plus private
  sheet classes in `channels_page/sheets.dart` (quick actions, create channel,
  new DM) and the community switcher in `channels_page/community.dart`.
- `mobile/lib/features/channels/deep_link_dispatcher.dart` already exposes a
  `destinationBuilder` override — a clean seam for the shell to intercept
  deep-link navigation. `channel_link_navigation.dart` (`openChannelLink`) is the
  other central "open a channel" entry.
- Chrome: `FrostedScaffold` overlays a `FrostedAppBar` (Stack + `Positioned`);
  bar height = `MediaQuery.paddingOf(context).top + 48`, so it degrades cleanly
  to 48px when there is no status bar. `FrostedAppBar` auto-shows a back button
  when `Navigator.canPop(context)` — embedded panes at the root route get no
  back button for free.
- Keyboard: **zero** existing `Shortcuts`/`CallbackShortcuts`/`LogicalKeyboardKey`
  usage in `lib/`. The composer sends via `TextInputAction.send` +
  `onSubmitted` (`compose_bar.dart:623–631`, `maxLines: 5`) — a soft-keyboard
  mechanism; on desktop hardware keyboards Enter inserts a newline in a
  multiline field, so explicit key handling is required work, not polish.
- Responsiveness: no breakpoint code exists (only media-sizing `LayoutBuilder`s).
- **Pulse is orphaned**: nothing outside `lib/features/pulse/` references it — no
  navigation entry exists on mobile today. "Light up pulse" means net-new wiring.
- Read state: `channels/read_state/` + `unread_badge/` are route-lifecycle-driven
  (mark-on-open/dispose). Embedded panes must reproduce this on selection change.
- Theme/tokens: `Grid` (2–80px scale) in `shared/theme/grid.dart`, `Radii` in
  `app_theme.dart`, `context.colors` / `context.textTheme` extensions.
- Tests: 49 files, `WidgetHelpers.testable(child, overrides)` +
  `ProviderScope` overrides + mocktail; fake notifiers extend real notifiers.
- Dependencies: nothing in `pubspec.yaml` blocks a pure-Dart shell. Riverpod 3
  (`hooks_riverpod ^3.0.3`) + `flutter_hooks`, `riverpod_lint`/`custom_lint`.

## Explored Approaches

**A. Width-adaptive shell composition (breakpoint-driven, state-backed panes)** — Recommended: Yes

Keep `HomePage` as the single entry. At `< 840dp` render the existing mobile shell
unchanged; at `≥ 840dp` render a new `DesktopShell` that composes existing feature
views as panes. Channel/thread/panel selection moves into a small shared state
(`shared/shell/`), and the handful of central navigation helpers
(`openChannelLink`, `DeepLinkDispatcher.destinationBuilder`, channel-list select,
search-hit select) branch on layout: push at narrow, select at wide. Full-screen
pages get thin "View" extractions so panes can embed them.

- Pros: mobile path untouched (zero regression surface at narrow widths); pure
  Dart and fully testable now via `setSurfaceSize`; also benefits tablets/foldables
  immediately; matches §5's wording ("responsive multi-pane"); incremental —
  each pane/conversion lands independently; no new dependencies.
- Cons: two navigation models coexist (push vs selection) with resize edge cases;
  requires embedding refactors of `ChannelDetailPage`/`ThreadDetailPage`/
  `ForumThreadPage`; ~6 navigation call sites and all 21 sheet call sites touched.
- Best when: the mobile UX must keep shipping unchanged while desktop layout is
  built ahead of desktop targets — exactly this situation.

**B. Platform-gated separate desktop shell (`Platform.isMacOS/…` picks a distinct app shell)** — Recommended: No

A standalone `DesktopHomePage` selected at startup by platform check, designed
desktop-first with no breakpoints.

- Pros: total freedom in the desktop layout; zero conditional layout logic inside
  panes; mobile code literally untouched.
- Cons: **cannot be exercised at all until Phase 0 lands** (no desktop platform to
  return true, and platform checks are awkward to fake in widget tests), so this
  phase would ship dead, unverifiable code — directly violating the
  "verifiable via flutter test" constraint; desktop windows still resize, so
  breakpoint handling is needed anyway; tablets get nothing; invites divergence
  between two shells.
- Best when: Phase 0 already shipped and the desktop UX intentionally diverges
  from any width-based rule. Not our case.

**C. Navigator-restructure: nested navigators / router-driven panes** — Recommended: No

Put the detail region behind a nested `Navigator` so existing pushes
(`ThreadDetailPage`, `ForumThreadPage`, media viewer) land "inside the pane"
without refactoring, or go further to a Navigator 2.0/GoRouter pane router.

- Pros: near-zero refactoring of existing pages for the nested-navigator variant;
  router variant gives deep-linkable pane URLs.
- Cons: GoRouter/Navigator 2.0 violates the repo's explicit Navigator 1.0
  convention and is a large-risk migration for no Phase 1 requirement. The
  nested-navigator variant hides navigation state from the shell (thread panel
  cannot be docked as a *sibling* column — it would stack *over* the messages),
  complicates deep-link dispatch, dialog/root-navigator scoping, and back-button
  semantics, and produces a stacked-pages-in-a-pane UX rather than the §5 parity
  layout (list + messages + thread side panel simultaneously visible).
- Best when: a temporary bridge is acceptable and parity layout is not the goal.
  It is the goal here.

## Recommended Approach (design direction)

Approach A, shaped as follows.

### Breakpoints — `mobile/lib/shared/layout/breakpoints.dart`

Material 3 window-size-class aligned, two thresholds only:

- `< 840` **compact/medium** → existing mobile UX, unchanged.
- `≥ 840` **expanded** → shell: rail (~64) + channel list pane (~280, fixed) +
  message pane (flex). Thread/side panel opens as a right-edge overlay.
- `≥ 1200` **large** → same, but the thread/side panel docks as a fourth column
  (~360, fixed).

Exposed as pure functions (`isExpandedLayout(BuildContext)`,
`isLargeLayout(BuildContext)`) reading `MediaQuery.sizeOf`. No pane resizing or
persistence in Phase 1.

### Shell state — `mobile/lib/shared/shell/`

A small Riverpod `Notifier` (`shellStateProvider`) holding IDs only (no feature
types, keeping `shared/` dependency-clean):

- `selectedChannelId: String?` (+ optional pending `initialMessageId` /
  `initialThreadRootId` carried from deep links/search),
- `sidePanel`: sealed — `none | thread(rootId, initialMessageId?) | activity`,
- `mainContent`: `channels | pulse` (rail destination).

Rules: opening one side panel closes the other; changing channel closes the
thread panel; state is ignored at narrow widths (push navigation remains
authoritative there).

### Shell composition — `mobile/lib/features/home/`

`home_page.dart` becomes the adaptive switch (existing mobile body extracted
unchanged); `desktop_shell.dart` + `part` files under
`features/home/desktop_shell/` (`community_rail.dart`, `side_panel_host.dart`,
`shell_shortcuts.dart`, …) compose:

- **Community rail**: community avatars + active indicator from
  `shared/community` providers (no dependency on the channels switcher sheet);
  Pulse destination icon; activity bell with unread badge (reuses
  `unread_badge` provider — home already imports channels); "+" (add community →
  existing pairing/join flow, pushed full-window); profile avatar at bottom →
  pushes `SettingsPage`.
- **Channel list pane**: reuse of the `ChannelsPage` body via an
  `onSelectChannel` override (it already threads `onSelectChannel` into
  `_ChannelsBody`); at wide widths select-into-state instead of push; the FAB
  becomes a header "+" icon button in pane mode (FAB is mobile-only).
- **Message pane**: `ChannelWorkspace` (new, in `features/channels/`) renders the
  selected channel via an extracted `ChannelDetailView` keyed by
  `ValueKey(channelId)` (fresh state per channel, matching today's
  fresh-route-per-channel behavior), plus the docked/overlay thread panel using an
  extracted `ThreadView` — keeping the `threadHead`/`allMessages` plumbing
  internal to the channels feature. Empty state when nothing selected.
  `ChannelDetailPage`/`ThreadDetailPage` remain as thin mobile wrappers around
  the extracted views (move-only refactor).
- **Side panel host**: the right-edge slot at shell level; renders Activity
  (existing `ActivityPage` body) when `sidePanel == activity`; the thread panel
  itself renders inside `ChannelWorkspace` but is driven by the same
  `sidePanel` state so the two never show simultaneously. Forum thread opens in
  the same slot via an extracted `ForumThreadView` (self-sufficient — loads by
  `channelId` + `postEventId`); channels already imports forum, so precedent
  holds.

### Navigation branching (push vs select)

One decision point per entry, all existing seams:

- `channels_page` select, `channel_link_navigation.openChannelLink`,
  `search_page` hit/DM navigation, `invite_join_sheet` post-join open, and
  `DeepLinkDispatcher` (via its existing `destinationBuilder` parameter): at
  wide → write `shellStateProvider`; at narrow → push exactly as today.
- Stays a full-window pushed route in Phase 1 (works fine in a desktop window):
  `SettingsPage` (+`ThemePickerPage`), `PairingPage`, pulse compose,
  `MediaViewerPage` (gains Esc-to-close).

### Bottom sheets → dialogs — `mobile/lib/shared/widgets/adaptive_modal.dart`

`Future<T?> showAdaptiveModal<T>(context, {required builder, bool
isScrollControlled = false, double maxWidth = 480})`: narrow →
`showModalBottomSheet` (drag handle, current look); wide → `showDialog` with a
`Dialog` constrained to `maxWidth` and `Radii` corners. All 21 call sites convert
mechanically; sheet content widgets are reused unchanged. Message actions
additionally gain `onSecondaryTapUp` (right-click) on message rows opening the
same surface; positioned/anchored popovers are deferred polish.

### Keyboard shortcuts — `shell_shortcuts.dart` + composer

`CallbackShortcuts` above the shell, modifier-based only (no bare-key conflicts
with text fields):

- Cmd/Ctrl+K → search overlay (existing `SearchPage` body inside a wide dialog;
  Search remains a tab at narrow widths),
- Cmd/Ctrl+, → settings,
- Esc → close side panel (dialogs already handle their own dismiss),
- Alt+ArrowUp/ArrowDown → previous/next channel in the visible ordered list
  (ordering helper exposed from the channels feature).

Composer (wide layouts / hardware keyboards): Enter sends, Shift+Enter inserts a
newline — explicit key handling in `ComposeBar`, since `TextInputAction.send`
does not fire for hardware Enter in a multiline field.

### Drag-drop seam — `mobile/lib/shared/widgets/attachment_drop_region.dart`

`AttachmentDropRegion(child, onFilesDropped)` with a provider-injected backend
(`dropRegionBackendProvider`, default no-op) and a hover/highlight visual state.
`ComposeBar` wraps the message pane region with it and adds a path/bytes-based
entry into the existing attachment upload pipeline (native sanitize steps
try/catch-gated — already a §5 desktop requirement). Phase 0 wires
`desktop_drop`'s `DropTarget` as the backend in one small change. Rationale:
`desktop_drop` is a platform plugin that cannot run or be verified without
platform folders; shipping the seam plus the upload path is the honest Phase 1
deliverable.

### Testing strategy

- Wide-surface widget tests via `tester.binding.setSurfaceSize(Size(1440, 900))`
  (and 1000×700 for the 840–1199 overlay band); narrow-size tests assert the
  mobile shell renders unchanged.
- Behavior tests: select channel → workspace swaps without route push; thread
  opens docked at ≥1200 and overlaid at 840–1199; activity/thread mutual
  exclusion; Esc closes panel; `showAdaptiveModal` picks dialog vs sheet by
  width; Cmd+K opens search; Alt+arrows move selection; composer
  Enter/Shift+Enter; drop-region backend fake delivers files into attachment
  state; embedded read-state marks on selection change.
- Existing 49 test files must stay green — the mobile-regression gate.

### Proposed file map (for the plan stage)

- `mobile/lib/shared/layout/breakpoints.dart` (+ test)
- `mobile/lib/shared/shell/shell_state.dart`, `shell_state_provider.dart` (+ tests)
- `mobile/lib/shared/widgets/adaptive_modal.dart` (+ test)
- `mobile/lib/shared/widgets/attachment_drop_region.dart` (+ test)
- `mobile/lib/features/home/home_page.dart` (adaptive switch; mobile body → part)
- `mobile/lib/features/home/desktop_shell.dart` + `desktop_shell/` parts
- `mobile/lib/features/channels/channel_workspace.dart`
- `mobile/lib/features/channels/channel_detail_view.dart` (extraction)
- `mobile/lib/features/channels/thread_view.dart` (extraction)
- `mobile/lib/features/forum/forum_thread_view.dart` (extraction)
- `mobile/lib/features/search/search_overlay.dart` (dialog host)
- Touch points: `channel_link_navigation.dart`, `deep_link_dispatcher.dart`,
  `channels_page.dart` (+parts), `compose_bar.dart` (+parts), all 21 sheet call
  sites, `media_viewer_page.dart` (Esc).

## Key Decisions

1. **Width-driven, not platform-driven** (840/1200, M3-aligned): testable today
   without desktop targets; activates automatically after Phase 0; tablets
   benefit; desktop windows resize anyway.
2. **Shell lives in `features/home`; selection state in `shared/shell` as IDs
   only**: `home` is the existing composition root; `shared/` must not import
   feature types, and leaf features may import `shared/shell` to trigger
   selection without breaking feature isolation.
3. **Panes embed extracted Views; pages stay as thin mobile wrappers**:
   move-only refactors preserve mobile behavior and keep both modes on one code
   path; no nested navigators (they preclude the docked side-by-side parity
   layout and complicate deep links and dialog scoping).
4. **Thread/activity share one side-panel slot** (docked ≥1200, overlay
   840–1199; mutually exclusive): matches §5 "thread/side panel" with the least
   state machinery.
5. **One `showAdaptiveModal` helper, centered dialogs everywhere** at wide
   widths; content unchanged; right-click opens message actions; anchored
   popovers deferred: converts 21 call sites mechanically and reversibly.
6. **Drag-drop ships as a pure-Dart seam + upload-pipeline entry, backend no-op
   until Phase 0** (`desktop_drop` is the designated backend): a platform plugin
   is unverifiable without platform folders, and zero-new-deps wins.
7. **Composer hardware-key handling is in scope** (Enter send / Shift+Enter
   newline): `TextInputAction.send` is soft-keyboard-only — without this the
   desktop composer cannot send at all.
8. **Pulse surfaces as a rail destination rendering `PulsePage` in the main
   content region, desktop shell only**: Pulse is currently orphaned (zero
   references outside its folder); wiring it into mobile navigation is a product
   change out of Phase 1 scope.
9. **Full-window pushed routes are retained where non-jarring** (settings,
   pairing, media viewer with Esc, pulse compose): Navigator pushes work fine in
   a desktop window; only bottom sheets and the core nav flow are unusable at
   width and thus converted.
10. **Zero new dependencies in Phase 1**; all §5 dep swaps (`file_selector`,
    `media_kit`, `desktop_drop`, `window_manager`, clipboard) recorded as
    deferred to Phase 0/2.

## Risks & Mitigations

1. **Mobile regression from View extractions** (channel/thread/forum pages are
   load-bearing): extractions are move-only with wrappers preserving constructor
   contracts; existing 49 test files gate; add narrow-width shell tests.
2. **No desktop runtime exists to verify visually** — the phase's output is
   proven by analyze + wide-surface widget tests only; real-window QA happens in
   Phase 0. Mitigation: test at 1000×700, 1440×900, and narrow sizes; keep all
   layout constants in one place for cheap retuning later.
3. **Two navigation models + window resize edge cases**: crossing wide→narrow
   leaves shell selection dormant (list page shows as today); narrow→wide leaves
   any pushed detail route stacked over the shell until popped. Accepted for
   Phase 1 and documented; no breakpoint-crossing auto-pop machinery (YAGNI).
4. **Read-state/unread correctness in embedded mode**: mark-read is currently
   tied to route lifecycle (`read_state/deferred_read_state_update.dart`).
   Selection-change effects must reproduce open/close semantics exactly; this is
   the subtlest logic touched (DESKTOP_PORT_PLAN §8.2 warns here). Mitigation:
   dedicated widget tests around channel-switch mark-read, and reuse the
   existing read-state API rather than adding a parallel path.
5. **1000-line file cap pressure**: `channel_detail_page.dart` and
   `channels_page.dart` already carry many parts; extractions must land as new
   files/parts, never grow existing ones past the cap (`check-file-sizes.mjs`
   enforces).
6. **Dialog-ified sheets may look sparse/phone-shaped at 480px**: cosmetic;
   accepted for parity-shell scope; per-surface polish deferred.
7. **Scope breadth** (shell + state + 21 sheet sites + shortcuts + composer +
   drop seam + extractions): mitigated by the slicing below — each slice is
   independently green and mergeable.

## Open Questions — Resolved with Defaults

1. *Expanded breakpoint 840 vs 900/1000?* → **840** (Material 3 "expanded"
   boundary; landscape tablets get the shell; desktop default windows exceed it).
2. *Where does channel creation live on desktop?* → **Header "+" icon button in
   the channel list pane** opening the existing quick-actions surface as a
   dialog; FAB remains mobile-only (floating FABs are alien in a 280px pane).
3. *Search on desktop: pane, page, or overlay?* → **Cmd/Ctrl+K centered overlay
   dialog reusing the SearchPage body**; remains a tab at narrow. Matches the
   desktop app's overlay pattern with zero new search logic.
4. *Does the community switcher sheet get reused for the rail?* → **No — the
   rail renders directly from `shared/community` providers**; the sheet remains
   the mobile surface. Avoids exporting channels-feature internals.
5. *Thread panel at 840–1199 where a docked column doesn't fit?* → **Right-edge
   overlay panel (same widget, positioned)**; docked only at ≥1200. Rail 64 +
   list 280 + messages ≥400 + thread 360 needs ~1104+; overlay keeps messages
   readable below that.
6. *Should the thread panel auto-open on reply/mention?* → **No** — existing
   triggers only (tap thread affordance, deep links). New auto-behaviors are
   product decisions beyond parity.
7. *Media viewer: windowed/hover rebuild now?* → **No — full-window push +
   Esc-to-close**; the §5 windowed viewer is real work with no Phase 1 payoff
   and depends on desktop window behavior we cannot run yet.
8. *Forum thread: full-window push or panel?* → **Side-panel via
   `ForumThreadView` extraction** — a full-window push over the shell for a core
   reuse feature is the most jarring remnant, and the view is self-sufficient
   (loads by IDs). Flagged as the first slice to drop to a fast-follow if scope
   must shrink.
9. *Keyboard shortcut breadth?* → **Four global shortcuts + composer keys**
   (listed above). Every additional binding is trivially added later; conflicts
   and discoverability are the risk, not implementation.
10. *Profile "basic edit" scope?* → **Whatever exists today (settings-hosted
    edit + user profile sheet as dialog)** — no new profile-editing UI; §3 only
    requires view + basic edit to be reachable in the shell.
11. *Should `App`/`app.dart` change?* → **Only if needed for shell providers;
    the auth `switch` stays provider-driven and structurally as-is** (§5 asks
    for a rework "accordingly" — the adaptive split lives inside `HomePage`,
    which is the smaller change).

## Auto-resolved assumptions

Recorded per the non-interactive run contract; each would normally be a human
question.

1. **Phase 0 is not done and is not started here**: pure Dart under `mobile/lib`
   + `mobile/test`; no `flutter create`, no platform folders, no
   `flutter run/build/clean/upgrade`; verification = `dart format` +
   `flutter analyze` + `flutter test` only. The shell is breakpoint-driven so it
   is dormant on phones, active in wide widget tests today, and fully active
   once Phase 0 lands. (Hard constraint, treated as fixed.)
2. **Repo conventions are binding**: Riverpod 3 + flutter_hooks
   (`HookConsumerWidget`/`ConsumerWidget`, never `StatefulWidget`), no code-gen,
   Navigator 1.0, feature isolation with `shared/` as the only cross-feature
   import (with `features/home` continuing its existing composition-root role),
   1000-line cap via `part` files, `Grid`/`Radii` tokens,
   `context.colors`/`context.textTheme`, widget tests preferred, `debugPrint`.
   (Hard constraint.)
3. **YAGNI cut line**: Phase 1 only — no Bucket A/B features, no home
   inbox/feed, no OS notifications; zero new dependencies; dep swaps
   (`media_kit`, `file_selector`, `desktop_drop`, `window_manager`) explicitly
   deferred to Phase 0/later. (Hard constraint.)
4. Breakpoints fixed at **840/1200** without design input, per Material 3 window
   size classes.
5. **Drag-drop is delivered to the OS boundary only** (seam + pipeline + visual
   state, no-op backend): a platform plugin cannot be exercised without Phase 0,
   so full OS drop lands there. This interprets the Phase 1 bullet "add
   drag-drop upload" as "everything verifiable in pure Dart".
6. **Pulse gets a desktop-only entry point** (rail); mobile navigation is
   intentionally left unchanged despite Pulse being orphaned there.
7. **Sheets become centered dialogs uniformly** (no per-surface
   popover/side-panel designs in Phase 1), except thread/activity/forum-thread
   which get the side panel, and message actions which also gain right-click
   invocation.
8. **Settings, pairing, media viewer, pulse compose remain full-window pushed
   routes** in Phase 1.
9. **Resize-across-breakpoint edge cases are accepted and documented** rather
   than engineered around (no auto-pop, no state migration between modes).
10. **Search overlay uses Cmd/Ctrl+K**, accepting the collision with the desktop
    app's quick-switcher semantics (here it opens full search) until a
    quick-switcher exists.
11. The brainstorm skill's interactive steps (scope confirmation, approach
    choice, branch setup, next-step menu) were resolved non-interactively: scope
    = feature work in this repo on the current branch; approach = A; no workflow
    branching performed by this stage.

## Deferred (explicit, for later phases)

- Phase 0: desktop platform folders; `desktop_drop` backend wiring;
  `file_selector`/`media_kit`/`app_badge_plus` guards; `buzz/media_upload`
  MethodChannel gating verification on a real desktop build; visual QA of the
  shell; `AppBadgePlus` call-site guard in `app.dart`.
- Phase 2+: home inbox/feed, OS notifications, window chrome/traffic
  lights/vibrancy, anchored popovers/context menus, windowed media viewer,
  pane resizing + persistence, quick-switcher, deep-link pane URLs.

## Suggested implementation slicing (input to the plan/split stage)

1. **Foundations**: breakpoints + `shared/shell` state + `showAdaptiveModal` +
   adaptive `HomePage` switch with placeholder shell (tests for all).
2. **Shell panes**: community rail, channel list pane reuse,
   `ChannelDetailView` extraction + `ChannelWorkspace` + empty state; selection
   branching at the navigation seams; embedded read-state handling.
3. **Side panel**: `ThreadView` extraction + docked/overlay panel + activity
   panel + `ForumThreadView`; deep-link `destinationBuilder` integration.
4. **Sheet conversions**: all 21 call sites through `showAdaptiveModal`;
   right-click message actions; media viewer Esc.
5. **Input layer**: shortcuts, composer Enter/Shift+Enter, drop-region seam +
   upload-pipeline entry; Pulse rail destination.
