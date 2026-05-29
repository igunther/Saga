//
//  SheetConfiguration.swift
//  SagaSheets
//

import SwiftUI

/// Configuration for sheet presentation styles
public enum SheetConfiguration {
    /// Auto-adjusts to content height
    case auto
    /// Small fixed detent (25% of screen)
    case small
    /// Medium fixed detent (50% of screen)
    case medium
    /// Large fixed detent (90% of screen)
    case large
    /// Custom fraction of screen height (0.0 - 1.0)
    case fraction(Double)
    /// Custom fixed height in points
    case height(CGFloat)
    /// Multiple detents for user to choose from
    case detents([PresentationDetent])

    /// Converts configuration to presentation detents
    var presentationDetents: Set<PresentationDetent> {
        switch self {
        case .auto:
            // Will be handled by the modifier
            return [.medium]
        case .small:
            return [.fraction(0.25)]
        case .medium:
            return [.medium]
        case .large:
            return [.fraction(0.9)]
        case .fraction(let value):
            return [.fraction(value)]
        case .height(let points):
            return [.height(points)]
        case .detents(let detents):
            return Set(detents)
        }
    }
}

/// Options for sheet appearance
public struct SheetOptions: Sendable {
    public var showDragIndicator: Bool
    public var enableInteractiveDismiss: Bool

    public init(
        showDragIndicator: Bool = true,
        enableInteractiveDismiss: Bool = true
    ) {
        self.showDragIndicator = showDragIndicator
        self.enableInteractiveDismiss = enableInteractiveDismiss
    }

    public nonisolated(unsafe) static let `default` = SheetOptions()
}
