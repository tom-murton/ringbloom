# App Review Notes — Ringbloom 1.4

Ringbloom is free to download. Garden and Flower Show Classes 1–5 are free. A single non-consumable in-app purchase, **Complete Flower Show**, unlocks Classes 6–30 and the Champion Circuit. No account, login, demo credentials, subscription, advertising, or special hardware is required.

## What changed in 1.4

Version 1.4 improves Flower Show access recovery and preserves existing Garden and Flower Show progress. It also adds clearer accessibility feedback across later classes. Ringbloom includes AppsFlyer’s Strict iOS SDK as its sole mobile attribution and measurement provider. AppsFlyer automatically measures installs and sessions; Ringbloom sends one idempotent `af_purchase` event after the verified £2.99 Complete Flower Show purchase. The SDK uses no IDFA and Ringbloom does not show an ATT prompt.

## Core review path

1. On first launch, tap **Play Garden 1**. The short **How to Bloom** explanation appears; tap **Begin**.
2. Garden 1 highlights one live first move for free. Follow the highlighted ring and direction to make the first bloom.
3. Select the Inner, Middle, or Outer ring, then use **Turn Left** / **Turn Right**. A short tangential swipe around a ring performs the same one-notch action.
4. Align the same colour and glyph across all three rings to bloom a spoke. Reach the bloom target before the move counter reaches zero. If moves run out, **Try Again** is immediately available.
5. After Garden 1 is won, Flower Show becomes available. Classes 1–5 are free and can be replayed from the Class Book.

## In-app purchase review path

1. Complete Flower Show Classes 1–5. The complete Class 5 result appears first; tap **Continue** to open the purchase screen.
2. Alternatively, open **Class Book** and tap any locked Class 6–30 tile.
3. The purchase screen is headed **CONTINUE THE SHOW** and shows the localised price. Tap **UNLOCK FOR £2.99** and complete the sandbox non-consumable purchase.
4. The success screen confirms that Classes 6–30 and the Champion Circuit are ready. **Restore Purchases** is available on the purchase screen and no account is required.
5. Customers who acquired paid production builds 1–4 receive full access automatically through a verified production app transaction. This legacy path intentionally does not trigger in TestFlight/sandbox, where Apple reports original app version 1.0.

## Flower Show review path

Flower Show contains 30 deterministic judged classes, followed by the endless Champion Circuit from Class 31. **Ring Harmony** begins at Class 1, **Unbroken** at Class 6, **Bindweed** at Class 11 and **Twin Bloom** at Class 16. Each class offers one **Hint** and one exact **Undo**. Class progress and an active class are stored separately from Garden progress and resume after relaunch.

## Pause, save, and exact resume

During a playing Garden or Flower Show class, make at least one move and tap the pause button at the top-left. Tap **Save & Home**, then tap **Resume** on Home. The board, selected ring, score, moves, bloom progress, current chain and remaining hints resume from the saved state.

## Accessibility, audio, and data

Sound and haptics are optional and can be switched off independently. Gameplay remains understandable without either. Petal colours are paired with distinct glyphs; VoiceOver, Larger Text layouts, Increased Contrast and Reduce Motion are supported.

All game state and preferences are stored locally on-device. Ringbloom has no login, account or advertising system and makes no network request for gameplay. Network access is used for Apple StoreKit purchase/restore operations and AppsFlyer’s privacy-preserving install, session and purchase measurement. AppsFlyer is the sole mobile attribution/measurement provider; no TikTok SDK is included. Full details are in the linked privacy policy.

App Review contact: Tom Murton · shopping@tommurton.com · +447957357194.
