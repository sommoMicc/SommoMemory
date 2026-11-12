# SommoMemory multiplayer protocol v1

Connect to `wss://sommomemory.sommomi.cc/ws`. Every frame is one JSON object.
Rooms support exactly two players. No email or advertising identifier is used.
An optional opaque profile token associates completion gems with a synced wallet;
room sessions and profile sessions are independent credentials.

## Client messages

| type | fields | behavior |
| --- | --- | --- |
| `create` | `name`, `pairs` (6, 8, 12 or 18), `theme` (canonical deck ID), optional `profileToken`, `supportedDecks`, `supportedFeatures`, `matchType`, `arenaId` | Creates a friendly room by default; ranked requires an authenticated profile and current arena. Save returned room session locally. |
| `join` | `code`, `name`, optional `profileToken`, `supportedDecks`, `supportedFeatures` | Joins the second seat; a lobby waits for both players to be ready, while legacy rooms start immediately. Guest need not own the selected friendly deck. Ranked requires distinct profiles in the same arena. |
| `resume` | `code`, `token`, optional `supportedDecks`, `supportedFeatures` | Restores a seat after reconnect or server restart; replaces previous socket. |
| `flip` | `index` (integer, zero based) | Reveals one card if permitted by server. |
| `ready` | `ready` (boolean) | Sets or withdraws readiness in a lobby. |
| `nextRound` | none | Ranked only: votes for the next round after `roundFinished`; both connected players must vote. |
| `rematch` | none | Votes to replay. Both connected players must vote. |
| `leave` | none | Leaves and invalidates the seat token. Active play forfeits; a lobby guest frees the seat while the host closes the room. |
| `preview` | `code` | Reads a full room's public score/result snapshot without taking a seat or creating a session. |
| `ping` | none | Returns `pong` with server time. |
| `voice` | `action` `join`, `leave`, `mute` (`muted` boolean) or `signal` | Optional lobby-wide voice. See `voice-v1`. |

One active session per socket. Leave it before creating or joining another room.
Player names are trimmed and limited to 24 visible Unicode characters.
New clients send `supportedDecks` on **every create, join and resume**: an array
of at most 64 distinct canonical deck IDs from the supported theme list. Unknown
IDs, duplicates, nonstrings and nonarrays yield `INVALID_CAPABILITIES`. Omission
means exactly the legacy three decks `garden`, `cosmos`, `ocean`. For an available
seat, an unsupported room theme yields `UPDATE_REQUIRED` with **Aggiorna SommoMemory per giocare con
questa collezione.**, before occupying a seat, reconnecting a player, replacing
an existing socket or sending any state. Updated clients send all 22 known
IDs; old free-deck rooms continue to accept old and new clients. No protocol
version bump is needed.
For a valid capabilities payload, an already full legacy room returns `ROOM_FULL`
**before** checking theme compatibility. Lobby feature compatibility is checked first. Its limited preview needs no deck
rendering support; legacy clients can still see this denial safely. Malformed
capability arrays remain `INVALID_CAPABILITIES` and never mutate a seat.

## Server messages

`session`: `{type:"session",code,token,playerId}`. The token is a bearer secret;
retain it on the device, never put it in links or logs. `resume` echoes the same token.
This is followed by `state`.

`state`:

```json
{
  "type": "state",
  "code": "ABC234",
  "pairs": 8,
  "theme": "garden",
  "roundId": "random-round-id",
  "rewards": {},
  "phase": "playing",
  "turn": "player-id",
  "cards": [null,"0",null,"0"],
  "matched": [1,3],
  "selected": [],
  "players": [{"id":"player-id","name":"Michele","score":1,"connected":true}],
  "revision": 8,
  "rematch": [],
  "lockedUntil": null,
  "winnerId": null,
  "finishReason": null
}
```

The sample `cards` is shortened; its actual length is `pairs * 2`.
Friendly card values are string IDs `"0"` through `String(pairs-1)`. Ranked boards sample 12 distinct values from `"0"`–`"17"` before doubling and shuffling. Values map to shared ordered collections on each client (the existing garden/cosmos/ocean/paola/food/sports/travel mappings are unchanged). Images or syllable text are bundled on each device; only card IDs cross the network. Hidden values are **never sent**. Matched cards remain visible.
Paola is free and maps IDs 0–17 to PA, PE, PI, PO, PU, LA, LE, LI, LO, LU, MA,
ME, MI, MO, MU, SA, SE, SI, in this order; no image download is required.
`selected` contains exposed indices that have not yet matched. A mismatch remains
visible for 900ms; `lockedUntil` is the server Unix time in milliseconds. After
that time the server hides the pair and broadcasts a new state. In friendly play it also changes turn; ranked boards have no turns.
The client presents immutable snapshots independently of authority. Card targets
animate first; scores, matched styling and results appear only after opening
flips complete, and turn changes wait for closing flips. Table input stays locked
through both opening and closing animations, even after the engine unlocks.
Remote card changes are queued in order; repeated unchanged snapshots are
ignored. Reduced motion settles without an artificial animation delay. Input
still checks the latest authoritative turn and lock, so presentation cannot
authorize a stale move. In friendly play a successful match retains the turn. `revision` increases
on every mutation.

For friendly games, `phase` is `waiting`, `playing` or `finished`. Ranked games
also use `roundFinished` between rounds. `turn` is null outside active play and throughout ranked play.
`winnerId` is null on draws and before completion. `finishReason` is `completed`,
`forfeit`, `cancelled` (ranked) or null. A disconnected player has 90 seconds to resume. During active play, play pauses
while either player is disconnected. If the grace period expires, the opponent
wins by forfeit; if both grace periods have expired the room is discarded.
Explicit leave immediately forfeits active play and disables rematch.

`rematch` contains player IDs that voted for a rematch. When both connected players
vote, scores reset and a freshly shuffled board starts; in friendly play the starter alternates.
`roundId` changes each round, while `code` remains the room code. `rewards` resets
to `{}` and, on a completed round, contains only actual wallet receipts:
`{ "player-id": { "gems":20, "granted":true } }`. No profile IDs or balances are
public. A profile receives at most one reward per round, even if both seats use it.
Forfeits earn nothing. Refresh the authenticated REST profile after completion;
use the receipt for that round's result UI rather than a wallet-balance delta.
Ledger retries/restarts cannot double-credit. During a temporary wallet-storage
failure the final board is still published; the receipt is retried and a rematch
returns `REWARD_PENDING` until resolved. Existing unprofiled free-deck clients
remain compatible. See [ECONOMY_PROTOCOL.md](../docs/ECONOMY_PROTOCOL.md).

`error`: `{type:"error",code,message}`. `message` is suitable for display in Italian.
`left`: `{type:"left"}` confirms departure. `pong`: `{type:"pong",time}`.

`ROOM_FULL` additionally includes `roomPreview`:

```json
{
  "code": "ABC234",
  "phase": "finished",
  "players": [
    {"id":"alice","name":"Alice","score":5,"connected":true},
    {"id":"bob","name":"Bob","score":3,"connected":false}
  ],
  "winnerId": "alice",
  "finishReason": "completed"
}
```

This public object contains exactly code, phase, two players (room player ID,
chosen name, score, connected flag), winnerId and finishReason. It contains no
cards, hidden identities, deck/pair metadata, session/profile credentials,
profile IDs, wallet balances or rewards. In-progress previews use `phase:"playing"`
and null result fields. Finished previews distinguish a draw (`winnerId:null`)
from a winner and include `completed` or `forfeit`. Preview requests never enroll
the requester; a subsequent `flip` from that socket still returns `NO_SESSION`.

The preview is a copied snapshot, not a live subscription. An explicit
`{type:"preview",code}` refresh returns
`{type:"roomPreview",roomPreview:{...}}` with the same whitelist, without a
`session` or game `state`. The client can close the connection after receiving
it. Only full two-player playing/finished rooms expose this endpoint; missing,
expired or waiting rooms return `ROOM_NOT_FOUND`. No new authentication is
needed. Limits are 16 KiB/frame, 120 messages/10s and 32 connections/address;
there is no automatic polling or spectator gameplay.

The client keeps `roomPreview` separate from playable `state`. ROOM_FULL,
UPDATE_REQUIRED and invalid/expired sessions are terminal: clear pending entry
actions and room credentials, cancel retries/heartbeats and ignore queued old
socket messages. `open(null)` does not reopen a terminal session. Manual preview
refresh is a separate read-only action; a new explicit create/join can start a
new workflow. Initial transport failures and temporary SERVER_FULL remain
manually retryable.

## Waiting room extension: `lobby-v1`

Updated clients send `lobby-v1` on create, join and resume. A host advertising
it creates a lobby for friendly or ranked rooms. Old hosts retain immediate
start; incompatible clients cannot join or resume a lobby (`UPDATE_REQUIRED`).
State has `lobbyMode:true` and `lobbyReady` with ready player IDs. While waiting,
players are ordered host first and cards remain hidden. Send `ready` with a
boolean: both connected players must be ready before play starts. Ranked arena,
profiles and the eligible pool are rechecked and the decks drawn at that point.
Readiness clears on disconnect or guest departure.

Before play, guest leave invalidates that token and frees the second seat while
the host retains the same code. A disconnected guest retains the seat for 90
seconds, then it is released. Host leave or timeout closes the lobby. Pregame
departures do not produce a forfeit, crowns or gems. A ranked lobby seat reserves
the profile until departure or closure.

## Ranked extension: `ranked-v1`

`create` with `matchType:"ranked"` requires `profileToken`, `arenaId` equal to
the profile's current arena, and `supportedFeatures:["ranked-v1","ranked-attempts-v1"]`. Both features must accompany join and resume. A profile can occupy one active ranked
match, including its waiting room and intermissions. Joining requires a second,
distinct authenticated profile in the same current arena. Private invites are
the entry mechanism in this release; automatic matchmaking is a future feature.

The server freezes an ordered sample of three distinct decks from the union of
that arena's free decks and paid decks owned by either profile. Each deck has
equal weight regardless of whether one or both own it. Both clients must support
the entire eligible pool before a seat is taken; unsupported clients receive
`UPDATE_REQUIRED` without modifying a seat. An arena with fewer than three
complete free decks is unavailable even if paid decks would fill the sample.

State adds the following fields (also supplied with friendly defaults):

| Field | Meaning |
| --- | --- |
| `matchType` | `friendly` or `ranked` |
| `arenaId` | Arena of the match; null for Paola |
| `matchId` | Stable ID for the whole ranked match; new on rematch |
| `roundIndex`, `roundCount` | One-based current round and total round count (1 or 3) |
| `roundDecks` | Ordered deck IDs fixed at match start |
| `roundResults` | Completed rounds: `{round,theme,scores:{playerId:number},attempts:{playerId:number},winnerId}` |
| `totalScores` | Sum of completed scores plus the active round, keyed by player ID |
| `roundReady` | Player IDs that voted to continue at an intermission |
| `totalAttempts` | Attempts across completed rounds plus the active round, keyed by player ID |

In ranked games `players[].attempts` is the current round count and `players[].roundComplete` marks completion; `roundResults[].attempts` records each player’s count.

Each round uses 12 pairs. Both players receive the same shuffled layout but play independent boards simultaneously, without turns. `cards`, `matched`, `selected` and `lockedUntil` are specific to the receiving player; opponents never receive the other board’s revealed values or positions. An attempt is counted when a second distinct card is flipped, whether it matches or not. Each board has its own mismatch timer. Both players must finish their board before a round ends. All three rounds are played. A completed round remains visible with
`phase:"roundFinished"`; both players send `nextRound` to start the next board.
Each new round has a fresh `roundId`, but retains `matchId`, arena and deck order.
After round 3, the player with fewer total attempts wins; equal totals are a draw. Pair scores describe progress only.
Intermediate rounds award no gems or crowns. UI must wait for the final flip
before showing intermission, totals or final rewards; queued next-round states
must not overwrite the previous round's last animation.

At a completed match each profile gets 20 gems and +20/−20/0 crowns for a
win/loss/draw, floored at zero. `rewards` receipts add `crownsDelta`, the effective
change, including zero. Forfeit changes crowns but grants no gems. If both peers'
disconnect windows expire, or a participating profile is deleted, the match is
cancelled without rewards. The final settlement is a single SQLite transaction
keyed by `matchId`, persisted independently of room files and safe to retry.
`REWARD_PENDING` blocks rematch and another active ranked match until settlement.
Refresh the profile after a final result or leaving a match.

A rematch creates a new match, checks both profiles' current arena again and
resamples the union. Promotion/demotion affects the next match, never the one
already started. Old clients retain friendly support and cannot enter ranked.
Public previews can also show `roundFinished` or a `cancelled` final result.

The client persists `room.activeRanked` with its room credentials, including
while final settlement is pending. Pausing preserves the seat; attempting
another online entry offers to resume before creating a new workflow that could
erase that token. A final receipt or cancellation releases the local guard.
Leaving or an expired session clears it. Session transfer never erases the
new tab's stored seat. A completed game returns home without a forfeit warning.

## Voice extension: `voice-v1`

Updated clients advertise `voice-v1`. Voice is optional and covers the whole
room: there is no private side channel. Only seats that advertised `voice-v1`
can send or receive `voice` messages; others get `VOICE_UNSUPPORTED` and never
see a roster.

Client messages (`type:"voice"`):

| `action` | Fields | Effect |
| --- | --- | --- |
| `join` | optional `muted` boolean | Enters the channel. Every join, including a repeat, takes a **new generation**; generations are never reused. Re-joining is how a client asks both ends to rebuild their audio link. |
| `leave` | none | Leaves voice without leaving the match. |
| `mute` | `muted` boolean | Updates the muted flag. No broadcast when it is unchanged. |
| `signal` | `to`, `kind` (`offer`/`answer`/`ice`), `generation`, optional `peerGeneration`, `payload` | Relays one description or candidate. |

Server messages:

```json
{ "type": "voice", "action": "config", "iceServers": [{"urls": ["stun:…"]}] }
{ "type": "voice", "action": "state", "members": [{"id":"player-id","muted":false,"generation":7}] }
{ "type": "voice", "action": "signal", "from": "player-id", "kind": "offer", "generation": 7, "peerGeneration": 9, "payload": {} }
{ "type": "voice", "action": "error", "code": "NOT_IN_VOICE", "message": "…" }
```

`config` answers each `join` with the ICE servers to use. STUN comes from
`VOICE_STUN_URLS` (public defaults). TURN is offered only when `VOICE_TURN_URLS`
and `VOICE_TURN_SECRET` are both set; its username and credential are derived
per request with the coturn `use-auth-secret` scheme and expire after
`VOICE_TURN_TTL_SECONDS` (default 14400). The shared secret never reaches a
client. TURN relays only encrypted media.

An empty channel does not insert a message between `session` and `state`; a
roster follows only when someone is already in voice. Membership belongs to the
connection that joined: closing that socket, leaving the seat, resuming the seat
on another socket or closing the room ends it immediately, and a late close of a
replaced socket cannot remove the new connection's membership.

A peer link is identified by the pair of generations. `signal.generation` is the
sender's own generation and `peerGeneration` the one it believes the target has.
The relay forwards a signal only while both are current and stamps the
forwarded message with the target's generation; a stale pair, or a target that
just left, is dropped silently because the next roster already reports the
change. Clients that omit `peerGeneration` (build 30018) are still relayed on the
sender's generation alone. Errors (`NOT_IN_VOICE`, `INVALID_SIGNAL`,
`VOICE_UNSUPPORTED`, `RATE_LIMITED`) never end the match. Voice signaling has its
own allowance of 120 messages per 10 seconds on top of the game allowance.
Descriptions are not stored, logged or included in admin history; audio is
peer-to-peer.

## Operational behavior

- `GET /healthz`: JSON liveness, protocol version and room count (no room data).
- Static Flutter web assets are served from `WEB_DIR` (SPA fallback).
- `GET /privacy` and `/support`: static public information pages.
- Rooms persist atomically to `DATA_DIR/rooms.json` (default `./data`). Tokens are
  stored only as SHA-256 hashes. On restart players become disconnected and may resume.
- Rooms expire after 24 hours of inactivity; default limit is 500 concurrent rooms.
- Messages are limited to 16 KiB, 120 messages per 10 seconds per connection, and
  32 concurrent connections per network address. Server heartbeats clean up dead sockets.
- Service is a **single instance**; persistent storage must survive container replacement.
  A future multi-instance deployment needs shared transactional storage and pub/sub.
