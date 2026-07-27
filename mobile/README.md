# Buzz Mobile

Flutter mobile client for Buzz.

## Setup

```bash
cd mobile
flutter pub get
```

## Run

```bash
# From repo root (recommended — starts Docker, relay, and simulator):
just mobile-dev

# Direct (requires services and relay already running):
cd mobile && flutter run
```

## Web (experimental)

The same Flutter app also builds for the browser. This is Phase 0: it compiles,
paints, and pairs, but several native capabilities are deliberately disabled and
there is no CI coverage yet.

```bash
# Build, then serve same-origin from the relay (avoids the CORS gap below):
just mobile-build-web
BUZZ_WEB_DIR=mobile/build/web cargo run -p buzz-relay

# Point the build at a non-default relay:
cd mobile && flutter build web --release --dart-define=BUZZ_RELAY_URL=https://relay.example
```

`--dart-define` works identically for web (`Env.relayUrl` in
`lib/shared/relay/relay_provider.dart`); `RelayConfig.wsUrl` derives `wss` from
`https`, so mixed content is correct by construction.

**Serve same-origin.** Cross-origin serving shows broken avatars, broken inline
images, and failed uploads: the relay's
`Access-Control-Allow-Headers: *` does not cover `Authorization`
(`crates/buzz-relay/src/router.rs:397-421`). That is a pre-existing relay bug
that also affects the React client's `just web` dev mode; the fix is tracked as a
follow-up and is not applied here.

**Disabled on web in Phase 0:** the app badge, all media upload from the compose
bar (the paperclip/attach affordance is hidden), QR-code scanning during
pairing, and `buzz://` deep links.

**Sign-in is session-only, but not everything is.** Sign-in material — the Nostr
`nsec` — is never persisted on web and must be re-entered after a reload: the
only durable browser storage available to `flutter_secure_storage_web` is
`localStorage`, and it stores its own extractable AES key next to the
ciphertext, so any XSS on the origin would recover the key. Pubkey-keyed channel
preferences kept in `shared_preferences` — read state, mutes, stars, sections —
**do** persist to `localStorage` and survive a reload. No key material is stored
there, but a shared browser does retain an identity fingerprint after a "logout
by reload".

**`defaultTargetPlatform` is user-agent derived on web**, so mobile-browser user
agents (and unknown ones, which fall back to `android`) take the android/iOS
code paths. Platform checks that guard a `MethodChannel` must therefore also
check `isWebProvider` (`lib/shared/platform/is_web.dart`) — the only web seam.

## Checks

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Or from the repo root: `just mobile-check` and `just mobile-test`.

## Android release signing

Android release builds fail unless all upload-key inputs are supplied through the
environment:

- `BUZZ_ANDROID_UPLOAD_KEYSTORE_PATH`: path to a CI-vended keystore file
- `BUZZ_ANDROID_UPLOAD_KEYSTORE_PASSWORD`
- `BUZZ_ANDROID_UPLOAD_KEY_ALIAS`
- `BUZZ_ANDROID_UPLOAD_KEY_PASSWORD`

The keystore path must be absolute, and the keystore must remain outside the
repository. Development and debug builds do not require these variables.

Release pipelines that sign through the central APK Signer service instead of
a local upload keystore must set `BUZZ_ANDROID_RELEASE_SIGNING=external`. That
mode produces an unsigned release bundle and refuses to run if any
`BUZZ_ANDROID_UPLOAD_*` value is also set.

## Architecture

```
lib/
├── main.dart              # Entry point, Riverpod bootstrap
├── app.dart               # MaterialApp with theme
├── shared/
│   └── theme/             # Catppuccin light/dark, spacing tokens, extensions
└── features/
    └── home/              # Placeholder home surface
```

- **State management:** Riverpod + Hooks (`HookConsumerWidget`)
- **Theme:** Catppuccin Latte (light) / Macchiato (dark) — matches desktop
- **Spacing:** `Grid` tokens for consistent spacing
- **Linting:** `flutter_lints` + `riverpod_lint` via `custom_lint`
- **Feature isolation:** No cross-feature imports except `shared/`
