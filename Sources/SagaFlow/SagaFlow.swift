//
//  SagaFlow.swift
//  Generic Flow infrastructure
//

// MARK: - Overview
//
// SagaFlow provides lightweight, type-safe coordinator/flow infrastructure for SwiftUI apps.
// It replaces ad-hoc navigation logic in views with a clean, testable pattern built around
// three concerns: push navigation, modal presentation, and async flow results.
//
// ## Core Types
//
// Router<Route>  — The central building block. Each feature flow owns one Router, keyed on
//                 its own Route enum (Hashable). The router drives three SwiftUI bindings:
//                   • path       → NavigationStack path (push/pop/popToRoot)
//                   • sheet      → .sheet(item:) binding
//                   • fullScreen → .fullScreenCover(item:) binding
//
// PresentedItem  — A type-erased wrapper (AnyView + PresentationStyle) used as the
//                 Identifiable item bound to sheet/fullScreenCover modifiers. The
//                 isConfigured flag signals whether the wrapped view already carries its
//                 own presentation modifiers (e.g. auto-height sheets from SagaSheets).
//
// FlowHandle<Value> — A one-shot async continuation bridge. Use it when a sub-flow must
//                    return a typed value to its caller via withCheckedContinuation.
//                    Call finish(_:) or cancel() to resume the suspended caller exactly once.
//
// FlowResult<Value> — The return type of a handled flow: .finished(value) or .cancelled.
//
// Flowable       — An optional protocol that any flow class may adopt to advertise
//                 its Router in a uniform way. Not required for flows to work.
//
// ## Typical Usage
//
//   1. Define a Route enum (Hashable) for a feature's navigation destinations.
//   2. Add `@Published var router = Router<Route>()` to the feature's Flow class.
//   3. In the feature's tab/container view, bind:
//        NavigationStack(path: $flow.router.path) { ... }
//        .sheet(item: $flow.router.sheet) { $0.view }
//        .fullScreenCover(item: $flow.router.fullScreen) { $0.view }
//   4. Call router.push/presentSheet/presentFullScreen from the flow to navigate.
//   5. Flows communicate upward through a weak `parent` reference typed to a protocol.
//
// ## Dependency
//   None. Imports SwiftUI only.

import SwiftUI

// MARK: - Presentation

public enum PresentationStyle: Equatable {
    case sheet
    case fullScreen
}

public struct PresentedItem: Identifiable, Equatable {
    public let id = UUID()
    public let style: PresentationStyle
    public let view: AnyView
    public let isConfigured: Bool // Whether the view already has presentation modifiers

    public init(style: PresentationStyle, view: AnyView, isConfigured: Bool = false) {
        self.style = style
        self.view = view
        self.isConfigured = isConfigured
    }

    public static func == (lhs: PresentedItem, rhs: PresentedItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Router

/// Base router used by all flows.
/// - Push: NavigationStack path
/// - Present: sheet/fullScreenCover stack
@MainActor
open class Router<Route: Hashable>: ObservableObject {
    @Published public var path: [Route] = []
    @Published public var sheet: PresentedItem? = nil
    @Published public var fullScreen: PresentedItem? = nil

    public init() {}

    public func push(_ route: Route) { path.append(route) }
    public func pop() { _ = path.popLast() }
    public func popToRoot() { path.removeAll() }

    public func presentSheet(_ view: some View) {
        sheet = PresentedItem(style: .sheet, view: AnyView(view))
    }

    /// Present a sheet that already has presentation configuration applied
    public func presentConfiguredSheet(_ view: some View) {
        sheet = PresentedItem(style: .sheet, view: AnyView(view), isConfigured: true)
    }

    public func presentFullScreen(_ view: some View) {
        fullScreen = PresentedItem(style: .fullScreen, view: AnyView(view))
    }

    public func dismissSheet() { sheet = nil }
    public func dismissFullScreen() { fullScreen = nil }

    public func dismissAllPresented() {
        sheet = nil
        fullScreen = nil
    }
}

// MARK: - Flow Result Pattern

public enum FlowResult<Value>: Sendable where Value: Sendable {
    case finished(Value)
    case cancelled
}

/// A helper to run "flows" that return values.
/// You start a flow by presenting a view. That view (or a flow behind it)
/// completes the continuation with either .finished or .cancelled.
@MainActor
public final class FlowHandle<Value: Sendable> {
    public var continuation: CheckedContinuation<FlowResult<Value>, Never>?
    fileprivate var isCompleted = false

    public init() {}

    public func finish(_ value: Value) {
        guard !isCompleted else { return }
        isCompleted = true
        continuation?.resume(returning: .finished(value))
        continuation = nil
    }

    public func cancel() {
        guard !isCompleted else { return }
        isCompleted = true
        continuation?.resume(returning: .cancelled)
        continuation = nil
    }
}

// MARK: - Flow Protocol

@MainActor
public protocol Flowable: ObservableObject {
    associatedtype Route: Hashable
    var router: Router<Route> { get }
}
