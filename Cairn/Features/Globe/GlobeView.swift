import MapKit
import SwiftUI

/// Home tab: a full-screen photo behind the headline, search and category
/// chips. On launch it's a famous mountain picked at random (`HomeBackdrops`).
/// Picking a mountain or place fades to the globe, which flies there (spin and
/// land), then swaps to a full-screen photo of the spot. Closing it goes back
/// to the opening photo. If a photo can't load, the globe stays instead.
/// Pins for logged adventures, real stats and chip filtering arrive in Phase 3.
struct GlobeView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(PlanStore.self) private var plans
    @Environment(AppRouter.self) private var router
    /// The place whose Plan form is open.
    @State private var planning: GlobeDestination?
    @State private var showLogSheet = DebugLaunch.showLogSheet
    @State private var search = GlobeSearchModel()
    @FocusState private var searchFocused: Bool
    @State private var destination: GlobeDestination?
    @State private var category: AdventureCategory = .all
    /// The current destination's photo and its downloaded picture (nil until ready).
    @State private var photo: PlacePhoto?
    @State private var photoImage: UIImage?
    /// True once the globe has landed on the current destination.
    @State private var hasLanded = false

    /// The launch photo, shown before any search.
    private struct Opening {
        let spot: GlobeDestination
        let photo: PlacePhoto
        let image: UIImage
    }
    @State private var opening: Opening?
    /// The launch photo couldn't load (e.g. offline): show the globe instead.
    @State private var openingFailed = false

    /// The photo on screen: the picked spot's once the globe has landed on it,
    /// otherwise the launch photo.
    private var shownPhoto: (photo: PlacePhoto, image: UIImage)? {
        if destination != nil {
            guard hasLanded, let photo, let photoImage else { return nil }
            return (photo, photoImage)
        }
        return opening.map { ($0.photo, $0.image) }
    }

    private var showsPhoto: Bool { shownPhoto != nil }

    /// The globe shows during a flight, on a spot with no photo, or when the
    /// launch photo failed. While the launch photo loads, it's just the dark gradient.
    private var showsGlobe: Bool { destination != nil || openingFailed }

    private var isSearching: Bool { searchFocused || !search.query.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if destination != nil, let shown = shownPhoto {
                    photoTopBar(shown.photo)
                } else {
                    topBar(credit: shownPhoto?.photo)
                }
            }
            .transition(.opacity)
            Spacer(minLength: 12)

            Group {
                if isSearching {
                    GlobeSearchResults(model: search, onPickPeak: pick, onPickPlace: pick)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if let destination, showsPhoto {
                    photoHeadline(destination)
                        .transition(.opacity)
                } else if let destination {
                    DestinationCard(
                        destination: destination,
                        isPlanned: plans.plan(forPlace: destination.id) != nil,
                        onPlan: { planning = destination },
                        onLog: { showLogSheet = true },
                        onClose: close
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    headline(photoOf: opening?.spot)
                        .transition(.opacity)
                }
            }
            .padding(.bottom, 20)

            GlobeSearchBar(text: $search.query, isFocused: $searchFocused, onPhoto: showsPhoto)
                .padding(.bottom, 14)

            categoryChips
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background { backdrop }
        .animation(.smooth(duration: 0.25), value: isSearching)
        .onChange(of: search.query) { search.refresh() }
        .task {
            await loadOpeningPhoto()
        }
        .task {
            // Debug-only: open with a search typed in, for screenshots.
            if let query = DebugLaunch.searchQuery {
                search.query = query
                searchFocused = !DebugLaunch.pickFirstResult
                if DebugLaunch.pickFirstResult {
                    try? await Task.sleep(for: .seconds(1.5))
                    if let first = search.peaks.first { pick(first) }
                }
            }
        }
        .sheet(isPresented: $showLogSheet) {
            LogSheet()
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
        }
        .sheet(item: $planning) { place in
            PlanSheet(place: place, existing: plans.plan(forPlace: place.id))
                .presentationDetents([.large])
                .presentationBackground(Theme.background)
        }
        // Requests from other tabs (Plans): fly to a place, or open search.
        .onChange(of: router.focusRequest, initial: true) { _, place in
            guard let place else { return }
            router.focusRequest = nil
            show(place)
        }
        .onChange(of: router.searchRequest, initial: true) { _, requested in
            guard requested else { return }
            router.searchRequest = false
            searchFocused = true
        }
    }

    /// Full-screen scene behind everything: sky-to-valley gradient, the globe,
    /// and a dark fade at the bottom so the text over it stays readable.
    private var backdrop: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Theme.homeSky, Theme.homeMid, Theme.homeDeep],
                               startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6))

                // Only built when needed, so it isn't spinning (and using the
                // GPU) hidden behind the launch photo.
                if showsGlobe {
                    TopoGlobe(reservedTop: geo.size.height * 0.135,
                              reservedBottom: geo.size.height * 0.52,
                              focus: destination,
                              onArrive: { withAnimation(.easeInOut(duration: 0.8)) { hasLanded = true } })
                        .transition(.opacity)
                }

                if let shown = shownPhoto {
                    Image(uiImage: shown.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }

                // Over the globe: a deep fade so the text sits on near-black.
                // Over a photo: just enough shade low down to read the text,
                // so the photo stays the star (like a magazine cover).
                LinearGradient(stops: showsPhoto
                               ? [.init(color: .black.opacity(0), location: 0.34),
                                  .init(color: .black.opacity(0.4), location: 0.58),
                                  .init(color: .black.opacity(0.7), location: 1)]
                               : [.init(color: Theme.homeDeep.opacity(0), location: 0.45),
                                  .init(color: Theme.homeDeep.opacity(0.85), location: 0.68),
                                  .init(color: Theme.homeDeep, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)

                // A soft dark band at the top keeps the status bar and the pills
                // readable when the globe is zoomed into pale land.
                LinearGradient(colors: [Theme.homeDeep.opacity(showsPhoto ? 0.4 : 0.75), Theme.homeDeep.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * 0.16)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { searchFocused = false }
        }
        .ignoresSafeArea()
    }

    /// Picks a random famous mountain and loads its photo for the launch screen.
    private func loadOpeningPhoto() async {
        guard opening == nil, !openingFailed else { return }
        guard let peak = await PeakSearch.shared.peak(id: HomeBackdrops.randomPeakID()) else {
            openingFailed = true
            return
        }
        let spot = search.destination(for: peak)
        guard let photo = await PlacePhotos.shared.photo(for: spot),
              let image = await PlacePhotos.shared.image(for: photo)
        else {
            withAnimation(.easeInOut(duration: 0.6)) { openingFailed = true }
            return
        }
        withAnimation(.easeInOut(duration: 0.8)) {
            opening = Opening(spot: spot, photo: photo, image: image)
        }
    }

    /// Small dark pills: rank on the left; on the right, the photo credit when a
    /// photo is showing (its free license requires it), otherwise total XP.
    private func topBar(credit: PlacePhoto?) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "mountain.2.fill")
                    .font(.cairn(.caption))
                    .foregroundStyle(Theme.homeDeep)
                    .frame(width: 26, height: 26)
                    .background(Theme.accent, in: Circle())
                Text("\(progress.progression.level.rank.title) · Lv \(progress.progression.level.number)")
                    .font(.cairn(.footnote, weight: .semibold))
            }
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .background(Theme.homeDeep.opacity(0.88), in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rank: \(progress.progression.level.rank.title), level \(progress.progression.level.number)")

            Spacer()

            if let credit {
                creditPill(credit)
            } else {
                HStack(spacing: 6) {
                    Text("\(progress.progression.totalXP.formatted()) XP")
                    Image(systemName: "sparkles")
                }
                .font(.cairn(.caption, weight: .medium))
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(Theme.homeDeep.opacity(0.88), in: Capsule())
                .accessibilityElement(children: .combine)
            }
        }
        .foregroundStyle(.white)
    }

    /// Over a photo: a see-through close button on the left and the photo
    /// credit (which its free license requires) in a small dark pill on the right.
    private func photoTopBar(_ photo: PlacePhoto) -> some View {
        HStack(alignment: .center) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.cairn(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(Color.black.opacity(0.2), in: Circle())
                    .environment(\.colorScheme, .dark)
            }
            .accessibilityLabel("Close")

            Spacer(minLength: 24)

            creditPill(photo)
        }
    }

    /// The photo credit in a small dark pill; tapping opens the photo's source page.
    private func creditPill(_ photo: PlacePhoto) -> some View {
        Link(destination: photo.creditURL) {
            HStack(spacing: 5) {
                Image(systemName: "camera")
                Text(photo.shortCredit)
                    .lineLimit(1)
            }
            .font(.cairn(.caption2, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Theme.homeDeep.opacity(0.78), in: Capsule())
        }
        .accessibilityLabel(photo.creditLine)
        .accessibilityHint("Opens the photo's source page")
    }

    /// Over a photo: kicker, the place's name big in white, then where it is and
    /// a small white "Log" pill.
    private func photoHeadline(_ spot: GlobeDestination) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your next adventure")
                .font(.cairn(.subheadline, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(spot.name)
                .font(.cairn(size: 52, weight: .semibold, relativeTo: .largeTitle))
                .foregroundStyle(Theme.accent)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Label(spot.subtitle, systemImage: "mappin.and.ellipse")
                .font(.cairn(.subheadline))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            HStack(spacing: 10) {
                let isPlanned = plans.plan(forPlace: spot.id) != nil
                Button { planning = spot } label: {
                    Label(isPlanned ? "Planned" : "Plan", systemImage: isPlanned ? "bookmark.fill" : "bookmark")
                        .font(.cairn(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(.black.opacity(0.45), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                }
                .accessibilityHint(isPlanned ? "Edit your plan" : "Save it to Plans")
                Button { showLogSheet = true } label: {
                    Label("Log", systemImage: "plus")
                        .font(.cairn(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 36)
                        .background(Theme.accent, in: Capsule())
                }
                .accessibilityLabel("Log an adventure here")
            }
            .padding(.top, 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, y: 1)
    }

    /// "Adventure Awaits". Over the launch photo, the location line names the
    /// mountain in it, like a magazine cover caption.
    private func headline(photoOf spot: GlobeDestination?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome back, Explorer")
                .font(.cairn(.subheadline, weight: .semibold))
                .foregroundStyle(spot == nil ? Theme.homeMuted : .white.opacity(0.9))
            // Two lines pulled together: SwiftUI ignores negative line spacing,
            // and Outfit's built-in leading is loose at display sizes.
            VStack(alignment: .leading, spacing: -14) {
                Text("Adventure")
                Text("Awaits")
            }
            .font(.cairn(size: 52, weight: .semibold, relativeTo: .largeTitle))
            .foregroundStyle(Theme.accent)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Label(spot.map { "\($0.name) · \($0.subtitle)" } ?? "Every summit on Earth, on one globe",
                  systemImage: "mappin.and.ellipse")
                .font(.cairn(.subheadline))
                .foregroundStyle(spot == nil ? Theme.homeMuted : .white.opacity(0.85))
                .lineLimit(1)
                .padding(.top, 4)
        }
        .shadow(color: .black.opacity(spot == nil ? 0 : 0.5), radius: 8, y: 1)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdventureCategory.allCases) { item in
                    let isSelected = category == item
                    Button {
                        withAnimation(.snappy) { category = item }
                    } label: {
                        Chip(title: item.title, symbol: item.symbol, isSelected: isSelected, onPhoto: showsPhoto)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }

    private func pick(_ peak: Peak) {
        show(search.destination(for: peak))
    }

    private func pick(_ place: MKLocalSearchCompletion) {
        Task {
            if let found = await search.destination(for: place) { show(found) }
        }
    }

    private func show(_ spot: GlobeDestination) {
        searchFocused = false
        search.clear()
        // Picked the spot that's already showing: nothing to fly to.
        guard destination?.id != spot.id else { return }
        // Fade any current photo back to the globe; it flies to the new spot
        // while the new photo downloads.
        withAnimation(.easeInOut(duration: 0.5)) {
            hasLanded = false
            photoImage = nil
            photo = nil
        }
        withAnimation(.smooth) { destination = spot }
        Task {
            guard let found = await PlacePhotos.shared.photo(for: spot),
                  let image = await PlacePhotos.shared.image(for: found),
                  destination?.id == spot.id // still the current pick
            else { return }
            withAnimation(.easeInOut(duration: 0.8)) {
                photo = found
                photoImage = image
            }
            await PlacePhotos.shared.reportShown(found)
        }
    }

    private func close() {
        withAnimation(.smooth) {
            destination = nil
            hasLanded = false
            photoImage = nil
            photo = nil
        }
    }
}

/// Category chips above the globe. They'll filter the globe's pins once
/// adventures can be logged (Phase 3).
enum AdventureCategory: String, CaseIterable, Identifiable {
    case all, hiking, skiing, summits, climbing, camping

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .hiking: "Hiking"
        case .summits: "Summits"
        case .climbing: "Climbing"
        case .skiing: "Skiing"
        case .camping: "Camping"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .hiking: "figure.hiking"
        case .summits: "mountain.2.fill"
        case .climbing: "figure.climbing"
        case .skiing: "figure.skiing.downhill"
        case .camping: "tent.fill"
        }
    }
}
