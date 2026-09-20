# Ringbloom PostHog analytics

Source contract: schema version 2, implemented on 13 September 2026 for TOM-572. Live v2 ingestion and saved decision insights require separate verification in EU project 261844; the 31 August 2026 debug-ingestion check covered the earlier schema only.

## Project and privacy

- [Ringbloom EU project](https://eu.posthog.com/project/261844/home); [existing product and paywall dashboard](https://eu.posthog.com/project/261844/dashboard/924385). Reject query results and URLs for project 261427.
- The public client token comes from Configuration/PostHog.xcconfig. Do not put it in logs or documentation. AppsFlyer remains the install attribution and purchase-postback provider.
- Explicit events include analytics_schema_version: 2, app_version, build_number, build_configuration, platform: ios, product: ringbloom, session_id, distribution_environment, and analytics_data_tier. Callers cannot override these common fields.
- PostHog automatic application lifecycle events remain on as transport telemetry. Automatic screen capture, element interactions, session replay, surveys, default person properties and identify are off. $geoip_disable = true is added before upload.
- Never send board contents, move sequences, raw errors, filesystem paths, save backups, free text, names, emails, account details, price or revenue, StoreKit product or transaction identifiers. Attempt and session IDs are anonymous random UUIDs, not account IDs.

## Routing and decision eligibility

The resolver uses a verified StoreKit AppTransaction.environment first, then Debug build status and the receipt name (sandboxReceipt or receipt). A missing or unrecognised release receipt is unknown. Distribution environment values are production, sandbox, xcode and unknown.

| Situation | Collection and analytics_data_tier |
|---|---|
| Verified or receipt-fallback production Release | Collected as production. |
| Release with unknown environment | Collected as unknown; report as a coverage gap. |
| Normal Debug, Xcode, sandbox/TestFlight or deterministic launch | Local only; no remote capture. |
| Explicit verification with RINGBLOOM_ANALYTICS_TEST_INGESTION=1 | Collected in existing EU project 261844 as test; session IDs begin test-. Hosted unit tests remain disabled. |

Decision insights must filter analytics_schema_version = 2 and analytics_data_tier = production. Exclude test and unknown tiers from activation, retention and purchase denominators; show unknown separately to expose coverage. There is no account system, so there is no known-account filter. A fresh local progress record is a measurement cohort, not proof of a new install or acquisition.

The UI-test launch helper passes the opt-in to the app only when the test-runner process has that exact environment variable set to 1. The narrow test testExplicitAnalyticsIngestionFreshGardenWin starts a fresh in-memory progress record and plays the real deterministic Garden engine to a result, generating real lifecycle events. Normal UI tests remain remote-disabled. A plain shell variable on xcodebuild was not observed in its UI runner. The verified route is the copied xctestrun file at delivery-2026-09-13/growth/DerivedData/Build/Products/Ringbloom_analytics-test.xctestrun, which sets the flag only for the UI runner. Run xcodebuild test-without-building against that file and only that test; confirm the RINGBLOOM_ANALYTICS_TEST_OPT_IN_FORWARDED log marker. Regenerate the copied xctestrun after a clean build. Do not use the frozen 1.5.1(10) reliability archive as v2 evidence.

## Identity, persistence and cohort

Session ID is one UUID per process, regenerated on relaunch. App session started fires once per process. App foregrounded fires once at its first active scene and again after each actual background-to-active return, retaining the same session ID if the process survives; inactive overlays and repeated active notifications do not count. A Garden attempt ID is saved with its active Garden engine; a Flower Show attempt ID is the engine's existing persisted UUID. Resume keeps the ID and emits attempt_resumed once per process, with resume_source home, class_book, rules or relaunch. A deliberate restart or replacement emits attempt_abandoned for the old ID and attempt_started for the new one. Termination does not infer abandonment or finish. An upgraded active Garden without an ID receives one at its first successful save, labelled attempt_id_origin: migrated_active_save; it emits resume, not start.

Analytics progress is a versioned marker stored in the TOM-571 protected GameProgress record. A genuinely empty local record begins fresh_instrumented_progress; an existing, migrated, recovered or incompatible marker is conservatively existing_progress. On the first fresh-v2 Garden start only, attempt_started has first_eligible_start: true and milestone_basis: fresh_instrumented_progress. All later, resumed, restarted and existing-progress starts have first_eligible_start: false; their basis remains explicit. The true marker is persisted before the event is sent. First bloom and first Garden 1 win are prospective and fire once only for the fresh basis. No earlier win is backfilled. TOM-571 recovery merges markers conservatively, so a recovered old record cannot become fresh by accident.

Attempt lifecycle and milestone events are queued until a successful progress save. A transient failure keeps them in memory for the next save or retry and emits progress_save_failed with a closed reason code; successful recovery emits progress_save_recovered. A process crash between the durable marker write and network delivery can undercount an event. PostHog delivery is not a transactional outbox, so dashboard counts remain descriptive and must not be treated as exact financial or acquisition records.

## Event contract

Every event below also has the common schema fields. Attempt and gameplay milestones carry attempt_id, mode, attempt_kind, garden or class_number, and access_state (checking, sample, legacy_paid_app, store_purchase). Attempt kind is garden, campaign, replay or circuit. Event ID is supplied on lifecycle and milestone events for query deduplication; it is not an identity or transaction ID.

| Event | Additional properties and meaning |
|---|---|
| app_session_started | launch_kind, safe progress_load_reason_code, analytics_eligibility; once per process, not acquisition. |
| app_foregrounded | foreground_reason: cold_launch or return_from_background, foreground_index increasing within the process, stable session_id and distinct event_id; cold first activation and real background returns only. Use for return/retention. |
| attempt_started | attempt_id_origin: new, milestone_basis, first_eligible_start; once when a new playable attempt is saved. |
| attempt_resumed | attempt_id_origin, resume_source; first successful resume of an ID per process. |
| attempt_abandoned | abandon_reason: restart or replaced; explicit replacement only. |
| attempt_finished | outcome: won or lost, turns, blooms, score, moves remaining, hint and undo booleans, and Flower Show rating; terminal once. A Flower Show loss remains reversible while Undo is available. |
| first_bloom_achieved | bloom_count_after_turn, milestone_basis: fresh_instrumented_progress; first eligible bloom only. |
| first_garden_win_achieved | garden: 1, fresh milestone basis; first eligible Garden 1 win only. |
| tutorial_completed | Garden, attempt_id, tutorial_variant: standard; after the tutorial start action. |
| sample_access_unlocked | Garden attempt, access_state: sample, unlock_reason: qualifying_garden_win; first qualifying committed win when actual access state is sample. |
| flower_show_milestone | milestone: class_completed, class_5_completed, grand_champion or circuit_class_completed; rating; only after a committed result, with the engine attempt ID. |
| review_request_eligible | A committed terminal Garden or Flower Show result meeting the persisted milestones, two observed process sessions, current-version and 120-day gates. Queued until the result save succeeds. Includes successful_garden_completions, meaningful_session_count (two), and closed request_reason: garden_established_use, garden_to_flower_show or established_circuit. Class 5 purchase handoff and replay results are excluded. Eligibility can recur after a cancelled natural-break delay; this does not mean a request was made. |
| review_request_attempted | A settled Garden or committed Flower Show result after the attempt marker has been saved, immediately before the discretionary StoreKit request. Carries the same closed request_reason and counts. It does not mean a prompt was displayed or a review was submitted. |
| rating_link_tapped | Voluntary Home/Settings utility tap with destination: app_store_review and screen: home. The fixed link is `https://apps.apple.com/app/id6789952808?action=write-review`; this event does not establish that the App Store opened or a rating was given. |
| purchase_outcome | Paywall context, outcome: success, pending, cancelled, failed or disabled; access before and after. Success means the direct StoreKit response met the local verified-new qualification at that time; restore and generic unlocks do not count. It remains a UI outcome and is not the accepted conversion metric. |
| purchase_verified_new | Store boundary only: proven local verified StoreKit purchase, including later approval of a locally pending purchase. Closed `source`: direct_purchase or pending_approved; `environment`: production, sandbox, xcode or unknown; `money_status`: positive, zero or unavailable. It contains no price, currency, product, receipt, date or transaction ID and is emitted once even if a later copy supplies money. Use `money_status = positive` only for a verified-payer proxy; unavailable can undercount that proxy. |
| restore_outcome | Paywall context, outcome: restored, no_entitlement or failed; access before and after; separate from purchase. |
| paywall_unlocked | Paywall context, unlock_source: purchase, restore or legacy; state transition only, never a purchase conversion. |
| progress_load_outcome, progress_save_failed, progress_save_recovered | Safe reason_code, Circuit cursor and save revision; failure and recovery also include save_health: pending, blocked or saved. No raw error or path. |
| flower_show_share_intent | Explicit post-result share tap only. Carries class_number, attempt_kind, rating, milestone and is_circuit. It is recorded after the queued review opportunity is abandoned and before the native sheet opens. It contains no attempt ID, board, recipient, address, destination account or purchase data. |
| flower_show_share_completed | Only the native activity-controller callback with completed = true. It uses the same bounded result fields as intent. Cancellation, dismissal and a missing callback produce no completion event. Neither event means a recipient viewed the card, installed Ringbloom or purchased. |
| feedback_opened | The anonymous feedback form was opened. Carries only the closed source: home, settings or after_session. |
| feedback_nudge_shown | A post-result feedback invitation became visible after the persisted eligibility and cooldown checks. Carries source: after_session. |
| feedback_nudge_dismissed | The visible invitation was dismissed with reason: not_now and source: after_session. It does not mean the permanent Home or Settings entry points are unavailable. |
| feedback_send_attempted, feedback_send_succeeded, feedback_send_failed | FeedbackKit transport milestones with the closed source only. Never attach the message, category, submission ID or raw error. Success records transport acceptance, not a promised reply or product commitment. |

The v1 navigation, control and gameplay events (screen_viewed, button_tapped, game_started, game_finished, game_resumed, turn_completed, ring_selected and related actions) remain for continuity. Attempt-scoped compatibility events carry attempt_id where available. Do not use them as the v2 attempt funnel. Paywall consideration events (paywall_requested/viewed/action/session_ended, purchase_started, restore_started, product_load_outcome and purchase_outcome) remain descriptive UI telemetry. Use `purchase_verified_new` for accepted purchase conversion; if naming verified payers, filter it to `money_status = positive`. Never substitute paywall_unlocked, restore_outcome or purchase_outcome.

## Insight definitions and verification boundary

The TOM-572 dashboard should use eligible first Garden starts (attempt_started, mode = garden, first_eligible_start = true) as the first-start denominator, then first bloom, first Garden 1 win, sample entry and Class 5 completion. Sample entry means a real attempt_started with mode = flower_show, attempt_kind = campaign and access_state = sample; sample_access_unlocked is only the opportunity to play. First-bloom and first-win events are emitted only for fresh instrumented progress; the eligible first-start marker anchors the cohort; Flower Show milestones can occur later in another session. Use PostHog's anonymous installation identity for person-level funnels and the event or attempt IDs for separate attempt analysis. Do not name the denominator new users or acquisition. Deduplicate on event_id where the query supports it. The final purchase step depends on TOM-573's store-boundary purchase_verified_new event for delayed approvals and durable deduplication; direct purchase_outcome success is provisional and must not be used as accepted conversion.

For D1/D7 return, include only cohorts old enough to have matured for the window; use a real subsequent app_foregrounded on another day and report counts and eligible denominators. A surviving process can foreground again without another app_session_started. Exclude inactive overlays and SDK automatic Application Opened telemetry from the v2 return definition. Save health should show failed attempts and subsequently recovered saves, broken down by safe reason and health, with unknown tier separately. Small samples remain descriptive.

## Achievement sharing

The optional native share sheet contains a generated card with the committed Flower Show result and the fixed App Store listing URL `https://apps.apple.com/app/id6789952808`. The direct store URL has no campaign parameter, referrer token or attributable install join. Share intent and a system-reported completion are engagement signals only; they must not be joined to AppsFlyer install attribution, purchase conversion or recipient behaviour. A share tap first abandons the queued discretionary review opportunity, and sheet dismissal does not requeue it.

Source-side tests and simulator results are in [the TOM-572 handover](delivery-2026-09-13/growth/TOM-572-HANDOVER.md). The owner completed live opt-in ingestion and read back all five saved decision insights in EU project 261844/dashboard 924385 on 13 September. The final six-step test funnel is 1→1→1→1→1→1; production filters exclude that traffic and currently return no eligible cohort. Evidence: delivery-2026-09-13/growth/posthog-complete-funnel-verification.json. The sample flow uses seeded real gameplay and an explicitly guarded synthetic transaction with unavailable money; it is not a paid purchase or acquisition. Insight5913573 (6jAADWGZ) contains the final ordered 14-day production funnel. The previous 31 August 2026 debug screen_viewed/Application Installed sighting verifies only the original app-to-EU path, not this v2 contract.
