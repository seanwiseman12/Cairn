import MapKit
import SwiftUI

/// A spot the globe is showing because the user picked it in search (also
/// what a saved plan points at, so it's Codable).
struct GlobeDestination: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double
    let symbol: String
    /// The bundled peak's GeoNames id, for looking up its photo. Nil for places.
    var peakID: Int64? = nil
    /// ISO country code and summit height, when known (peaks), for XP estimates.
    var countryCode: String? = nil
    var elevation: Int? = nil
}

/// Search state for the Globe tab: mountains from the bundled database and
/// places from Apple's autocomplete, refreshed as the user types.
@Observable
@MainActor
final class GlobeSearchModel {
    var query = ""
    private(set) var peaks: [Peak] = []
    private(set) var places: [MKLocalSearchCompletion] = []

    private let placeSearch = PlaceSearch()
    private var peakTask: Task<Void, Never>?

    var hasResults: Bool { !peaks.isEmpty || !places.isEmpty }

    /// Call whenever `query` changes.
    func refresh() {
        let text = query
        peakTask?.cancel()
        peakTask = Task {
            // Wait for a short pause in typing before hitting the database.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let found = await PeakSearch.shared.search(text)
            guard !Task.isCancelled else { return }
            peaks = found
        }
        placeSearch.update(text) { [weak self] results in
            self?.places = results
        }
    }

    func clear() {
        query = ""
        peakTask?.cancel()
        peaks = []
        places = []
    }

    func destination(for peak: Peak) -> GlobeDestination {
        var details: [String] = []
        if let elevation = peak.elevation {
            details.append(Measurement(value: Double(elevation), unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided)))
        }
        if let country = Locale.current.localizedString(forRegionCode: peak.countryCode) {
            details.append(country)
        }
        if details.isEmpty { details.append(peak.kind.label) }
        return GlobeDestination(
            id: "peak-\(peak.id)",
            name: peak.name,
            subtitle: details.joined(separator: " · "),
            latitude: peak.latitude,
            longitude: peak.longitude,
            symbol: peak.kind.symbol,
            peakID: peak.id,
            countryCode: peak.countryCode.isEmpty ? nil : peak.countryCode,
            elevation: peak.elevation
        )
    }

    func destination(for place: MKLocalSearchCompletion) async -> GlobeDestination? {
        guard let coordinate = await placeSearch.coordinate(for: place) else { return nil }
        return GlobeDestination(
            id: "place-\(place.title)-\(place.subtitle)",
            name: place.title,
            subtitle: place.subtitle,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            symbol: "mappin.and.ellipse"
        )
    }
}

/// White pill search field: "Search mountains & places".
struct GlobeSearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    /// Over a location photo: a see-through white pill with dark text and a thin
    /// underline, so the photo shows through. Otherwise a frosted dark pill.
    var onPhoto = false

    var body: some View {
        HStack(spacing: 10) {
            TextField("", text: $text,
                      prompt: Text("Search mountains & places")
                          .foregroundStyle(onPhoto ? Theme.onAccent.opacity(0.7) : Theme.textSecondary))
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .font(.cairn(.body, weight: .medium))
                .foregroundStyle(onPhoto ? Theme.onAccent : .white)
                .tint(onPhoto ? Theme.onAccent : Theme.accent)
            Button {
                if text.isEmpty { isFocused.wrappedValue = true } else { text = "" }
            } label: {
                Image(systemName: text.isEmpty ? "magnifyingglass" : "xmark")
                    .font(.cairn(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(onPhoto ? Theme.onAccent : Theme.surfaceMuted, in: Circle())
            }
            .accessibilityLabel(text.isEmpty ? "Search" : "Clear search")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .frame(minHeight: 56)
        .background {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(onPhoto ? Theme.accent.opacity(0.42) : Theme.surface.opacity(0.75))
        }
        .overlay(alignment: .bottom) {
            if onPhoto {
                // The thin rule under the text, like a field on paper.
                Capsule()
                    .fill(Theme.onAccent.opacity(0.75))
                    .frame(height: 1.5)
                    .padding(.leading, 20)
                    .padding(.trailing, 56)
                    .padding(.bottom, 9)
            }
        }
        .overlay(Capsule().strokeBorder(onPhoto ? Color.white.opacity(0.2) : Theme.border, lineWidth: 1))
        .environment(\.colorScheme, onPhoto ? .light : .dark)
    }
}

/// Results list under the search bar: Mountains, then Places.
struct GlobeSearchResults: View {
    let model: GlobeSearchModel
    let onPickPeak: (Peak) -> Void
    let onPickPlace: (MKLocalSearchCompletion) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !model.peaks.isEmpty {
                    sectionHeader("Mountains")
                    ForEach(model.peaks) { peak in
                        let destination = model.destination(for: peak)
                        row(symbol: destination.symbol, title: peak.name, subtitle: destination.subtitle) {
                            onPickPeak(peak)
                        }
                    }
                }
                if !model.places.isEmpty {
                    sectionHeader("Places")
                    ForEach(model.places, id: \.self) { place in
                        row(symbol: "mappin.and.ellipse", title: place.title, subtitle: place.subtitle) {
                            onPickPlace(place)
                        }
                    }
                }
                if !model.hasResults {
                    Text(model.query.count < 2 ? "Type a mountain, town or park." : "Nothing found yet. Try another spelling.")
                        .font(.cairn(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                }
                Text("Mountain data © GeoNames (CC BY 4.0)")
                    .font(.cairn(.caption2))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(.top, 6)
        }
        .scrollDismissesKeyboard(.immediately)
        .frame(maxHeight: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.cairn(.footnote, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func row(symbol: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.cairn(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.surfaceMuted, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.cairn(.body, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.cairn(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Card for the spot the globe flew to (shown during the flight, and when the
/// spot has no photo): name, details and a "Log" button.
struct DestinationCard: View {
    let destination: GlobeDestination
    var isPlanned = false
    let onPlan: () -> Void
    let onLog: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: destination.symbol)
                    .font(.cairn(.title2))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.name)
                        .font(.cairn(.headline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Label(destination.subtitle, systemImage: "mappin.and.ellipse")
                        .font(.cairn(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    CircleIconLabel(symbol: "xmark", size: 36)
                }
                .accessibilityLabel("Close")
            }
            HStack(spacing: 10) {
                Button(action: onPlan) {
                    Label(isPlanned ? "Planned" : "Plan", systemImage: isPlanned ? "bookmark.fill" : "bookmark")
                        .font(.cairn(.headline))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 54)
                        .background(Theme.surfaceMuted, in: Capsule())
                }
                .accessibilityHint(isPlanned ? "Edit your plan" : "Save it to Plans")
                Button("Log it here", action: onLog)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .card(padding: 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}
