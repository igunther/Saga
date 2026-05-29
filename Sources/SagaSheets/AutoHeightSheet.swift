//
//  AutoHeightSheet.swift
//  SagaSheets
//

import SwiftUI

/// A sheet that automatically adjusts to its content height
public struct SagaAutoHeightSheet<Content: View>: View {
    let options: SagaSheetOptions
    @ViewBuilder let content: () -> Content

    public init(
        options: SagaSheetOptions = .default,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.options = options
        self.content = content
    }

    public var body: some View {
        content()
            .modifier(AutoHeightModifier(options: options))
    }
}

/// Modifier that reads content height and sets presentation detent
private struct AutoHeightModifier: ViewModifier {
    let options: SagaSheetOptions
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: HeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                }
            )
            .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
                withAnimation(.easeInOut(duration: 0.2)) {
                    // Add padding for safe area and drag indicator
                    height = newHeight + 40
                }
            }
            .presentationDetents([.height(height)])
            .presentationDragIndicator(options.showDragIndicator ? .visible : .hidden)
            .interactiveDismissDisabled(!options.enableInteractiveDismiss)
    }
}

/// PreferenceKey for reading view height
private struct HeightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
