# Flutter Desktop App — Port & Feature-Parity Plan

**Goal:** Build a Flutter **desktop** app (macOS / Windows / Linux) that reuses the
existing Flutter code in `mobile/lib` and additionally re-implements the features
currently available only in the Tauri + React desktop app (`desktop/`).

**Status:** Planning. Investigation complete (see [§2](#2-current-state)).

**Scope note:** **Huddle (real-time voice) is DEFERRED** — out of scope for the
initial effort. It is documented here for completeness but is not on the roadmap
below.

---

## 1. TL;DR — the finding that drives all the work

The two apps are architected in **opposite** ways, and that is what determines cost:

- **`mobile/` (Flutter)** is a *real Nostr client written in Dart*. The relay/WebSocket
  stack, NIP-42 auth, crypto, OS key storage, all event models, every feature's
  business logic, and the entire theme system live in **portable Dart**.
- **`desktop/` (Tauri + React)** is a *thin React UI over a fat Rust core*. Almost
  nothing touches the network in JS — Rust owns keys, signing, the relay connection,
  feed/search/threads, media, the local archive, agents, huddle audio, git, and
  local-LLM compute.

Therefore "re-implement the desktop features in Flutter" is **three kinds of work**,
and most desktop features land in the cheap bucket:

1. **Reuse** — the mobile app already ported the core Nostr/crypto/theme layer. Big win.
2. **Re-layout** — mobile has no responsive multi-pane shell and uses bottom-sheets
   everywhere; the reused features need a desktop UI.
3. **Reproduce native capabilities** — the genuinely expensive part (agents, git,
   local-LLM; huddle deferred).

**Step 0:** the Flutter project has **no desktop targets yet** — `mobile/macos`,
`mobile/windows`, `mobile/linux` do not exist. First action is
`flutter create --platforms=macos,windows,linux .` (or a new desktop app that
depends on the shared code).

**The single most important strategic decision:** for the hard native features
(agents, mesh-compute, git — and huddle if/when it returns) **reuse the existing
Rust via [`flutter_rust_bridge`](https://cjycode.com/flutter_rust_bridge/)**, do not
rewrite in Dart. Those Rust modules have minimal Tauri coupling, which is exactly
what makes bridging viable and a Dart rewrite wasteful/risky.

---

## 2. Current state

### 2.1 Mobile Flutter app (`mobile/lib`) — the reuse base

- ~33.6k LOC Dart, Flutter SDK `^3.11.4`, clean layered architecture
  (`main.dart` → `app.dart` → `features/*` + `shared/*`, hard "no cross-feature
  imports except `shared/`" rule).
- **Riverpod 3 + flutter_hooks**, hand-written notifiers, **no code-gen** (no Freezed /
  build_runner), **Navigator 1.0** (no GoRouter).
- Targets **android + ios only** — no desktop platform folders.
- Everything flows over a **single relay WebSocket** (NIP-01/29 + NIP-42 auth); only
  two HTTP calls remain (`POST /query` bridge, Blossom `PUT /upload`).

### 2.2 Desktop app (`desktop/`) — the feature source

- **Frontend** (`desktop/src`, React 19 + Vite + TanStack Router/Query + Tailwind):
  28 feature areas, but *pervasively* backend-dependent — no "pure UI, just re-skin"
  tier. The WebSocket itself is routed through a native Tauri plugin, and every
  outbound event is signed by Rust.
- **Backend** (`desktop/src-tauri`, ~93k LOC Rust): ~230 Tauri commands. It is a relay
  *client* (there is **no embedded relay**), plus a large set of OS-level capabilities.

---

## 3. Reuse inventory — what already exists in Flutter

The data/domain layer and theme port **essentially unchanged** — the majority of the
codebase and all the hard protocol logic:

| Already in Flutter mobile | Reuse status |
|---|---|
| Relay client, NIP-42/98 auth, subscriptions, reconnect, batching/dedup | Pure Dart — as-is |
| Nostr event models + `EventKind` catalog (kept in sync with `desktop/src/shared/constants/kinds.ts`) | As-is |
| Crypto — NIP-44 v2, ECDH, HKDF (pointycastle, pure Dart) | As-is |
| Key storage — `flutter_secure_storage` (Keychain / Cred Mgr / libsecret) | As-is (desktop-capable) |
| Multi-community / workspace switching | As-is |
| **Channels** + message timeline + composer (mentions, `#channel`, custom emoji, markdown, code, reactions, threads, media) | Logic as-is; **needs desktop layout** |
| Forum, Pulse (kind-1 notes), Search (NIP-50), Profile, Presence (kind 20001), User-status (NIP-38), Custom emoji (NIP-30), Activity feed, Invites | Logic as-is; **needs desktop layout** |
| Full theme system — Catppuccin Latte/Macchiato + 60-theme adaptive engine (ported from `desktop/src/shared/theme/adaptive-theme.ts`) | As-is — pixel-matches desktop |

For these, the porting cost is **layout, not logic** (see [§5](#5-the-desktop-shell-re-layout-work)).

---

## 4. Gap analysis — what must be re-implemented

Legend: **A** = product feature, mostly Dart/Nostr work · **B** = native/heavy
capability · effort is relative.

### 4.1 Bucket A — product features desktop has that Flutter lacks (moderate, Dart-side)

| Feature | Desktop size | Notes |
|---|---|---|
| **Home Inbox/Feed** | ~4.8k LOC | Desktop `/` = resizable inbox of threads/DMs + feed sections + recent notes. Mobile "home" is only a bottom-nav shell → this screen is net-new. |
| **Onboarding flows** | ~9.5k LOC | 3 gated state machines (device/keyring → community/relay-join → app/profile). Mobile's is much lighter. |
| **Workflows** | ~3k LOC | Trigger→step automations, webhooks, approvals. Mostly UI over relay data. |
| **Notifications (OS)** | ~1.6k LOC | Mobile has only in-app activity + app badge; real OS notifications + dock/taskbar badge + bounce are missing (native bits in [§6](#6-native--os-plumbing-bucket-c)). |
| **Community-members admin** | ~1.5k LOC | Relay-level membership (roles, invite links). Partial today via mobile invites. |
| **Reminders (NIP-ER)** | ~1.4k LOC | Encrypted "remind me later" on messages + snooze/scheduling. |
| **Moderation** | ~940 LOC | Timeouts, report-message, restriction banners. |
| **Agent-memory viewer** | ~786 LOC | Visualizes agent NIP-AE "engram" graph. |
| **Channel-templates** | ~260 LOC | Reusable channel-set templates. |

### 4.2 Bucket B — native-capability features (expensive; prefer Rust reuse via bridge)

| Feature | Why it's hard | Recommendation |
|---|---|---|
| **Agents** (managed AI agents) — *~38k LOC, biggest single cost* | Spawns/supervises local CLI processes (ACP runtimes + MCP servers): process-group / Windows Job-Object **tree-kill**, cross-instance orphan reaping, large env injection, PATH augmentation, live transcripts, model/provider discovery, observer encryption | **Reuse** the `buzz-acp` sidecar + Rust spawn core; re-do only the supervise/env layer. `dart:io` `Process` can spawn but **cannot tree-kill without FFI**. |
| **Projects** (git/PR/issues) — ~15k LOC | Native git clone/diff/PR-sign, opens native terminal, diff rendering | Reuse Rust git commands via bridge; build diff/PR UI in Flutter (`Process.start` + a Dart diff view). |
| **Mesh-compute** (local LLM) | Embedded llama.cpp/ggml+Metal, `iroh` QUIC P2P mesh, OpenAI-compatible localhost ingress on `:9337` | No Dart path exists. FRB-wrap the `mesh-llm` SDK **or** ship as a sidecar. **Strong candidate to cut for v1.** |
| **Local-archive** | SQLite event store + per-kind save-subscriptions + observer index | **Easy in Dart** — `drift`/`sqlite3` port the schema (`archive/store.rs`) directly. |
| **Identity-archive** | Archive/unarchive identities, resolve orphaned-agent ("OA") ownership | Small — keyring + Nostr work. |
| **Animated-avatar studio** (part of `profile`) | Webcam capture + MediaPipe background removal + animated-PNG encoding | A mini-app in itself. Defer or ship a simplified static-avatar editor first. |
| ~~**Huddle** (real-time group voice)~~ | **DEFERRED — see [§7](#7-deferred-huddle)** | Not on the roadmap. |

### 4.3 Feature → mobile-status map (quick reference)

| Desktop feature | Mobile status |
|---|---|
| channels, chat, messages | ✅ exists (reuse + re-layout) |
| forum, pulse, search, custom-emoji | ✅ exists |
| profile, presence, user-status | ✅ exists (animated-avatar studio missing) |
| communities | ✅ exists (multi-community storage) |
| sidebar | ⚠️ navigation pattern differs (mobile = bottom nav) → build desktop shell |
| home | ⚠️ different concept (mobile shell vs desktop inbox/feed) → build inbox/feed |
| onboarding | ⚠️ lighter on mobile → build full flows |
| notifications | ⚠️ in-app only on mobile → add OS notifications |
| community-members | ⚠️ partial (invites) → build admin |
| reminders, moderation, workflows, channel-templates, agent-memory, identity-archive, local-archive | ❌ missing (Bucket A/B) |
| agents, projects, mesh-compute | ❌ missing (Bucket B, native) |
| huddle | ⛔ **deferred** |

---

## 5. The desktop shell — re-layout work

The reused mobile features are built for touch and full-screen navigation; the desktop
UI must change even though the logic is kept:

- **Navigation shell:** replace `home_page.dart`'s floating bottom tab bar +
  `Navigator.push` full-screen pages with a **responsive multi-pane layout**
  (community rail + channel list + message pane + thread/side panel). Rework the
  `app.dart` auth `switch` accordingly (keep it provider-driven).
- **Bottom sheets → dialogs/popovers/panels:** every `showModalBottomSheet` surface
  (compose attach, emoji picker, members sheet, user-profile sheet, set-status,
  manage-channel, invite-join, agent-activity) becomes a desktop dialog/side panel.
- **Composer:** keep the logic; add drag-and-drop file upload, right-click menus, and
  desktop keyboard shortcuts (Enter-to-send already present).
- **Media viewer:** windowed/hover viewer instead of full-screen pinch-zoom.
- **Chrome:** `FrostedAppBar`/`FrostedScaffold` assume the mobile status-bar safe area;
  retune for desktop window chrome. `SystemUiOverlayStyle` calls are inert on desktop.

**Mobile-specific deps to swap even for reused features:**

| Mobile dep | Problem on desktop | Replace with |
|---|---|---|
| `image_picker` | mobile gallery idiom | `file_selector` + drag-drop |
| `video_player` | no official Windows/Linux support | `media_kit` |
| `mobile_scanner` (QR camera) | camera-scan pairing is a mobile *receiver* flow | not needed — invert pairing (see [§6](#6-native--os-plumbing-bucket-c)) |
| `app_badge_plus` | mobile dock badge | guard to macOS; `window_manager` badge elsewhere |
| Native `buzz/media_upload` MethodChannel (HEIC sanitize, image→JPEG, video→MP4, clipboard-image) — Kotlin+Swift only | **no desktop impl → `MissingPluginException`** | reimplement via `Process.start(ffmpeg)` + `package:image`, or gate off |

---

## 6. Native / OS plumbing (Bucket C)

Each Tauri capability needs a Flutter-desktop equivalent. **Good news: no system tray
and no global shortcuts are used today** (huddle's PTT shortcut is the only global
hotkey, and it's deferred), so those are non-requirements for v1.

| Native capability | In use? | Flutter equivalent | Difficulty |
|---|---|---|---|
| Raw WebSocket (native plugin) | yes | **native Dart `WebSocket`** — the plugin *disappears* | trivial |
| Clipboard (text + image) | yes | `super_clipboard` | easy |
| Open external URL | yes | `url_launcher` | easy |
| File pickers / dialogs | yes | `file_selector` / `file_picker` | easy |
| Prevent-sleep | yes | `wakelock_plus` (or IOKit FFI for exact idle) | easy |
| Deep links `buzz://` | yes | `app_links` (already used on mobile) | easy-medium |
| Notifications + dock/taskbar badge + bounce + focus | yes | `local_notifier` + `window_manager` | medium |
| Window drag / double-click-maximize / webview-zoom / fullscreen | yes | `window_manager` / `bitsdojo_window` | medium |
| ffmpeg / image transcode | yes | `Process.start(ffmpeg)` + `package:image` (PATH-discovery caveat) | medium |
| OS-idle detection | yes | FFI (`CGEventSource…` / `GetLastInputInfo`) | medium |
| Window vibrancy / custom titlebar / traffic-lights | yes | `flutter_acrylic` + `window_manager` | medium |
| Single-instance + deep-link forwarding | yes | `flutter_single_instance` or manual mutex/socket (Linux `.desktop` / Windows registry) | medium |
| Auto-updater + relaunch | yes | `auto_updater` (Sparkle/macOS + Windows); Linux AppImage self-update manual | medium-hard |
| Secret store nuances — single-blob/one-prompt, cross-process advisory lock, DPK/legacy migration | yes | `flutter_secure_storage` covers the 3 backends, but the one-prompt + inter-process lock are **load-bearing** and need FFI/custom work | medium-hard |
| **Device pairing — inverted** | — | mobile is the *receiver* (QR scan); desktop is the **source** (show QR, send identity via NIP-AB). The source-side flow **does not exist** in `mobile/lib` — net-new. Reusable parts: `pairing_crypto`/`nip44`/`ecdh` + NIP-AB message shapes, run in the opposite role. | medium-hard |

---

## 7. Deferred: Huddle

**Not in scope for now** (per project decision). Recorded so the deferral is explicit
and the eventual cost is known.

- Real-time group voice in a channel with live STT (posted as chat) and TTS playback of
  AI-agent replies; push-to-talk or VAD.
- **Not WebRTC** — a custom server-mixed **WebSocket audio** wire protocol
  (`wss://{relay}/huddle/{channel}/audio`, 8-byte per-frame header) + **Opus** (libopus)
  + **NetEQ** jitter buffer + **sherpa-onnx** STT (Parakeet TDT-CTC) & TTS
  (Kyutai Pocket, ~473 MB) + **cpal/rodio** audio I/O. ~660 MB of models pulled lazily.
- Mic capture currently lives in the WebView AudioWorklet and would need rebuilding
  (`record` / cpal-FFI).
- **When revisited:** FRB-wrap the existing `desktop/src-tauri/src/huddle/` module rather
  than rewrite — it is portable Rust with minimal Tauri coupling, and `sherpa_onnx` has
  official Dart bindings. A pure-Dart rewrite is impractical.

---

## 8. Hidden costs (don't under-budget)

1. **Relay resilience layer.** Desktop has ~15 files of reconnect/replay/rate-limit/
   stall-watchdog logic (`desktop/src/shared/api/relay*.ts`). Mobile has a solid version
   (`relay_session.dart`), but desktop's is more elaborate — budget for parity.
2. **Read-state / unread engine.** Subtle and well-tested on both sides
   (`desktop/src/features/channels/readState/`, mobile `channels/read_state/`,
   `unread_badge/`). Reuse the mobile one in the new shell; don't reinvent.
3. **AppShell composition root.** `desktop/src/app/AppShell.tsx` (~37 KB) wires ~40
   cross-cutting hooks. The Flutter equivalent (the multi-pane shell + its provider
   wiring) is a real piece of work on its own.

---

## 9. Roadmap

### Phase 0 — Scaffold (days)
- `flutter create --platforms=macos,windows,linux .` in the Flutter project.
- Verify the reusable core builds on desktop: relay stack, crypto, secure storage,
  theme. Swap `video_player`→`media_kit`, `image_picker`→`file_selector`, guard
  `app_badge_plus`, and gate the native `buzz/media_upload` MethodChannel.
- Prove one reused screen end-to-end (e.g. a channel message list) in a desktop window.

### Phase 1 — Parity shell (reuse-heavy, highest value/lowest risk)
- Build the **responsive multi-pane navigation shell** ([§5](#5-the-desktop-shell-re-layout-work)).
- Light up everything in the reuse inventory ([§3](#3-reuse-inventory--what-already-exists-in-flutter)):
  channels, messages, forum, pulse, profile (view + basic edit), search, settings,
  presence, user-status, custom-emoji, communities, activity, invites.
- Convert bottom-sheets to dialogs/panels; add drag-drop upload + keyboard shortcuts.

### Phase 2 — Cheap missing features (Bucket A)
- Home inbox/feed, reminders, moderation, community-members admin, channel-templates,
  workflows, agent-memory viewer, fuller onboarding flows, **OS notifications**
  (+ dock badge/bounce via `window_manager`).
- Native plumbing from [§6](#6-native--os-plumbing-bucket-c): deep links, prevent-sleep,
  single-instance, auto-updater, window chrome.

### Phase 3 — Native bridges (Bucket B) — decide per feature
- **Reuse Rust via `flutter_rust_bridge`** for: agents (spawn core), projects (git).
  Build the Flutter UI on top.
- Local-archive: straight Dart (`drift`). Identity-archive: small Dart.
- **Defer** mesh-compute and the animated-avatar studio (cut for v1; revisit later).

### Deferred (not scheduled)
- **Huddle** ([§7](#7-deferred-huddle)) and its PTT global shortcut.
- Mesh-compute (P2P local LLM) — the single hardest capability; cut first.

---

## 10. Open decisions

1. **Where does the desktop app live?** Add desktop targets to the existing `mobile/`
   Flutter project (simplest code reuse) vs a new sibling Flutter app that depends on a
   shared package. Recommendation: add targets to `mobile/` first; extract a shared
   package only if a second app materializes.
2. **Rust reuse mechanism per native feature:** `flutter_rust_bridge` (in-process FFI)
   vs shipping the existing binaries as **sidecar processes** (Flutter has no Tauri
   `externalBin`; binaries ship as bundled assets, paths resolved manually). Agents
   already use a sidecar (`buzz-acp`) — likely keep it; bridge the smaller Rust cores.
3. **v1 feature cut line.** Proposed: ship Phases 0–2 + local-archive/identity-archive;
   defer agents/projects to a fast-follow, and mesh-compute + huddle + animated-avatar
   indefinitely.
4. **Secret-store parity.** Accept multiple keychain prompts initially, or port the
   single-blob/one-prompt + cross-process lock design via FFI up front?

---

*Generated from an investigation of `mobile/lib` (Flutter), `desktop/src` (React
frontend), and `desktop/src-tauri` (Rust backend). Paths and sizes are from that
review; treat LOC figures as approximate.*
