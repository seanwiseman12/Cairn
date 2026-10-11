import MapKit
import SwiftUI

/// Home tab: the globe, a journal header with stats and level, and the + button.
/// Pins and real stats arrive once adventures can be logged (Phase 3).
struct GlobeView: View {
    // Zoomed far out so MapKit renders the 3D globe.
    @State private var camera: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: .init(latitude: 25, longitude: -45), distance: 45_000_000)
    )
    @State private var showLogSheet = DebugLaunch.showLogSheet

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $camera)
                // Satellite imagery is the style that renders as a true 3D globe when zoomed out.
                .mapStyle(.imagery(elevation: .realistic))
                .mapControls { }
                .safeAreaInset(edge: .top) {
                    JournalSummaryCard()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

            Button {
                showLogSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Theme.rust, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .accessibilityLabel("Log an adventure")
            .padding(20)
        }
        .background(.black)
        .sheet(isPresented: $showLogSheet) {
            LogSheet()
                .presentationDetents([.medium, .large])
                .presentationBackground { ContourBackground() }
        }
    }
}

/// Header card: title, the four headline stats, and level progress.
private struct JournalSummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("MY JOURNAL")
                    .font(.display(32, relativeTo: .title))
                    .tracking(1)
                    .foregroundStyle(Theme.ink)
                Spacer()
                // Level numbers use the display face: the italic's old-style "1" reads like "I".
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Trailhead")
                        .font(.script(20, relativeTo: .subheadline))
                    Text("LV 1")
                        .font(.display(20, relativeTo: .subheadline))
                        .tracking(0.8)
                }
                .foregroundStyle(Theme.forest)
            }

            HStack(spacing: 0) {
                Stat(value: "0", label: "Countries")
                Stat(value: "0", label: "Continents")
                Stat(value: "0", label: "Summits")
                Stat(value: "0 m", label: "Climbed")
            }

            PencilProgressBar(progress: 0)
        }
        .journalCard(padding: 14)
    }

    private struct Stat: View {
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 2) {
                Text(value)
                    .font(.display(30, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                Text(label).journalLabel()
            }
            .frame(maxWidth: .infinity)
        }
    }
}
