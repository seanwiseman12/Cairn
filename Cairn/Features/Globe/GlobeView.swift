import MapKit
import SwiftUI

/// Home tab. Phase 3 adds adventure pins and the stats header.
struct GlobeView: View {
    // Zoomed far out so MapKit renders the 3D globe.
    @State private var camera: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: .init(latitude: 20, longitude: 0), distance: 30_000_000)
    )

    var body: some View {
        Map(position: $camera)
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea(edges: .top)
    }
}
