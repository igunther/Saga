# App-owned update reminders

`SagaUpdateReminderService` adds an optional, UI-independent reminder policy to
`SagaUpdates`. It evaluates a `SagaUpdateSnapshot`; it never fetches from Apple,
opens a URL, schedules notifications, or presents a view. Each app owns its copy,
design, placement, accessibility, and SagaSheets presentation.

Existing `SagaUpdateService`, `snapshots()`, `newVersions()`, and monitoring APIs
are unchanged. Existing consumers, including Skiltvis, can adopt reminders
incrementally.

## Two independent cadences

| Concern | Owner | Default |
| --- | --- | --- |
| Successful lookup cache | `SagaUpdateService` / lookup repository | 24 hours |
| Retry after lookup failure | `SagaUpdateService` / lookup repository | 1 hour |
| Repeat reminder for an already presented version | Reminder policy | 7 days |
| “Later” snooze for one version | Reminder policy | 7 days |
| Maximum age of a successful check used for a reminder | Reminder policy | 24 hours |

All reminder durations are configurable positive, finite `TimeInterval` values.
At exactly `maximumCheckAge`, a snapshot is stale. At exactly the end of the
reminder interval or snooze, that restriction expires. If both restrictions
apply, both must have expired. Choose `maximumCheckAge` alongside the configured
lookup interval; a stale snapshot needs a new successful lookup before prompting.

Eligibility requires `.updateAvailable`, a release with a valid numeric version,
no `lastError`, and a recent `checkedAt` that is not in the future. Unknown,
up-to-date, failed, malformed, and stale snapshots do not produce reminders.
The original snapshot remains available for Settings regardless of reminder policy.

## Composition

Create one long-lived update service and one reminder service at the host's
composition boundary, with the same App Store ID. Inject them into the host's
view model or wrap them in the app's own Domain service protocol.

```swift
import SagaUpdates

let updates = SagaUpdateService(
  configuration: SagaUpdateConfiguration(
    appStoreID: 123456789,
    installedVersion: installedMarketingVersion,
    region: .automatic(fallbackCountryCode: "NO")
  )
)

let reminders = SagaUpdateReminderService(
  appStoreID: 123456789,
  policy: SagaUpdateReminderPolicy(
    reminderInterval: 7 * 24 * 60 * 60,
    snoozeInterval: 7 * 24 * 60 * 60,
    maximumCheckAge: 24 * 60 * 60
  )
)
```

Keep `.sagaUpdateMonitoring(updates)` on the root view, or forward scene activity
to `updates.setActive(_:)` as before. The reminder service needs no scene modifier
or timer. Supply `storageSuiteName` for isolated preferences or a host-selected
suite, and an injected `now` closure for deterministic tests. Production uses
standard local preferences and the current date by default.

## Presentation flow

1. Observe `updates.snapshots()` in the host's view model. This includes the
   persisted initial snapshot; do not rely only on `newVersions()`.
2. When the app is active and ready, obtain the current snapshot and call
   `await reminders.reminder(for: snapshot)`.
3. If a release is returned, the host may present its custom card, banner, or
   SagaSheets sheet. Recheck host readiness and the latest snapshot after awaiting:
   onboarding, a purchase, editing, another sheet, or a storefront change may
   have occurred while evaluating.
4. Call `recordPresentation(of:)` when the UI actually appears, once per
   presentation. Merely discovering or evaluating a release does not consume it.
5. Forward user actions using the release that was actually presented:

```swift
// Evaluate from the host's view model when presentation is safe.
let snapshot = await updates.snapshot()
let candidate = await reminders.reminder(for: snapshot)
// Revalidate host state after the await; present candidate using the app's UI.

// The host's on-appear intent, forwarded through its view model.
await reminders.recordPresentation(of: presentedRelease)

// “Later”: persist the snooze, then dismiss the host's presentation.
await reminders.snooze(presentedRelease)

// “Ignore this version”: persist the choice, then dismiss.
await reminders.ignore(presentedRelease)
```

These are separate callbacks, not three actions to run together. A swipe dismissal
can simply retain the presentation interval already recorded, or the host can
explicitly treat it as “Later”. Opening the App Store does not prove installation;
record only the actual presentation and let the host open `presentedRelease.storeURL`.
On the next launch, construct `SagaUpdateService` using the installed marketing
version so a completed update produces `.upToDate`.

Serialize presentation decisions in the host's main-actor view model or Saga flow,
including across multiple scenes. `reminder(for:)` is a read, not an atomic claim:
two callers may receive the same eligible release before either records a
presentation. Set host presentation state before allowing another decision and
await recording before clearing that state. Reevaluate when the app becomes
active, when a snapshot changes, or when a previously blocked presentation becomes
safe. Long-lived cards can use a host-owned wake-up if exact snooze expiry matters;
the reminder service emits no timer or status stream of its own.

Settings should read the update snapshot directly and offer the product-page
action even during snooze or after ignore. Reminder policy controls automatic
nudges, not manual access. The host should also decide whether automatic reminders
are enabled for Dev/TestFlight builds and allow isolated previews of its design.

## Persistence and boundaries

The new Domain service owns eligibility, numeric version normalization, and timing
rules. `SagaUpdateReminderRepository` owns the history cache and persistence through
the existing Data-layer `UpdateCacheStoring` adapter. Actor isolation protects
mutable history. The Domain service never reads preferences directly.

History is local, keyed by App Store ID and normalized version, deliberately
independent of storefront. `2`, `2.0`, and `02.0.0` share history. A different
version has independent history; returning to an earlier version restores its
previous snooze/ignore state. Region changes therefore cannot bypass the user's
choice for the same version. Lookup results remain cached separately by region.

Each entry stores `lastPresentedAt`, `snoozedUntil`, and `isIgnored` under the
preferences key `SagaUpdates.Reminders.<appStoreID>`. Ignore persists for that
version until local preferences are removed. There is no iCloud synchronization or
change to a host app's backup/export format. Hosts integrating a preference suite
must decide whether their backup contract includes these preferences. Preferences
are best-effort local persistence, not a transactional cross-process store.

No migration of the old lookup cache is needed. Missing or unreadable reminder
history starts empty. Preserve one reminder owner per App Store ID and storage
suite; independent instances or processes do not synchronize their in-memory
copies. Old entries are retained; no automatic history pruning is performed.

`newVersions()` still means a once-per-version-and-region discovery event. It does
not mean the user saw a reminder, and its persistent deduplication does not affect
this new reminder history. Do not translate discovery events directly into
`recordPresentation(of:)`.

## Verification and limitations

`SagaUpdateReminderTests` uses fixed dates and isolated preferences, without
network requests or sleeps. It covers repeated evaluation, actual presentation,
restart persistence, interval and snooze boundaries, combined restrictions,
per-version and per-app isolation, equivalent versions, ignore, stale/future/missing
check times, unavailable/error/malformed snapshots, and post-installation status.

Run `swift test` and build `SagaUpdates` for iOS Simulator. The core supports the
package's iOS 18+ and macOS 15+ deployment targets. No UI or preview is added to the
package; host UI previews must use isolated snapshots and reminder dependencies.

This remains a best-effort reminder about a published listing, never a forced
update. The existing lookup does not expose minimum OS compatibility; hosts that
need a compatibility guarantee require an additional lookup/model capability.
This change does not integrate the policy into Skiltvis or BlendCellar or alter
their existing presentation behavior.
