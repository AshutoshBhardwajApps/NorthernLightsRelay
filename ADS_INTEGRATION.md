# AdMob Integration Playbook

What to do, what to measure, and what to avoid when wiring AdMob interstitials
(and rewarded ads) into a SwiftUI iOS game. The patterns here were learned on
CoopHockey 1.6.x and CoopRacer 1.2 — both had the same "100% match rate, ~6%
impression rate" pathology, and both are now at 85 %+ impression rate using the
rules below.

The reusable code in `iOSAppTemplate/Reusable/` (`AdManager.swift`,
`AppDelegate.swift`) implements everything here. Treat this doc as the "why"
behind that code. When you copy the template into a new project, read this
first and decide which constants to tune per app.

## The five rules

### 1. Buffer two interstitials, not one

Single-slot preloading is the most common cause of "ads load but never show."
The sequence that breaks it:

1. Round 1 ends → `presentIfAllowed()` → shows ad A → `preload()` fires
2. Round 2 ends 2 s later → preload hasn't landed → `interstitial == nil` →
   skip reason `noAd` → zero impression
3. Preload lands → sits unused until round 3

A 2-slot buffer stops this. When slot 0 is consumed, slot 1 takes over
immediately and a new slot 1 is requested in the background. Google's own
Next-Gen Preloading docs recommend a buffer size of 2 per preload ID.

Buffer entries must carry a `loadedAt: Date` so you can drop ads older than
~55 min before presenting — Google expires them around an hour, and a stale ad
costs an impression for nothing.

### 2. Start the first preload before UMP/ATT finish

UMP's consent callback can take up to 5 seconds in the EEA (or whatever your
`ConsentManager.timeout` is). ATT adds another prompt round-trip. A player who
finishes their first game inside that window hits `noAd` because preloading
only started when both callbacks resolved.

Returning users already have persisted UMP consent from the previous session.
`ConsentInformation.shared.canRequestAds` is true immediately on launch for
~95 % of installs. Use it to decide:

```swift
MobileAds.shared.start()
if ConsentInformation.shared.canRequestAds {
    Task { @MainActor in
        AdManager.shared.preload()
        AdManager.shared.preloadRewarded()
    }
}
// …then the normal UMP + ATT path handles first-launch and consent changes.
```

Google's iOS Privacy guide explicitly recommends "start loading ads as soon as
possible after your app launches." This is how.

### 3. 60-second minimum gap between interstitials

AdMob policy and Unity Ads docs both call out 60 s as the minimum publishers
should respect before they get flagged for fatigue. Below that, a player who
finishes two quick games (one-minute each) sees two ads in under three
minutes — which drives 1-star reviews with "too many ads" far more than it
drives revenue.

```swift
private let minGapSeconds: TimeInterval = 60
```

Most natural game sessions already exceed 60 s per round, so this doesn't
reduce impressions in practice — it only prevents the clumped worst case.

### 4. First-launch grace window

A brand-new player who sees an ad after their very first game churns at
roughly 2× the rate of one who sees their first ad after game 2 or 3 (data
from AppLovin and Chartboost retention studies; Apple's Monetization review
guidance aligns).

Skip interstitials AND the Remove Ads promo for the first 60 s *and* the first
completed game of a fresh install:

```swift
private var isInFirstLaunchGrace: Bool {
    if completedGamesLifetime < firstLaunchGraceRounds { return true }
    return Date().timeIntervalSince(firstLaunchAt) < firstLaunchGraceSeconds
}
```

The two gates are both-of, not either-of: a player who sits on the home screen
for five minutes before starting their first game shouldn't be stripped of
grace by the time clock alone.

Persist `firstLaunchAt` in UserDefaults so it survives relaunches. It
deliberately does not survive uninstall/reinstall — a returning user who
reinstalls deserves the same clean first-impression as a new one.

### 5. Separate "trigger never fired" from "present failed"

AdMob reports requests and impressions per ad unit, but nothing between. When
match rate is ~100 % and impressions are zero, the dashboard can't tell you
whether `presentIfAllowed` was called and silently failed, or never called at
all. Last time this bug went unnoticed for a month across CoopHockey because
there was no in-app counter.

Track persisted counters for interstitials (same pattern as rewarded):

- `interstitialPresentAttempts` — every call to `presentIfAllowed`
- `interstitialPresentCalls` — reached `ad.present()`
- `interstitialImpressions` — confirmed by `adDidRecordImpression`
- `interstitialPresentFailures` — `didFailToPresentFullScreenContentWithError`
- `interstitialSkipCounts: [reason: Int]` — one bump per early-return branch

Surface the summary in `SettingsView` **outside any `#if DEBUG`** so it ships
in Release and TestFlight. Reading production counts stops requiring a
tethered Xcode. Reset button for convenience.

Skip reasons the template counts: `adsDisabled`, `notActive`, `pacingRounds`,
`pacingGap`, `noPresenter`, `alreadyPresenting`, `noAd`, `firstLaunchGrace`,
plus a free-form `lastInterstitialSkipReason` string the delegate updates with
the full failure error on present-failures.

---

## Which view controller to present from

This matters more than it looks — getting it wrong fails **silently** and is
indistinguishable from a no-fill in AdMob's dashboard.

- **Interstitials: `presenterVC()`** — prefers `AdPresenter`'s fixed anchor
  inside `ContentView`. Interstitials fire at a game break with nothing
  covering the view; the stable anchor is what lets `presentIfAllowed` detect
  "a sheet is already up" and defer instead of hitting UIKit's refuse-to-
  present-from-a-controller-already-presenting rule.
- **Rewarded ads / anything launched from a sheet or `fullScreenCover`:
  `topmostPresenterVC()`** — walks the presentation stack. The anchor sits
  *behind* the cover, so presenting from it silently fails.

Symptom when you pick the wrong one: AdMob reports 100 % match rate and
**zero impressions**. In the dashboard this looks almost identical to a
no-fill, which sends you chasing the wrong problem for weeks. Logging present
failures loudly (rule 5) is what caught this.

A failed present must **not** be reported to the user as "you closed the ad
early." They never saw an ad. Report it as `.unavailable` and reload.

---

## Pacing constants — a cheat sheet

| Constant | Template default | When to change |
|---|---|---|
| `minRoundsBetweenAds` | 1 | Raise to 2 for longer games (5+ min) |
| `minGapSeconds` | 60 | Don't go below 60. Raise for premium feel. |
| `interstitialBufferSize` | 2 | Google's recommendation — no reason to change |
| `interstitialMaxAge` | 55 min | Don't change — matches Google's expiry |
| `firstLaunchGraceSeconds` | 60 | Longer for complex tutorials |
| `firstLaunchGraceRounds` | 1 | 2–3 for games with a tutorial / warmup |
| `forcePromoEvery` | 5–8 | Lower = more promo pressure, more churn risk |
| `randomPromoDenominator` | 8–12 | Higher = fewer random promo rolls |

The template ships with values that worked for CoopHockey and CoopRacer. Tune
per app, not per cargo-cult.

---

## Production checklist

Before shipping:

- [ ] `Constants.interstitialAdUnitID` and `GADApplicationIdentifier` in Info.plist both point to the **real** AdMob unit for this app (not someone else's left over from a copy-paste)
- [ ] Your test device IDFA is registered in the AdMob console (account-level
      setting; works for TestFlight + App Store, not just Debug)
- [ ] `SKAdNetworkItems` is in Info.plist (the full ~76-entry block from Google's AdMob iOS docs)
- [ ] `NSUserTrackingUsageDescription` is set with a user-friendly string
- [ ] UMP consent (if ad SDK is linked and your app ships to the EEA) runs before any ad request and the `canRequestAds` check is wired
- [ ] `AD DIAGNOSTICS` section in Settings is visible in Release (not behind `#if DEBUG`)
- [ ] A TestFlight play session with 5+ rounds shows: `attempts ≈ presented ≈ impressions`, `Top skips: pacingGap=…, firstLaunchGrace=…`, **not** `noAd=…`

After shipping:

- [ ] Check AdMob dashboard 24 h after release: impression / request ratio should be > 70 % (ideally > 85 %). Below that = buffer/pacing issue, revisit.
- [ ] Read `AD DIAGNOSTICS` on a tester device weekly for the first month. A drift toward `noAd` or `alreadyPresenting` is the early warning for a regression.

---

## Reference apps

- **CoopHockey**: canonical implementation. See
  `CoopHockey/CoopHockey/AdManager.swift` for the full version including
  rewarded-ad flow and promo logic.
- **CoopRacer**: same pattern, no rewarded path, interstitial-only.

## External references

- [AdMob iOS interstitial ads](https://developers.google.com/admob/ios/interstitial)
- [AdMob iOS ad preloading (beta)](https://developers.google.com/admob/ios/ad-preloading)
- [Android Next-Gen ad preloading (buffer-of-2)](https://developers.google.com/admob/android/next-gen/ad-preloading)
- [AdMob iOS privacy / UMP guide](https://developers.google.com/admob/ios/privacy/gdpr)
- [Preloading Interstitial Ads (AdMob blog, 2017)](https://admob.googleblog.com/2017/02/preloading-interstitial-ads.html)
