//
//  ConfigurableSheet.swift
//  SagaSheets
//

import SwiftUI

/// A sheet with flexible configuration options
public struct SagaConfigurableSheet: View {
    let configuration: SagaSheetConfiguration
    let options: SagaSheetOptions
    let content: AnyView

    public init(
        configuration: SagaSheetConfiguration = .medium,
        options: SagaSheetOptions = .default,
        content: AnyView
    ) {
        self.configuration = configuration
        self.options = options
        self.content = content
    }

    public var body: some View {
        if case .auto = configuration {
            // Use auto-height for .auto configuration
            AnyView(SagaAutoHeightSheet(options: options, content: content))
        } else {
            // Use standard presentation detents
            AnyView(
                content
                    .presentationDetents(configuration.presentationDetents)
                    .presentationDragIndicator(options.showDragIndicator ? .visible : .hidden)
                    .interactiveDismissDisabled(!options.enableInteractiveDismiss)
            )
        }
    }
}

// MARK: - Convenience Extensions

// MARK: - Convenience Extensions

public extension View {
    /// Wraps the view in a sheet with auto-height
    func asAutoHeightSheet(options: SagaSheetOptions = .default) -> some View {
        SagaAutoHeightSheet(options: options, content: AnyView(self))
    }

    /// Wraps the view in a configurable sheet
    func asSheet(
        _ configuration: SagaSheetConfiguration = .medium,
        options: SagaSheetOptions = .default
    ) -> some View {
        SagaConfigurableSheet(configuration: configuration, options: options, content: AnyView(self))
    }
}
