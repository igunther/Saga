import Foundation

/// Presentation cadence, independent of the App Store lookup cadence.
public struct SagaUpdateReminderPolicy: Sendable {
  public let reminderInterval: TimeInterval
  public let snoozeInterval: TimeInterval
  public let maximumCheckAge: TimeInterval

  public init(
    reminderInterval: TimeInterval = 7 * 24 * 60 * 60,
    snoozeInterval: TimeInterval = 7 * 24 * 60 * 60,
    maximumCheckAge: TimeInterval = 24 * 60 * 60
  ) {
    precondition(reminderInterval.isFinite && reminderInterval > 0)
    precondition(snoozeInterval.isFinite && snoozeInterval > 0)
    precondition(maximumCheckAge.isFinite && maximumCheckAge > 0)
    self.reminderInterval = reminderInterval
    self.snoozeInterval = snoozeInterval
    self.maximumCheckAge = maximumCheckAge
  }
}

/// Decides whether a host may remind the user. Never fetches data or presents UI.
/// Keep one instance per app and let the host coordinate presentation on the main actor.
public actor SagaUpdateReminderService {
  public let policy: SagaUpdateReminderPolicy

  private let repository: SagaUpdateReminderRepository
  private let now: @Sendable () -> Date

  init(
    policy: SagaUpdateReminderPolicy,
    repository: SagaUpdateReminderRepository,
    now: @escaping @Sendable () -> Date
  ) {
    self.policy = policy
    self.repository = repository
    self.now = now
  }

  /// Evaluates without consuming the reminder. Reevaluate when the host is ready to present.
  public func reminder(for snapshot: SagaUpdateSnapshot) async -> SagaStoreRelease? {
    let date = now()
    guard
      snapshot.availability == .updateAvailable,
      snapshot.lastError == nil,
      let checkedAt = snapshot.checkedAt,
      checkedAt <= date,
      date.timeIntervalSince(checkedAt) < policy.maximumCheckAge,
      let release = snapshot.release,
      let key = versionKey(release.version)
    else {
      return nil
    }

    let history = await repository.history(for: key)
    guard !history.isIgnored else {
      return nil
    }

    if let snoozedUntil = history.snoozedUntil,
      date < snoozedUntil
    {
      return nil
    }

    if let lastPresentedAt = history.lastPresentedAt,
      date < lastPresentedAt.addingTimeInterval(policy.reminderInterval)
    {
      return nil
    }

    return release
  }

  /// Call only when the reminder actually appears, including cards and custom sheets.
  public func recordPresentation(of release: SagaStoreRelease) async {
    guard let key = versionKey(release.version) else {
      return
    }

    await repository.recordPresentation(
      for: key,
      at: now()
    )
  }

  /// Handles “Later”. Other versions retain their own independent reminder history.
  public func snooze(_ release: SagaStoreRelease) async {
    guard let key = versionKey(release.version) else {
      return
    }

    await repository.snooze(
      key,
      until: now().addingTimeInterval(policy.snoozeInterval)
    )
  }

  /// Suppresses automatic reminders for this version across app launches and storefronts.
  public func ignore(_ release: SagaStoreRelease) async {
    guard let key = versionKey(release.version) else {
      return
    }

    await repository.ignore(key)
  }

  private func versionKey(_ version: String) -> String? {
    guard
      let parsed = SagaVersion(version),
      case .components(var components) = parsed
    else {
      return nil
    }

    while components.count > 1,
      components.last == 0
    {
      components.removeLast()
    }

    return components.map(String.init).joined(separator: ".")
  }
}
