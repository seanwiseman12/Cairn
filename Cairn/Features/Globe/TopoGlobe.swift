import SwiftUI
import UIKit

/// The home-screen globe, drawn as pale continents with soft contour lines on a
/// green sea by the `topoGlobe` Metal shader (TopoGlobe.metal) from real elevation data
/// (NOAA ETOPO1, public domain, in Resources/Globe/globe-relief.png).
///
/// - Drag to spin, pinch to zoom, double-tap to zoom in (or back out when fully in).
/// - At normal size it turns slowly on its own.
/// - It fills its frame so a zoomed-in globe spreads edge to edge;
///   `reservedTop`/`reservedBottom` keep the unzoomed globe clear of other content.
///
/// When `focus` is set, the globe flies there (zooms out, spins round and lands,
/// zooming in) and drops a pin, then calls `onArrive`.
struct TopoGlobe: View {
    /// Points from the top of the screen that the unzoomed globe should stay below.
    var reservedTop: CGFloat = 0
    /// Points from the bottom of the screen that the unzoomed globe should stay above.
    var reservedBottom: CGFloat = 0
    /// A searched spot to fly to and mark with a pin.
    var focus: GlobeDestination?
    /// Called when a flight to `focus` has landed.
    var onArrive: () -> Void = {}

    /// Where the globe is centered (degrees) at the moment `spinStart`.
    @State private var lon: Double = DebugLaunch.globeLon ?? -40
    @State private var lat: Double = DebugLaunch.globeLat ?? 22
    @State private var zoom: Double = DebugLaunch.globeZoom ?? 1
    @State private var spinStart = Date()
    @State private var dragOrigin: (lon: Double, lat: Double)?
    @State private var pinchOrigin: Double?
    /// Bumped by each new flight, so a flight interrupted by another stops.
    @State private var flight = 0
    @State private var isFlying = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let zoomRange = 1.0...10.0
    /// Idle spin speed in degrees of longitude per second.
    private let idleSpin = 4.0

    private var isSpinning: Bool {
        dragOrigin == nil && pinchOrigin == nil && !isFlying && zoom <= 1.05 && !reduceMotion
    }

    var body: some View {
        GeometryReader { geo in
            let fit = fitCircle(in: geo.size)
            TimelineView(.animation(paused: !isSpinning)) { context in
                GlobeLayer(
                    center: fit.center,
                    baseRadius: fit.radius,
                    radius: fit.radius * zoom,
                    lon: currentLon(at: context.date),
                    lat: lat,
                    marker: focus
                )
            }
            .contentShape(Rectangle())
            .gesture(spinGesture(radius: fit.radius * zoom).simultaneously(with: pinchGesture))
            .onTapGesture(count: 2) { doubleTapZoom() }
        }
        .onChange(of: focus) { _, newFocus in
            if let newFocus { fly(to: newFocus) } else { zoomOut() }
        }
        .onAppear {
            // Created with a spot already picked (the home screen only builds
            // the globe when it's needed): start the flight straight away.
            if let focus { fly(to: focus) }
        }
        .accessibilityElement()
        .accessibilityLabel("Globe of your adventures")
        .accessibilityHint("Drag to spin, pinch to zoom")
        .accessibilityAdjustableAction { direction in
            withAnimation(.smooth) {
                switch direction {
                case .increment: zoom = clampZoom(zoom * 2)
                case .decrement: zoom = clampZoom(zoom / 2)
                @unknown default: break
                }
            }
        }
    }

    /// The largest circle (with a small margin) between the reserved areas.
    private func fitCircle(in size: CGSize) -> (center: CGPoint, radius: Double) {
        let available = max(100, size.height - reservedTop - reservedBottom)
        let center = CGPoint(x: size.width / 2, y: reservedTop + available / 2)
        let radius = min(size.width - 28, available) / 2
        return (center, Double(radius))
    }

    private func currentLon(at date: Date) -> Double {
        guard isSpinning else { return lon }
        return lon + idleSpin * date.timeIntervalSince(spinStart)
    }

    private func clampZoom(_ value: Double) -> Double {
        min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, value))
    }

    /// Dragging moves the surface under your finger: right spins east-to-west,
    /// down tilts the north pole toward you. Zoomed in, the same drag turns the
    /// globe less, so the map tracks your finger.
    private func spinGesture(radius: Double) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = (currentLon(at: .now), lat)
                }
                guard let origin = dragOrigin else { return }
                let degreesPerPoint = 180 / (.pi * radius)
                lon = origin.lon - Double(value.translation.width) * degreesPerPoint
                lat = min(80, max(-80, origin.lat + Double(value.translation.height) * degreesPerPoint))
            }
            .onEnded { _ in
                spinStart = .now
                dragOrigin = nil
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchOrigin == nil {
                    lon = currentLon(at: .now)
                    pinchOrigin = zoom
                }
                guard let origin = pinchOrigin else { return }
                zoom = clampZoom(origin * Double(value.magnification))
            }
            .onEnded { _ in
                spinStart = .now
                pinchOrigin = nil
            }
    }

    /// Flies to the spot in three moves: zoom back out (if zoomed in), spin
    /// round at least once while tilting to its latitude, then land by zooming in.
    /// With Reduce Motion on, it just glides straight there.
    private func fly(to spot: GlobeDestination) {
        flight += 1
        let thisFlight = flight
        lon = currentLon(at: .now)
        isFlying = true
        let targetLat = min(80, max(-80, spot.latitude))

        func turn() -> Double {
            let raw = (spot.longitude - lon).truncatingRemainder(dividingBy: 360)
            return raw > 180 ? raw - 360 : (raw < -180 ? raw + 360 : raw)
        }

        func land() {
            guard thisFlight == flight else { return }
            withAnimation(.smooth(duration: 0.9)) {
                zoom = max(zoom, 6)
            } completion: {
                guard thisFlight == flight else { return }
                isFlying = false
                onArrive()
            }
        }

        if reduceMotion {
            withAnimation(.smooth(duration: 0.8)) {
                lon += turn()
                lat = targetLat
            } completion: { land() }
            return
        }

        func spin() {
            guard thisFlight == flight else { return }
            let shortest = turn()
            // One full extra turn in the direction of travel, so it reads as a spin.
            let spinTurn = shortest + (shortest >= 0 ? 360 : -360)
            withAnimation(.easeInOut(duration: 1.6)) {
                lon += spinTurn
                lat = targetLat
            } completion: { land() }
        }

        if zoom > 1.3 {
            withAnimation(.smooth(duration: 0.6)) { zoom = 1 } completion: { spin() }
        } else {
            spin()
        }
    }

    private func zoomOut() {
        flight += 1
        isFlying = false
        spinStart = .now
        withAnimation(.smooth(duration: 0.9)) { zoom = 1 }
    }

    private func doubleTapZoom() {
        lon = currentLon(at: .now)
        spinStart = .now
        withAnimation(.smooth(duration: 0.45)) {
            zoom = zoom >= Self.zoomRange.upperBound * 0.9 ? 1 : clampZoom(zoom * 2.5)
        }
    }
}

/// The shader-drawn globe itself, plus the marker pin. It's `Animatable` on
/// its position and radius, so changes made inside `withAnimation` glide
/// instead of jumping.
private struct GlobeLayer: View, Animatable {
    var center: CGPoint
    var baseRadius: Double
    var radius: Double
    var lon: Double
    var lat: Double
    var marker: GlobeDestination?

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(lon, AnimatablePair(lat, radius)) }
        set {
            lon = newValue.first
            lat = newValue.second.first
            radius = newValue.second.second
        }
    }

    /// Where a latitude/longitude lands on screen, or nil when it's on the far side.
    /// This is the shader's orthographic projection run forwards.
    private func project(latitude: Double, longitude: Double) -> CGPoint? {
        let phi = latitude * .pi / 180
        let lambda = (longitude - lon) * .pi / 180
        let tilt = lat * .pi / 180
        let x = cos(phi) * sin(lambda)
        let worldY = sin(phi)
        let worldZ = cos(phi) * cos(lambda)
        let y = worldY * cos(tilt) - worldZ * sin(tilt)
        let z = worldY * sin(tilt) + worldZ * cos(tilt)
        guard z > 0.02 else { return nil }
        return CGPoint(x: center.x + x * radius, y: center.y - y * radius)
    }

    private static let relief = Image(uiImage: UIImage(named: "globe-relief.png") ?? UIImage())

    var body: some View {
        Rectangle()
            .fill(.white)
            .colorEffect(
                ShaderLibrary.topoGlobe(
                    .float2(center),
                    .float(Float(radius)),
                    .float(Float(radius / baseRadius)),
                    .float(Float(lon * .pi / 180)),
                    .float(Float(lat * .pi / 180)),
                    .image(Self.relief),
                    .color(Theme.globeLand),
                    .color(Theme.globeSea),
                    .color(Theme.globeLandInk),
                    .color(Theme.globeSeaInk)
                )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .overlay {
                if let marker, let point = project(latitude: marker.latitude, longitude: marker.longitude) {
                    GlobePin(name: marker.name)
                        .position(x: point.x, y: point.y)
                }
            }
    }
}

/// Map pin: a dark dot ringed in white (it sits on white land), with the name on a white tag above
/// it. The view is laid out around the dot, so `.position` puts the dot
/// exactly on the spot.
private struct GlobePin: View {
    let name: String

    var body: some View {
        Circle()
            .fill(Theme.onAccent)
            .frame(width: 16, height: 16)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .overlay(alignment: .bottom) {
                Text(name)
                    .font(.cairn(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.surface, in: Capsule())
                    .fixedSize()
                    .alignmentGuide(.bottom) { $0[.bottom] + 22 }
            }
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
