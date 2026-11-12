# Android — new app and historical listing

## 30020 — Optional voice chat, internal testing

Verified **12 November 2026**: **3.1.1 (30020)** is active on the existing
internal track `internal` as **3.1.1 Chat vocale**. The Android Publisher API
read the previous active build 30017, uploaded the new signed AAB, replaced only
the internal-track release, committed the edit, and read back build 30020 as
`completed`. The existing tester audience was not modified; no production track
or store listing was changed. Receipt: `artifacts/play-internal-30020.json`.

The optional room-wide voice chat captures microphone audio only. The signed
AAB is 109,182,407 bytes, SHA-256
`50076c19f50d2e0fb826d89d49823435f66fd4aba495232ca14c4042984d7e0f`; its
package/version and bundletool validation passed for `cc.sommomi.mymemory`,
versionName 3.1.1, versionCode 30020, min SDK 24 and target SDK 36. It is signed
by the existing upload certificate. R8 mapping and native debugging symbols are
embedded in the AAB. Italian, en-US and en-GB internal release notes are in the
receipt.

## 30017 — Italian and English (previous internal release)

Verified **6 November 2026**: **3.1.0 (30017)** is active on the existing internal
track as release **15**, **3.1.0 Sala giochi pop · English**. The English UI follows
the device language automatically and can be selected explicitly in Settings;
Italian remains available, including as an explicit saved override. Other device
languages fall back to English. Paola's syllables remain Italian.

The existing **MyMemory test interno** audience, observed with **three users**,
was preserved. Play reports zero newly unsupported devices. The AAB and APK
signatures, package/version and bundletool validation passed; receipts are
`artifacts/android-native-build-30017.json` and
`artifacts/play-internal-30017.json`. The AAB is 91,393,410 bytes, SHA-256
`958acdacdbdd8eb4c039098c425afd06195398016785df909e22f78a4503d80b`.

Italian, en-US and en-GB listing texts are saved and reread; availability changes
for exactly **27 EU states + USA** are included in the production review submission.
The final 30017 capture set includes four Italian and four English phone images
at 1080×1920, with PNG CRC/sBIT and RGB pixel hashes verified. All four images are
saved and reread for each of the three listing locales, together with the shared
icon and feature graphic. Console's pre-submission checks passed.
Receipts are in `artifacts/store-30017/`, including `play-listing.json`,
`play-localizations.json`, `play-markets.json` and `screenshots.json`. The
production change set contains only build 30017 in the same 28 countries;
automatic checks passed and all **13 changes** were submitted for review.
The changes include the production full rollout, markets and required listing and
declaration setup; they also include the already-saved closed Alpha tester list
and feedback URL. Review is in progress. Managed publishing is disabled, so the
release may roll out automatically after approval. Evidence:
`artifacts/google-play-final-readiness-30017.json` and
`artifacts/store-30017/production-submission.json`.

## 30016 — Sala giochi pop (previous internal release)

Verified **6 November 2026**: **3.1.0 (30016)** is active on the existing internal
track as release **14**, **Sala giochi pop · comandi più leggibili**. It supersedes
intermediate build 30015. The cobalt/yellow/coral visual system includes the new
app icon, framed mode tiles and cards, yellow matched pairs and opaque settings,
profile and collection surfaces. The final correction gives back/share controls
and the Bluetooth lobby adequate contrast and declares Outfit explicitly for
button labels.

The package ID, signing identity and existing tester audience are preserved. Play
reports **zero newly unsupported devices**. The AAB and APK signatures and the
bundle manifest/version were verified; bundletool validation passed. The
consolidated delivery evidence is `artifacts/play-internal-30016.json`, with the
native details in `artifacts/android-native-build-30016.json` and the proof image
`artifacts/play-internal-live-30016.jpg`.

The store screenshot set contains four real Flutter UI captures at 1080×1920,
rendered with an isolated fresh guest and exported as RGB without alpha. Capture
provenance and hashes are in `artifacts/store-30016/screenshots.json`; these are
widget-renderer images, not physical-device captures. The Italian listing text,
512×512 icon, feature graphic and all four screenshots are saved and reread in
Console, which reports the listing ready for review. The receipt is
`artifacts/store-30016/play-listing.json`. This listing state does not by itself
verify every initial app-setup requirement. No production rollout or first-review
submission has been performed.

## New app requested by the user

On 5 November 2026 the user explicitly requested a **new Android app**, internal
testing, and deletion of the historical app. The new Console record is created:

| Field | Verified value |
| --- | --- |
| Installed app display name | SommoMemory |
| Console record name | MyMemory Together; SommoMemory is the installed app display name |
| Package/application ID | `cc.sommomi.mymemory` (Console availability verified) |
| Console app ID | `4972469070574777722` |
| Language/category/pricing | Italian `it-IT`, game, free |
| Internal track ID | `4700857721365894827` |
| Tester list | MyMemory test interno; three existing users observed; unchanged |
| Release | **3.1.1 (30020)**, 3.1.1 Chat vocale; **active on internal track** |
| Binary | **3.1.1 (30020)** uploaded and accepted |
| Track status | **Attivo** |
| App signing | Releases signed by Google Play; no new terms prompt appeared |
| Production | Build 30017 remains in review for 28 countries; 30020 changed only internal testing |

[New app dashboard](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/app-dashboard)
and [internal release details](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/tracks/4700857721365894827/releases/15/details).
The **live internal opt-in link** is
[Join the internal test](https://play.google.com/apps/internaltest/4700857721365894827).
It was opened in the owner's signed-in browser and showed the invitation to test
`cc.sommomi.mymemory (unreviewed)` plus **Accept invite**. The invitation was not
accepted on the user's behalf. The tester must open it with the account included
in the selected tester list and accept the invitation before installation.

The current AAB is `artifacts/SommoMemory-3.1.1-30020.aab` (109,182,407 bytes;
SHA-256 `50076c19f50d2e0fb826d89d49823435f66fd4aba495232ca14c4042984d7e0f`).
Its local JAR signature and bundletool checks passed; build 30020 is active on the
existing internal track. The upload/activation receipt is
`artifacts/play-internal-30020.json`. Localized listing and market preparation is
tracked in `artifacts/store-30017/`; listing changes remain separate from internal
testing. Production review submission is unchanged; no public rollout was made
for build 30020.

Google temporarily displays the unreviewed package name instead of the eventual
store name for this new internal app. This release is **internal only**, not a
production listing. Console accepted the binary with min API 24, target API 36,
three ABIs, and ReTrace mapping/native symbols attached.

Build **30020** is the current internal binary. Build **30017** added the bilingual
interface and pop arcade redesign; build **30014** added the illustrated journey
map and offline solo games with gems, collection unlocks and automatically
synchronized progress and records; crowns remain reserved for ranked games. The existing internal tester
audience is unchanged. Build **30013** and the feature and package details below
document the preceding releases and remain as release history. Build
**30011** replaced the intermediate internal build 30010. That binary uses
`wss://sommomemory.sommomi.cc/ws`; the public service is
`https://sommomemory.sommomi.cc`. Only this new domain is associated with native
invites; legacy-host intent filters were removed before the final rebuild, as the
user requested. API, domain associations and TLS were verified live before upload.
Package, signing identity, internal track and owner-only tester
list are unchanged. Proof of the active release:
`artifacts/play-internal-live-30011.jpg`.

## Earlier releases and capabilities (historical)

Build 30011 includes optional original sound cues and haptic feedback for card
flips, matches, mismatches and turns, with saved sound/haptics preferences. The
audio is bundled PCM WAV; lifecycle changes stop pending feedback and iOS uses
the ambient audio category. The generator is kept outside the app under
`scripts/synthesize-feedback.py`: only the WAV and NOTICE are bundled. The final
archive and AssetManifest contain **zero `.py`/`.pyc` files**. Android 30010 was
briefly active as release 8 at 18:01 and has now been superseded by 30011, with no
rollback or tester changes.

A full room now returns a public snapshot of its two players, current scores and
final result if available. Manual refresh uses a separate read-only request: it
cannot claim a seat or reveal cards, profile data, balances or session tokens.
Full-room status precedes theme compatibility, while actual entry still checks
supported decks. Terminal entry/session errors cancel retry loops and discard
pending entry actions; transport failures remain retryable. Snapshot immutability,
late socket messages, refresh without joining, and unchanged frame/rate limits
are covered by server and client tests.

Build 30011 also includes game-only gems (100 once per new profile, 20 per verified complete
game), permanent deck unlocks and optional cross-device profiles via a recovery
code. There are no payments, real-money purchases or account-balance merges.
Four decks are free: Animals, Space, Ocean and **Paola**, whose 18 syllables are
bundled as text. Food costs 200 gems, Sports 300 and Travel 400; the six illustrated
collections contain 108 bundled licensed PNGs. The deck is selected before play.
Only the multiplayer host needs to own a paid deck. Offline rewards require a
prepared server ticket and synchronize after reconnection; practice without a
ticket does not award gems. See [ECONOMY_PROTOCOL.md](ECONOMY_PROTOCOL.md).

Invites use verified Android App Links on `sommomemory.sommomi.cc` and the explicit
`sommomemory` app scheme. The association uses the verified **Google Play App
Signing** certificate SHA-256
`CF88459A498AE9C368EE97B9BFDCC74BEABF6C1AA73140CFF3931CAD85A97313`, distinct
from the upload certificate below. Older clients are rejected with an update
message before receiving a deck they cannot render. All **31 Node tests passed**,
including economy concurrency, restart/recovery, credentials, paid-host access
and old/new WebSocket compatibility. Native package, signatures, all 108 PNGs,
syllables, licenses and the final new-domain configuration were verified against
the frozen source; see local `artifacts/native-builds-30011.json`.

The presentation synchronization introduced in build 30007 remains. Scores,
matched-pair styling and the final result follow the actual card animations and appear
after the opening flip completes; turn changes appear after both cards finish
closing. Input stays locked during opening, closing and queued presentation
updates. Rapid remote snapshots preserve the visual sequence without replaying
heartbeat events. Rotation and new-round resets cannot strand an animation lock
or replay an old action. The authoritative local, Bluetooth and server engines
and their 900ms mismatch interval are unchanged.

At the final runtime freeze, Flutter analysis and **all 91 Flutter tests passed**, including
local final-pair events, online/Bluetooth snapshot ordering, complete closing,
reduced motion, rotation and round-reset regressions. Independent review first
reproduced the rotation lock and then verified its correction.
The final packaging regression verifies that the audio AssetManifest contains
only WAV and NOTICE, with no Python files. Live public-preview verification also
confirmed a read-only refresh from an in-progress 0–1 score to a final 5–1 result.

Full-screen animated scenery for Animals, Space and Ocean, floating characters,
reduced-motion and pause handling, illustrated collections, animated card flips,
complete uniform rows and non-scrolling screens remain. The upload and review
screens verified versionCode **30011**,
versionName **3.0.0**; Console reports **zero previously supported devices lost**.
The owner tester list and invitation link were unchanged.

Uploaded artifact:
`artifacts/SommoMemory-3.0.0-30011.aab`, SHA-256
`08f1b10f936c710a123d96829b897970ab18141543f4beb05e9a32c2408884e9`.
The dedicated upload certificate SHA-256 is
`404D6F54025C024007E37F2A25352CB84471268A1C6C0D78C17A9565E12BED67`.
Private signing materials remain outside the repository.

Creation required ordinary program-policy compliance and US export-law
acknowledgments. No new signing-service contract was presented at creation.
At creation there was no connected Play tool or configured Play Developer API credential;
the official [API resource reference](https://developers.google.com/android-publisher/api-ref/rest)
also exposes no create-app operation, so this work uses the signed-in Console UI.
For release 30009, the subsequently available generic service-account credential
authenticated successfully (OAuth HTTP200), but the read-only generated-APKs
request for this app's existing build 30008 returned HTTP403 `PERMISSION_DENIED`.
No grants were changed and no API edit/upload was created. The authorized
signed-in Console was used for internal distribution.

## SommoMemory rename — historical Store draft status

On 5 November 2026 the user requested the display name **SommoMemory**, preserving
the existing package and app record. The default Italian Store listing did not
previously exist. Its **Nome app** is now **SommoMemory**, saved as a draft and
verified after reloading the editor. No identifiers or tester settings changed.
Local evidence, excluded from Git: `artifacts/play-sommomemory-name-draft.jpg`.

At the time of this earlier snapshot, the name was a saved draft and the listing
description and screenshots were absent. Those statements describe the earlier
snapshot, not the 30016 listing work, which is tracked in
`docs/STORE_METADATA_3_1_IT.md`. Console may continue to show **MyMemory Together**
and the temporary name **cc.sommomi.mymemory (unreviewed)** before first review. Google's
[internal-testing guidance](https://support.google.com/googleplay/android-developer/answer/9845334)
explains that testers see a temporary name before the app's first review. A
complete Store listing and review are separate from the internal binary release;
neither production publication nor a first-review submission was performed.

Build **30011 was the live internal version** before release 30013, with
SommoMemory as its installed launcher name. The Store draft status below is
historical; the 3.1.0 listing update is tracked above. No production review submission or rollout was performed.

## Old app deleted — recoverable until 12 November 2026

The historical **com.michele.mymemory** app (Console ID
`4975576173768407729`) was deleted on **5 November 2026**, after the replacement
internal release was available. The user explicitly authorized both deletion and
transmitting the private registration-receipt identifier to the official Google
Play deletion form. That identifier is not recorded in this document or repository.

Console confirms **Hai tempo fino al giorno 12 nov 2026 per recuperare questa app
eliminata** and offers **Recupera app** under Advanced settings > App availability.
The deletion is recoverable until that displayed deadline; after it, Google makes
the deletion permanent. No additional irreversible deletion action was requested.

Immediately after deletion, the replacement **cc.sommomi.mymemory** app was
refreshed and verified separately: its then-current 30003 internal release
remained **Attivo**, with the owner tester list selected and the opt-in link
enabled. The replacement app and its signing settings were not modified during
deletion. The current SommoMemory update 30013 is recorded above.

The [current official deletion guide](https://support.google.com/googleplay/android-developer/answer/16483176)
requires an unpublished app, fewer than 1000 active devices, no unresolved review,
and an eligible account owner. An app with any historical installs retains its old
package permanently, so deleting it does **not** make `com.michele.mymemory`
reusable. The new package above is independent of the old signing key.

The following sections preserve the original read-only audit for historical
reference; they describe updating the old listing, a route the user superseded.

## Historical Play Console audit

Verified read-only on **5 November 2026**, in the user's existing signed-in Google
Play Console browser session. No Console fields, releases, declarations or signing
settings were modified. No Play Developer API credential or connected Play tool
was available in this task, so these facts were read directly from Console UI.

### Existing app

| Field | Verified value |
| --- | --- |
| App name | MyMemory |
| Package/application ID | `com.michele.mymemory` |
| Console app ID | `4975576173768407729` |
| Developer account ID | `5468026965874523214` |
| App-level publication status | **Non pubblicata** (Unpublished) |
| Home-page last update | 26 November 2018 |
| Latest and only uploaded artifact | APK, **versionCode 2**, **versionName 0.9** |
| Artifact upload time shown in Console | 16 October 2015, 13:59 |
| Production release | 0.9; historical rollout 100%; release details show 16 October 2015 |

The **Tutti gli app bundle** page showed one row only and disabled next-page
navigation, so the highest observed uploaded versionCode is **2**. The release
overview labels the old production release as available on Google Play; the
account home explicitly marks the app **unpublished**. The release label does not
establish that the listing is currently visible to new users. The 2018 home-page
update should not be interpreted as a newer binary release.

Authoritative Console pages:

- [App dashboard](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/app-dashboard)
- [All uploaded artifacts](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/bundle-explorer-selector)
- [Release overview](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/releases/overview)
- [Signing management](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/keymanagement)

### Signing requirement for the historical listing

The **Protetto con Play** overview explicitly states **Release non firmate da
Google Play**. Signing management presents an enrollment flow headed **Consenti a
Google Play di gestire la chiave di firma dell'app**, with the unselected option
**Usa chiave di firma dell'app esistente dell'archivio chiavi Java**. Therefore this
existing app is **not enrolled in Play App Signing**.

Updating this listing requires the original release signing key. A newly created
key or an Android debug key cannot update installations signed with the original
key. No enrollment option was selected and no signing key was uploaded. The old
local versionCode-1 APK's debug certificate is not proof of the versionCode-2 Play
release certificate; see `legacy/AUDIT.md`.

The modern project's earlier restoration build preserved
`applicationId = "com.michele.mymemory"`, but the user now requested a new app with
`cc.sommomi.mymemory`. Updating the historical listing would have required locating
and verifying the original keystore and its password/alias; these credentials
must stay outside source control. The new app uses its own upload key.

### Historical Console requirements visible for the next release

The **Testa e rilascia** page listed these required incomplete declarations:

- Privacy policy.
- Target audience and content.
- Data safety.
- Financial features.
- Health apps.

These were observed only; they were not completed or submitted. Public privacy
and support pages for the restored service are available at
`https://sommomemory.sommomi.cc/privacy` and `/support`, but Console declarations still
need to reflect the final app behavior and the user's intended audience.

During the initial historical audit, no Android upload, production submission or
republishing action was performed. The subsequent replacement internal release
and authorized old-app deletion are recorded above.
