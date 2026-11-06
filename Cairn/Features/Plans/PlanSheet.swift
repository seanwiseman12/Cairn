import SwiftUI

/// Plan an adventure at a place (or edit a plan): what you'll do, when, and notes.
struct PlanSheet: View {
    let place: GlobeDestination
    let existing: PlannedAdventure?

    @Environment(PlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var type: AdventureType
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var notes: String

    init(place: GlobeDestination, existing: PlannedAdventure?) {
        self.place = place
        self.existing = existing
        _type = State(initialValue: existing?.type ?? (place.peakID != nil ? .summit : .hike))
        _hasDate = State(initialValue: existing?.targetDate != nil)
        _date = State(initialValue: existing?.targetDate
                      ?? Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now)
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(existing == nil ? "Plan an adventure" : "Edit plan")
                        .font(.cairn(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(place.name)
                        .font(.cairn(.largeTitle, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Label(place.subtitle, systemImage: "mappin.and.ellipse")
                        .font(.cairn(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 28)

                section("What") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(AdventureType.allCases) { item in
                            Button {
                                type = item
                            } label: {
                                Chip(title: item.label, symbol: item.symbol, isSelected: type == item)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(type == item ? .isSelected : [])
                        }
                    }
                }

                section("When") {
                    HStack(spacing: 8) {
                        Button { withAnimation(.snappy) { hasDate = false } } label: {
                            Chip(title: "Someday", symbol: "sparkles", isSelected: !hasDate)
                        }
                        Button { withAnimation(.snappy) { hasDate = true } } label: {
                            Chip(title: "Pick a date", symbol: "calendar", isSelected: hasDate)
                        }
                    }
                    .buttonStyle(.plain)
                    if hasDate {
                        DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: .now)...,
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Theme.accent)
                            .padding(8)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                            .transition(.opacity)
                    }
                }

                section("Notes") {
                    TextField("Route, gear, who's coming…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(CairnFieldStyle())
                }

                VStack(spacing: 12) {
                    Button(existing == nil ? "Add to plans" : "Save changes", action: save)
                        .buttonStyle(PrimaryButtonStyle())
                    if let existing {
                        Button("Remove plan", role: .destructive) {
                            store.remove(existing.id)
                            dismiss()
                        }
                        .font(.cairn(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.cairn(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

    private func save() {
        var plan = existing ?? PlannedAdventure(place: place, type: type)
        plan.type = type
        plan.targetDate = hasDate ? date : nil
        plan.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        store.save(plan)
        dismiss()
    }
}
