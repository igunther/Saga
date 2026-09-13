# App update checks

`SagaUpdates` is an opt-in product for iOS 18+. Its core also builds for macOS 15+ when the package declares that platform. It checks the public App Store listing and reports whether the installed marketing version is older. The host app owns Settings, links, nudge policy, and sheet presentation. The package never presents UI or opens the App Store.

## Architecture and data flow

`StoreKitRegionSource` in Data reads `Storefront.current` and `Storefront.updates`. Foundation's ISO region data converts StoreKit's ISO 3166-1 alpha-3 code to the lookup API's alpha-2 country code; unknown or absent codes use the configured fallback. Neither app language nor device locale participates. The source is injectable for isolated tests.

`AppStoreLookup` in Data calls Apple's ID-based iTunes Lookup API. It validates the result ID, response shape, and HTTPS App Store link. `SagaUpdateRepository` maps the lookup response to a repository model, coalesces simultaneous requests, and stores the latest successful result, check time, retry time, and last reported version through a Data-owned `UserDefaults` store. `SagaUpdateService` maps that model to a Domain release, compares dotted numeric marketing versions, and publishes status. `SagaUpdateMonitoringModifier` only forwards the host app's scene phase to the service. `SagaUpdateComposition` wires the default implementations.

The cache key includes App Store ID and country code. Switching storefronts replaces the published status with that region's persisted cache (or `.unknown`) and checks when due. An old region's result stays in its cache but cannot overwrite current status. Returning to a region reuses its check/retry cadence. `newVersions()` deduplicates persistently per App Store ID and country: the same version may emit once in each region, but not again when returning. An in-flight result superseded by a region switch emits no event. Active monitoring uses one storefront observer, cancelled when inactive.

A successful result is reused for `checkInterval` (24 hours by default). After a failed request, the next attempt waits for `retryInterval` (one hour by default); the last successful result remains available with `lastError`. `refresh(force: true)` bypasses these limits for an explicit user request. Cancellation does not publish an error state. The lookup API may have a propagation delay after a release and results depend on storefront availability.

## Host integration

Link the `SagaUpdates` product and create one long-lived service at the app composition root:

```swift
import SagaUpdates

let updates = SagaUpdateService(configuration: .init(
    appStoreID: 123456789,
    installedVersion: installedMarketingVersion,
    countryCode: "NO"
))
```

For automatic App Store-region selection (for example, in SkiltVis with Norway as fallback):

```swift
let updates = SagaUpdateService(configuration: .init(
    appStoreID: 123456789, // Replace with SkiltVis's App Store ID.
    installedVersion: installedMarketingVersion,
    region: .automatic(fallbackCountryCode: "NO")
))
```

Pass the app's `CFBundleShortVersionString` as `installedMarketingVersion`, not its build number. The existing `countryCode: "NO"` initializer continues to pin the lookup to Norway regardless of StoreKit changes. Both explicit and fallback values are two-letter App Store country codes. In automatic mode, `configuration.countryCode` exposes the normalized fallback for legacy readers; `configuration.region` distinguishes the mode. Attach `.sagaUpdateMonitoring(updates)` once to a root view. Saga then checks when the app becomes active and maintains the interval while it remains open. The host app does not need a timer.

Read `await updates.snapshot()` for the latest persisted value or subscribe to `await updates.snapshots()` for a replayed state stream. A snapshot contains `release?.version`, `release?.storeURL`, `availability`, `checkedAt`, and `lastError`; Settings can show the last known version even when a later request fails. Subscribe to `await updates.newVersions()` before starting monitoring for a once-per-version event. The event is deliberately not replayed; hosts should also consult `snapshot()` when deciding whether a nudge is appropriate after launch. Persisting nudge dismissal and deciding when to show a SagaSheets sheet belong to the host app.

The version parser accepts nonnegative, dot-separated integer components such as `1`, `1.2`, and `1.2.3`. It compares components numerically and treats trailing zeroes as equal. Suffixes such as `-beta` are unsupported because public App Store marketing versions use numeric components. Invalid installed versions produce `SagaUpdateError.invalidInstalledVersion`; invalid store versions produce `invalidStoreResponse`.

## Optional iOS background refresh

Set `backgroundTaskIdentifier` in the configuration to opt in. The host app must enable the Background Modes **Background fetch** capability and include the same identifier in `BGTaskSchedulerPermittedIdentifiers`. Register a matching SwiftUI scene handler:

```swift
WindowGroup {
    RootView().sagaUpdateMonitoring(updates)
}
.backgroundTask(.appRefresh("com.example.app.update-check")) {
    await updates.performBackgroundRefresh()
}
```

Saga schedules the task when the app becomes active and reschedules it after the handler runs. The handler checks and updates stored state only; a host may show a sheet when the app is next active. iOS decides whether and when the task runs, so a daily background run is not guaranteed. The foreground cadence remains the reliable path. `scheduleBackgroundRefresh()` is also public if the host needs to retry a scheduling failure. This adapter is iOS-only; macOS uses active-app monitoring.

## Verification and limitations

`swift test --filter SagaUpdatesTests` covers version comparison, cache behavior, status, and error retention. Build the `SagaUpdates` scheme for iOS Simulator after iOS adapter changes. Tests use stub lookups and isolated preferences; they do not call Apple. No app can check an unpublished TestFlight build against a future App Store version using this public lookup. Apple's lookup is storefront-specific, so an unavailable listing reports `appUnavailable` rather than assuming the user is up to date.
