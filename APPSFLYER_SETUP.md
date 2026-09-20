# Ringbloom AppsFlyer setup

The prior version is archived at `delivery-2026-09-13/growth/573/APPSFLYER_SETUP.pre-TOM-573-2026-09-13.md`. Its August TikTok setup record is retained below as dated evidence, not silently rewritten as current configuration.

## September 2026 delivery status

- The live App Store version is **1.5 (build 9)**. The separate **1.5.1 (build 10)** reliability candidate is uploaded and validated; its archive and destination readbacks are frozen under `delivery-2026-09-13/reliability/`. Growth changes are not uploaded.
- TOM-573 changes source-side purchase semantics only. They have no live AppsFlyer, Meta, TikTok, App Store Connect, credential, permission or partner-setting verification yet.
- The owner’s 13 September isolated-browser readback confirms the existing **Meta** AppsFlyer mapping: `af_app_opened` → `fb_mobile_activate_app` and `af_purchase` → `fb_mobile_purchase`, both for all media sources including organic with Values & revenue. Meta Advanced Data Sharing is enabled, Advanced Matching is disabled, seven-day click and 24-hour view-through are configured, and SKAN connection presence has not proved ingestion. See `delivery-2026-09-13/meta/TOM-580-LIVE-MAPPING.md` for the complete read-only evidence and limits.
- This document does not assert that any partner mapping is consent-compliant, receiving events, correctly deduplicating purchases, or measuring paid acquisition. Organic postbacks must not be counted as paid acquisition.
- Current App Privacy publication cannot be verified by API: the isolated App Store Connect browser was unauthenticated. Treat `metadata/privacy.json` as a draft. Do not blindly replace a currently published declaration; first obtain an authenticated readback, compare the live declaration with the intended disclosure, then let Tom perform any publication or attestation.

## Implemented in the app

- AppsFlyer is the sole mobile attribution SDK. PostHog is used separately for product analytics; see `POSTHOG_ANALYTICS.md`.
- The app uses the official `AppsFlyerLib-Strict` Swift Package Manager product at exact version 7.0.1. Strict mode removes IDFA collection and the AdSupport dependency.
- `RingbloomAppDelegate` initialises AppsFlyer once during `didFinishLaunchingWithOptions`. AppsFlyer then handles automatic install and session measurement.
- SKAdNetwork measurement is enabled in `AppsFlyerLibConfig.plist`. Ringbloom does not contain `SKAdNetworkItems`: Apple defines that list for source apps that display ads, and Ringbloom displays no ads. Do not copy a publisher-side ad-network list into this advertised app.
- A proven local, verified new purchase of `com.tommurton.ringbloom.flower_show` sends `af_purchase` with the StoreKit `Transaction.price` `Decimal` in its actual currency units, `Transaction.currency` ISO identifier, product ID and StoreKit transaction ID. The app never substitutes a fixed price or divides by 1,000. Local pending intent plus transaction dates distinguish a new local flow from restore/bootstrap ownership; family-shared, revoked, unverified and historic ownership never report revenue.
- Missing price or currency does not deny access and does not create a revenue event. It remains eligible for one later priced transaction copy. Reported IDs are persisted immediately before the SDK call, so duplicate updates and relaunches are at-most-once locally. This can undercount if the app terminates between that write and remote SDK delivery. A local pre-initialisation queue is flushed after AppsFlyer initialises; it is best-effort, not a transactional outbox.
- No ATT prompt, IDFA collection, TikTok SDK, customer user ID, hashed contact data, uninstall token or ad-revenue module is included.

## 1. Ringbloom app record in AppsFlyer

The account now contains the active iOS app `id6789952808`, named Ringbloom. It was created from **Settings → My Apps → Add app** using:

1. Choose **iOS, tvOS, MacOS** and **Available in store**.
2. Use `https://itunes.apple.com/gb/app/ringbloom/id6789952808`.
3. Currency **GBP** and timezone **Europe/London**. Currency becomes irreversible after cost or revenue is recorded.
4. The account holder’s child-directed-app declaration. Agents must not choose or change this legal declaration.

The local Dev Key is configured in the ignored `Configuration/AppsFlyer.local.xcconfig` using:

   ```xcconfig
   APPSFLYER_DEV_KEY = <account dev key>
   ```

Never add the real local file or Dev Key to source control. The tracked `Configuration/AppsFlyer.xcconfig` contains only the public App Store ID and an optional include of that ignored file, so a clean checkout still builds safely with AppsFlyer disabled.

## Historical August 2026 TikTok setup record — unreverified

The following TikTok sections record the 15 August setup and documentation review. They are not a statement of current partner configuration; obtain a fresh, read-only destination inspection before relying on them.

## 2. Configure SKAdNetwork in AppsFlyer

1. Select Ringbloom, then open **Settings → SKAN Conversion Studio**.
2. SKAN measurement is active. AppsFlyer must remain the only component updating conversion values.
3. The schema was updated on 15 August 2026 and AppsFlyer is analysing its first seven days of data until 22 August. Do not replace it before AppsFlyer’s recommended 15 September decision point unless a measured campaign need justifies the reset.
4. Do not add the TikTok SDK. AppsFlyer and TikTok document that their SKAN interoperation is configured in the two dashboards and requires no TikTok code in the app.

## 3. Connect TikTok for Business

The SAN connection was created on 15 August 2026 under the **Tom Murton Apps** TikTok ad account:

- App Store app: Ringbloom, `6789952808`
- Mobile measurement partner: AppsFlyer
- TikTok App ID: `7674247953074618376`
- Preferred connection method: Mobile measurement partner
- TikTok status: **Pending verification** until TikTok receives the first eligible AppsFlyer event

AppsFlyer’s **TikTok for Business – Advanced SRN** (`tiktokglobal_int`) integration is active with that TikTok App ID. The deprecated legacy `bytedanceglobal_int` integration is not used. Re-engagement remains off.

## 4. Install and purchase postbacks

The TikTok integration’s **Integration** tab was saved and read back with:

- Partner activation on.
- Install click-through lookback window at the AppsFlyer-recommended seven days.
- Install postbacks limited to **This partner only**.
- In-app event postbacks on, with only AppsFlyer `af_purchase` mapped to TikTok **Purchase**.
- Purchase **For users from** set to **This partner only**.
- Purchase **Including** set to **Values & revenue**, allowing the event's actual StoreKit transaction amount and currency to be sent when a qualifying `af_purchase` is delivered.
- Advanced Data Sharing, Advanced Matching, view-through attribution, reinstall attribution and re-engagement attribution off.

Do not enable broad Advanced Data Sharing or send events from all media sources in this no-ATT configuration. Reconsider that only with a documented campaign need plus a fresh privacy/ATT review. Partner-only attributed postbacks are the proportionate default.

## 5. Add Ringbloom to TikTok Ads Manager

1. Ringbloom is present in **Events Manager → Data sources** under ad account `7581139560365670401`; the App Store ID, AppsFlyer partner, SAN status and TikTok App ID were read back after creation.
2. When a campaign is required, create or edit an app-promotion campaign and select the Ringbloom data source. Do not accept TikTok’s anti-discrimination attestation or add billing information as part of measurement setup; Tom retains those actions.
3. For iOS 14+ campaigns, use the AppsFlyer SKAN schema. Do not upload a competing TikTok SDK schema.
4. Select install optimisation first. Switch to Purchase optimisation only after TikTok shows enough valid purchase events for the data source.

## 6. Test install and purchase attribution

1. Add the physical iPhone as an AppsFlyer test device using **Settings → Test Devices**, then open **SDK Integration Tests** for Ringbloom.
2. Use a dedicated disposable test installation for a clean-attribution check. Never delete or reinstall a partner or affected player's installation to force attribution; AppsFlyer reinstall windows and existing ownership can change the result.
3. Launch once and confirm AppsFlyer reports SDK 7.0.1, app ID `id6789952808`, an install and a session. The Strict SDK should show no IDFA.
4. Complete the non-consumable purchase with an Apple Sandbox/TestFlight account. Confirm one `af_purchase` event with the StoreKit-provided revenue and currency, the expected product ID and one transaction/order ID.
5. Retry the purchase path and use **Restore Purchases**. Confirm access restores but the AppsFlyer purchase count does not increase for the same StoreKit transaction.
6. In TikTok Events Manager diagnostics, confirm the mapped Purchase postback arrives with value and currency. A true paid-attribution test requires a TikTok campaign click on an eligible clean device; SKAN reporting can be delayed and should be checked separately from AppsFlyer’s real-time SDK test.

## 7. Privacy and release gate

- The Ringbloom privacy policy is now canonical at `https://weevolve.app/ringbloom/privacy/`; the old GitHub Pages URL remains as a compatibility copy for older links.
- Version 1.5 build 9 is live on the App Store. Version 1.5.1 build 10 is a separate uploaded reliability candidate; growth source is not uploaded. `metadata/privacy.json` is a local draft, not proof of the current App Store Connect declaration.
- Before any privacy publication, obtain an authenticated readback of the current App Store Connect declaration and compare it with the intended draft. Do not replace the published declaration blindly. Tom retains any save, publication and attestation.
- The staged App Store declaration covers coarse location, other technical data (including IDFV and anonymous installation identifiers), performance data, product interaction and purchase history; all are linked, used for the listed analytics/functionality/marketing purposes, and none is marked as tracking. **Advertising Device ID is not selected because the shipped strict configuration disables IDFA collection.**
- Tom must perform the App Store privacy publication and any associated attestation. Do not submit a build or app version as part of this setup.

## Official references

### 13 September purchase-boundary verification

TOM-573 passed 63 targeted regression cases and an explicit local StoreKit purchase test on iOS 26.0. The production StoreKit client returned a verified, non-revoked purchased transaction in the Xcode environment with `Decimal` 2.99 and currency GBP; a captured AppsFlyer logger received one matching monetary payload despite duplicate reporting. Evidence: `delivery-2026-09-13/growth/573/local-storekit-ios260-final.log`. This is local test evidence, not Apple Sandbox, AppsFlyer delivery or a Meta/TikTok postback. The iOS 26.5 test failed at StoreKit configuration with Code 3 before purchasing; its failed log is retained. No consent or partner settings changed.

- [Install AppsFlyer iOS SDK 7](https://dev.appsflyer.com/hc/docs/install-ios-sdk-7)
- [Initialise and start AppsFlyer iOS SDK 7](https://dev.appsflyer.com/hc/docs/integrate-ios-sdk-7)
- [AppsFlyer iOS in-app events and revenue](https://dev.appsflyer.com/hc/docs/in-app-events-ios)
- [AppsFlyer privacy manifest](https://support.appsflyer.com/hc/en-us/articles/21677433322641-Implement-Privacy-Manifest-in-your-app)
- [AppsFlyer App Store nutrition-label guidance](https://support.appsflyer.com/hc/en-us/articles/207032086-Preparing-for-the-App-Store-review-nutrition-labels)
- [TikTok for Business Advanced SRN setup](https://support.appsflyer.com/hc/en-us/articles/6722785184913-TikTok-for-Business-Advanced-SRN-integration-setup)
- [AppsFlyer and TikTok SKAN interoperation](https://support.appsflyer.com/hc/en-us/articles/360018499098-SKAN-interoperation-with-TikTok-for-Business)
- [TikTok: connect a new app with MMP-SAN](https://ads.tiktok.com/help/article/integrate-to-san-for-new-apps)
- [TikTok: generate and verify a TikTok App ID](https://ads.tiktok.com/help/article/how-to-generate-a-tiktok-app-id)
- [Apple’s `SKAdNetworkItems` definition](https://developer.apple.com/documentation/bundleresources/information-property-list/skadnetworkitems)
