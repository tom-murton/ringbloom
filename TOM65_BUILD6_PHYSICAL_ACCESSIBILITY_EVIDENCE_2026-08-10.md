# TOM-65 — build 6 physical and accessibility evidence

Evidence date: 10 August 2026  
Execution windows: 09:01–09:16, 09:41–09:45 and 11:21–11:46 BST  
Candidate: Ringbloom 1.2 (6)  
ASC build ID: `a3434f64-3bf5-484a-9f6d-6daf0a0a3b92`  
Uploaded IPA SHA-256: `57a1ed81256ac0746975047c5e0c2d4b14a3912595be613799e2848d71d2aff4`

## Outcome

TOM-65's automated physical UI gate is **passed**. The final canonical helper ran all 39 UI tests
on the attached iPhone with zero failures, and the complete Swift Testing target passed as well.
The two earlier automation-mode failures and the intermediate nine-test physical harness run are
retained as diagnostic history. The final helper necessarily installed an Apple Development-signed
test product rather than exercising the uploaded TestFlight binary, so the manual TestFlight
commerce and assistive-technology rows remain open. CoreDevice does not expose an installed signer,
receipt or binary hash; the earlier TestFlight read-back is therefore correlated identity evidence,
not a cryptographic match to the uploaded IPA.

## Candidate and TestFlight identity — passed

- `shasum -a 256` of
  [Ringbloom-1.2-6.ipa](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/export/Ringbloom-1.2-6.ipa>)
  returned exactly
  `57a1ed81256ac0746975047c5e0c2d4b14a3912595be613799e2848d71d2aff4`.
- The IPA `Info.plist` reports bundle ID `com.tommurton.ringbloom`, version `1.2`, build
  `6`, minimum iOS `17.0` and no non-exempt encryption.
- [The build-6 inspection summary](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/inspection/ipa-inspection-summary.txt>)
  records App Store distribution profile `Ringbloom App Store 2026`, `get-task-allow=false`,
  privacy manifest present, StoreKit linked and no packaged `.storekit` file.
- ASC read-back reports build ID `a3434f64-3bf5-484a-9f6d-6daf0a0a3b92` as `VALID`, version
  `1.2` (6), uploaded 10 August 2026, minimum iOS 17.0, internal state `IN_BETA_TESTING`
  and external state `READY_FOR_BETA_SUBMISSION`.
- Internal group `Test` (`1b19d25b-82e2-4b28-89d8-c715d3cd957c`) has access to all builds,
  explicitly links build 6, and contains Tom's installed tester account. Build 6 is therefore
  available for internal TestFlight installation without another distribution mutation.
- No TestFlight group, tester, notification, review, credential, price or release state was
  changed.

## Physical devices discovered read-only

| Device | Connection/state | OS | Relevant app identity | Result |
|---|---|---|---|---|
| `Toms test phone`, iPhone SE (`iPhone12,8`), UDID `00008030-001C510C2298402E` | Wired, paired, Developer Mode enabled | iOS 26.6 (`23G71`) | TestFlight 4.3.0 (659.1) is installed. The first post-helper baseline showed Ringbloom 1.2 (6) as the helper's **Developer App**; the later pre-helper TestFlight-correlated identity and its subsequent replacement are recorded below. | Device and OS verified; TestFlight correlation preserved, but an exact installed-binary hash was unavailable. |
| `Toms phone`, iPhone 17 Pro (`iPhone18,1`), UDID `00008150-001E443A2E87801C` | Paired over local network, locked | iOS 26.6 (`23G71`) | App listing could not be read because the developer disk image could not mount: `kAMDMobileImageMounterDeviceLocked`. | Device and OS verified; installed build identity **not exercised**. |

ASC build-6 beta-usage metrics returned `installCount: 0`, `sessionCount: 0` at the time of
read-back. These metrics can lag, but they do not provide evidence of a build-6 TestFlight
installation and are not used to claim one.

### Resumed pre-helper TestFlight-correlated identity

At 09:41 BST, after Tom confirmed installing Ringbloom from TestFlight, the wired iPhone SE
read-back showed:

- iPhone SE (`iPhone12,8`), UDID `00008030-001C510C2298402E`, iOS 26.6 (`23G71`), wired,
  paired, unlocked and Developer Mode enabled;
- TestFlight 4.3.0 (659.1) installed;
- Ringbloom bundle ID `com.tommurton.ringbloom`, version `1.2`, build `6`;
- app container
  `/private/var/containers/Bundle/Application/1968BC94-BF14-4D4C-839F-8502F99C53A8/Ringbloom.app`;
- `defaultApp=false`, `removable=true`, `internalApp=false`, `builtByDeveloper=true`.

The prior helper-installed app used container `FCDAE388-FAC4-4E18-90F5-42A76C7DEB12`; the new
container corroborates a reinstall. `builtByDeveloper` is CoreDevice's third-party-app field and
does not expose distribution signing. Device APIs available in this environment did not expose a
signer identity, TestFlight receipt, installed executable checksum or ASC build UUID. The read-back
therefore correlates Tom's confirmed TestFlight action, exact displayed version/build, container
change and the exact ASC build-6 availability; it does **not** claim the device binary hashes to the
uploaded IPA.

## First canonical physical helper — failed

The required command was run unchanged from the project root:

```text
/Users/tommurton/GitHub/Build-an-app/scripts/test-on-iphone.sh Ringbloom.xcodeproj Ringbloom
```

Authoritative final marker:

```text
PHYSICAL_IPHONE_TESTS_FAILED (xcodebuild status 75)
```

Stable result bundle:

[Test-Ringbloom-2026.08.10_09-01-50-+0100.xcresult](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_09-01-50-+0100.xcresult>)

The result summary records:

- 128 logical Swift tests in 14 suites passed;
- 205 parameterised Swift executions passed;
- zero Swift failures and zero skips;
- zero UI tests executed;
- one `RingbloomUITests-Runner` infrastructure failure before test execution:
  `Timed out while enabling automation mode.`

XCTest's `Executed 0 tests` line preceded Swift Testing and is not treated as the result. Swift
Testing's own final line was `Test run with 128 tests in 14 suites passed`.

After the automation timeout, Xcode's diagnostic collection invoked `sudo /usr/bin/true` and
displayed `Password:`. No password or credential was entered. Only the blocked diagnostic child
was terminated so that `xcodebuild` and the wrapper could return the required final marker. The
result bundle retains the action log and runner failure; the complete console stream is also
retained in the Codex task transcript.

## Resumed canonical physical helper — failed

After the pre-helper identity was recorded, the same required command was run unchanged again.
Xcode explicitly signed and installed a local test product with `Apple Development: Tom Murton
(Q8Z7AR2TT9)` and the team provisioning profile, replacing the TestFlight-correlated installation.
The post-helper Ringbloom container changed again to
`82A58545-74EB-425E-BACC-FC1D1C8215FD`.

Authoritative final marker:

```text
PHYSICAL_IPHONE_TESTS_FAILED (xcodebuild status 65)
```

Stable result bundle:

[Test-Ringbloom-2026.08.10_09-42-35-+0100.xcresult](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_09-42-35-+0100.xcresult>)

The result summary records 128/128 logical Swift tests in 14 suites and 205/205 parameterised
executions passed, with zero Swift failures/skips. Zero UI tests executed; the sole failure was the
UI runner timing out while enabling automation mode. Xcode diagnostic collection again invoked
`sudo /usr/bin/true`; no password was entered, and only the stopped diagnostic subprocesses were
terminated so the wrapper could emit its marker.

## Final canonical physical helper — passed

After Tom left the phone face-up, unlocked and awake, the required command was run again. The
device reported `passcodeRequired: false`, `unlockedSinceBoot: true` and an active display before
the run. The final authoritative marker was:

```text
PHYSICAL_IPHONE_TESTS_PASSED: 	 Executed 39 tests, with 0 failures (0 unexpected)
```

The source-matched result bundle is:

[Test-Ringbloom-2026.08.10_11-25-37-+0100.xcresult](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_11-25-37-+0100.xcresult>)

Its summary records the wired iPhone SE (`00008030-001C510C2298402E`), iOS 26.6 (`23G71`),
167 total tests, zero failures/skips, 128 logical Swift tests in 14 suites with 205 parameterised
executions, and all 39 `RingbloomUITests` passed. The UI target completed in 1,244.768 seconds.
The helper installed the local Apple Development test product; this is physical UI evidence, not
an exact TestFlight-binary identity proof.

## Exact-source automated accessibility evidence — passed, not physical

[Ringbloom-build6-full.xcresult](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/.asc/artifacts/freemium-1.2-build6-20260810T070034Z/test/Ringbloom-build6-full.xcresult>)
is the clean pre-archive result for the unchanged build-6 source manifest. It passed 167 logical
tests / 244 executions with zero failures or skips on an iPhone 17 Pro / iOS 26.5 simulator,
including all 39 UI tests. It covers stable accessibility semantics, compact/current-large layout,
Accessibility XXXL, Increased Contrast and Reduce Motion launch paths. It cannot prove physical
VoiceOver speech, focus timing, haptics, colour perception or StoreKit account behaviour.

## TestFlight sandbox acceptance results

| TOM-65 check | Result | Evidence/limitation |
|---|---|---|
| 1. Fresh qualified sample can play Garden and Classes 1–5 | **Not exercised** | Tom installed build 6 from TestFlight and its device identity was read before the helper, but this journey was not manually executed. The helper subsequently tested a development-signed replacement. Deterministic UI coverage is not substituted for this physical row. |
| 2. Real sandbox product and localised price appear | **Not exercised** | ASC confirms the £2.99 IAP configuration; no physical sandbox storefront was opened. |
| 3. User cancellation preserves free access without error | **Not exercised** | No Apple purchase sheet was entered or cancelled. |
| 4. Non-consumable purchase unlocks Classes 6–30 and Circuit | **Not exercised** | No sandbox purchase was made. |
| 5. Relaunch preserves StoreKit entitlement | **Not exercised** | No sandbox entitlement was established. |
| 6. Delete/reinstall restores entitlement through Apple account | **Not exercised** | Tom performed a TestFlight reinstall, but no sandbox entitlement had been established, so entitlement recovery was not exercised. |
| 7. Restore Purchases succeeds and routes correctly | **Not exercised** | No physical restore was initiated. |
| 8. Pending/Ask to Buy | **Not exercised** | Current sandbox-account support was not established. This remains an explicit optional observation, not a pass. |
| 9. Refund/revocation removes IAP-only access after propagation | **Not exercised** | No sandbox entitlement or revocation/refund action was created. |
| 10. Legacy entitlement is not claimed as TestFlight-testable | **Passed as a declared limitation** | No TestFlight legacy claim was made. Exact deterministic legacy policy/unit/UI tests passed in the source-matched build-6 suite; sandbox AppTransaction version 1.0 remains intentionally ineligible. |

## Manual build-6 checklist

### Passed

- [x] Exact IPA SHA, embedded version/build/bundle ID and App Store signing inspected.
- [x] ASC processing and internal TestFlight availability read back by exact build ID.
- [x] ASC version 1.2 still references build 6 and uses manual release.
- [x] The prepared review submission contains exactly two ready items: version 1.2/build 6 and
  IAP `6799735184`; no submission is active in App Review.
- [x] Version metadata, complete review notes and all seven named screenshots in both current
  iPhone size sets remain present.
- [x] App Privacy authenticated read-back reports `Data Not Collected`, the policy URL is present,
  and the published declaration remains present.
- [x] IAP product ID, en-GB/en-US localisations, £2.99 pricing, review notes and complete `SOURCE`
  review screenshot remain present.
- [x] The production app price/release state was not changed.
- [x] Attached test iPhone model, UDID, iOS build and wired state read back.
- [x] Tom-confirmed TestFlight installation was correlated read-only to Ringbloom 1.2 (6), its new
  container and exact ASC build-6 availability, without claiming an unavailable device hash.
- [x] Physical Swift Testing target passed on the final run: 128/128 logical tests and 205/205
  executions.
- [x] Physical UI automation passed on the final run: 39/39 `RingbloomUITests`, zero failures or
  skips, on the wired iPhone SE / iOS 26.6.
- [x] No credential, purchase, review-submission, price or release action performed.

### Repeat physical confirmation (10 August 2026, 13:10 BST)

The complete shared `Ringbloom` scheme was rerun on the same wired iPhone SE after the
TestFlight-install check. The helper's authoritative marker was
`PHYSICAL_IPHONE_TESTS_PASSED`; `xcresulttool` independently reports 167 logical tests / 244
passed executions, zero failures or skips (128 Swift logical / 205 parameterised executions
and 39 UI tests). Device: iPhone SE, iOS 26.6 (23G71), UDID
`00008030-001C510C2298402E`. Result bundle:

[`Test-Ringbloom-2026.08.10_13-10-45-+0100.xcresult`](</Users/tommurton/Library/Developer/Xcode/DerivedData/Ringbloom-ekhndzksekjkwghedtgicyqvimkg/Logs/Test/Test-Ringbloom-2026.08.10_13-10-45-+0100.xcresult>)

As with the earlier helper run, this is development-signed physical automation: the helper
installs its test product and UI runner, so it is not evidence of the uploaded TestFlight IPA's
receipt or signing identity.

### Historical failed attempts (retained)

- [ ] First canonical helper: failed with status 75 because UI automation mode timed out.
- [ ] Resumed canonical helper: failed with status 65 for the same timeout.
- [ ] Physical UI automation failed before execution in the two earlier attempts; the final
  source-matched run passed all 39 tests.

### Not exercised

- [ ] Exact TestFlight build 6 manual launch and journey on an identified physical iPhone. The
  final helper's development build passed the physical UI suite; no device binary hash was
  available to prove the installed app was the uploaded TestFlight IPA.
- [ ] Fresh install and reinstall with progress preserved as specified.
- [ ] TestFlight sandbox purchase success.
- [ ] Deterministic user cancellation from Apple's purchase sheet.
- [ ] Restore success on a second/fresh installation.
- [ ] Revocation/refund downgrade and retained premium progress.
- [ ] Every manual state/transition row in
  [the UI/accessibility matrix](</Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom/FLOWER_SHOW_UI_ACCESSIBILITY_VERIFICATION_MATRIX.md>).

### Tom interaction required

- [ ] Reinstall Ringbloom 1.2 (6) from TestFlight again because the resumed helper replaced it with
  a development-signed test product. Leave the phone unlocked for the manual commerce/accessibility
  work; the pre-helper identity read-back is already preserved.
- [x] Authorise and complete the canonical physical UI automation run. No password was shared or
  written into project evidence.
- [ ] Use a Sandbox Apple Account/TestFlight purchase sheet to perform one success, one explicit
  cancellation, restore after reinstall, and the agreed revocation/refund scenario. Purchases and
  account actions remain Tom-controlled.
- [ ] With VoiceOver enabled, execute Home → Class Book → rules/briefing → play → Goals → result →
  checking retry → Continue/purchase, verifying spoken order, disabled state, modal containment and
  useful focus restoration.
- [ ] Repeat the visual/layout rows at Accessibility XXXL and Increased Contrast/Differentiate
  Without Colour; repeat transitions with Reduce Motion; inspect grayscale/colour filters.
- [ ] Exercise Voice Control, Switch Control and Full Keyboard Access for the result/retry/purchase
  path, and verify physical haptic/sound behaviour.

## Smallest safe handoff

1. Open TestFlight on the wired iPhone SE and reinstall **Ringbloom 1.2 (6)** again, because the
   canonical helper necessarily replaced it with an Apple Development-signed app.
2. Tom then performs the Apple-account actions: purchase, cancel, reinstall/restore and the chosen
   revocation/refund. No production purchase is needed; TestFlight uses sandbox.
3. Tom completes the spoken/perceptual checks (VoiceOver, Accessibility XXXL, Increased Contrast,
   Differentiate Without Colour, Reduce Motion and grayscale). Screen recordings can support the
   record, but VoiceOver focus and announcement results require written observations.

Until those interactions are complete, TOM-65 remains open and the production-readiness verdict
remains **not production-ready**.

## Final external-state read-back

At 09:48 BST, a fresh post-retry ASC query again returned build 6 as `VALID` and
`IN_BETA_TESTING`, with
external state `READY_FOR_BETA_SUBMISSION`. Internal group `Test` remained an all-builds internal
group, still linked build 6 and still linked Tom's tester ID. Build-6 usage remained zero installs,
zero sessions and zero crashes. Version 1.2 remained `READY_FOR_REVIEW`, manually released and
attached to build 6. Draft `30e4396e-5bae-473d-8212-b85ca0c7663b` remained `READY_FOR_REVIEW` with
exactly two ready items; authenticated UI read-back identified them as the app version and IAP.
No submission was active in review.

The API and authenticated UI also retained the complete en-GB metadata, full review notes, two
complete seven-image iPhone screenshot sets, published `Data Not Collected` privacy declaration
and policy URL. IAP `6799735184` retained the exact product ID, non-consumable type, en-GB/en-US
localisations, £2.99 current price, review notes and complete 1320×2868 `SOURCE` review asset. The
production app remained paid at its existing price and manual release remained selected.

A query after the first run identified the iPhone SE installation as the helper's developer app
and TestFlight as installed. The resumed run then preserved a new pre-helper 1.2 (6) container
after Tom's TestFlight reinstall before replacing it with another Apple Development-signed product.
The final ASC query was read-only and found no distribution, review, pricing or release-state
change. The checks do not claim a device binary hash or signing identity that CoreDevice did not
expose.
