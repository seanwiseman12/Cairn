import SwiftUI

/// Plans tab: adventures you want to do next. "Up next" holds dated plans,
/// soonest first; "Someday" holds the rest in the order you drag them into.
/// Filter by type, tap a plan to fly the globe there, swipe to edit or remove,
/// and "Log it" once you've been.
struct PlansView: View {
    @Environment(PlanStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(AppRouter.self) private var router

    @State private var filter: AdventureType?
    @State private var editing: PlannedAdventure?
    @State private var showLogSheet = false

    private func matches(_ plan: PlannedAdventure) -> Bool { filter == nil || plan.type == filter }
    private var upcoming: [PlannedAdventure] { store.upcoming.filter(matches) }
    private var someday: [PlannedAdventure] { store.someday.filter(matches) }

    var body: some View {
        List {
            header
                .plainRow(top: 12)

            if store.plans.isEmpty {
                emptyState.plainRow()
            } else {
                filterChips.plainRow()

                if !upcoming.isEmpty {
                    sectionTitle("Up next", detail: "Soonest first").plainRow(top: 10)
                    ForEach(upcoming) { plan in
                        row(plan).plainRow()
                    }
                }

                if !someday.isEmpty {
                    sectionTitle("Someday", detail: filter == nil ? "Hold and drag to reorder" : nil)
                        .plainRow(top: 10)
                    ForEach(someday) { plan in
                        row(plan).plainRow()
                    }
                    // Reordering only makes sense on the full list, not a filtered one.
                    .onMove(perform: filter == nil ? { store.moveSomeday(from: $0, to: $1) } : nil)
                }

                if upcoming.isEmpty && someday.isEmpty {
                    Text("No \(filter?.label.lowercased() ?? "") plans yet.")
                        .font(.cairn(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .plainRow(top: 10)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .sheet(item: $editing) { plan in
            PlanSheet(place: plan.place, existing: plan)
                .presentationDetents([.large])
                .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showLogSheet) {
            LogSheet()
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScreenTitle(text: "Plans")
            if !store.plans.isEmpty {
                let total = store.plans.reduce(0) { $0 + progress.progression.estimate(for: $1).xp }
                Text("\(store.plans.count) \(store.plans.count == 1 ? "adventure" : "adventures") · about \(total.formatted()) XP waiting")
                    .font(.cairn(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var filterChips: some View {
        let types = AdventureType.allCases.filter { type in store.plans.contains { $0.type == type } }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, title: "All", symbol: "square.grid.2x2.fill")
                ForEach(types) { chip($0, title: $0.label, symbol: $0.symbol) }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(_ type: AdventureType?, title: String, symbol: String) -> some View {
        Button {
            withAnimation(.snappy) { filter = type }
        } label: {
            Chip(title: title, symbol: symbol, isSelected: filter == type)
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(filter == type ? .isSelected : [])
    }

    private func sectionTitle(_ title: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionTitle(text: title)
            if let detail {
                Text(detail)
                    .font(.cairn(.caption))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
            }
        }
    }

    private func row(_ plan: PlannedAdventure) -> some View {
        PlanCard(plan: plan, estimate: progress.progression.estimate(for: plan),
                 onLog: { showLogSheet = true })
            .contentShape(Rectangle())
            .onTapGesture { router.showOnGlobe(plan.place) }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { store.remove(plan.id) } label: {
                    Label("Remove", systemImage: "trash")
                }
                Button { editing = plan } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(Theme.surfaceMuted)
            }
            .contextMenu {
                Button { router.showOnGlobe(plan.place) } label: { Label("Show on globe", systemImage: "globe") }
                Button { editing = plan } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) { store.remove(plan.id) } label: { Label("Remove", systemImage: "trash") }
            }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            EmptyStateCard(
                symbol: "bookmark",
                title: "Nothing planned yet",
                message: "Search any mountain or place on the globe and tap Plan to save it here."
            )
            Button("Find somewhere", action: router.startSearch)
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

/// One plan: photo, name, when, what, estimated XP, notes, and "Log it".
struct PlanCard: View {
    let plan: PlannedAdventure
    let estimate: PlanEstimate
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                PlaceThumbnail(place: plan.place)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.place.name)
                        .font(.cairn(.headline))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text(plan.place.subtitle)
                        .font(.cairn(.footnote))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        tag(plan.type.label, symbol: plan.type.symbol)
                        tag(whenText, symbol: plan.targetDate == nil ? "sparkles" : "calendar")
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }

            if !plan.notes.isEmpty {
                Text(plan.notes)
                    .font(.cairn(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("≈ +\(estimate.xp.formatted()) XP")
                        .font(.cairn(.subheadline, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.textPrimary)
                    if let note = estimate.listNote ?? (estimate.isNewCountry ? "New country!" : nil) {
                        Text(note)
                            .font(.cairn(.caption))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Button(action: onLog) {
                    // HStack, not Label: inside a List, Labels spread into columns.
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Log it")
                    }
                        .font(.cairn(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Log \(plan.place.name)")
            }
        }
        .card()
        .accessibilityElement(children: .contain)
    }

    private var whenText: String {
        guard let date = plan.targetDate else { return "Someday" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now),
                                                   to: Calendar.current.startOfDay(for: date)).day ?? 0
        let relative = switch days {
        case 0: "today"
        case 1: "tomorrow"
        case let n where n < 0: "\(-n)d ago"
        case let n where n < 60: "\(n)d"
        default: "\(days / 30)mo"
        }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())) · \(relative)"
    }

    private func tag(_ text: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text)
        }
            .font(.cairn(.caption, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(minHeight: 24)
            .background(Theme.surfaceMuted, in: Capsule())
    }
}

/// Small square photo of a place (its Wikimedia or Unsplash photo), or its
/// icon while loading or when there's no photo.
struct PlaceThumbnail: View {
    let place: GlobeDestination
    var size: CGFloat = 72

    @State private var image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
            .fill(Theme.surfaceMuted)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: place.symbol)
                        .font(.cairn(.title3))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .task(id: place.id) {
                guard image == nil, let photo = await PlacePhotos.shared.photo(for: place) else { return }
                let loaded = await PlacePhotos.shared.image(for: photo)
                withAnimation(.easeInOut(duration: 0.3)) { image = loaded }
            }
            .accessibilityHidden(true)
    }
}

private extension View {
    /// A List row with no background, separator or default insets.
    func plainRow(top: CGFloat = 6) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: 6, trailing: 20))
    }
}
