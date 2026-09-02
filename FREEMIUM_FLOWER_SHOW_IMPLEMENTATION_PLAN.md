# Ringbloom 1.2 — Free Garden and Flower Show Unlock

## Executor brief

Implement this plan end to end from `/Users/tommurton/GitHub/Gaming Benchmark/GPT5.6 Sol Ultra - Ringbloom`. Treat the product decisions, identifiers, prices, entitlement cutoff and copy below as locked. Make routine implementation decisions without asking Tom. Preserve all Garden behaviour, Flower Show progress, benchmark evidence and unrelated files.

Stop only at the human gates called out in this document. In particular, do **not** submit version 1.2 to App Review, change the live app to Free, or release version 1.2 on the production App Store. Prepare and verify everything up to those points, then give Tom the exact action and wait for him.

When finished, create `FREEMIUM_FLOWER_SHOW_IMPLEMENTATION_REPORT.md` containing changed files, App Store Connect IDs and states, automated and physical-device test evidence, screenshot paths, unresolved limitations and the remaining human actions.

## 1. Locked product decision

Ringbloom becomes free to download in version 1.2.

- **Garden:** free, unlimited and permanent.
- **Flower Show qualification:** win one Garden. This replaces the current ten-Garden requirement.
- **Free Flower Show sampler:** Classes 1–5, including replays and the first Rosette Class.
- **One paid unlock:** Classes 6–30 plus the Champion Circuit.
- **Purchase type:** non-consumable; one purchase, no expiry.
- **Price:** £2.99 in the UK and $2.99 in the US. Use Apple's automatic equalisation for other storefronts.
- **Existing paid customers:** anyone whose verified production app transaction shows an original iOS build earlier than build 5 receives the full Flower Show automatically.
- **No:** adverts, subscription, consumables, energy, recurring pressure, account, analytics SDK, third-party purchase SDK or backend.

The five-Class sampler is deliberate. Class 5 supplies a satisfying mini-arc and first Rosette; Class 6 introduces Unbroken and is a natural, honest boundary for the full Show.

## 2. Verified starting point and preflight

The following was verified on 9 August 2026 and must be re-read before mutation because external state can change:

| Item | Starting value |
|---|---|
| App | Ringbloom |
| App Store Connect app ID | `6789952808` |
| Bundle ID | `com.tommurton.ringbloom` |
| Live version | 1.1 |
| Live build | 4 |
| Current app price | US $1.99; UK £1.99 |
| Existing In-App Purchases | None |
| Project generator | XcodeGen |
| Deployment target | iOS 17.0 |
| Swift | Swift 6, strict concurrency |

Before editing:

1. Read `AGENTS.md`, this plan, `project.yml`, `Ringbloom/Sources/GameModel.swift`, `Ringbloom/Sources/ContentView.swift`, `Ringbloom/Sources/FlowerShowClassBookView.swift`, the current tests and version 1.1 metadata.
2. Run current `asc --version` and the relevant subcommand `--help` screens before every App Store Connect mutation. The plan was written against `asc` 1.6.1, but the installed CLI remains the authority.
3. Read back the live app version, build, app pricing across all storefronts, IAP list, App Store version state and agreements. Record the JSON in the implementation report. Abort App Store mutation if a newer production build already exists or an IAP has appeared; do not guess a new grandfathering cutoff.
4. Generate the project from `project.yml` and run the existing unit/UI test suite on an available simulator. Record the actual baseline count and failures; do not copy a historical test count into the report.
5. Inspect local changes and preserve them. This benchmark directory is not a Git worktree; do not manufacture Git history or overwrite evidence.

## 3. Access rules and truth table

Use **qualified** for the one-Garden progression gate and **full access** for the commercial entitlement. They are independent concepts.

`highestGarden` already advances to 2 when Garden 1 is won, so qualification is `highestGarden > 1`. Do not infer qualification merely from starting Garden 1.

| State | Garden | Classes 1–5 | Classes 6–30 | Circuit |
|---|---:|---:|---:|---:|
| Has not won Garden 1 | Yes | No | No | No |
| Qualified, no full access | Yes | Yes | Purchase required | Purchase required |
| Qualified, verified paid-app owner, original build 1–4 | Yes | Yes | Yes | Yes |
| Qualified, verified non-consumable purchaser | Yes | Yes | Yes | Yes |
| Access still being checked | Yes | Yes if qualified | Wait; do not show a paywall yet | Wait |
| Product temporarily unavailable | Yes | Yes if qualified | Existing entitlement still works; otherwise unavailable | Same |
| IAP refunded or revoked and no legacy entitlement | Yes | Yes if qualified | Purchase required | Purchase required |

Additional rules:

- Progression rules remain in force after purchase. Buying does not skip Classes.
- Full access controls the premium boundary only; it does not bypass the one-Garden qualification.
- Completed Classes 1–5 are always replayable after qualification.
- All play paths for Class 6 or later, including replay, resume, retry, next-Class progression, saved attempts and Circuit, require full access.
- Existing premium progress is never deleted, truncated or rewritten when access is absent. Display its ratings and saved state, but gate play until entitlement is restored or repurchased.
- A transient StoreKit error must not erase an entitlement already established during the current process.
- Never display the paywall to a legacy or IAP-entitled player. Wait for the access check before deciding that premium content is locked.

## 4. StoreKit and entitlement design

Use native StoreKit 2. RevenueCat would add a dependency and account without solving a problem for one non-consumable product.

### 4.1 New domain types

Add `Ringbloom/Sources/FlowerShowAccess.swift` with pure, testable definitions:

```swift
enum FlowerShowEntitlementSource: Equatable, Sendable {
    case legacyPaidApp
    case storePurchase
}

enum FlowerShowAccessState: Equatable, Sendable {
    case checking
    case sample
    case full(FlowerShowEntitlementSource)
}

@MainActor
protocol FlowerShowAccessProviding: AnyObject {
    var state: FlowerShowAccessState { get }
    var hasFullFlowerShowAccess: Bool { get }
}
```

Also define a pure `FlowerShowAccessPolicy` and the following constants in one obvious location:

```swift
static let productID = "com.tommurton.ringbloom.flower-show"
static let businessModelChangeBuild = BuildNumber("5")
static let qualifyingGardenWins = 1
static let freeClasses = 1 ... 5
```

`BuildNumber` must compare dot-separated numeric components, not strings. For example, build `10` must be later than build `5`. Reject malformed or non-numeric production values rather than granting access.

The policy must answer at least:

- whether Flower Show is qualified;
- whether a Class number may be played;
- whether a Class is free or premium;
- whether the current saved attempt may resume;
- whether a tap should play, wait for access, open the purchase screen or remain progression-locked.

### 4.2 Store controller

Add `Ringbloom/Sources/FlowerShowStore.swift` as an `@MainActor final class FlowerShowStore: ObservableObject, FlowerShowAccessProviding`.

Its published state must separate entitlement from storefront operations:

- `accessState`: `.checking`, `.sample`, or `.full(source)`;
- `productState`: loading, available `Product`, or unavailable with a recoverable message;
- `purchaseState`: idle, purchasing, pending, success, or failed.

Required behaviour:

1. At launch, independently request `Product.products(for:)`, verify `AppTransaction.shared`, and enumerate `Transaction.currentEntitlements`.
2. Grant legacy access only when all of these are true:
   - `AppTransaction.shared` is verified;
   - `appTransaction.environment == .production`;
   - the parsed `originalAppVersion` is earlier than build 5.
3. Do not grandfather `.sandbox` or `.xcode` app transactions. Apple reports sandbox `originalAppVersion` as `1.0`; treating it as a paid production build would make every TestFlight and StoreKit tester look entitled.
4. Grant purchase access only for a verified current entitlement whose product ID exactly matches `com.tommurton.ringbloom.flower-show`.
5. Listen to `Transaction.updates` for the controller lifetime. Apply verified updates, refresh current entitlements and finish a transaction only after access has been delivered.
6. On a successful direct purchase, require a verified transaction, grant access, then finish it. Handle `.pending` and user cancellation separately; cancellation is not an error.
7. `RESTORE PURCHASES` explicitly calls `AppStore.sync()`, then reruns both entitlement checks. Do not call `sync()` automatically at launch because it may present authentication UI.
8. Refunds/revocations are naturally handled because they do not appear in `currentEntitlements`. A legacy paid-app entitlement still wins if the IAP source disappears.
9. Product loading failure must not affect legacy or already verified purchase access. It only prevents a new purchase until retry succeeds.
10. Cancel the transaction-listener task on teardown and keep all published changes on the main actor.

Wrap StoreKit entry points behind a small injected client/protocol so unit tests use deterministic fakes and never contact Apple. Do not persist an authoritative `hasPurchased` Boolean in `UserDefaults`, `GameProgress` or `FlowerShowProgressV3`; the verified app transaction/current entitlements remain the source of truth.

### 4.3 App ownership and launch overrides

Modify `Ringbloom/Sources/RingbloomApp.swift` so one `FlowerShowStore` instance is created first, injected into `GameModel`, and also supplied to views as an environment object. `GameModel` depends only on `FlowerShowAccessProviding`, not StoreKit types.

The default `GameModel` access provider in tests must be sample-only, never full access. Tests that require premium routes must inject an explicit full-access stub.

Support deterministic non-production overrides:

- `--flower-show-access=sample`
- `--flower-show-access=full-purchase`
- `--flower-show-access=legacy`
- `--flower-show-access=checking`
- `--flower-show-product-unavailable`
- `--flower-show-purchase=pending`
- `--flower-show-purchase=failed`

Honour these only when `GameLaunchMode` is `.uiTest` or `.screenshot`. Ignore them in `.production`, even if a malicious user supplies process arguments. Temporarily retain `--flower-show-unlocked` as a non-production alias for full purchase access so older screenshot tooling does not silently break; migrate the current suite and scripts to the explicit argument.

### 4.4 Defence below the UI

Modify `Ringbloom/Sources/GameModel.swift`:

- Replace `flowerShowUnlocked` with a clearly named qualification property based on `highestGarden > 1`.
- Inject `FlowerShowAccessProviding`.
- Apply `FlowerShowAccessPolicy` inside `startFlowerShowClass`, `startFlowerShowReplay`, `resumeFlowerShow`, `nextFlowerShowClass`, Flower Show `retry`, and the private attempt-starting boundary.
- Return a success/result value from attempted navigation where the caller needs to distinguish play, purchase required and access still checking.
- Preserve active premium attempts loaded from disk but do not resume or mutate them without full access.
- Keep Garden persistence, Flower Show V3 decoding and historical ratings unchanged.

UI-only disabling is not acceptable. A direct method call must also fail safely for Class 6+ without full access.

## 5. Product flow and exact interface copy

Use the existing calm Ringbloom voice: short uppercase headings and actions, no urgency, countdowns, fake discounts or modal pressure. Prices always come from `Product.displayPrice`; never hard-code `£2.99` in the binary.

### 5.1 Home states

Update the Flower Show card in `Ringbloom/Sources/ContentView.swift`:

| State | Detail | Progress/status | Primary action |
|---|---|---|---|
| Not qualified | `Win your first Garden to qualify.` | `0 / 1 GARDEN WON` | `LOCKED` |
| Qualified, Class 1 not started | `Classes 1–5 are free.` | `0 / 5 FREE CLASSES` | `BEGIN SHOW` |
| Free Class in progress | `Classes 1–5 are free.` | Existing Class progress | `RESUME CLASS N` |
| Free sampler progressing | `Classes 1–5 are free.` | `N / 5 FREE CLASSES` | `CONTINUE CLASS N` |
| Class 5 complete, checking access | `Checking your Flower Show access…` | `5 / 5 FREE CLASSES` | `CHECKING…` disabled |
| Class 5 complete, no full access | `Classes 1–5 complete. Unlock Class 6 and beyond.` | `5 / 5 FREE CLASSES` | `UNLOCK FULL SHOW` |
| Full access | `30 Classes and the Champion Circuit.` | Existing campaign status | Existing continue/resume action |

The Class Book becomes visible after the first Garden win, including for sampler players.

### 5.2 Natural paywall trigger

Show the complete Class 5 result and Rosette celebration first. When a non-entitled player taps its existing Continue action, dismiss the stored result and open a full-screen `FlowerShowPurchaseView`. Do not interrupt the Class, hide the result or present the paywall on app launch.

Also open the purchase view when the player explicitly taps `UNLOCK FULL SHOW` or a purchase-locked Class 6–30 tile. If full access is still checking, show the checking state and do not flash the paywall underneath it.

Modify `ContentView.Screen` to include a purchase destination and keep a `FlowerShowPurchaseContext` containing the origin and intended target Class. After purchase/restore, show success first, then honour that target. Do not unexpectedly launch gameplay while Apple's sheet is dismissing.

### 5.3 Purchase screen

Add `Ringbloom/Sources/FlowerShowPurchaseView.swift` and reuse `RingbloomTheme` and existing button styles.

Normal state, exact copy:

- Eyebrow: `FLOWER SHOW`
- Heading: `CONTINUE THE SHOW`
- Body: `Unlock Classes 6–30 and the Champion Circuit.`
- Benefit 1: `25 more handcrafted Classes`
- Benefit 2: `Six more special rules`
- Benefit 3: `The endless Champion Circuit`
- Benefit 4: `One permanent purchase`
- Preview label: `NEXT · CLASS 6`
- Preview value: `UNBROKEN`
- Primary: `UNLOCK FOR {localized Product.displayPrice}`
- Secondary: `KEEP PLAYING FREE`
- Tertiary: `RESTORE PURCHASES`

Success state:

- Heading: `FLOWER SHOW UNLOCKED`
- Body: `Classes 6–30 and the Champion Circuit are ready.`
- Primary after Class 5: `START CLASS 6`
- For another saved target: `CONTINUE CLASS N`
- Secondary: `BACK TO HOME`

Operational states, exact copy:

| State | Heading | Body | Actions |
|---|---|---|---|
| Product load failed | `FLOWER SHOW UNAVAILABLE` | `The full Flower Show can’t be loaded right now. Garden and Classes 1–5 are still available.` | `TRY AGAIN`, `KEEP PLAYING FREE`, `RESTORE PURCHASES` |
| Purchases disabled | `PURCHASES UNAVAILABLE` | `Purchases aren’t available on this device.` | `KEEP PLAYING FREE`, `RESTORE PURCHASES` |
| Pending approval | `PURCHASE PENDING` | `Flower Show will unlock when the purchase is approved.` | `KEEP PLAYING FREE` |
| Purchase failed | `PURCHASE NOT COMPLETED` | `Check your connection and try again.` | `TRY AGAIN`, `KEEP PLAYING FREE`, `RESTORE PURCHASES` |

A user-cancelled Apple purchase sheet produces no error alert or failure toast; simply return to the normal purchase screen.

Add stable identifiers at minimum: `flowerShowPurchaseView`, `flowerShowPurchaseButton`, `flowerShowKeepPlayingButton`, `flowerShowRestoreButton`, `flowerShowPurchaseRetryButton` and `flowerShowPurchaseSuccessButton`. Supply meaningful VoiceOver labels/hints, expose the localized price once, maintain 44-point targets and ensure logical focus after state transitions.

### 5.4 Class Book behaviour

Update `Ringbloom/Sources/FlowerShowClassBookView.swift` to separate progression lock from purchase lock.

- Classes 1–5 behave as today after qualification.
- Without full access, Classes 6–30 show a lock treatment and `FULL SHOW` while retaining any historical rating.
- Tapping any purchase-locked premium tile opens the purchase view.
- After purchase, the normal sequential progression rules still decide which Classes can start.
- A completed premium Class without current entitlement is announced as, for example, `Class 8, completed, best Class rating Flourishing. Full Flower Show required to replay.`
- A future premium Class is announced as `Class 12, locked. Full Flower Show required.`

Do not make a progression-locked Class playable merely because it was used to open the purchase screen.

## 6. Local StoreKit configuration

Add `Ringbloom/Resources/Ringbloom.storekit` with one non-consumable matching the production product ID and price. Configure the Debug Run action in `project.yml` to use it through XcodeGen's StoreKit configuration setting. Keep Release/Archive attached to the real App Store, and verify the `.storekit` file is not copied into the production IPA.

Use the local configuration to exercise:

- successful purchase;
- user cancellation;
- pending/interrupted purchase;
- forced product/purchase error;
- restore;
- refund/revocation;
- relaunch with an existing non-consumable.

StoreKit configuration is development infrastructure, not entitlement state. The deterministic UI launch overrides remain necessary for reliable UI tests.

## 7. Automated and manual verification

### 7.1 Pure unit tests with Swift Testing

Add focused files such as `RingbloomTests/FlowerShowAccessTests.swift` and `RingbloomTests/FlowerShowStoreTests.swift`. Follow the existing Swift Testing style; keep XCTest for UI tests.

Required cases:

1. Qualification is false at `highestGarden == 1` and true after Garden 1 is won.
2. Qualified sample access permits every Class 1–5 and rejects Class 6, Class 30 and Circuit.
3. Full legacy and IAP access permit premium play while still enforcing campaign sequence.
4. Free replays work; premium replays and saved premium attempts require full access.
5. A verified production original build 1, 3 or 4 grants legacy access.
6. Production build 5 and 10 do not grant legacy access.
7. Sandbox/Xcode `1.0` never grants legacy access.
8. Unverified or malformed app transactions fail closed without altering game progress.
9. Only a verified current entitlement for the exact product ID grants purchase access.
10. Missing/refunded/revoked IAP access falls back to sample unless legacy access also exists.
11. Verified direct purchases and transaction updates grant access before finishing exactly once.
12. Pending, cancellation, disabled purchases, product load failure and restore/sync have distinct outcomes.
13. A transient refresh error does not downgrade an already established in-memory entitlement.
14. `GameModel` rejects every Class 6+ entry path with sample access, including retry/resume and private-boundary attempts.
15. Existing `FlowerShowProgressV3` and Garden fixtures still decode unchanged; ratings and active attempts survive access changes.
16. No entitlement Boolean appears in encoded `GameProgress`.

Use injected fakes, `#expect` and `#require`; no live network or real StoreKit account in unit tests. Avoid fixed sleeps.

### 7.2 UI tests with XCTest

Update `RingbloomUITests/RingbloomUITests.swift` and the screenshot scripts for the explicit access overrides. Add tests for:

- fresh Home shows `0 / 1 GARDEN WON` and one-Garden qualifier copy;
- winning Garden 1 exposes Flower Show and the Class Book;
- sample access can enter/replay Classes 1–5;
- a Class 5 result appears before Continue opens the purchase view;
- Class 6 cannot begin under sample access through Home or Class Book;
- the paywall shows all promised content, localized test price, Keep Playing and Restore;
- cancellation retains Garden and Classes 1–5 without an error;
- simulated purchase unlocks Class 6;
- legacy override bypasses the paywall;
- checking access does not flash the paywall;
- product unavailable, pending and failed purchase states use the exact copy;
- historical premium ratings remain visible but gated;
- restore-success routing works;
- all relevant controls expose the stable accessibility identifiers.

Run visual/accessibility checks at standard and Accessibility XXXL Dynamic Type, Increased Contrast and Reduce Motion. Cover a compact iPhone layout such as SE/13 mini and a current large iPhone. Check that the localized price does not truncate in likely long-price locales.

### 7.3 StoreKit, sandbox and TestFlight

After the IAP exists in App Store Connect, test on a physical iPhone with a Sandbox Apple Account and through TestFlight. TestFlight purchases use sandbox and do not charge. Because sandbox app transactions report `originalAppVersion == 1.0`, legacy access is deliberately not testable there; use the injected legacy unit/UI path until production.

Run project-native verification, then use:

```text
/Users/tommurton/GitHub/Build-an-app/scripts/test-on-iphone.sh Ringbloom.xcodeproj Ringbloom
```

Report the helper's final `PHYSICAL_IPHONE_TESTS_PASSED` or `PHYSICAL_IPHONE_TESTS_FAILED` line verbatim. A build with no executed tests is not test coverage.

Production grandfathering can only be finally proven after release with an Apple account that genuinely acquired build 1–4. Tom controls that account action. The executor must verify the resulting in-app state rather than assume it from a successful release.

## 8. App version and App Store metadata

Set `MARKETING_VERSION` to `1.2` and `CURRENT_PROJECT_VERSION` to `5` in `project.yml`, then regenerate `Ringbloom.xcodeproj`. Build 5 is a contractual entitlement cutoff; do not increment it casually before the binary is uploaded. If build 5 becomes unusable and build 6 must ship for this same free-model launch, keep the business-model cutoff at 5.

Create `metadata/version/1.2/en-GB.json` by copying 1.1 and making these changes:

### Description replacement

Replace the `A COMPLETE PREMIUM GAME` section with:

```text
FREE TO START. ONE PURCHASE TO OWN.
Play the endless Garden and the first five Flower Show Classes free. Unlock Classes 6–30 and the Champion Circuit with one permanent purchase. No ads, energy, subscription, account, tracking or data collection.
```

Keep the accurate gameplay, accessibility and AI-development sections. Remove every claim that the app has no In-App Purchases or is a paid complete game. `plays fully offline` may remain only if entitlement verification and restored offline use are validated on device; otherwise replace it with a narrower claim that gameplay itself needs no connection.

### Promotional text

```text
Play Garden and the first five Flower Show Classes free. Unlock the complete Show once and keep it forever.
```

### What's New

```text
Ringbloom is now free to start.

• Play the endless Garden free.
• Qualify for Flower Show after your first Garden win.
• Play Classes 1–5 free, including the first Rosette Class.
• Unlock Classes 6–30 and the Champion Circuit with one permanent purchase.

Existing paid players keep the complete Flower Show automatically. There are still no ads, subscriptions, accounts or tracking.
```

Keep the current keywords unless an ASO validation finds an objective limit/error; monetisation is not a reason to churn them.

### Support and privacy

Update `support-site/index.html` and `support-site/privacy/index.html` anywhere they state there are no In-App Purchases or that the app is paid upfront. State that purchases are processed by Apple and that Ringbloom itself still collects no data. Validate `metadata/privacy.json` and the live App Privacy answers; `DATA_NOT_COLLECTED` should remain only if the implementation truly adds no data collection or third-party analytics.

## 9. Store screenshots

The current product page leads with the complete premium Flower Show. Replace that story so a downloader can understand the free boundary before installing.

Create seven refreshed screenshots for both supported App Store sets. Use accepted source sizes already supported by the project: 1242×2688 and 1320×2868, with no alpha channel.

1. `PLAY GARDEN FREE` — Home/Garden.
2. `TRY THE FIRST FIVE CLASSES FREE` — Class Book showing Classes 1–5.
3. `UNLOCK THE COMPLETE FLOWER SHOW ONCE` — the in-app purchase view with a StoreKit-supplied test price.
4. `EVERY TURN HAS CONSEQUENCES` — representative gameplay.
5. `MASTER SEVEN SPECIAL RULES` — a later premium rule, clearly part of the full Show.
6. `THE SHOW NEVER ENDS` — Champion Circuit.
7. `BECOME GRAND CHAMPION` — end-state aspiration.

Keep in-app captures unaltered apart from deterministic test state; framing and captions may use the established pipeline. Validate dimensions, colour space, alpha and legibility locally. Upload to the 1.2 version only, then read the destination back and compare order/count.

Also capture one clean in-app paywall screenshot for IAP review. This is review-only and need not use the marketing frame.

## 10. App Store Connect IAP specification

Create exactly one product:

| Field | Value |
|---|---|
| Type | `NON_CONSUMABLE` |
| Product ID | `com.tommurton.ringbloom.flower-show` |
| Reference name | `Flower Show – Full Unlock` |
| Display name, en-GB | `Complete Flower Show` |
| Description, en-GB | `Classes 6–30 and the Champion Circuit.` |
| Display name, en-US | `Complete Flower Show` |
| Description, en-US | `Classes 6–30 and the Champion Circuit.` |
| UK price | £2.99 |
| US price | $2.99 |
| Other storefronts | Apple's automatic equalisation |
| Availability | All current storefronts and automatically include new storefronts |
| Family Sharing | Off for 1.2 |
| Promoted IAP | Off for 1.2 |

The product ID and product type cannot be edited later; read them back before continuing. Do not enable Family Sharing: the installed CLI warns that enabling it cannot be undone. Do not create a promoted purchase because 1.2 does not implement App Store purchase-intent routing.

With `asc` 1.6.1, the intended creation shape is:

```text
asc iap setup --app 6789952808 --type NON_CONSUMABLE --reference-name "Flower Show – Full Unlock" --product-id com.tommurton.ringbloom.flower-show --locale en-GB --display-name "Complete Flower Show" --description "Classes 6–30 and the Champion Circuit." --price 2.99 --base-territory "United Kingdom"
```

Re-run `asc iap setup --help` first and do not use `--no-verify`. Add en-US through `asc iap localizations create`, explicitly resolve/set the US $2.99 manual price if automatic equalisation differs, and enable all-territory availability with `--available-in-new-territories`. Read back `asc iap view`, localisations, price schedule, US/UK prices and availability. Store all returned IDs in the implementation report.

If the CLI cannot write review notes, use App Store Connect's In-App Purchase page for that field, then verify by reading the destination UI/API. Upload the review screenshot through `asc iap review-screenshots create` and read it back.

Exact IAP review notes:

```text
Ringbloom 1.2 changes from a paid app to free-to-download with one non-consumable unlock.

Garden is completely free. Win Garden 1 to qualify for Flower Show. Classes 1–5 are free. After the Class 5 result, Continue opens this purchase. The same purchase can be opened by tapping a locked Class 6–30 tile in the Class Book. The product permanently unlocks Classes 6–30 and the Champion Circuit. Restore Purchases is on the purchase screen. No account is required.

Customers who acquired paid production builds 1–4 receive the same full access automatically through a verified AppTransaction.originalAppVersion. This legacy path intentionally does not trigger in TestFlight/sandbox because Apple reports sandbox originalAppVersion as 1.0. For review, please use the sandbox non-consumable purchase.
```

Apple requires the first non-consumable IAP to be submitted with a new app version, so attach this IAP to the 1.2 review submission. Do not submit the IAP on its own.

## 11. Build, TestFlight and submission preparation

1. Regenerate the project and validate Debug and Release builds.
2. Run all unit and UI tests and the physical-iPhone helper.
3. Archive version 1.2 build 5, export with the existing App Store export options and inspect the IPA. Confirm bundle ID/version/build, signing, privacy manifest and that no StoreKit test configuration is packaged.
4. Upload build 5 and wait until processing completes. A successful upload request is not proof of a processed build.
5. Add build 5 to the appropriate internal TestFlight group and verify availability on the destination device. Test the sandbox purchase/restore and all free paths.
6. Create App Store version 1.2 with **manual release**, sync en-GB metadata, screenshots, age rating, privacy, review information and build 5.
7. Add the non-consumable IAP to the same 1.2 review submission.
8. Run `asc validate` and read back every destination object. Save a readiness snapshot in the report.
9. Optionally create/reuse an ongoing App Analytics report request with `asc analytics request --app 6789952808 --access-type ONGOING --reuse-existing`; this is first-party reporting and adds no SDK to the app.

### Human gate A — App Review submission

Stop with version 1.2, build 5 and the IAP fully ready but unsubmitted. Tom alone presses **Submit for Review**. After he does, the executor may monitor and diagnose review feedback, but must not submit or resubmit without another explicit instruction.

## 12. Production price and release sequence

The order matters. If build 5 becomes available while Ringbloom still costs money, a new customer can pay for the download and then be asked to buy the Flower Show because build 5 is not grandfathered. That double-charge window is unacceptable.

Use this sequence only after Apple has approved both version 1.2 and the IAP and the app is waiting for developer release:

1. Confirm 1.2 build 5 is approved, manual release is selected, the IAP is approved/associated, and the live public version is still 1.1 build 4.
2. Prepare the Free app-price schedule across every storefront and inspect the dry-run/equalisation. Do not activate it early.
3. **Human gate B:** Tom explicitly authorises/activates the production app-price change to Free.
4. Read back `asc pricing current --app 6789952808 --all-territories` until every available storefront is Free. Also verify the public App Store product page in at least UK and US. Do not infer propagation from the write response.
5. Accept the small, deliberate transition window: anyone downloading free 1.1 build 4 during it will be grandfathered. This is preferable to charging anybody twice.
6. **Human gate C:** once Free is verified everywhere, Tom releases approved version 1.2. The executor must not run `asc versions release`, `asc publish appstore --submit` or any equivalent production release command.
7. Verify the public store shows Free and version 1.2, then install from the public App Store as a new customer and confirm Garden/Class 1–5/free and Class 6/paywall behaviour.
8. With a genuine pre-build-5 purchaser account controlled by Tom, update/reinstall and confirm full access appears automatically without a paywall or purchase.
9. With a new production account, make one real IAP only if Tom chooses to spend the £2.99; purchases remain his decision. Otherwise record that production checkout itself is not yet exercised, while sandbox/TestFlight coverage is complete.

Do not change the app back to paid after build 5 ships without a new entitlement design and binary. Build 5 customers are intentionally outside the legacy cutoff.

## 13. Post-release evidence and decision rule

There is no meaningful paid baseline: the only known sale/review is from Tom's girlfriend. Do not present that as market evidence and do not judge the model on the first few users.

Use App Store Connect App Analytics and Sales and Trends at 7 and 28 days. Record:

- product-page impressions and views;
- first-time downloads;
- IAP units, unique paying users and proceeds;
- download-to-purchase conversion: unique IAP purchasers ÷ first-time downloads;
- retention/session metrics where Apple's privacy thresholds expose them;
- ratings, reviews, crashes and purchase-related support contacts.

Do not add tracking merely to measure paywall impressions in 1.2. The first decision is whether free distribution produces a real audience and any conversion at all. At 28 days, write a short evidence report comparing download volume, revenue and qualitative feedback with the tiny paid baseline. Recommend changes only from observed behaviour; do not introduce subscriptions, ads or consumables by default.

## 14. Failure containment

- If the product cannot load before release, do not submit/release; fix configuration or code.
- If App Review rejects either item, keep the live paid 1.1 untouched, address the stated issue and return to Human gate A.
- If price propagation is not Free in every storefront, do not release 1.2.
- If StoreKit fails after release, Garden and Classes 1–5 remain usable. Preserve all premium progress and ship a fix; do not silently grant every build-5 user full access and do not make the app paid again.
- If grandfathering fails for a genuine paid owner, treat it as a release-blocking defect before broad promotion. Capture the verified app transaction environment/original build without logging personal purchase data.
- Never delete the IAP to repair metadata. Its product ID cannot be reused.

## 15. Definition of done

Implementation is complete only when all of the following are true:

- Garden is unlimited and free; Flower Show qualifies after the first Garden win.
- Classes 1–5 are fully playable/replayable without purchase.
- Every path into Class 6+ and Circuit is defended below the UI.
- Verified production paid owners from builds 1–4 get full access; sandbox `1.0` does not.
- Purchase, cancellation, pending, failure, restore, refund/revoke and offline/relaunch behaviour have recorded evidence.
- No existing Garden or Flower Show save is lost or rewritten by entitlement state.
- Purchase UI uses the exact copy and live localized price and meets accessibility/layout checks.
- The non-consumable exists with the exact immutable ID, price, localisations, availability and review assets.
- Version 1.2 build 5 is processed in TestFlight and staged with the IAP, metadata and refreshed screenshots.
- `asc validate`, all current tests and the physical-iPhone helper pass, or every genuine limitation is named precisely.
- App Review submission, live price activation and production release remain with Tom.
- `FREEMIUM_FLOWER_SHOW_IMPLEMENTATION_REPORT.md` contains reproducible evidence and the final human checklist.

## 16. Apple references

- [Supporting a paid-to-free business-model change with AppTransaction](https://developer.apple.com/documentation/storekit/supporting-business-model-changes-by-using-the-app-transaction)
- [AppTransaction.originalAppVersion](https://developer.apple.com/documentation/storekit/apptransaction/originalappversion)
- [Transaction.currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [Testing purchases with Xcode, sandbox and TestFlight](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox)
- [Create a consumable or non-consumable IAP](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/)
- [Submit the first non-consumable with a new app version](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/)
- [IAP metadata and review screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)
- [App price configuration](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/)
- [Current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
