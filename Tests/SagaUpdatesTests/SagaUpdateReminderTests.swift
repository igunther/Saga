import Foundation
import Testing

@testable import SagaUpdates

private let reminderTestDate = Date(timeIntervalSince1970: 1_000_000)

private struct ReminderFixture {
  let suiteName = "SagaUpdateReminderTests.\(UUID())"

  func service(
    at date: Date = reminderTestDate,
    appStoreID: Int = 123,
    policy: SagaUpdateReminderPolicy = SagaUpdateReminderPolicy()
  ) -> SagaUpdateReminderService {
    SagaUpdateReminderService(
      appStoreID: appStoreID,
      policy: policy,
      storageSuiteName: suiteName,
      now: { date }
    )
  }

  func cleanUp() {
    UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
  }
}

private func reminderRelease(_ version: String = "2.0") -> SagaStoreRelease {
  guard let storeURL = URL(string: "https://apps.apple.com/app/id123") else {
    preconditionFailure("Invalid App Store fixture URL")
  }

  return SagaStoreRelease(
    version: version,
    storeURL: storeURL
  )
}

private func reminderSnapshot(
  version: String = "2.0",
  checkedAt: Date = reminderTestDate,
  availability: SagaUpdateAvailability = .updateAvailable,
  error: SagaUpdateError? = nil
) -> SagaUpdateSnapshot {
  SagaUpdateSnapshot(
    release: reminderRelease(version),
    availability: availability,
    checkedAt: checkedAt,
    lastError: error
  )
}

@Test func eligibilityDoesNotConsumeReminder() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let service = fixture.service()
  let snapshot = reminderSnapshot()

  #expect(await service.reminder(for: snapshot) == snapshot.release)
  #expect(await service.reminder(for: snapshot) == snapshot.release)
  #expect(await fixture.service().reminder(for: snapshot) == snapshot.release)
}

@Test func actualPresentationPersistsAndExpiresAtConfiguredBoundary() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let policy = SagaUpdateReminderPolicy(reminderInterval: 100)
  let service = fixture.service(policy: policy)
  await service.recordPresentation(of: reminderRelease())

  let before = reminderTestDate.addingTimeInterval(99)
  let beforeService = fixture.service(
    at: before,
    policy: policy
  )
  #expect(await beforeService.reminder(for: reminderSnapshot(checkedAt: before)) == nil)

  let boundary = reminderTestDate.addingTimeInterval(100)
  let afterService = fixture.service(
    at: boundary,
    policy: policy
  )
  #expect(await afterService.reminder(for: reminderSnapshot(checkedAt: boundary)) != nil)
}

@Test func snoozePersistsPerVersionUntilSevenDaysHaveElapsed() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let service = fixture.service()
  await service.snooze(reminderRelease())

  let before = reminderTestDate.addingTimeInterval(7 * 86_400 - 1)
  let beforeService = fixture.service(at: before)
  #expect(await beforeService.reminder(for: reminderSnapshot(checkedAt: before)) == nil)
  #expect(
    await beforeService.reminder(
      for: reminderSnapshot(
        version: "2.1",
        checkedAt: before
      )
    ) != nil
  )

  let boundary = reminderTestDate.addingTimeInterval(7 * 86_400)
  let afterService = fixture.service(at: boundary)
  #expect(await afterService.reminder(for: reminderSnapshot(checkedAt: boundary)) != nil)
}

@Test func snoozeAndPresentationCadenceBothApply() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let policy = SagaUpdateReminderPolicy(
    reminderInterval: 200,
    snoozeInterval: 100
  )
  let service = fixture.service(policy: policy)
  await service.recordPresentation(of: reminderRelease())
  await service.snooze(reminderRelease())

  let date = reminderTestDate.addingTimeInterval(100)
  let restarted = fixture.service(
    at: date,
    policy: policy
  )
  #expect(await restarted.reminder(for: reminderSnapshot(checkedAt: date)) == nil)
}

@Test func ignoreSurvivesRestartAndDoesNotSuppressANewVersionOrAnotherApp() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let service = fixture.service()
  await service.ignore(reminderRelease())
  await service.recordPresentation(of: reminderRelease())
  await service.snooze(reminderRelease())

  let later = reminderTestDate.addingTimeInterval(30 * 86_400)
  let restarted = fixture.service(at: later)
  #expect(await restarted.reminder(for: reminderSnapshot(checkedAt: later)) == nil)
  #expect(
    await restarted.reminder(
      for: reminderSnapshot(
        version: "2.1",
        checkedAt: later
      )
    ) != nil
  )

  let otherApp = fixture.service(
    at: later,
    appStoreID: 456
  )
  #expect(await otherApp.reminder(for: reminderSnapshot(checkedAt: later)) != nil)
}

@Test func equivalentNumericVersionsShareReminderHistory() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let service = fixture.service()
  await service.ignore(reminderRelease("02.0.0"))

  #expect(await service.reminder(for: reminderSnapshot(version: "2")) == nil)
  #expect(await service.reminder(for: reminderSnapshot(version: "2.0.1")) != nil)
}

@Test func staleFutureAndMissingCheckDatesNeverRemind() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let service = fixture.service()
  let dates: [Date?] = [
    reminderTestDate.addingTimeInterval(-86_400),
    reminderTestDate.addingTimeInterval(-86_401),
    reminderTestDate.addingTimeInterval(1),
    nil,
  ]

  for date in dates {
    let snapshot = SagaUpdateSnapshot(
      release: reminderRelease(),
      availability: .updateAvailable,
      checkedAt: date
    )
    #expect(await service.reminder(for: snapshot) == nil)
  }

  #expect(
    await service.reminder(
      for: reminderSnapshot(checkedAt: reminderTestDate.addingTimeInterval(-86_399))
    ) != nil
  )
}

@Test func unavailableFailedOrMalformedSnapshotsNeverRemind() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let service = fixture.service()
  let snapshots = [
    reminderSnapshot(availability: .unknown),
    reminderSnapshot(availability: .upToDate),
    reminderSnapshot(error: .networkUnavailable),
    reminderSnapshot(error: .appUnavailable),
    reminderSnapshot(version: "2-beta"),
    SagaUpdateSnapshot(
      release: nil,
      availability: .updateAvailable,
      checkedAt: reminderTestDate
    ),
  ]

  for snapshot in snapshots {
    #expect(await service.reminder(for: snapshot) == nil)
  }
}

@Test func successfulInstallationSuppressesReminderDespitePreviousHistory() async {
  let fixture = ReminderFixture()
  defer {
    fixture.cleanUp()
  }

  let service = fixture.service()
  #expect(await service.reminder(for: reminderSnapshot()) != nil)
  await service.recordPresentation(of: reminderRelease())

  let afterInstallation = reminderSnapshot(availability: .upToDate)
  #expect(await service.reminder(for: afterInstallation) == nil)
}
