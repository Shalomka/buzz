// Throwaway dev helper: mint a Buzz relay invite as the community owner, then
// print a deep link you can fire into the iOS simulator. Delete when done.
//
// The owner SECRET is read from the env at runtime — it is never written to disk
// by this script. Run it yourself so the key stays on your side:
//
//   cd web
//   OWNER_NSEC='nsec1...'            node mint-invite.mjs      # nsec or 64-hex
//   OWNER_NSEC='<64-hex>' TTL_SECS=86400 RELAY=http://localhost:3000 node mint-invite.mjs
//
// Requires the relay running with RELAY_OWNER_PUBKEY set to THIS key's pubkey.

import { finalizeEvent, getPublicKey, nip19 } from "nostr-tools";
import { createHash } from "node:crypto";

const RELAY = (process.env.RELAY ?? "http://localhost:3000").replace(/\/+$/, "");
const TTL_SECS = Number(process.env.TTL_SECS ?? 86400); // default 1 day
const raw = process.env.OWNER_NSEC;

if (!raw) {
  console.error("✖ Set OWNER_NSEC (nsec1... or 64-char hex secret key) in the env.");
  process.exit(1);
}

// Accept nsec (bech32) or 64-char hex → Uint8Array secret key.
let sk;
if (raw.startsWith("nsec1")) {
  const dec = nip19.decode(raw);
  if (dec.type !== "nsec") {
    console.error(`✖ Expected an nsec, got: ${dec.type}`);
    process.exit(1);
  }
  sk = dec.data;
} else if (/^[0-9a-fA-F]{64}$/.test(raw)) {
  sk = Uint8Array.from(Buffer.from(raw, "hex"));
} else {
  console.error("✖ OWNER_NSEC must be an nsec1... or a 64-char hex secret key.");
  process.exit(1);
}

const pubkey = getPublicKey(sk);

// The signed `u` tag MUST equal the relay's nip98_expected_url:
//   http://<tenant.host()>/api/invites  — and tenant.host() keeps the port.
const url = `${RELAY}/api/invites`;
const body = JSON.stringify({ ttl_secs: TTL_SECS });
const payloadHash = createHash("sha256").update(body, "utf8").digest("hex");

// NIP-98 (kind 27235) auth event, signed by the owner key.
const authEvent = finalizeEvent(
  {
    kind: 27235,
    created_at: Math.floor(Date.now() / 1000),
    content: "",
    tags: [
      ["u", url],
      ["method", "POST"],
      ["payload", payloadHash],
      ["nonce", `${Date.now()}-${Math.random().toString(16).slice(2)}`],
    ],
  },
  sk,
);
const authHeader = "Nostr " + Buffer.from(JSON.stringify(authEvent)).toString("base64");

const res = await fetch(url, {
  method: "POST",
  headers: { Authorization: authHeader, "Content-Type": "application/json" },
  body,
});

const text = await res.text();
if (!res.ok) {
  console.error(`✖ Mint failed: HTTP ${res.status}`);
  console.error(`  owner pubkey used: ${pubkey}`);
  console.error(`  response: ${text}`);
  console.error(
    "\n  If this is 403, the relay's RELAY_OWNER_PUBKEY does not match this key's pubkey.",
  );
  process.exit(1);
}

const out = JSON.parse(text);
const code = out.code;

// Build the ws relay origin for the buzz://join deep link (http→ws, https→wss).
const u = new URL(RELAY);
const wsScheme = u.protocol === "https:" ? "wss" : "ws";
const wsRelay = `${wsScheme}://${u.host}`; // host keeps the port
const buzzLink =
  `buzz://join?relay=${encodeURIComponent(wsRelay)}&code=${encodeURIComponent(code)}`;

console.log(`\n✅ Invite minted  (owner ${pubkey})`);
console.log(`   code       : ${code}`);
console.log(`   expires_at : ${out.expires_at}  (${new Date(out.expires_at * 1000).toISOString()})`);
console.log(`   web url     : ${out.url}`);
console.log(`\n👉 Fire it into the booted simulator (triggers the invite-join sheet):\n`);
console.log(`   xcrun simctl openurl booted "${buzzLink}"`);
console.log("");
