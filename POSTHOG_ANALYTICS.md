# Ringbloom PostHog analytics

Last verified against PostHog iOS SDK 3.59.3 and the live EU Cloud project on 31 August 2026.

## Project

- Project: **Ringbloom**
- Project ID: `261844`
- Region: **EU Cloud**
- [Project home](https://eu.posthog.com/project/261844/home)
- [Product and paywall dashboard](https://eu.posthog.com/project/261844/dashboard/924385)
- The public client project token is supplied through `Configuration/PostHog.xcconfig`. Do not copy it into this document or log it in tickets.

PostHog is Ringbloom's product analytics service. AppsFlyer remains the mobile attribution provider for installs, campaign measurement and its deduplicated purchase postback.

## What is implemented

`ProductAnalytics` configures PostHog once at app launch and adds these properties to every explicit event:

- `analytics_schema_version`
- `app_version`
- `build_number`
- `build_configuration` (`debug` or `release`)
- `platform` (`ios`)
- `product` (`ringbloom`)

The SDK's automatic application lifecycle events remain enabled. Automatic screen capture, element autocapture, session replay, surveys and default person-property updates are disabled. Ringbloom does not call `identify`, so PostHog uses an anonymous installation identifier rather than an account, email address or name.

Every event is amended before upload with `$geoip_disable = true`, preventing PostHog's server-side GeoIP enrichment from adding city, postcode, coordinates or other derived location fields.

Analytics is disabled for screenshot launches, UI-test launches and the hosted unit-test bundle. Debug traffic is retained only to verify the integration; filter to `build_configuration = release` before using the data for product decisions.

## Event schema

### Navigation and explicit controls

| Event | Important properties | Product question |
|---|---|---|
| `screen_viewed` | `screen`, progress and access state | Which areas are reached and where do people stop? |
| `button_tapped` | `button`, `screen`, progress and access state | Which explicit controls are used most or ignored? |
| `tutorial_completed` | `garden` | Do people complete the first explanation? |
| `class_selected` | `class_number` | Which Flower Show classes are chosen or replayed? |
| `locked_content_tapped` | `content`, `class_number`, `screen` | What locked content creates purchase intent? |

### Gameplay

| Event | Important properties |
|---|---|
| `game_started` | `mode`, `start_type`, `garden` or `class_number` |
| `ring_selected` | `mode`, `ring`, current progression |
| `turn_completed` | `ring`, `direction`, `turn_number`, `bloom_count`, `combo`, `points`, `score`, `moves_remaining`, `did_reshuffle` |
| `hint_requested` | `hints_remaining_before`, `hint_already_visible`, current game context |
| `undo_used` | current game context |
| `game_paused`, `game_resumed`, `game_left_to_home`, `game_restarted` | current game context and source where relevant |
| `game_finished` | `outcome`, `score`, `blooms`, `best_streak`, `moves_remaining`, current game context |

The gameplay context includes mode, Garden or class where relevant, phase, score, moves remaining, bloom target/progress and Flower Show access. It does not include the board layout or a replay of individual gestures.

### Paywall consideration and purchase

| Event | Important properties | Product question |
|---|---|---|
| `paywall_requested` | `origin`, optional `target_class`, progress and access state | What created purchase intent? |
| `paywall_viewed` | origin, target, progress, product and purchase state | Did the paywall actually become visible and in what state? |
| `paywall_action` | `action`, `seconds_visible`, paywall context | What did the person choose, and how long did they consider it first? |
| `paywall_session_ended` | `last_action`, `seconds_visible`, `unlocked`, paywall context | How did each consideration session end? |
| `purchase_started`, `purchase_outcome` | paywall context, `outcome` | Did intent become a purchase attempt and how did it finish? |
| `restore_started`, `restore_outcome` | paywall context, `outcome` | Are people trying to recover access, and does restoration work? |
| `product_load_outcome` | paywall context, `outcome` | Is product loading preventing a purchase? |
| `paywall_unlocked` | paywall context | Did the paywall session produce full access? |

Paywall context includes `origin`, optional `target_class`, free and campaign classes completed, `target_is_playable`, `product_state` and `purchase_state`. PostHog does not receive StoreKit transaction IDs, the local board state, card details or purchase revenue.

## Dashboard views

The **Ringbloom Product & Paywall** dashboard contains:

1. **Paywall entry points** — `paywall_requested`, broken down by `origin`.
2. **Average paywall consideration time** — average `seconds_visible` on `paywall_session_ended`.
3. **Paywall choices** — `paywall_action`, broken down by `action`.
4. **Top button clicks** — `button_tapped`, broken down by `button`.
5. **Paywall consideration to unlock** — `paywall_requested` → `paywall_viewed` → `purchase_started` → `paywall_unlocked`.

The views are deliberately defined before production events exist, so they will populate when an instrumented release starts receiving traffic. Segment the paywall views by `origin`, `target_class`, `free_classes_completed`, `product_state` and `app_version` when investigating a change.

## Privacy and release gate

- Session replay, automatic element capture, surveys and user identification are disabled.
- GeoIP enrichment is disabled for every event before upload.
- Do not add names, email addresses, transaction IDs, free text or board contents to event properties.
- The PostHog project is hosted in EU Cloud.
- The compatibility privacy copy in `support-site/privacy/index.html` and the canonical policy at `https://weevolve.app/ringbloom/privacy/` describe PostHog. The canonical policy was deployed and verified live on 31 August 2026.
- App Store Connect App Privacy was verified in the signed-in web UI on 31 August 2026. The published declaration already covers Product Interaction for Analytics, links it to the device/installation identifier and declares that it is not used for tracking. No App Privacy change or republication was required for PostHog.
- Tom retains the final App Store attestation and submission actions. Do not submit the app for review as part of analytics setup.

## Verification

On 31 August 2026 a normal debug simulator launch produced `screen_viewed` and `Application Installed` in the Ringbloom project's PostHog activity feed using the `posthog-ios` library. That proves app → EU ingestion → project visibility end to end. The dashboard's paywall and button views will remain empty until those actions occur in an instrumented build.
