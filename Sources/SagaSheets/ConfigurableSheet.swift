//
//  ConfigurableSheet.swift
//  SagaSheets
//

import SwiftUI

/// A sheet with flexible configuration options
public struct ConfigurableSheet<Content: View>: View {
    let configuration: SheetConfiguration
    let options: SheetOptions
    @ViewBuilder let content: () -> Content

    public init(
        configuration: SheetConfiguration = .medium,
        options: SheetOptions = .default,
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
                AutoHeightSheet(options: options, content: content)
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
    func asAutoHeightSheet(options: SheetOptions = .default) -> some View {
        AutoHeightSheet(options: options) {
            self
        }
    }

    /// Wraps the view in a configurable sheet
    func asSheet(
        _ configuration: SheetConfiguration = .medium,
        options: SheetOptions = .default
    ) -> some View {
        ConfigurableSheet(configuration: configuration, options: options) {
            self
        }
    }
}
