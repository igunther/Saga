//
//  ConfigurableSheet.swift
//  SagaSheets
//

import SwiftUI

/// A sheet with flexible configuration options
public struct SagaConfigurableSheet<Content: View>: View {
    let configuration: SagaSheetConfiguration
    let options: SagaSheetOptions
    @ViewBuilder let content: () -> Content

    public init(
        configuration: SagaSheetConfiguration = .medium,
        options: SagaSheetOptions = .default,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.configuration = configuration
        self.options = options
        self.content = content
    }

    public var body: some View {
        Group {
            if case .auto = configuration {
                // Use auto-height for .auto configuration
                SagaAutoHeightSheet(options: options, content: content)
            } else {
                // Use standard presentation detents
                content()
                    .presentationDetents(configuration.presentationDetents)
                    .presentationDragIndicator(options.showDragIndicator ? .visible : .hidden)
                    .interactiveDismissDisabled(!options.enableInteractiveDismiss)
            }
        }
    }
}

// MARK: - Convenience Extensions

// MARK: - Convenience Extensions

public extension View {
    /// Wraps the view in a sheet with auto-height
    func asAutoHeightSheet(options: SagaSheetOptions = .default) -> some View {
        SagaAutoHeightSheet(options: options) {
            self
        }
    }

    /// Wraps the view in a configurable sheet
    func asSheet(
        _ configuration: SagaSheetConfiguration = .medium,
        options: SagaSheetOptions = .default
    ) -> some View {
        SagaConfigurableSheet(configuration: configuration, options: options) {
            self
        }
    }
}
