import MapKit
import SwiftUI

public enum SagaMapDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case standard
    case hybrid
    case imagery

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard:
            "Map"
        case .hybrid:
            "Hybrid"
        case .imagery:
            "Satellite"
        }
    }

    public var icon: String {
        switch self {
        case .standard:
            "map.fill"
        case .hybrid:
            "map.circle.fill"
        case .imagery:
            "photo.fill"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            .standard(elevation: .realistic)
        case .hybrid:
            .hybrid(elevation: .realistic)
        case .imagery:
            .imagery(elevation: .realistic)
        }
    }
}

public enum SagaMapControlPlacement: Sendable {
    case topLeft
    case topCenter
    case topRight
    case rightCenter
    case bottomRight
    case bottomCenter
    case bottomLeft
    case leftCenter

    case topLeading
    case top
    case topTrailing
    case leading
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing

    var alignment: Alignment {
        anchor.alignment
    }

    fileprivate var anchor: SagaMapControlAnchor {
        switch self {
        case .topLeft, .topLeading:
            .topLeft
        case .topCenter, .top:
            .topCenter
        case .topRight, .topTrailing:
            .topRight
        case .rightCenter, .trailing:
            .rightCenter
        case .bottomRight, .bottomTrailing:
            .bottomRight
        case .bottomCenter, .bottom:
            .bottomCenter
        case .bottomLeft, .bottomLeading:
            .bottomLeft
        case .leftCenter, .leading:
            .leftCenter
        }
    }
}

private enum SagaMapControlAnchor: CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case rightCenter
    case bottomRight
    case bottomCenter
    case bottomLeft
    case leftCenter

    var alignment: Alignment {
        switch self {
        case .topLeft:
            .topLeading
        case .topCenter:
            .top
        case .topRight:
            .topTrailing
        case .leftCenter:
            .leading
        case .rightCenter:
            .trailing
        case .bottomRight:
            .bottomTrailing
        case .bottomCenter:
            .bottom
        case .bottomLeft:
            .bottomLeading
        }
    }

    var axis: Axis {
        switch self {
        case .topCenter, .bottomCenter:
            .horizontal
        case .topLeft, .topRight, .rightCenter, .bottomRight, .bottomLeft, .leftCenter:
            .vertical
        }
    }

    var touchesTop: Bool {
        switch self {
        case .topLeft, .topCenter, .topRight:
            true
        case .rightCenter, .bottomRight, .bottomCenter, .bottomLeft, .leftCenter:
            false
        }
    }

    var touchesLeading: Bool {
        switch self {
        case .topLeft, .bottomLeft, .leftCenter:
            true
        case .topCenter, .topRight, .rightCenter, .bottomRight, .bottomCenter:
            false
        }
    }

    var touchesBottom: Bool {
        switch self {
        case .bottomRight, .bottomCenter, .bottomLeft:
            true
        case .topLeft, .topCenter, .topRight, .rightCenter, .leftCenter:
            false
        }
    }

    var touchesTrailing: Bool {
        switch self {
        case .topRight, .rightCenter, .bottomRight:
            true
        case .topLeft, .topCenter, .bottomCenter, .bottomLeft, .leftCenter:
            false
        }
    }
}

public enum SagaMapZoomAxis: Sendable {
    case vertical
    case horizontal
}

public struct SagaMapHintConfiguration: Sendable {
    public let title: String
    public let systemImage: String
    public let placement: SagaMapControlPlacement

    public init(
        title: String,
        systemImage: String = "hand.tap.fill",
        placement: SagaMapControlPlacement = .topLeading
    ) {
        self.title = title
        self.systemImage = systemImage
        self.placement = placement
    }
}

public struct SagaMapZoomConfiguration: Sendable {
    public let axis: SagaMapZoomAxis
    public let placement: SagaMapControlPlacement
    public let minDelta: CLLocationDegrees
    public let maxDelta: CLLocationDegrees

    public init(
        axis: SagaMapZoomAxis = .vertical,
        placement: SagaMapControlPlacement = .topTrailing,
        minDelta: CLLocationDegrees = 0.005,
        maxDelta: CLLocationDegrees = 40
    ) {
        self.axis = axis
        self.placement = placement
        self.minDelta = minDelta
        self.maxDelta = maxDelta
    }
}

public struct SagaMapStylePickerConfiguration: Sendable {
    public let placement: SagaMapControlPlacement

    public init(placement: SagaMapControlPlacement = .bottom) {
        self.placement = placement
    }
}

public struct SagaMapFitControlConfiguration: Sendable {
    public let placement: SagaMapControlPlacement
    public let accessibilityLabel: String

    public init(
        placement: SagaMapControlPlacement = .topTrailing,
        accessibilityLabel: String = "Fit map content"
    ) {
        self.placement = placement
        self.accessibilityLabel = accessibilityLabel
    }
}

public struct SagaMapControlInsets: Sendable {
    public static let zero = SagaMapControlInsets()

    public let top: CGFloat
    public let leading: CGFloat
    public let bottom: CGFloat
    public let trailing: CGFloat

    public init(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init(_ edgeInsets: EdgeInsets) {
        self.init(
            top: edgeInsets.top,
            leading: edgeInsets.leading,
            bottom: edgeInsets.bottom,
            trailing: edgeInsets.trailing
        )
    }
}

public struct SagaMapConfiguration: Sendable {
    public let minHeight: CGFloat
    public let height: CGFloat?
    public let cornerRadius: CGFloat
    public let bottomMapContentInset: CGFloat
    public let hint: SagaMapHintConfiguration?
    public let zoom: SagaMapZoomConfiguration?
    public let stylePicker: SagaMapStylePickerConfiguration?
    public let fitControl: SagaMapFitControlConfiguration?
    public let showsBorder: Bool
    public let showsNativeMapControls: Bool
    public let controlPadding: CGFloat
    public let controlContentInsets: SagaMapControlInsets

    public init(
        minHeight: CGFloat = 220,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = 14,
        bottomMapContentInset: CGFloat = 0,
        hint: SagaMapHintConfiguration? = nil,
        zoom: SagaMapZoomConfiguration? = nil,
        stylePicker: SagaMapStylePickerConfiguration? = nil,
        fitControl: SagaMapFitControlConfiguration? = nil,
        showsBorder: Bool = true,
        showsNativeMapControls: Bool = false,
        controlPadding: CGFloat = 8,
        controlContentInsets: SagaMapControlInsets = .zero
    ) {
        self.minHeight = minHeight
        self.height = height
        self.cornerRadius = cornerRadius
        self.bottomMapContentInset = bottomMapContentInset
        self.hint = hint
        self.zoom = zoom
        self.stylePicker = stylePicker
        self.fitControl = fitControl
        self.showsBorder = showsBorder
        self.showsNativeMapControls = showsNativeMapControls
        self.controlPadding = controlPadding
        self.controlContentInsets = controlContentInsets
    }
}

public struct SagaMap<Content: MapContent>: View {
    @Binding private var position: MapCameraPosition
    @Binding private var style: SagaMapDisplayStyle
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var mapLongPressTracker = SagaMapLongPressTracker()

    private let configuration: SagaMapConfiguration
    private let onMapTap: ((CLLocationCoordinate2D) -> Void)?
    private let onMapLongPress: ((CLLocationCoordinate2D) -> Void)?
    private let onFit: (() -> Void)?
    private let content: () -> Content

    public init(
        position: Binding<MapCameraPosition>,
        style: Binding<SagaMapDisplayStyle>,
        configuration: SagaMapConfiguration = SagaMapConfiguration(),
        onMapTap: ((CLLocationCoordinate2D) -> Void)? = nil,
        onMapLongPress: ((CLLocationCoordinate2D) -> Void)? = nil,
        onFit: (() -> Void)? = nil,
        @MapContentBuilder content: @escaping () -> Content
    ) {
        _position = position
        _style = style
        self.configuration = configuration
        self.onMapTap = onMapTap
        self.onMapLongPress = onMapLongPress
        self.onFit = onFit
        self.content = content
    }

    public var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                content()
            }
            .mapStyle(style.mapStyle)
            .mapControlVisibility(configuration.showsNativeMapControls ? .automatic : .hidden)
            .onMapCameraChange { context in
                visibleRegion = context.region
            }
            .safeAreaInset(edge: .bottom) {
                if configuration.bottomMapContentInset > 0 {
                    Color.clear
                        .frame(height: configuration.bottomMapContentInset)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: configuration.minHeight)
            .frame(height: configuration.height)
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            .overlay {
                controlsLayer()
            }
            .overlay {
                if configuration.showsBorder {
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .stroke(.secondary.opacity(0.16), lineWidth: 1)
                }
            }
            .onTapGesture(coordinateSpace: .local) { point in
                guard let onMapTap, let coordinate = proxy.convert(point, from: .local) else { return }
                onMapTap(coordinate)
            }
            .simultaneousGesture(longPressGesture(proxy: proxy))
        }
    }

    private func longPressGesture(proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard onMapLongPress != nil else { return }
                mapLongPressTracker.update(with: value)
            }
            .onEnded { value in
                guard let onMapLongPress,
                      mapLongPressTracker.isLongPress(value),
                      let coordinate = proxy.convert(value.location, from: .local) else {
                    mapLongPressTracker.reset()
                    return
                }

                mapLongPressTracker.reset()
                onMapLongPress(coordinate)
            }
    }

    private func controlsLayer() -> some View {
        ZStack {
            controls(for: .topLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            controls(for: .topCenter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            controls(for: .topRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            controls(for: .rightCenter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            controls(for: .bottomRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            controls(for: .bottomCenter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            controls(for: .bottomLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            controls(for: .leftCenter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func controls(for anchor: SagaMapControlAnchor) -> some View {
        if hasControls(at: anchor) {
            Group {
                switch anchor.axis {
                case .vertical:
                    VStack(spacing: configuration.controlPadding) {
                        controlsContent(for: anchor)
                    }
                case .horizontal:
                    HStack(spacing: configuration.controlPadding) {
                        controlsContent(for: anchor)
                    }
                }
            }
            .padding(controlPadding(for: anchor))
        }
    }

    private func controlPadding(for anchor: SagaMapControlAnchor) -> EdgeInsets {
        let base = configuration.controlPadding
        let insets = configuration.controlContentInsets
        return EdgeInsets(
            top: base + (anchor.touchesTop ? insets.top : 0),
            leading: base + (anchor.touchesLeading ? insets.leading : 0),
            bottom: base + (anchor.touchesBottom ? insets.bottom : 0),
            trailing: base + (anchor.touchesTrailing ? insets.trailing : 0)
        )
    }

    @ViewBuilder
    private func controlsContent(for anchor: SagaMapControlAnchor) -> some View {
        if let hint = configuration.hint, hint.placement.anchor == anchor {
            SagaMapHint(configuration: hint)
        }

        if configuration.stylePicker?.placement.anchor == anchor {
            SagaMapStylePicker(selection: $style)
        }

        if let zoom = configuration.zoom, zoom.placement.anchor == anchor {
            SagaMapZoomControls(
                axis: zoom.axis,
                onZoomIn: { applyZoom(factor: 0.5, configuration: zoom) },
                onZoomOut: { applyZoom(factor: 2, configuration: zoom) }
            )
        }

        if let fitControl = configuration.fitControl, fitControl.placement.anchor == anchor {
            SagaMapFitButton {
                if let onFit {
                    onFit()
                } else {
                    position = .automatic
                }
            }
            .accessibilityLabel(fitControl.accessibilityLabel)
        }
    }

    private func hasControls(at anchor: SagaMapControlAnchor) -> Bool {
        configuration.hint?.placement.anchor == anchor ||
            configuration.stylePicker?.placement.anchor == anchor ||
            configuration.zoom?.placement.anchor == anchor ||
            configuration.fitControl?.placement.anchor == anchor
    }

    private func applyZoom(factor: Double, configuration: SagaMapZoomConfiguration) {
        guard let visibleRegion else { return }

        let latitudeDelta = min(
            max(visibleRegion.span.latitudeDelta * factor, configuration.minDelta),
            configuration.maxDelta
        )
        let longitudeDelta = min(
            max(visibleRegion.span.longitudeDelta * factor, configuration.minDelta),
            configuration.maxDelta
        )

        position = .region(
            MKCoordinateRegion(
                center: visibleRegion.center,
                span: MKCoordinateSpan(
                    latitudeDelta: latitudeDelta,
                    longitudeDelta: longitudeDelta
                )
            )
        )
    }
}

@MainActor
private final class SagaMapLongPressTracker {
    private var startedAt: Date?
    private var startLocation: CGPoint?
    private let minimumDuration: TimeInterval = 0.45
    private let maximumMovement: CGFloat = 18

    func update(with value: DragGesture.Value) {
        if startedAt == nil {
            startedAt = Date()
            startLocation = value.startLocation
        }
    }

    func isLongPress(_ value: DragGesture.Value) -> Bool {
        guard let startedAt, let startLocation else {
            return false
        }

        let duration = Date().timeIntervalSince(startedAt)
        let distance = hypot(value.location.x - startLocation.x, value.location.y - startLocation.y)
        return duration >= minimumDuration && distance <= maximumMovement
    }

    func reset() {
        startedAt = nil
        startLocation = nil
    }
}

private struct SagaMapHint: View {
    let configuration: SagaMapHintConfiguration

    var body: some View {
        Label(configuration.title, systemImage: configuration.systemImage)
            .font(.caption.weight(.bold))
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }
}

private struct SagaMapZoomControls: View {
    let axis: SagaMapZoomAxis
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        Group {
            switch axis {
            case .vertical:
                VStack(spacing: 0) {
                    button(icon: "plus", action: onZoomIn)
                    divider
                    button(icon: "minus", action: onZoomOut)
                }
                .frame(width: 34)
            case .horizontal:
                HStack(spacing: 0) {
                    button(icon: "minus", action: onZoomOut)
                    divider
                        .frame(width: 1, height: 24)
                    button(icon: "plus", action: onZoomIn)
                }
                .frame(height: 34)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var divider: some View {
        Divider()
            .frame(width: axis == .vertical ? 24 : nil)
            .background(.secondary.opacity(0.2))
    }

    private func button(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(.clear)

                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .frame(width: 34, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SagaMapStylePicker: View {
    @Binding var selection: SagaMapDisplayStyle

    var body: some View {
        Picker("Map style", selection: $selection) {
            ForEach(SagaMapDisplayStyle.allCases) { style in
                Label(style.title, systemImage: style.icon)
                    .tag(style)
            }
        }
        .pickerStyle(.segmented)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SagaMapFitButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "scope")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("SagaMap - Right Edge Controls") {
    SagaMapPreviewCanvas(
        title: "Right edge controls",
        configuration: SagaMapConfiguration(
            minHeight: 420,
            height: 420,
            cornerRadius: 0,
            zoom: SagaMapZoomConfiguration(
                axis: .vertical,
                placement: .bottomRight
            ),
            stylePicker: SagaMapStylePickerConfiguration(placement: .topLeft),
            fitControl: SagaMapFitControlConfiguration(
                placement: .rightCenter,
                accessibilityLabel: "Fit visible route"
            ),
            controlPadding: 16
        )
    )
}

#Preview("SagaMap - Mixed Control Positions") {
    SagaMapPreviewCanvas(
        title: "Mixed control positions",
        configuration: SagaMapConfiguration(
            minHeight: 420,
            height: 420,
            cornerRadius: 18,
            hint: SagaMapHintConfiguration(
                title: "Long press to add",
                systemImage: "mappin.and.ellipse",
                placement: .topLeft
            ),
            zoom: SagaMapZoomConfiguration(
                axis: .vertical,
                placement: .leftCenter
            ),
            stylePicker: SagaMapStylePickerConfiguration(placement: .topRight),
            fitControl: SagaMapFitControlConfiguration(
                placement: .bottomRight,
                accessibilityLabel: "Fit preview content"
            ),
            controlPadding: 12
        )
    )
}

#Preview("SagaMap - Horizontal Zoom") {
    SagaMapPreviewCanvas(
        title: "Horizontal zoom controls",
        configuration: SagaMapConfiguration(
            minHeight: 360,
            height: 360,
            cornerRadius: 18,
            hint: SagaMapHintConfiguration(
                title: "Tap the route",
                systemImage: "hand.tap.fill",
                placement: .bottomLeft
            ),
            zoom: SagaMapZoomConfiguration(
                axis: .horizontal,
                placement: .bottomCenter
            ),
            stylePicker: SagaMapStylePickerConfiguration(placement: .topLeft),
            fitControl: SagaMapFitControlConfiguration(
                placement: .topCenter,
                accessibilityLabel: "Fit horizontal zoom preview"
            ),
            controlPadding: 12
        )
    )
}

private struct SagaMapPreviewCanvas: View {
    let title: String
    let configuration: SagaMapConfiguration
    @State private var position: MapCameraPosition = .region(.sagaMapPreviewRegion)
    @State private var style: SagaMapDisplayStyle = .standard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))

            SagaMap(
                position: $position,
                style: $style,
                configuration: configuration,
                onMapTap: { _ in },
                onMapLongPress: { _ in },
                onFit: {
                    position = .region(.sagaMapPreviewRegion)
                }
            ) {
                MapPolyline(coordinates: CLLocationCoordinate2D.sagaMapPreviewRoute)
                    .stroke(.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

                Marker("Start", systemImage: "house.fill", coordinate: .sagaMapPreviewStart)
                    .tint(.green)

                Marker("Camp", systemImage: "tent.fill", coordinate: .sagaMapPreviewCamp)
                    .tint(.orange)

                Annotation("Vehicle", coordinate: .sagaMapPreviewVehicle, anchor: .bottom) {
                    Image(systemName: "car.side.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.blue.gradient)
                        .clipShape(Circle())
                        .shadow(radius: 6, y: 3)
                        .accessibilityLabel("Vehicle position")
                }
            }
        }
        .padding()
        .background(Color.sagaMapPreviewBackground)
    }
}

private extension MKCoordinateRegion {
    static let sagaMapPreviewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.55, longitude: 10.68),
        span: MKCoordinateSpan(latitudeDelta: 1.1, longitudeDelta: 1.4)
    )
}

private extension Color {
    static var sagaMapPreviewBackground: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(uiColor: .systemGroupedBackground)
#endif
    }
}

private extension CLLocationCoordinate2D {
    static let sagaMapPreviewStart = CLLocationCoordinate2D(latitude: 59.4340, longitude: 10.6577)
    static let sagaMapPreviewVehicle = CLLocationCoordinate2D(latitude: 59.7190, longitude: 10.8358)
    static let sagaMapPreviewCamp = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)

    static let sagaMapPreviewRoute = [
        sagaMapPreviewStart,
        CLLocationCoordinate2D(latitude: 59.55, longitude: 10.72),
        sagaMapPreviewVehicle,
        sagaMapPreviewCamp
    ]
}
#endif
