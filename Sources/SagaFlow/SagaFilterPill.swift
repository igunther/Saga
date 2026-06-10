import SwiftUI

/// A compact selectable pill for filter rows, sort menus, and lightweight toggles.
public struct SagaFilterPill: View {
    private let title: String
    private let systemImage: String?
    private let isSelected: Bool
    private let selectedForeground: Color
    private let foreground: Color
    private let selectedBackground: Color
    private let background: Color
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat

    public init(
        _ title: String,
        systemImage: String? = nil,
        isSelected: Bool,
        selectedForeground: Color = .black,
        foreground: Color = .primary,
        selectedBackground: Color = .accentColor,
        background: Color = Color.primary.opacity(0.08),
        horizontalPadding: CGFloat = 9,
        verticalPadding: CGFloat = 5
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.selectedForeground = selectedForeground
        self.foreground = foreground
        self.selectedBackground = selectedBackground
        self.background = background
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }

            Text(title)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundColor(isSelected ? selectedForeground : foreground)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(isSelected ? selectedBackground : background)
        .clipShape(Capsule())
    }
}
