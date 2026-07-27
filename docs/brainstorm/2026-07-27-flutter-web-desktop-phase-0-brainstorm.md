---
date: 2026-07-27
topic: flutter-web-desktop-phase-0
source-plan: mobile/DESKTOP_PORT_PLAN.md (§9 Phase 0, §5, §6, §10)
predecessor: docs/plan/2026-07-26-feat-flutter-desktop-parity-shell-plan.md (Phase 1, landed)
---

# Flutter Web as the "Desktop" Surface (Phase 0, retargeted to web only)

## Problem Statement

`mobile/DESKTOP_PORT_PLAN.md` §9 defines Phase 0 as: add desktop platform
targets, verify the reusable core builds there, swap mobile-only dependencies,
prove one reused screen in a desktop window. Phase 1 (the responsive multi-pane
parity shell) **already landed** on `main` — `desktop_shell.dart`,
`breakpoints.dart`, `shell_state_provider.dart`, `adaptive_modal.dart`,
`attachment_drop_region.dart` and 60 test files ship today. But the shell is
**dormant**: `mobile/` targets android + ios only, so no runtime exists where
width ≥ 840 and the desktop layout is reachable.

The human has narrowed the target: **macOS, Windows and Linux are out of scope.
The "desktop" surface is a Flutter WEB build viewed in a browser window at
desktop width.**

That retargeting invalidates most of the plan's Phase 0 dependency-swap list,
which was written for *native* desktop. `video_player` and `image_picker` have
first-party endorsed web implementations; the plan's suggested replacements
(`media_kit`, `file_selector`) are native-desktop answers that buy nothing on
web. Meanwhile web introduces four risks the plan never considered: browser
CORS, browser key storage, `MissingPluginException` for plugins with no web
implementation, and `dart:io` symbols that compile fine and then throw at
runtime.

## What We're Building

A **web platform target for the existing `mobile/` Flutter app**, added
additively so android and iOS are untouched. Concretely: a hand-authored
`mobile/web/` runner directory, `kIsWeb` gating at the handful of call sites
that would crash in a browser, a session-only credential store for web, and a
`flutter build web` gate plus desktop-width widget tests that prove the
already-landed Phase 1 shell renders through a real web compile.

This is a **compile-and-gate** phase, not a feature phase. It ends with an
unmerged PR whose value is: the web target exists, the reachable Dart graph
compiles under dart2js, the known runtime landmines are guarded and tested, and
a human has a precise checklist of what only they can verify in a browser.

## Goals

1. `cd mobile && flutter build web --release` succeeds from a hand-authored
   `mobile/web/`, with no `flutter create`.
2. Every identified web runtime crash is guarded and covered by a widget test.
3. Credentials are not persisted to browser storage.
4. Android/iOS behavior is byte-identical: no dependency changes, no pubspec
   version bump, no change to any non-web code path.
5. A documented, honest statement of what the automated gates prove and what
   only a human running a browser can confirm.

## Non-Goals

- **No native desktop platform folders** (`mobile/macos`, `mobile/windows`,
  `mobile/linux`). Explicitly cut by the human.
- **No dependency additions, removals, or version changes.** In particular no
  `file_selector`, `media_kit`, `desktop_drop`, `window_manager`,
  `super_clipboard`, or an `app_badge_plus` replacement.
- **No Phase 1 re-layout work** — it landed. No new panes, breakpoints,
  dialogs, or shortcuts.
- **No Phase 2/3 features** (home inbox/feed, onboarding, workflows, OS
  notifications, reminders, moderation, members admin, channel templates,
  agent-memory, agents, projects, local-archive), no huddle, no mesh-compute,
  no animated-avatar studio.
- **No changes to `crates/buzz-relay`** or any Rust. The CORS gap found below
  is reported, not fixed, in this run.
- **No CI workflow changes** — `.github/workflows/ci.yml` is guardrail-blocked.
  The web build gate is a local `just` recipe only.
- **No "Phase 0 visual QA"** items inherited from Phase 1 (see
  [Inherited Phase 1 backlog](#inherited-phase-1-backlog-resolved-item-by-item)).

## Codebase Context (grounding facts)

Everything below was verified in this repo at `feat/flutter-web-desktop-phase-0`
(clean, Flutter 3.44.4 / Dart 3.12.2, `flutter analyze` → **No errors**).

- `mobile/lib`: 172 Dart files, ~35.6k LOC. `mobile/test`: 60 `*_test.dart`
  files. `flutter analyze` is clean today — that is the regression baseline.
- `mobile/` has `android/` and `ios/` only. `flutter build web` currently exits
  with: `This project is not configured for the web. To configure this project
  for the web, run flutter create . --platforms web` — and `flutter create` is
  hook-blocked.
- `flutter config` reports `enable-web: true`. No config change needed.
- `WebProject.existsSync()` (`flutter_tools/lib/src/project.dart:1132-1133`)
  requires exactly `web/` **and** `web/index.html`. That is the whole gate.
- The SDK template is `$FLUTTER_ROOT/packages/flutter_tools/templates/app/web/`:
  `index.html.tmpl`, `manifest.json.tmpl`, `favicon.png`, and four icons
  (`Icon-192`, `Icon-512`, `Icon-maskable-192`, `Icon-maskable-512`).
  `index.html` uses `<base href="$FLUTTER_BASE_HREF">` and a single
  `<script src="flutter_bootstrap.js" async>`. **`flutter_bootstrap.js` is
  generated at build time — do not hand-write it.** No `serviceWorkerVersion`,
  no `_flutter.loader.loadEntrypoint`; those are the obsolete pre-3.22 forms.
- `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
  exists and is a usable source for the web icons via `sips` (the bundled
  `assets/images/buzz-icon.png` is 294×197, not square — unsuitable).
- `mobile/.gitignore` ignores `/build/` but nothing named `web`, so
  `mobile/web/` is committable and `mobile/build/web/` output is ignored.
- Relay URL: `Env.relayUrl` = `String.fromEnvironment('BUZZ_RELAY_URL')`,
  default `http://localhost:3000` (`relay_provider.dart:35-38`). `--dart-define`
  works identically for `flutter build web`. `RelayConfig.wsUrl` derives
  `wss` from `https`, else `ws` (`relay_provider.dart:22-27`) — mixed-content
  correct by construction.
- `CI` (`.github/workflows/ci.yml:761-816`) runs mobile format/analyze/test/
  `build-android`. Editing it is blocked.

## The four risk surfaces

### 1. `dart:io` — compiles on web, throws at runtime (empirically verified)

The plan's framing ("only a web compile catches this") is **wrong**, and the
correction matters. `dart:io` is mapped for `dart2js` via `_dart2js_common`
in `dart-sdk/lib/libraries.json`, patched by
`_internal/js_runtime/lib/io_patch.dart` (120 `UnsupportedError` throws), with
`support_conditional_import: false`. So: **`import 'dart:io'` compiles cleanly
under dart2js**, and `dart.library.io` still evaluates `false` in conditional
imports.

Verified empirically by compiling a probe with `dart compile js` and running it
under node:

| Symbol | Compiles | Runtime on web |
|---|---|---|
| `HttpStatus.notFound` / `.methodNotAllowed` / `.unsupportedMediaType` / `.unprocessableEntity` | yes | **OK** — plain int consts (404/405/415/422) |
| `x is SocketException` | yes | **OK** — always `false` |
| `x is FileSystemException` | yes | **OK** — always `false` |
| `File(path)` construction, `.path` | yes | **OK** — lazy |
| `File(path).existsSync()` / `.length()` / `.readAsBytes()` / `.delete()` | yes | **THROWS** `Unsupported operation: _Namespace` |
| `Platform.isAndroid` / `.operatingSystem` | yes | **THROWS** `Unsupported operation: Platform._operatingSystem` |

**Consequence: `flutter build web` succeeding proves nothing about `dart:io`
safety.** That reshapes the verification strategy (§ below).

Actual hits — only three files in `mobile/lib` import `dart:io`:

| File | Symbols used | Verdict |
|---|---|---|
| `mobile/lib/features/channels/channels_page.dart:2` | `SocketException`, used only at `channels_page/badges.dart:138` (`if (error is SocketException)`) | **Web-safe as written.** Type test evaluates `false`; the error message falls through to the generic branch. No change needed. (An earlier audit called this import unused — it is used, by a `part` file.) |
| `mobile/lib/shared/relay/media_upload.dart:2` | `HttpStatus.*` at :255-269 (safe); `File(...)` I/O at :215-227 and :611-612; `FileSystemException` at :622 | **Constants safe.** The `File` I/O sits inside `pickAndUploadVideo()` and inside a `defaultTargetPlatform == TargetPlatform.android` branch (:610). The android branch is unreachable on web; `pickAndUploadVideo()` is reachable — but it hits the MethodChannel *first* (see §3). |
| `mobile/lib/shared/relay/mp4_fast_start.dart:2` | `File`, `RandomAccessFile`, `FileMode` throughout | **Unreachable on web** — its only caller is `media_upload.dart:616`, inside the android-only branch. |

No `dart:io` `Platform` usage exists anywhere in `mobile/lib` — every hit is
`defaultTargetPlatform` from `package:flutter/foundation.dart`, which is
web-correct. Transitive packages that import `dart:io` unconditionally
(`video_player/video_player.dart:6` for `.file()`;
`package_info_plus`'s unconditionally-exported `_linux.dart`) are compile-safe
for the same reason and are not reachable via the app's call sites.

**Strategy: no conditional-import scaffolding is needed.** The plan assumed a
`_stub.dart` / `_io.dart` / `_web.dart` seam per file; the evidence says that
would be pure ceremony. The three files stay as they are. What actually needs
gating is the *plugin* layer, below.

### 2. Plugin web-support audit (versions from `mobile/pubspec.lock`)

| Package | Resolved | Web impl | Verdict |
|---|---|---|---|
| **`app_badge_plus`** | **1.2.10** | **NONE** (android/ios/macos only) | 🔴 **`MissingPluginException` at runtime.** The one guaranteed crash. |
| `flutter_secure_storage` | 10.3.0 | `flutter_secure_storage_web` 2.1.1 | 🟡 Works, but **insecure** — see §4 |
| `app_links` | 6.4.1 | `app_links_web` 1.0.4 | 🟡 Degenerate: emits `window.location.href` **once**, then closes |
| `mobile_scanner` | 7.2.0 | inline `MobileScannerWeb` | 🟡 Works, but lazily fetches ZXing from `unpkg.com` CDN |
| `video_player` | 2.11.1 | `video_player_web` 2.4.0 | 🟡 `.networkUrl()` (our only call site) works; `httpHeaders` ignored |
| `image_picker` | 1.2.1 | `image_picker_for_web` 3.1.1 | 🟡 Works; `XFile.path` is a blob URL — `File(path)` invalid |
| `url_launcher` | 6.3.2 | `url_launcher_web` 2.4.2 | 🟢 Our only call site is http(s) from message content |
| `connectivity_plus` | 7.1.1 | `ConnectivityPlusWebPlugin` | 🟢 Reports wifi/none only — our code already does `results.any((r) => r != none)` |
| `shared_preferences` | 2.5.5 | `shared_preferences_web` 2.4.3 | 🟢 localStorage; no secrets stored here |
| `package_info_plus` | 10.1.0 | `PackageInfoPlusWebPlugin` | 🟢 Fetches generated `version.json`; `buildSignature` is `''` |
| `web_socket_channel` | 3.0.3 | pure Dart, conditional | 🟢 `WebSocketChannel.connect()` works — see §5 |
| `nostr` 2.0.0, `pointycastle` 4.0.0, `flutter_svg`, `gpt_markdown`, `highlight`, `intl`, `uuid`, `http`, `scrollable_positioned_list`, `lucide_icons_flutter`, `hooks_riverpod`, `flutter_hooks` | — | pure Dart / properly conditional | 🟢 Safe. `nostr` has **zero** `dart:io` (its own pubspec says "Flutter Web compatible"); `pointycastle` conditionally selects `web.dart`. |

**This corrects the plan's §5 swap table.** `image_picker`→`file_selector` and
`video_player`→`media_kit` are native-desktop remedies with **no web
justification** — both originals have endorsed web implementations. The only
package that genuinely has no web story is `app_badge_plus`, and a browser tab
badge is not a Phase 0 requirement.

**The dangerous class is runtime-only**: everything above compiles. Only
`app_badge_plus` hard-crashes, and it does so from `lib/app.dart:50/52/54` —
which run at startup and on every unread-count change. Note the trap:
`AppBadgePlus.isSupported()` also throws, so it is unusable as a feature probe;
the guard must be `kIsWeb` at the call site.

### 3. The `buzz/media_upload` MethodChannel

> **Correction (plan review, 2026-07-27).** The audit table below is **wrong**
> about the four "already dead on web" methods. On Flutter web
> `defaultTargetPlatform` is derived from the **browser user agent**
> (`flutter/lib/src/foundation/_platform_web.dart` →
> `ui_web.browser.operatingSystem`; note `unknown` maps to `android`), not from
> "is this a native mobile OS". So Android Chrome yields `TargetPlatform.android`
> and iOS Safari yields `TargetPlatform.iOS`, and **three** of the five methods
> are reachable in a browser: `sanitizeImageForUpload` and `transcodeImageToJpeg`
> via `_supportsNativeUploadImageProcessing()` (`media_upload.dart:525-530`) on
> every image upload, and `clipboardHasImage` via `compose_bar.dart:141` on iOS
> Safari. The conclusion "only the video path needs work" and the claim "image
> upload on web is unaffected and works end to end" below are both void.
> A related consequence: the native sanitize step is
> `AndroidImageProcessor.encodeAndScrub`, i.e. the EXIF/GPS strip — so skipping
> it on web would trade a crash for a privacy regression.
> The plan resolves this by disabling media upload on web outright. See
> `docs/plan/2026-07-27-feat-flutter-web-target-phase-0-plan.md` §"Correction:
> `defaultTargetPlatform` on web is user-agent derived" and §"Media upload on
> web". The rest of this section (which methods exist, which call sites reach
> them) is accurate and still useful.

Kotlin + Swift only (`media_upload.dart:36-38`), five methods. Call-site audit:

| Method | Reached via | Existing guard | Phase 0 action |
|---|---|---|---|
| `sanitizeImageForUpload` | `_sanitizePickedImageBytes` | ✅ `_shouldSanitizePickedImage` → `_supportsNativeUploadImageProcessing()` (`:525-530`, android/iOS only) | none — already dead on web |
| `transcodeImageToJpeg` | `_transcodePickedImageToJpeg` | ✅ `_shouldTranscodePickedImage` → same predicate (`:451-454`) | none — already dead on web |
| `clipboardHasImage` | `compose_bar.dart:147` | ✅ `if (defaultTargetPlatform != TargetPlatform.iOS) return null` (`:141`) | none — already dead on web |
| `readClipboardImage` | `compose_bar.dart:524` | ✅ only from iOS-gated context-menu items (`:528`, `:544`) | none — already dead on web |
| **`transcodeVideoToMp4`** | `pickAndUploadVideo()` → `compose_bar.dart:777` | ❌ **unguarded** | 🔴 **gate** |

So the MethodChannel is already 4/5 web-safe by accident of the existing
iOS/android platform gates. **Only the video path needs work**, and it needs it
twice over: the MethodChannel throws `MissingPluginException`, and the
subsequent `File(transcodedPath).length()` would throw `UnsupportedError`.

Decision: hide the "Video" attach affordance when on web, **and** make
`MediaUploadService.pickAndUploadVideo()` fail fast with a readable message
rather than a raw platform exception. Belt and braces, because the service is
public API and the affordance is not the only conceivable caller.

Image upload on web is unaffected and works end to end: `image_picker_for_web`
returns an `XFile`, `_prepareUploadImage` calls `readAsBytes()` (never
`File(path)`), both native-processing predicates return `false`, and
`uploadBytes()` runs pure Dart + `package:http`.

### 4. Secure storage on web — the one genuinely security-sensitive decision

`flutter_secure_storage_web` 2.1.1 stores values in **`window.localStorage`**
encrypted with WebCrypto AES-GCM-256 — and then **exports the AES key
(`extractable: true`) and writes it, base64, into the same `localStorage`**
under the key `FlutterSecureStorage`. Stated plainly: **any JavaScript running
on the origin — i.e. any XSS — can read the wrapping key, import it, and
decrypt every stored value.** The optional `wrapKey` is a second key you compile
into the JS bundle; the package README calls it "make it more difficult to
analyze", and the same README says the implementation is "**experimental… Use at
your own risk at this time**". It also throws outside a secure context, so plain
`http://` on a non-localhost host fails every read/write.

What this app stores there: `mobile/lib/shared/community/community_storage.dart`
persists the whole community list — **including each community's `nsec`** — as
one JSON blob via `const FlutterSecureStorage()` (`:22`), i.e. default options,
i.e. the AES key persisted unwrapped. On iOS/Android that blob is Keychain /
Keystore-backed. On web it would be **XSS-equivalent to storing the Nostr
private key in `localStorage` in the clear**.

**Decisive precedent in this repo:** the shipped browser client already refuses
this trade. `web/src/shared/lib/nostr-signer.ts` signs via a **NIP-07 browser
extension** (`window.nostr`), throwing `Nip07UnavailableError` when absent, and
otherwise uses a module-level **in-memory ephemeral secret key** that is never
written to any storage. The project has already decided that the browser is not
trusted with a durable Nostr private key.

**Phase 0 position: do not persist credentials on web.** Override
`communityStorageProvider` with an in-memory store when on web, so a page reload
requires re-entering the pairing code. This matches the existing browser
client's posture, removes the security question from the critical path, and is
strictly less work than shipping and then justifying `localStorage` key
custody. NIP-07 integration is a real future answer, but it is Phase 2+ scope
and not needed to prove a screen renders.

### 5. Relay connectivity from a browser

**WebSocket: fine.** The relay's WS is at path `/` (content-negotiated against
NIP-11), and NIP-42 auth is entirely **in-band over WebSocket text frames** —
the relay sends `["AUTH", challenge]` after upgrade and the client replies with
a signed event. No custom handshake headers are required, which matters because
`WebSocketChannel.connect()` has **no `headers` parameter at all** (headers are
exclusive to `IOWebSocketChannel`, which is `dart:io`). Cross-origin WebSocket
is not subject to CORS preflight. `mobile/lib/shared/relay/relay_socket.dart:66`
already uses the header-free form. ✅

**HTTP: there is a real CORS gap.** `crates/buzz-relay/src/router.rs:397-421`
builds the CORS layer as `CorsLayer::permissive()` when `BUZZ_CORS_ORIGINS` is
unset (the local-dev default — it is not in `.env.example`), else an origin
allowlist. **Both branches use `allow_headers(Any)`, which emits the literal
`Access-Control-Allow-Headers: *`.** Per the Fetch spec, `Authorization` is a
CORS *non-wildcard* request-header name: `*` does not cover it, it must be named
explicitly. Every browser enforces this.

What that breaks for a **cross-origin** Flutter web build:

- **Blossom `PUT /upload`** — sends `Authorization: Nostr …`
  (`media_upload.dart:301`). Preflight fails.
- **`GET /media/{sha}`** — `MediaImageProvider` fetches with
  `auth.headersFor(url)` (`media_image.dart:95`), and `MediaGetAuthService`
  attaches `Authorization` for any relay-host media URL whenever a key exists
  (`media_auth.dart:43-66`). **This is every avatar and every inline image in
  the app.** Preflight fails — and it fails even though the relay might have
  accepted the request unauthenticated, because the *header's presence* is what
  triggers the preflight.
- The `POST /query` bridge, if used with NIP-98.

Non-`Authorization` custom headers (`X-SHA-256`, `X-Auth-Tag`, `Content-Type`)
are covered by the wildcard and are fine. There are no CORS tests in the repo.
This is a pre-existing relay bug, not one this run introduces — it also affects
the shipped React client's cross-origin `just web` dev mode
(`web/src/features/invite/invite-api.ts:17-33`).

**Decision: sidestep it by serving same-origin, and report the bug.** The relay
already serves a browser SPA from `BUZZ_WEB_DIR` (`router.rs:145-186`;
`just relay-web` does `BUZZ_WEB_DIR=./web/dist cargo run -p buzz-relay`), and
`web/`'s own URL helper defaults to same-origin
(`web/src/shared/lib/relay-url.ts:12-24`) precisely because that is the
intended deployment. Pointing `BUZZ_WEB_DIR` at `mobile/build/web` makes CORS
inapplicable to the Flutter build too — zero Rust changes, and it exercises the
production topology rather than a dev-only one.

The consequence must be stated honestly and prominently: **cross-origin
development (serving the Flutter web build on a different port from the relay)
will show broken images and failed uploads until the relay names
`Authorization` in `Access-Control-Allow-Headers`.** That one-line Rust change
is filed as a follow-up, deliberately not made here.

One further gotcha: the relay binds a community from the `Host` header before
upgrading and 404s if unmapped — same-origin serving makes this automatically
consistent.

### 6. Deep links (`buzz://`) on web

`app_links_web` 1.0.4 is a ~30-line stub: it captures `window.location.href`
once at construction and `uriLinkStream` is `Stream.value(...)` — one emission,
then closed. It never observes `popstate` or hash changes, and it can only ever
deliver an `https://…` page URL, never a `buzz://` URI.

`pendingDeepLinkProvider` (`shared/deeplink/pending_deep_link_provider.dart:25`)
subscribes to that stream. On web it will receive exactly one
`http(s)://host/…` URI, which `deep_link.dart`'s parser will not match, and the
provider will hold `null`. **Harmless — no crash, no misfire.**

**Phase 0 position: `buzz://` deep links are out of scope on web. Leave the
code untouched.** Web deep linking is a different mechanism (path/query routing
on the served origin) and belongs with a routing story the app does not have
(it is Navigator 1.0 by convention). Nothing launches a `buzz://` URL via
`url_launcher`, so `url_launcher_web`'s refusal of unknown schemes is not
reachable.

## Explored Approaches

**A. Minimal additive web target** ← **Recommended**

Hand-author `mobile/web/`; guard the ~4 web-hostile call sites behind one
overridable `isWeb` provider; swap the credential store for an in-memory one on
web; gate with `flutter build web` + desktop-width widget tests; serve
same-origin from the relay. Zero dependency changes, zero Rust changes.

- Pros: smallest possible diff for the stated Phase 0 goal; cannot regress
  mobile (no shared code paths change behavior off-web); every decision is
  reversible; the honest limits are easy to state.
- Cons: several capabilities are *disabled* rather than *ported* on web (video
  upload, QR scan, badge, deep links). Cross-origin dev remains broken until
  the relay CORS follow-up.
- Best when: the goal is to establish and gate the target, not to reach feature
  parity — which is exactly what §9 Phase 0 says.

**B. Web target plus the plan's dependency swaps** ← Rejected

Additionally adopt `file_selector`, `media_kit`, `desktop_drop`, and a
Badging-API package.

- Pros: lights up drag-drop (`desktop_drop` 0.7.1 genuinely does declare web via
  `desktop_drop_web`) and a browser tab badge.
- Cons: the two headline swaps are **unjustified on web** — `image_picker` and
  `video_player` already have endorsed web implementations, so `file_selector`
  and `media_kit` would be pure churn. Every added plugin also declares android,
  so each one is a live regression risk to the two shipping platforms, gated
  only by tests that cannot exercise a browser. Reversing a dependency after
  merge is expensive.
- Best when: web has become a supported product surface. It has not.

**C. Separate Flutter web app depending on a shared package** ← Rejected

Extract `mobile/lib` into a package and create a sibling web app.

- Pros: hard isolation between surfaces.
- Cons: `mobile/lib` is not a package; extraction is a repo-wide refactor
  touching all 172 files and 60 test files, with a large mobile-regression
  surface, to solve a problem that a `web/` folder solves for free.
  `DESKTOP_PORT_PLAN.md` §10.1 already recommends against it ("add targets to
  `mobile/` first; extract a shared package only if a second app
  materializes").
- Best when: a genuinely divergent second app exists.

## Recommended Approach (design direction)

### `mobile/web/` — hand-authored runner

Reproduce the SDK template for 3.44.4 exactly:

```
mobile/web/index.html          # <base href="$FLUTTER_BASE_HREF">, <script src="flutter_bootstrap.js" async>
mobile/web/manifest.json       # name/short_name "Buzz", display standalone
mobile/web/favicon.png
mobile/web/icons/Icon-192.png
mobile/web/icons/Icon-512.png
mobile/web/icons/Icon-maskable-192.png
mobile/web/icons/Icon-maskable-512.png
```

Icons are generated from
`mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
with `sips -z <n> <n>` — no new asset authoring, no `flutter create`. Set
`manifest.json`'s `theme_color`/`background_color` to the app's existing
Catppuccin base rather than the template's default `#0175C2`.

Only `web/index.html` is strictly required by `flutter_tools`; the rest ships
for parity with what `flutter create` would have produced, because a
half-populated runner directory is a trap for the next contributor.

### One overridable web-platform seam — `mobile/lib/shared/platform/`

`kIsWeb` is a compile-time constant and therefore **untestable** — a widget test
can never exercise the web branch. Since the whole point of this phase is to
*prove* the gates work, introduce a single ~15-line provider:

```dart
// mobile/lib/shared/platform/is_web.dart
final isWebProvider = Provider<bool>((ref) => kIsWeb);
```

All gates read `ref.watch(isWebProvider)`; tests override it to `true`. One
provider, not a capability-abstraction layer — there are only four gates and
`shared/` must stay feature-type-free.

### The four gates

| Site | Change |
|---|---|
| `lib/app.dart:48-56` (`applyBadge`) | Skip all three `AppBadgePlus.updateBadge` calls when web. Prevents the one guaranteed crash. |
| `lib/features/channels/compose_bar.dart:769-780` | Hide the "Video" attach `ListTile` when web. |
| `lib/shared/relay/media_upload.dart` (`pickAndUploadVideo`) | Fail fast with a readable message when web, before touching the MethodChannel or `File`. |
| `lib/features/pairing/pairing_page.dart:85-91` | Hide the "Scan QR Code" button when web. Keeps the **paste-a-pairing-code** `TextField` (`:117`), so a community can still be added — the auth path stays intact. Avoids the camera prompt and `mobile_scanner`'s lazy fetch of `@zxing/library` from `unpkg.com`, which is an unannounced third-party CDN dependency for a chat client. |

Plus the storage decision: override `communityStorageProvider`
(`shared/community/community_provider.dart:7`) with an in-memory implementation
on web. `CommunityStorage` currently takes a concrete `FlutterSecureStorage`, so
this needs a minimal key-value seam (an abstract read/write/delete interface
with a secure-storage impl and a memory impl) rather than a provider override
alone.

Total: five behavior changes, all `false` on android/iOS, all covered by tests.

### Verification strategy — and what it does *not* prove

Because `dart:io` compiles on web, the build gate is weaker than it looks. State
the tiers explicitly:

**Genuinely proven by automation in this run**

1. `flutter build web --release` succeeds → the entire reachable Dart graph
   compiles under dart2js, every plugin's web registrant resolves, and the
   font/asset pipeline (Inter + GeistMono variable fonts, `buzz-icon.png`)
   builds. This is a real and previously-untested property of ~35.6k LOC.
2. Widget tests at 1440×900 with `isWebProvider` overridden to `true` assert:
   no badge call; no "Video" affordance; `pickAndUploadVideo()` throws the
   readable error, not `MissingPluginException`; no "Scan QR Code" button;
   `communityStorageProvider` resolves to the in-memory store; and the Phase 1
   `DesktopShell` still renders (rail + list + message pane). The 1440×900
   `tester.view.physicalSize` convention already exists in
   `test/features/home/desktop_shell_test.dart:56-57`.
3. All 60 existing test files still pass, `flutter analyze` stays at zero, and
   `dart format` is clean → mobile is not regressed.

**NOT proven — requires a human with a browser**

Rendering fidelity and font loading; scroll/gesture behavior with a mouse
wheel and trackpad; that the WebSocket actually connects and NIP-42 auth
completes against a live relay; that images load same-origin; that the shell's
breakpoints and pane widths look right in a real resizable window; that
`localStorage`-free credential entry is usable. These are exactly the "Phase 0
visual QA" items Phase 1 parked, and this run cannot close them.

Deliverable: a short **manual verification checklist** in the PR body, with the
same-origin run command (`pnpm`-free: `flutter build web --dart-define=...` then
`BUZZ_WEB_DIR=mobile/build/web cargo run -p buzz-relay`).

**Tooling:** add a `just mobile-build-web` recipe alongside `mobile-build-android`
(`justfile:589-590`). **Do not add it to `just ci`** — that would slow every
run for a non-shipping target, and the corresponding
`.github/workflows/ci.yml` change is guardrail-blocked anyway, so CI would not
enforce it regardless. Web-build enforcement in CI is a follow-up requiring a
human edit.

## Inherited Phase 1 backlog (resolved item by item)

Phase 1 parked five things "for Phase 0". Each is decided here:

| Parked item | Decision | Why |
|---|---|---|
| Wire `desktop_drop` into `attachmentDropBackendProvider` | **Defer** (not to a native-only excuse — it *is* possible) | `desktop_drop` 0.7.1 does declare web (`desktop_drop_web`), and its `DropItem extends XFile` satisfies the seam's `Uint8List bytes` contract. But it is a new plugin that also declares android, so it is a live risk to the shipping app, and it is not needed to prove a screen renders. The seam (`attachment_drop_region.dart:40`) was designed to be filled later with **no API change** — take that option. |
| Drop-target hover/highlight visuals | **Defer** | Phase 1 cut these precisely because there was no backend to highlight. Still true. |
| Breakpoint / pane-size retuning | **Defer** | Requires a human resizing a real window. Constants already live in `breakpoints.dart` for cheap retuning. |
| Promote the overlay side panel to a docked column | **Defer** | A visual judgement call, not a compile concern. |
| Selected-channel highlight / list-selection polish | **Defer** | Cosmetic; Phase 1 cut it as plan-invented scope and nothing here changes that. |

The honest summary: **"Phase 0 visual QA" is not deliverable by an unattended
run.** Renaming it does not make it so. This run delivers the *runtime* those
items need in order to become verifiable, and leaves them queued.

## Key Decisions

- **Web only; `mobile/web/` added to the existing app, no new package.** Follows
  `DESKTOP_PORT_PLAN.md` §10.1's own recommendation and keeps the diff additive.
- **Hand-author the runner from the SDK template at
  `flutter_tools/templates/app/web/`; generate icons from the existing 1024px
  iOS app icon with `sips`.** `flutter create` is blocked; `flutter_bootstrap.js`
  is build-generated and must not be hand-written.
- **Zero dependency changes.** The plan's `image_picker`→`file_selector` and
  `video_player`→`media_kit` swaps are native-desktop remedies that web does not
  need — both originals have endorsed web implementations. Re-deriving the list
  from evidence is the point of this retargeting.
- **`app_badge_plus` is gated, not replaced.** It is the only dependency with no
  web implementation at all and the only guaranteed runtime crash. A browser tab
  badge is not a Phase 0 requirement, and `isSupported()` cannot be used as a
  probe because it throws too.
- **Only the video path of `buzz/media_upload` needs gating.** Four of its five
  methods are already dead on web via pre-existing iOS/android
  `defaultTargetPlatform` guards; image upload works end to end in pure Dart.
- **No `dart:io` conditional-import scaffolding.** Empirically, `dart:io`
  compiles under dart2js; the constants and type-tests this app uses are
  runtime-safe, and the file I/O is already behind android-only guards. Adding
  stub/io/web triads would be ceremony.
- **Credentials are not persisted in browser storage.**
  `flutter_secure_storage_web` keeps its AES key in the same `localStorage` as
  the ciphertext, so an XSS recovers the Nostr private key; the repo's own
  browser client already refuses to persist keys (NIP-07 or in-memory ephemeral).
  Web gets a session-only store. Re-entry on reload is the accepted cost.
- **Serve the web build same-origin from the relay (`BUZZ_WEB_DIR`); do not
  touch `crates/buzz-relay`.** The relay's `Access-Control-Allow-Headers: *`
  does not cover `Authorization`, which would break every avatar, every inline
  image, and every upload cross-origin. Same-origin makes CORS inapplicable and
  matches how `web/` already deploys. The relay fix is filed as a follow-up.
- **`buzz://` deep links are out of scope on web.** `app_links_web` emits the
  page URL once and closes; it can never deliver a custom scheme. The existing
  provider degrades harmlessly, so no code changes.
- **QR-scan pairing is hidden on web; paste-a-code is kept.** Preserves the auth
  path while avoiding a camera prompt and an unannounced `unpkg.com` fetch.
- **Gates are read from one overridable `isWebProvider`, not raw `kIsWeb`.**
  `kIsWeb` is a compile-time constant and cannot be exercised by a widget test;
  proving the gates work is the deliverable.
- **`just mobile-build-web` is added but not wired into `just ci`.** The CI
  workflow is guardrail-blocked, so CI enforcement is a human follow-up.
- **All five inherited "Phase 0 visual QA" items are deferred**, including
  `desktop_drop` — which *is* web-capable, so this is a scope choice, not a
  platform limitation.

## Risks & Mitigations

1. **`flutter build web` succeeds but the app crashes on first paint.** The
   build gate cannot catch `MissingPluginException` or `UnsupportedError`.
   Mitigation: the four gates are derived from a complete, evidence-backed
   call-site audit rather than from guessing, and each is asserted by a widget
   test with `isWebProvider` overridden. Residual risk is explicitly handed to
   the human checklist.
2. **Mobile regression from touching shared files.** `app.dart`,
   `compose_bar.dart`, `media_upload.dart`, `pairing_page.dart` and the
   community-storage seam are all load-bearing on iOS/Android. Mitigation: every
   gate is a pure additive branch that evaluates `false` off-web; the 60
   existing test files are the regression gate and none may be weakened.
3. **The credential-store seam is the largest refactor in the run.**
   `CommunityStorage` takes a concrete `FlutterSecureStorage`, so an interface
   must be introduced. Mitigation: keep it to a three-method read/write/delete
   interface with the existing secure impl as the default; `communityStorageProvider`
   is already a clean single override point.
4. **First `flutter build web` may surface unknown compile errors** in code
   paths this audit did not reach. Mitigation: the audit covered all 172 lib
   files for `dart:io`, all 23 direct dependencies, and a 34-package transitive
   `dart:io` sweep — but the build is the arbiter, and it is permitted to run in
   this session, so failures surface inside this run rather than after it.
5. **Same-origin serving is a documentation-only mitigation for the CORS gap.**
   Anyone who runs the web build on its own port will see broken images and
   conclude the port is broken. Mitigation: state it prominently in the PR body
   and the run command, and file the relay follow-up with the exact line
   (`crates/buzz-relay/src/router.rs:397-421`) and fix (name `AUTHORIZATION` in
   `allow_headers`, or `AllowHeaders::mirror_request()`).
6. **The web target has no CI protection.** A later mobile change can silently
   break the web build. Mitigation: accepted and documented; the `just` recipe
   makes local checking one command, and the CI wiring is an explicit follow-up
   for a human.
7. **`mobile/web/index.html` drifts from the SDK template** as Flutter evolves
   (this happened industry-wide at the 3.22 `flutter_bootstrap.js` transition).
   Mitigation: a comment in `index.html` recording the SDK version it was
   authored against (3.44.4) and the template path to diff against.

## Open Questions

Resolved with YAGNI defaults for planning (see
[Auto-resolved assumptions](#auto-resolved-assumptions)); listed here because a
human may want to revisit:

1. **Should the relay CORS fix land in the same PR?** Defaulted to **no** —
   it is Rust, outside the additive-to-mobile scope, security-relevant, and
   unnecessary under same-origin serving. If cross-origin dev matters more than
   PR narrowness, this is the decision to flip.
2. **Should web ship a visible "session only — credentials are not saved"
   notice?** Defaulted to **no** — the behavior (re-entry on reload) is
   self-evident and a banner is UI scope. Revisit if web becomes user-facing.
3. **Is a session-only store acceptable, or should Phase 0 wire NIP-07
   instead?** Defaulted to session-only; NIP-07 is the right long-term answer
   and is Phase 2+ scope.
4. **Does the web build belong under `mobile/`** at all, or should the directory
   be renamed now that it hosts three platforms? Defaulted to **leave it** —
   renaming touches the justfile, CI path filters, and every doc reference, for
   zero functional gain.

## Auto-resolved assumptions

This brainstorm ran non-interactively. Every point where the skill would have
asked a human, the most YAGNI-aligned default was taken and recorded here.

1. **Skill interactivity resolved silently**: treated as a feature for the
   current project (not a new project, so no `/create` prompt); requirements
   judged to need brainstorming (the retargeting genuinely changes the task);
   `codebase-review-agent` **not** run — two targeted evidence agents (relay
   CORS + `web/` client; pub-cache plugin platform audit) were run instead
   because the questions were specific and factual, not pattern-discovery;
   no branch setup performed (the orchestrator owns
   `feat/flutter-web-desktop-phase-0`).
2. **Approach A selected without asking.** B and C are documented above with
   the evidence that rejects them.
3. **`dart:io` handling re-derived from evidence, contradicting the task
   framing.** The brief said "`flutter analyze` does NOT catch these, only a web
   compile does". Verified false: `dart:io` compiles under dart2js
   (`libraries.json` `_dart2js_common` → `io_patch.dart`, 120
   `UnsupportedError`s), confirmed by compiling and running a probe. So no
   conditional-import scaffolding is planned, and the verification strategy was
   rewritten around runtime gating + tests rather than around the build.
4. **`channels_page.dart`'s `dart:io` import is left in place.** It is used
   (by `channels_page/badges.dart:138`, not the main library) and it is
   web-safe: `is SocketException` evaluates `false`. Removing it would change
   mobile error-message behavior for no web benefit.
5. **Gate style = one overridable `isWebProvider`, not raw `kIsWeb`**, chosen
   so the gates are testable. Rejected a fuller "platform capabilities"
   abstraction as over-engineering for four call sites.
6. **QR pairing hidden but paste-a-code kept** — the minimum that preserves a
   working auth path on web. Hiding all of pairing would make it impossible to
   add a community and would defeat "prove one reused screen end-to-end".
7. **"One reused screen" = the Phase 1 `DesktopShell` (rail + channel list +
   message pane)**, not a hand-picked simple screen — it is the screen Phase 0
   exists to unblock, and it already has a 1440×900 test harness.
8. **`just mobile-build-web` added; `just ci` untouched.** Wiring it into CI
   requires editing `.github/workflows/ci.yml`, which the guardrail blocks.
9. **No relay changes, no `.env.example` changes, no pubspec version bump.**
10. **Full template parity for `mobile/web/`** (manifest + favicon + 4 icons)
    even though only `index.html` is required, because a partial runner
    directory is a trap. Icons generated from the existing iOS 1024px icon
    rather than authored.
11. **`desktop_drop` deferred despite being web-capable.** Recorded explicitly
    because the brief asked for a resolution: it is a scope choice (new plugin,
    also declares android, not needed for the goal), not a platform limitation.
12. **Detail level**: full brainstorm rather than "requirements are clear,
    proceed to planning" — the retargeting invalidated the source plan's task
    list, so the task list had to be re-derived here.

## Deferred (explicit, for later phases)

- Relay CORS fix — name `Authorization` in `Access-Control-Allow-Headers`
  (`crates/buzz-relay/src/router.rs:397-421`). Also fixes the shipped React
  client's cross-origin `just web` mode.
- CI enforcement of the web build (`.github/workflows/ci.yml`).
- `desktop_drop` drag-and-drop backend + drop-target visuals.
- Phase 1 visual QA: breakpoint/pane retuning, docked side panel,
  list-selection polish.
- NIP-07 signer integration (the real answer to browser key custody).
- Web deep linking (path/query routing on the served origin).
- Browser tab badge via the Badging API.
- Video upload on web (needs a browser-side transcode story or a relay-side one).
- QR scanning on web (needs a self-hosted ZXing bundle, not the `unpkg.com` CDN).
- Everything in `DESKTOP_PORT_PLAN.md` Phases 2–3, plus huddle, mesh-compute,
  and the animated-avatar studio.

## Suggested implementation slicing (input to the plan/split stage)

Small enough to be one PR, but if the plan stage splits it, the natural seams
are:

1. **Runner + build gate** — `mobile/web/*`, `just mobile-build-web`, first
   green `flutter build web`. No `lib/` changes. Independently valuable and
   independently reviewable.
2. **Runtime gates** — `isWebProvider`, the four call-site gates, and their
   widget tests.
3. **Credential store** — the key-value seam, the in-memory web impl, and its
   tests. This is the security-relevant slice and benefits from isolated review.
