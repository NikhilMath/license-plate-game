import SwiftUI

struct LeaderboardView: View {
    @Environment(GameStore.self) private var store

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(store.ranked.enumerated()), id: \.element.id) { index, player in
                        NavigationLink(value: player.id) {
                            LeaderboardRow(rank: rank(of: player, at: index), player: player,
                                           isCurrent: player.id == store.currentPlayer?.id)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.remove(player) }
                                .disabled(store.players.count == 1)
                        }
                    }
                } footer: {
                    Text("Tap a player to see their plates. Swipe left to remove a player.")
                }
            }
            .navigationTitle("Leaderboard")
            .navigationDestination(for: UUID.self) { id in
                PlayerDetailView(playerID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("New Road Trip (reset plates)", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmingReset = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Player", systemImage: "person.badge.plus") {
                        newName = ""
                        showingAdd = true
                    }
                }
            }
            .alert("Add Player", isPresented: $showingAdd) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { store.addPlayer(named: name) }
                }
            }
            .confirmationDialog("Start a new road trip?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset All Plates", role: .destructive) { store.resetAllPlates() }
            } message: {
                Text("Everyone keeps their name, but every spotted plate is cleared.")
            }
        }
    }

    /// Players tied on count share a rank.
    private func rank(of player: Player, at index: Int) -> Int {
        (store.ranked.firstIndex { $0.count == player.count } ?? index) + 1
    }
}

private struct LeaderboardRow: View {
    let rank: Int
    let player: Player
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 14) {
            rankBadge
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(player.name).font(.headline)
                    if isCurrent {
                        Text("PLAYING")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(player.color.opacity(0.2), in: Capsule())
                            .foregroundStyle(player.color)
                    }
                    Spacer()
                    Text("\(player.count)")
                        .font(.title3.bold().monospacedDigit())
                    + Text(" / \(USState.all.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                ProgressView(value: Double(player.count), total: Double(USState.all.count))
                    .tint(player.color)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var rankBadge: some View {
        switch rank {
        case 1:
            Image(systemName: "crown.fill").font(.title2).foregroundStyle(.yellow)
        case 2:
            Image(systemName: "medal.fill").font(.title2).foregroundStyle(.gray)
        case 3:
            Image(systemName: "medal.fill").font(.title2).foregroundStyle(.brown)
        default:
            Text("\(rank)").font(.title3.bold()).foregroundStyle(.secondary)
        }
    }
}

struct PlayerDetailView: View {
    @Environment(GameStore.self) private var store
    let playerID: UUID

    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        if let player = store.players.first(where: { $0.id == playerID }) {
            let spotted = player.spotted
                .compactMap { code, date in USState.byCode[code].map { ($0, date) } }
                .sorted { $0.1 > $1.1 }
            let needed = USState.all.filter { !player.hasSpotted($0) }

            List {
                Section {
                    Button("Play as \(player.name)", systemImage: "steeringwheel") {
                        store.currentPlayerID = player.id
                    }
                    .disabled(store.currentPlayer?.id == player.id)
                }
                Section("Spotted (\(spotted.count))") {
                    if spotted.isEmpty {
                        Text("Nothing yet. Keep your eyes on the road!").foregroundStyle(.secondary)
                    }
                    ForEach(spotted, id: \.0.id) { state, date in
                        HStack {
                            Text(state.code)
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundStyle(state.region.color)
                                .frame(width: 36, alignment: .leading)
                            Text(state.name)
                            Spacer()
                            Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Still Needed (\(needed.count))") {
                    ForEach(needed) { state in
                        HStack {
                            Text(state.code)
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .leading)
                            Text(state.name).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(player.name)
            .toolbar {
                Button("Rename") {
                    newName = player.name
                    renaming = true
                }
            }
            .alert("Rename Player", isPresented: $renaming) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { store.rename(player, to: name) }
                }
            }
        } else {
            ContentUnavailableView("Player removed", systemImage: "person.slash")
        }
    }
}
