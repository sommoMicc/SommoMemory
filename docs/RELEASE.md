# SommoMemory release readiness

## 3.1.1 (30020) — Optional lobby voice, TestFlight and Play internal

On **12 November 2026**, TestFlight build **3.1.1 (30020)** processed as
**VALID** and entered **IN_BETA_TESTING** in the existing **SommoMemory
Internal** group. The group still contains exactly the two existing testers;
the App Store Connect API attached the build and Italian beta notes without
creating testers or invitations. Receipt:
`artifacts/testflight-upload-30020.json`.

Google Play's existing internal track is also active with versionCode **30020**,
release name **3.1.1 Chat vocale**, and status `completed`. The Android Publisher
API preserved the track's tester configuration and did not change the production
track or listing. Receipt: `artifacts/play-internal-30020.json`.

The beta adds optional room-wide voice chat. It captures microphone audio only,
does not activate the camera or record audio, and supports mute and recovery
after leaving or losing a connection. iOS includes localized camera-purpose
strings because the bundled WebRTC runtime references camera APIs; the strings
state that the app does not activate the camera or transmit video. Signed IPA:
`artifacts/SommoMemory-3.1.1-30020.ipa`, SHA-256
`040c3cb78128e0a04591aa6b4c01720a8adf5411e2153eaa711798ae0f3db439`.

Build 30018 was rejected because the App Store version 3.1.0 train had closed.
Build 30019 was rejected because `NSCameraUsageDescription` was missing. Both
attempt receipts are retained as `artifacts/testflight-upload-30018-failed.json`
and `artifacts/testflight-upload-30019-failed.json`. No App Store review
submission or website deployment was performed for 30020.

## 30017 — Italian and English

The final bilingual revision is **3.1.0 (30017)**. It preserves the approved pop
visual system and adds English across home, settings, gameplay, Bluetooth,
collections, arenas, profiles and account controls. Device language resolves to
Italian for Italian devices and English otherwise. Settings offers **Automatic /
Italian / English**, persisted in `ui.language`. Dynamic parameters and user
names are inserted without translating their values; Paola remains an Italian
syllable deck. iOS English and Italian Bluetooth permission resources were
verified in the signed native package.

Analysis and **182 Flutter / 101 Node tests pass** after the source freeze. New
checks cover automatic IT/EN selection and the English fallback for other device
languages, live settings changes and persistence, rendered message templates,
plural labels and compact English gameplay. A live browser check on the public
30017 website verified Settings/Home switching to English and restored the
original Automatic preference afterwards. The capture suite passed all six
locale/device combinations and produced **24 approved RGB screenshots**. PNG
CRC, RGB channel count, sBIT metadata and unchanged RGB pixel hashes were
independently verified. The images use the real unchanged MyMemory widget tree
with an isolated guest; they are not physical-device or Simulator captures.
Evidence: `artifacts/store-30017/screenshots.json` and
`scripts/capture-store-30017_test.dart`.

- Google Play release **15**, **3.1.0 Sala giochi pop · English**, versionCode
  **30017**, is active on the existing internal track. The selected tester list
  has three observed existing users and was preserved. Receipt:
  `artifacts/play-internal-30017.json`.
- TestFlight build **0123368d-62a7-4ba0-954c-e73fba74d0e2** is **VALID /
  IN_BETA_TESTING** in **SommoMemory Internal** for the same two existing testers.
  Receipt: `artifacts/testflight-upload-30017.json`.
- Web release **20261106-pop-30017** is healthy. The active bootstrap selects
  `main.52c71468fa165976.dart.js`; its public bytes, worker/bootstrap/assets and
  four English privacy/support/account-deletion resources match the local build.
  A consistent new backup preceded deployment, all **56** existing profiles are
  preserved, the capability key is unchanged and SQLite integrity is `ok`.
  WSS handshake and protocol ping/pong passed. Receipt:
  `artifacts/deployment-30017.json`.

`artifacts/native-builds-30017.json` consolidates the signed IPA/AAB/APK hashes,
permissions, distribution and the **429 runtime files** whose hashes match across
Android, iOS and the workspace. The iOS IPA is 57,434,105 bytes, SHA-256
`05dc7ab74a6db7adfca2273ac20dbbda8433de9321cc3fff1eb2d3ec721b28c1`.

Store preparation preserves Italian as primary and adds **en-US / en-GB**.
Availability is saved for exactly **27 EU member states plus the United States**,
with no automatic future-territory inclusion. Market receipts and localized text
are in `artifacts/store-30017/`. All **24 Apple assets are COMPLETE**: six sets
(Italian/en-US/en-GB × iPhone/iPad), each ordered with exactly four current
screenshots. The three legacy screenshots were removed only after the new assets
completed. The three `apple-metadata*.json` receipts record the final readback.
Google Play's three localized galleries, icon and feature graphic are saved and
reread in `play-listing.json`.

The production submissions use build **30017** on both stores. Apple’s App Store
Connect API confirms version 3.1.0 is **WAITING_FOR_REVIEW**, with exactly one
submission item and release after approval. Google Play confirms all **13**
pending changes are **in review**: the production full rollout, EU27+USA markets,
store setup and the saved Alpha test-channel settings. Managed publishing is
disabled, so Google may begin the rollout after approval without another manual
publish step. Neither store has approved or publicly released the build yet.
Submission receipt: `artifacts/store-30017/production-submission.json`. Store
details are in `docs/STORE_METADATA_3_1_IT.md`.

## 30016 — Sala giochi pop (previous internal release)

Verified **6 November 2026**: **3.1.0 (30016)** is distributed on TestFlight and
the existing Google Play internal track, and deployed on the public website.
The approved direction A uses cobalt, yellow and coral, opaque panels, dark
frames and short hard shadows, explicit mode symbols, thick memory cards with
yellow matched states and coordinated launcher/web icons. The final correction
restores visible back/share controls, Bluetooth lobby contrast and explicit
Outfit button typography. Existing animation authority, feedback and game rules
are preserved.

- TestFlight: **VALID / IN_BETA_TESTING**, build
  `dc503284-e587-490d-ad38-1dc860068d91`, existing **SommoMemory Internal** group,
  exactly two existing testers. The configured App Store Connect API performed
  upload, processing checks and group assignment. Receipt:
  `artifacts/testflight-upload-30016.json`.
- Google Play: release **14**, **Sala giochi pop · comandi più leggibili**,
  versionCode **30016**, **active** on track `4700857721365894827`, with the
  existing tester audience and zero newly unsupported devices. API access still
  returns 403, so the signed-in Console handled upload and activation. Receipt:
  `artifacts/play-internal-30016.json`.
- Web/backend: **20261106-pop-30016**, healthy at
  `https://sommomemory.sommomi.cc`. All 50 profiles present at the retained
  consistent backup remain; 53 profiles existed at final verification. The
  capability key is preserved, SQLite integrity is `ok`, and no schema or volume
  reset occurred. The active bootstrap selects the expected hashed runtime;
  public files match local bytes and WSS handshake/ping-pong passed. Receipt:
  `artifacts/deployment-30016.json`.
- Analysis and the complete **166 Flutter / 99 Node tests pass**, with Flutter
  analysis and all 166 Flutter tests rerun after the final source freeze.
  Signed package identities, signatures and bundled content were verified in
  `artifacts/ios-native-verification-30016.json` and
  `artifacts/android-native-build-30016.json`.

The screenshot set contains 12 approved captures: four each at 1320×2868
(iPhone), 2064×2752 (iPad) and 1080×1920 (Play). They use the real Flutter widgets
with an isolated fresh guest, bundled Outfit/MaterialIcons loaded and an Apple
Color Emoji fallback supplied to the test renderer; they are not physical-device or Simulator captures. RGB conversion
strips only fully opaque alpha channels and preserves the RGB pixels.
`artifacts/store-30016/screenshots.json` records provenance and hashes.

Store preparation remains distinct from release acceptance. Apple is still in
`PREPARE_FOR_SUBMISSION`; the readiness receipt verifies the linked 30016 build,
Games/Card/Puzzle categories, copyright, review contact/notes, age rating **12+**,
free pricing, territorial availability and published privacy declarations with no
tracking. Screenshot and listing upload status is recorded by the store agent in
`artifacts/store-30016/` and `docs/STORE_METADATA_3_1_IT.md`. No production App
Review submission or Play production rollout was performed; the user will submit.

## 30015 — intermediate pop release

Build 30015 introduced the visual revision and Bluetooth contrast correction,
and reached Play internal release 13 and web release `20261106-pop-30015`.
The final 30016 revision supersedes it with corrected back/share icon contrast
and explicit Outfit button fonts. Receipts remain in
`artifacts/play-internal-30015.json` and `artifacts/deployment-30015.json`.

## 30014 — previous internal release

Verified **6 November 2026**: **3.1.0 (30014)** is distributed to the existing
internal testers on both stores. The arena map is an illustrated journey and
individual games save gems, unlocks and best-attempt records without a prepared
ticket or prior connection, then synchronize automatically. Ranked crown rules
are preserved.

- TestFlight: **VALID / IN_BETA_TESTING**, build
  `77362c17-8639-4967-a6ba-69f46d62db84`, existing **SommoMemory Internal** group,
  exactly two existing testers. Upload/finalization used the configured App Store
  Connect API. Receipt: `artifacts/testflight-upload-30014.json`.
- Google Play: release **12**, **Viaggio e partite offline**, versionCode
  **30014**, **active** on the existing internal track `4700857721365894827`.
  API access still returns 403, so the signed-in Console performed the authorized
  upload and internal rollout. Tester audience is preserved. Receipt:
  `artifacts/play-internal-30014.json`.
- Backend and web: **20261106-journey-offline-30014**, healthy at
  `https://sommomemory.sommomi.cc`. A consistent private backup preceded the
  additive migration. All 48 live profiles and associated rows were preserved,
  gem balances and the capability key match the pre-migration snapshot, and
  SQLite integrity is `ok`. Receipt: `artifacts/deployment-30014.json`.
- Analysis and **166 Flutter / 99 Node tests** pass, including real client/server
  offline replay. Signed IPA and AAB identities, signatures, account capabilities
  and bundled content were verified. Browser offline restart and public runtime,
  worker, assets, provider discovery and WebSocket ping were checked.

Native artifact hashes and consolidated release evidence are in
`artifacts/native-builds-30014.json`; signing credentials, native binaries and
Android mapping output remain outside Git. No App Store production submission
or Google Play production rollout was performed.

## 30013 — previous internal release

Verified 2026-11-05. The latest native build is **3.1.0 (30013)** for internal
testing. No production release or production store binary was published.

Build outputs, hashes and release evidence are recorded in
`artifacts/native-builds-30013.json`. The AAB is
`artifacts/SommoMemory-3.1.0-30013.aab` (90,032,282 bytes; SHA-256
`70629b0f64a282d6595321c92d643334d9610a44d7b8435a969e3f87eda6f273`); the IPA
is `artifacts/SommoMemory-3.1.0-30013.ipa` (57,101,304 bytes; SHA-256
`95e50e5a7fa159afdedf4f39410450bd4348db56a05b92df457e043caf0b4ae2`). The iOS
verification report confirms version/build, bundle ID, deep/strict code signing,
the distribution profile and required account entitlements. `jarsigner` reports
the Android AAB signature verified, with trust-chain and JAR stream consistency
warnings; Google Play has accepted this build.

TestFlight build **766a750e-62ec-4801-9f3c-47ff5f18b90b** is **VALID / IN_BETA_TESTING**
in the existing **SommoMemory Internal** group with two testers. Google Play
release **11**, versionCode **30013**, is active on internal track
**4700857721365894827**. See `ANDROID.md` for the current Play status and the
historic app record. Neither distribution is a production release.

The backend deployment is **20261105-arenas-30013**. The local preservation
report records 43 profiles, 43 tokens, 79 ledger entries, two linked identities,
two admin passkeys, two admin sessions, one used admin enrollment and nine online
rounds preserved; no preexisting rows were missing, gem balances were unchanged,
and the capability key was preserved. Apple Italian listing text is saved in
`PREPARE_FOR_SUBMISSION`, with two iPhone screenshots and one iPad screenshot
processed as COMPLETE. The Italian Google Play listing text and two new phone
screenshots are saved. Play Console blocks public review until required initial
app setup steps are complete; internal testing remains active. No production
submission was made. The main-branch verification run 42115892272 completed
successfully for both app and server.

The failed 30010 Apple validation attempt and corrected 30011 replacement remain
documented below for release history.

The UI was implemented with the explicitly requested Astra subagent. Full-viewport animated collection worlds extend behind safe areas, with original code-drawn scenery and bundled Noto characters. Motion stops in background and with reduced motion; reference research is documented in `DESIGN_REFERENCES.md` and `MEMORY_UI_REFERENCES.md`.
**91 Flutter tests** and analysis pass, including four viewports with realistic
iOS safe areas, all 36 cards visible and hit-testable, completion/rematch,
keyboard entry, settings, waiting rooms and Bluetooth lobby. The illustrated revision adds 320 ms 3D flips, reduced-motion behavior, persistent collection/difficulty, exact equal-length rows at all difficulties, and all 108 offline PNGs with bundled licenses, plus 18 text syllables in Paola. See `DECKS.md` for primary sources and pinned provenance. The game screens
do not scroll; Flutter's standard legal-license viewer retains its text scrolling.
**31 Node tests** pass, including the observed stale-browser-cache regression.
Native AAB/APK/IPA signatures and release identities were verified. The presentation layer captures immutable authority snapshots: card faces animate first, then scores, matched styling and results appear. Turn changes wait for both mismatch closing flips. Input remains locked during any flip and still checks the latest authority before sending a move. Early remote card changes queue in order; duplicate heartbeats are ignored. Reduced motion settles immediately. Regression tests cover the final pair, early reveal/hide, rotation during reveal and stale callbacks after a new round. Independent review reproduced and verified the rotation fix. The reveal and close presentation rules remain intact.

## 30011 features and validation (historical)

The replacement is **3.0.0 (30011)** on all platforms. The audio synthesis
source is now `scripts/synthesize-feedback.py`, outside Flutter assets; only
the original WAVs and NOTICE are explicitly bundled. The verified IPA contains
zero `.py`/`.pyc` files. Its SHA-256 is
`79bd46bc83d1e21856f4e3b742d1458e74a58ce62210b95239a6f0c2b47907b2`;
`artifacts/native-builds-30011.json` records signatures, 207 frozen files and
91 Flutter / 31 Node tests. The 30010 features and Italian beta notes below are
retained for 30011. After the final build go-ahead, Apple upload
`ed02d40e-9a06-4456-ac48-5e7ca969e6f9` completed binary delivery without
errors or warnings and passed Apple validation: **VALID / IN_BETA_TESTING**.
It is attached to the existing internal group for exactly the two existing
testers authorized by the user; no invitations or membership changes were made.

The verified Italian beta notes cover higher-contrast notices in every
collection, including the update-required message over Spazio; terminal online
errors that end the connection state; and a read-only full-room preview showing
the two current players, scores and final result when available. Preview refresh
is manual through **Aggiorna** and never grants a third playing slot or move
access.

Original card, match, mismatch and turn sounds/haptics are coordinated with the
card animations. **Suoni** and **Vibrazioni** are independently selectable and
persisted. Beta checks must include event timing, repeated snapshots, rapid
taps, rotation, reduced motion, iPhone silent mode and background/foreground
transitions. Audio, vibration, physical Bluetooth and operating-system link
behavior still need device validation; automated checks are not evidence of those
hardware checks. No real-money purchase or production submission is included.

## 30010 — Apple validation rejected

Build **3.0.0 (30010)** passed analysis, 90 Flutter tests and 31 Node tests.
The signed IPA SHA-256 is
`fcc4c8a183dfc9f008fa5a3a65a1c4bf7a42b2a307061e7e1dd9bb342fcef88a`;
`artifacts/native-builds-30010.json` records 207 frozen source files, 108 PNGs,
original WAV audio and provenance, signatures and unchanged native identity.
After deployment and final go-ahead, binary delivery completed under Apple
upload `6571666e-68b4-4e93-9bb5-61a9eaaac06a`. Apple then rejected it with
validation error **90035 / Invalid Signature**, identifying the bundled source
file `Runner.app/Frameworks/App.framework/flutter_assets/assets/audio/synthesize.py`
as an unsigned code object. Local deep/strict code-sign checks had passed; they
did not establish acceptance of that script by Apple. The generator was moved
outside the bundled asset directory for 30011, which Apple accepted. No valid
30010 build was created or assigned to testers; 30009 stayed available while the
corrected replacement was built.
The app record, SKU, bundle identifier and existing two-tester internal group
remain unchanged. The sanitized historical receipt
`artifacts/testflight-upload-30010-failed.json` records FAILED and the Apple
validation error without private upload URLs. Build 30010 will not be retried.

## 30009 features and validation

Build **3.0.0 (30009)** was rebuilt after removing the old domain from the
iOS Associated Domains entitlement and Android link filters. Only
`sommomemory.sommomi.cc` is associated with the apps. The verified IPA SHA-256 is
`2f644873011d066ca03d1774f39d21f8ee660174dbfc88876cf03f295f0af828`;
`artifacts/native-builds-30009.json` records 203 frozen source hashes, signatures,
108 bundled PNGs, licenses and the native link/keychain settings. Public API and
HTTPS association files on the new host were verified before upload.
Apple upload `4f5f9066-a6d9-4973-87ab-d205849d5772` completed binary delivery
and processing. Build 30009 is VALID / IN_BETA_TESTING in the existing internal
group for exactly the two existing testers authorized by the user.
The verified Italian beta notes cover seven collections (four free, including
Paola syllables), 100 initial gems, 20 gems for each service-validated completion,
permanent collection unlocks at 200/300/400 gems, offline reward submission,
optional profile recovery/synchronization and invitation links. Gems have no
cash value and cannot be bought with money. Physical iOS/Android Bluetooth and
Universal Link handoff still require device testing; automated checks do not
establish radio or operating-system link behavior.

The Italian beta description has been updated and reread through the API,
retaining `https://sommomemory.sommomi.cc` and `/privacy`. It explains anonymous
profiles, optional personal recovery codes and the absence of money purchases,
without requiring registration. The privacy page describes the
profile/wallet ledger, recovery credentials, validated game transcripts and
profile deletion. No App Store production privacy declaration or App Review submission was made.

## iOS

Bundle identifier: `cc.sommomi.mymemory`. Apple team: `L6CS7PYA4B`.
The bundle was registered through the configured App Store Connect API key
(resource `M5DK5NJ6KP`). Associated Domains is now enabled on that same bundle.
The App Store distribution profile used by the verified 30011 archive is
`SommoMemory App Store Links`, UUID `f4f89090-799a-486e-b289-1e0546b0df6f`,
resource `66Z2SB723S`: API verified ACTIVE / IOS_APP_STORE, expiring
2027-10-09. Enabling the capability automatically invalidated the historical
`MyMemory App Store` profile (`AC9UG6997P`, UUID
`10fd734b-e131-42ba-a75c-e62ff73105f2`); the API now reports INVALID for it.
The already-uploaded 30008 artifact used that historical profile before this
change. Certificate `86762T444Q` matches a private-key-bearing identity already
in the local keychain and expires 2027-10-09. No new signing private key was
created.

Runner Release/Profile use manual distribution signing. Debug keeps development
signing for simulator/device development. `app/ios/ExportOptions.plist` exports
for App Store Connect; the deployment target is iOS 15.

Use the configured API helper from the project root:

```sh
node scripts/asc.mjs status
```

The helper reads the existing local credentials configuration, signs five-minute
ES256 JWTs in process, follows no redirects, and sends bearer tokens only to the
official App Store Connect API. Credentials and tokens never enter project files.
Do not copy the private key into this repository.

To create a signed archive and IPA with the project's Flutter SDK:

```sh
cd app
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

App Store Connect record **6831015201** was created through the website as
**MyMemory Together** (the name MyMemory was already occupied), with Italian
primary locale, SKU `mymemory-ios`, iOS and unrestricted existing-team access.
On 5 November 2026, the existing record’s Italian public name was changed through
the API to **SommoMemory** and the Italian beta description was updated. The app
ID, SKU `mymemory-ios` and bundle identifier `cc.sommomi.mymemory` are unchanged.
The existing internal group was renamed **SommoMemory Internal**; its ID and
existing access were preserved. No new app record or tester was created.
The signed 30011 IPA has native display name and bundle name **SommoMemory**
and the same bundle identifier. It uses **SommoMemory App Store Links** for the
Associated Domains entitlement, with only `applinks:sommomemory.sommomi.cc`;
its keychain group is limited to `L6CS7PYA4B.cc.sommomi.mymemory`.
Beta and App Store metadata now point to `https://sommomemory.sommomi.cc`,
with `/privacy` and `/support` for their respective URLs. The updates were
verified through the API after public DNS and strict TLS validation of the new
site. No production submission was made.
Apple's
[Apps API documentation](https://developer.apple.com/documentation/appstoreconnectapi/apps)
states that creating a new app record requires the App Store Connect website.
The [Build Upload API introduced in 4.1](https://developer.apple.com/documentation/appstoreconnectapi/build-uploads)
does support direct binary uploads; that newer resource supersedes the older
Apps overview's Transporter-only upload statement. Use:

```sh
node scripts/testflight-upload.mjs app/build/ios/ipa/SommoMemory.ipa
```

Finalize an uploaded build using the existing internal group. The default guard
requires exactly the account-holder tester. The user explicitly authorized the
same two existing testers for subsequent internal releases; the additional ID
must already belong to that
group, and the finalizer verifies exactly those two members before and after
build assignment. It never creates, removes or invites testers:

```sh
node scripts/testflight-finalize.mjs --finalize --build=30011 --additional-tester=8f73fef5-1c02-4500-92e6-b8e31f908f11 --wait=1200
```

For a later authorized release, replace only the build number if the same two
existing testers should receive it. Omit `--additional-tester` only when the
group actually contains solely the account holder.

The uploader supports `--commit-only` to validate the existing receipt/native SHA-256 and resume only its checksum confirmation after completed binary transmission. It creates no new upload reservation and sends no binary parts in this mode; new uploads persist successful-part markers before confirming the checksum. Build 30006 used this recovery after an API connect timeout, and then completed VALID/internal testing.

The uploader verifies the IPA bundle identifier, reads the actual version/build,
creates the build-upload reservation and sends the binary in Apple's prescribed
chunks. It commits the MD5 delivery checksum Apple accepts and records a SHA-256
artifact fingerprint plus only nonsecret receipt/status
identifiers under `artifacts/testflight-upload.json`. The ASC bearer token is
sent only to the official API; the binary upload request uses separate headers
returned by Apple's reservation. The user authorized TestFlight upload during
this work; no production App Review submission is authorized.

Italian beta description and marketing/privacy URLs have been saved through the
API, along with the App Store privacy/support URLs. An updated Paid Applications
Schedule banner is present in the account; no binding agreements were accepted.

Before external testing: complete privacy declarations, age rating, support and
privacy URLs, store screenshots, review contact details, and required agreements.
The app has ordinary HTTPS and BLE networking; it declares no nonexempt encryption.

## Android

The user's requested replacement is a **new** app, **cc.sommomi.mymemory**,
Console app ID **4972469070574777722**. Google Play App Signing is active. The
current internal release is **3.1.0 (30013)**, release 11, active on track
**4700857721365894827**. A new dedicated upload key
is stored outside source control. There is no dependency on recovering the old
app's signing key for this new package.

The old **com.michele.mymemory** listing (historical versionCode2/version0.9, no
Play App Signing) was deleted on **2026-11-05**, following the user's explicit
confirmation to delete it and use the registration-receipt identifier in Google's
official form. Console confirms it can be recovered until **2026-11-12** and
offers **Recupera app**. The private identifier is not stored in this repository.
The new app's internal track was refreshed after deletion and remains **Attivo**.
Full evidence: `ANDROID.md`.

## Offline Bluetooth

BLE uses `bluetooth_low_energy` 6.2.1 in central/peripheral roles. The advertising
phone is authoritative: it stores the hidden deck, validates both players' turns,
scores matches, and distributes only visible cards. Service discovery filters on
the MyMemory service UUID. Hosts advertise a short random label to choose the
correct nearby game. The first subscribed peer starts the invited match.

Commands use writes with response; snapshots use indications. Messages are
fragmented for the minimum 20-byte ATT payload, bounded to 8KiB and reassembled
with ordered message/fragment identifiers. A two-second heartbeat republishes
full state to recover after an interrupted snapshot. Disconnection ends the game;
create a new match to reconnect. Both players must keep the app open and nearby.
The mode requires neither an account nor Internet.

Android 12+ asks for Nearby devices. Android 11 and earlier requires the location
permission for BLE scans; those permissions are capped at API 30. BLE hardware is
optional for installing the app. Devices without peripheral advertising support
can try joining a match hosted by the other phone. iOS includes the Bluetooth
purpose string. No Bluetooth background execution entitlement is requested.

The package's [official documentation](https://pub.dev/packages/bluetooth_low_energy)
requires physical BLE devices; simulators cannot validate radio interoperability.
Automated tests cover MTU fragmentation, malformed/dropped packet recovery,
concealed state, illegal turns and indices, mismatch timing and rematch voting.
Hardware validation still needs this matrix before claiming Bluetooth certified:

| Host | Guest | Checks |
| --- | --- | --- |
| iPhone | Android | Discover, join, complete a game, rematch, disconnect |
| Android | iPhone | Same; include Android advertising capability |
| iPhone | iPhone | Same; decline then grant Bluetooth permission |
| Android | Android | Same; API 30 location and API 31+ Nearby devices |

For every row, disable Wi-Fi and mobile data while leaving Bluetooth enabled,
then verify full play and matching scores. Also test radio off, permissions
denied, app background/foreground, two hosts nearby, and an interrupted connection.

## Recovery provenance

See `legacy/AUDIT.md` for source identities, original behavior, signing findings
and source paths. Legacy trees are preserved unchanged. The original Pokémon
artwork is retained as historical evidence and is not used by the new app.
