# Saga project facts

- Swift package with iOS 18+ support.
- Products: `Saga`, `SagaFlow`, `SagaSheets`, and opt-in `SagaUpdates`.
- `SagaUpdates` keeps its Data, Repository, Domain, Composition, and Presentation sources in separate folders. The host app owns update presentation.
- Verify with `swift test` and `xcodebuild -scheme SagaUpdates -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` after update-check changes.
