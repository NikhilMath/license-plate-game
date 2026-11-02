import SwiftUI

struct PlatesView: View {
    @Environment(GameStore.self) private var store

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", needed = "Needed", spotted = "Spotted"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var pendingRemoval: USState?
    @State private var spotCount = 0
    @State private var showCompleted = false

    private let columns = [GridItem(.adaptive(minimum: 105), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let player = store.currentPlayer {
                    ProgressHeader(player: player)
                        .padding(.horizontal)

                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
                        ForEach(Region.allCases) { region in
                            let states = visibleStates(in: region, for: player)
                            if !states.isEmpty {
                                Text(region.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(region.color)
                                    .padding(.horizontal)
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(states) { state in
                                        plateButton(state, player: player)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)

                    if Region.allCases.allSatisfy({ visibleStates(in: $0, for: player).isEmpty }) {
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
            .alert("All 51 plates!", isPresented: $showCompleted) {
                Button("Woo!") {}
            } message: {
                Text("\(store.currentPlayer?.name ?? "You") spotted every state and DC.")
            }
        }
    }

    private func plateButton(_ state: USState, player: Player) -> some View {
        let spotted = player.hasSpotted(state)
        return Button {
            if spotted {
                pendingRemoval = state
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    store.setSpotted(state, true, for: player)
                }
                spotCount += 1
                if store.currentPlayer?.count == USState.all.count { showCompleted = true }
            }
        } label: {
            LicensePlateCard(state: state, spotted: spotted, spotters: store.spotters(of: state))
        }
        .buttonStyle(.plain)
    }

    private func visibleStates(in region: Region, for player: Player) -> [USState] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return USState.all.filter { state in
            guard state.region == region else { return false }
            switch filter {
            case .all: break
            case .needed: if player.hasSpotted(state) { return false }
            case .spotted: if !player.hasSpotted(state) { return false }
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
    let player: Player

    var body: some View {
        let total = USState.all.count
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(player.color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(player.count) / CGFloat(total))
                    .stroke(player.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(player.count)")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.title3.bold())
                Text("\(player.count) of \(total) plates spotted")
                    .foregroundStyle(.secondary)
                Text("\(total - player.count) to go")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(player.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.snappy, value: player.count)
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
