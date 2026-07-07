import SwiftUI

public struct SagaMapPin: View {
    public let title: String
    public let accessibilityValue: String?
    public let pinColor: Color
    public let pinForegroundColor: Color
    public let containerColor: Color
    public let primaryTextColor: Color
    public let secondaryTextColor: Color
    public let icon: String?
    public let imageURL: URL?
    public let text: String?
    public let isExpanded: Bool
    public let bubbleTitle: String?
    public let bubbleSubtitle: String?

    @State private var didAppear = false
    @State private var swayRotation: Double = 0

    public init(
        title: String,
        accessibilityValue: String? = nil,
        pinColor: Color = .accentColor,
        pinForegroundColor: Color = .primary,
        containerColor: Color = .white.opacity(0.96),
        primaryTextColor: Color = .primary,
        secondaryTextColor: Color = .secondary,
        icon: String? = "mappin.circle.fill",
        imageURL: URL? = nil,
        text: String? = nil,
        isExpanded: Bool = false,
        bubbleTitle: String? = nil,
        bubbleSubtitle: String? = nil
    ) {
        self.title = title
        self.accessibilityValue = accessibilityValue
        self.pinColor = pinColor
        self.pinForegroundColor = pinForegroundColor
        self.containerColor = containerColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.icon = icon
        self.imageURL = imageURL
        self.text = text
        self.isExpanded = isExpanded
        self.bubbleTitle = bubbleTitle
        self.bubbleSubtitle = bubbleSubtitle
    }

    public var body: some View {
        VStack(spacing: 4) {
            if isExpanded, hasBubbleContent {
                bubble
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
            }

            pinBody
        }
        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        .scaleEffect(didAppear ? (isExpanded ? 1.08 : 1) : 0.68, anchor: .bottom)
        .opacity(didAppear ? 1 : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.48), value: didAppear)
        .animation(.spring(response: 0.36, dampingFraction: 0.42), value: isExpanded)
        .onAppear {
            didAppear = true
        }
        .onChange(of: isExpanded) {
            swayFromLeftWind()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(resolvedAccessibilityValue)
    }

    private var pinBody: some View {
        VStack(spacing: 0) {
            markerShell

            Image(systemName: "triangle.fill")
                .font(.caption2)
                .foregroundColor(containerColor)
                .rotationEffect(.degrees(180))
                .offset(y: -7)
        }
        .rotationEffect(.degrees(swayRotation), anchor: .bottom)
    }

    private var markerShell: some View {
        marker
            .padding(isExpanded ? 6 : 4)
            .background(containerColor)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(pinColor.opacity(0.36), lineWidth: 1)
            }
    }

    private var marker: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        fallbackPin
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackPin
                    @unknown default:
                        fallbackPin
                    }
                }
            } else {
                fallbackPin
            }
        }
        .frame(width: isExpanded ? 32 : 28, height: isExpanded ? 32 : 28)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(pinColor, lineWidth: 2)
        }
    }

    private var fallbackPin: some View {
        ZStack {
            Circle()
                .fill(pinColor)

            if let text, !text.isEmpty {
                Text(text)
                    .font(.caption2.weight(.black))
                    .foregroundColor(pinForegroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(2)
            } else if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(pinForegroundColor)
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let bubbleTitle, !bubbleTitle.isEmpty {
                Text(bubbleTitle)
                    .font(.caption2.weight(.black))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)
            }

            if let bubbleSubtitle, !bubbleSubtitle.isEmpty {
                Text(bubbleSubtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: 170, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(containerColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(pinColor.opacity(0.28), lineWidth: 1)
        }
    }

    private var hasBubbleContent: Bool {
        [bubbleTitle, bubbleSubtitle].contains { value in
            guard let value else { return false }
            return !value.isEmpty
        }
    }

    private var resolvedAccessibilityValue: String {
        if let accessibilityValue, !accessibilityValue.isEmpty {
            return accessibilityValue
        }

        return [bubbleTitle, bubbleSubtitle]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func swayFromLeftWind() {
        swayRotation = 10

        withAnimation(.spring(response: 0.38, dampingFraction: 0.35)) {
            swayRotation = -7
        } completion: {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.48)) {
                swayRotation = 3
            } completion: {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    swayRotation = 0
                }
            }
        }
    }
}

#Preview("Saga Map Pin") {
    VStack(spacing: 28) {
        SagaMapPin(
            title: "Geiranger Camping",
            pinColor: .green,
            pinForegroundColor: .black,
            containerColor: .white.opacity(0.96),
            icon: "tent.fill",
            isExpanded: true,
            bubbleTitle: "Stop 1",
            bubbleSubtitle: "Tap again to open details"
        )

        SagaMapPin(
            title: "Fresh water",
            pinColor: .blue,
            pinForegroundColor: .white,
            containerColor: .white.opacity(0.96),
            text: "W"
        )
    }
    .padding()
    .background(.black)
}
