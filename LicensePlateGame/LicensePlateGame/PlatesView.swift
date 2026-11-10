import SwiftUI

struct PlatesView: View {
    @Environment(GameStore.self) private var store

    enum Filter: String, CaseIterable, Identifiable {
        case needed = "Needed", spotted = "Spotted", all = "All"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .needed
    @State private var search = ""
    @State private var pendingRemoval: USState?
    @State private var spotCount = 0
    @State private var showCompleted = false
    /// Co-op: who already has the plate that was just tapped.
    @State private var alreadySpotted: String?

    private let columns = [GridItem(.adaptive(minimum: 105), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let player = store.currentPlayer {
                    Group {
                        if store.mode == .coop {
                            ProgressHeader(title: "Team", count: store.teamCount, color: .green,
                                           noun: "plates spotted together")
                        } else {
                            ProgressHeader(title: player.name, count: player.count, color: player.color,
                                           noun: "plates spotted")
                        }
                    }
                    .padding(.horizontal)

                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    let states = visibleStates(for: player)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(states) { state in
                            plateButton(state, player: player)
                        }
                    }
                    .padding()

                    if states.isEmpty {
                        ContentUnavailableView(emptyTitle, systemImage: "car.rear.road.lane")
                            .padding(.top, 40)
                    }
                }
            }
            .navigationTitle("Plates")
            .searchable(text: $search, prompt: "Search states")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { PlayerSwitcher() }
            }
            .sensoryFeedback(.success, trigger: spotCount)
            .confirmationDialog(
                "Remove \(pendingRemoval?.name ?? "")?",
                isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                titleVisibility: .visible
            ) {
                Button("Remove Plate", role: .destructive) {
                    if let state = pendingRemoval, let player = store.currentPlayer {
                        withAnimation(.snappy) { store.setSpotted(state, false, for: player) }
                    }
                }
            } message: {
                Text("This takes it off \(store.currentPlayer?.name ?? "this player")'s list.")
            }
            .alert("Already spotted", isPresented: Binding(get: { alreadySpotted != nil },
                                                           set: { if !$0 { alreadySpotted = nil } })) {
                Button("OK") {}
            } message: {
                Text(alreadySpotted ?? "")
            }
            .alert("All 51 plates!", isPresented: $showCompleted) {
                Button("Woo!") {}
            } message: {
                Text(store.mode == .coop
                     ? "The team spotted every state and DC."
                     : "\(store.currentPlayer?.name ?? "You") spotted every state and DC.")
            }
        }
    }

    private func plateButton(_ state: USState, player: Player) -> some View {
        let spotted = store.isSpotted(state, for: player)
        return Button {
            if player.hasSpotted(state) {
                pendingRemoval = state
            } else if spotted {
                // Co-op, and a teammate has it. Only they can take it back.
                let names = store.spotters(of: state).map(\.name).formatted(.list(type: .and))
                alreadySpotted = "\(names) spotted \(state.name) for the team."
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    store.setSpotted(state, true, for: player)
                }
                spotCount += 1
                let count = store.mode == .coop ? store.teamCount : store.currentPlayer?.count
                if count == USState.all.count { showCompleted = true }
            }
        } label: {
            LicensePlateCard(state: state, spotted: spotted, spotters: store.spotters(of: state))
        }
        .buttonStyle(.plain)
    }

    private func visibleStates(for player: Player) -> [USState] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return USState.alphabetical.filter { state in
            switch filter {
            case .all: break
            case .needed: if store.isSpotted(state, for: player) { return false }
            case .spotted: if !store.isSpotted(state, for: player) { return false }
            }
            return query.isEmpty
                || state.name.localizedCaseInsensitiveContains(query)
                || state.code.localizedCaseInsensitiveContains(query)
        }
    }

    private var emptyTitle: String {
        if !search.isEmpty { return "No matches" }
        return filter == .spotted ? "No plates spotted yet" : "You've got them all!"
    }
}

private struct ProgressHeader: View {
    let title: String
    let count: Int
    let color: Color
    let noun: String

    var body: some View {
        let total = USState.all.count
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(count) / CGFloat(total))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(count)")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text("\(count) of \(total) \(noun)")
                    .foregroundStyle(.secondary)
                Text("\(total - count) to go")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.snappy, value: count)
    }
}

struct PlayerSwitcher: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Picker("Playing as", selection: Binding(
                get: { store.currentPlayer?.id },
                set: { store.currentPlayerID = $0 }
            )) {
                ForEach(store.players) { player in
                    Text("\(player.name) (\(player.count))").tag(Optional(player.id))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(store.currentPlayer?.color ?? .gray).frame(width: 10, height: 10)
                Text(store.currentPlayer?.name ?? "Player")
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
        }
    }
}
