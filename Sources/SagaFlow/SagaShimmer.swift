import SwiftUI

/// A lightweight shimmering highlight that can be applied to loading placeholders.
public struct SagaShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    private let isActive: Bool
    private let highlight: Color
    private let duration: TimeInterval
    private let angle: Angle

    public init(
        isActive: Bool = true,
        highlight: Color = .white.opacity(0.34),
        duration: TimeInterval = 1.35,
        angle: Angle = .degrees(18)
    ) {
        self.isActive = isActive
        self.highlight = highlight
        self.duration = duration
        self.angle = angle
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    shimmerLayer
                        .mask(content)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onAppear {
                startAnimation()
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    startAnimation()
                }
            }
    }

    private var shimmerLayer: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: highlight.opacity(reduceMotion ? 0.22 : 0.08), location: 0.35),
                    .init(color: highlight, location: 0.5),
                    .init(color: highlight.opacity(reduceMotion ? 0.22 : 0.08), location: 0.65),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 1.7)
            .rotationEffect(angle)
            .offset(x: reduceMotion ? 0 : phase * width * 1.8)
        }
    }

    private func startAnimation() {
        guard isActive else {
            return
        }

        if reduceMotion {
            phase = 0
            return
        }

        phase = -1
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }
}

public extension View {
    /// Adds a moving shimmer highlight over the view while `isActive` is true.
    func sagaShimmer(
        isActive: Bool = true,
        highlight: Color = .white.opacity(0.34),
        duration: TimeInterval = 1.35,
        angle: Angle = .degrees(18)
    ) -> some View {
        modifier(
            SagaShimmer(
                isActive: isActive,
                highlight: highlight,
                duration: duration,
                angle: angle
            )
        )
    }
}

/// A themed placeholder block for skeleton loading layouts.
public struct SagaShimmerBlock: View {
    private let width: CGFloat?
    private let height: CGFloat
    private let cornerRadius: CGFloat
    private let baseColor: Color
    private let highlight: Color

    public init(
        width: CGFloat? = nil,
        height: CGFloat,
        cornerRadius: CGFloat = 8,
        baseColor: Color = Color.primary.opacity(0.10),
        highlight: Color = .white.opacity(0.34)
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.baseColor = baseColor
        self.highlight = highlight
    }

    public var body: some View {
        if let width {
            block
                .frame(width: width, height: height)
        } else {
            block
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
    }

    private var block: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(baseColor)
            .sagaShimmer(highlight: highlight)
            .accessibilityHidden(true)
    }
}
