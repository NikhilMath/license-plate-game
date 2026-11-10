import SwiftUI

struct LeaderboardView: View {
    @Environment(GameStore.self) private var store

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var confirmingReset = false

    @Environment(FriendSync.self) private var friendSync

    var body: some View {
        NavigationStack {
            let coop = store.mode == .coop
            let scores = scores
            List {
                Section {
                    Picker("Mode", selection: Binding(get: { store.mode }, set: { store.chooseMode($0) })) {
                        ForEach(GameMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Mode")
                } footer: {
                    Text(modeFooter)
                }

                FriendGroupSection()

                if coop {
                    Section("Team Progress") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(store.teamCount)")
                                    .font(.largeTitle.bold().monospacedDigit())
                                Text("of \(USState.all.count) plates")
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(store.teamCount), total: Double(USState.all.count))
                                .tint(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    ForEach(Array(scores.enumerated()), id: \.element.player.id) { index, entry in
                        let player = entry.player
                        let isFriend = store.isFriend(player.id)
                        NavigationLink(value: player.id) {
                            LeaderboardRow(rank: coop ? nil : (scores.firstIndex { $0.score == entry.score } ?? index) + 1,
                                           player: player, score: entry.score,
                                           isCurrent: player.id == store.currentPlayer?.id,
                                           isFriend: isFriend)
                        }
                        .swipeActions {
                            if !isFriend {
                                Button("Delete", role: .destructive) { store.remove(player) }
                                    .disabled(store.players.count == 1)
                            }
                        }
                    }
                } header: {
                    Text(coop ? "Found First" : "Standings")
                } footer: {
                    Text((coop ? "Each plate counts for whoever spotted it first. " : "")
                         + (store.groupCode == nil
                            ? "Tap a player to see their plates. Swipe left to remove a player."
                            : "Friends' plates update about every 30 seconds. Pull down to refresh."))
                }
            }
            .navigationTitle(coop ? "Team" : "Leaderboard")
            .refreshable { await friendSync.sync() }
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

    /// Players with the number shown beside them, best first. Competitive: plates spotted.
    /// Co-op: plates they were first on the team to spot.
    private var scores: [(player: Player, score: Int)] {
        guard store.mode == .coop else { return store.ranked.map { ($0, $0.count) } }
        let firsts = Dictionary(grouping: store.firstSpotters.values, by: { $0 }).mapValues(\.count)
        return store.ranked
            .map { ($0, firsts[$0.id] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    private var modeFooter: String {
        let scope = store.groupCode == nil ? "" : " Changing this changes it for your whole friend group."
        return (store.mode == .coop
                ? "Everyone works on one shared list. A plate is done as soon as anyone spots it."
                : "Everyone keeps their own list. Whoever spots the most plates wins.") + scope
    }
}

private struct FriendGroupSection: View {
    @Environment(GameStore.self) private var store
    @Environment(FriendSync.self) private var friendSync

    @State private var joining = false
    @State private var code = ""
    @State private var confirmingLeave = false

    var body: some View {
        Section {
            if let groupCode = store.groupCode {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Group code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(groupCode)
                            .font(.system(.title, design: .monospaced).bold())
                            .textSelection(.enabled)
                    }
                    Spacer()
                    ShareLink(item: "Play Plate Chase with me! Open the app, go to Leaderboard, tap Join with Code, and enter \(groupCode)") {
                        Label("Invite", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                status
                Button("Leave Group", role: .destructive) { confirmingLeave = true }
            } else {
                Text("Play with friends on their own phones, as a team or against each other. Create a group and text them the code, or join theirs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Create Group") { Task { await friendSync.createGroup() } }
                        .buttonStyle(.borderedProminent)
                    Button("Join with Code") {
                        code = ""
                        joining = true
                    }
                    .buttonStyle(.bordered)
                    if friendSync.isWorking { ProgressView().padding(.leading, 4) }
                }
                .disabled(friendSync.isWorking)
                if let error = friendSync.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Friend Group")
        }
        .alert("Join a Group", isPresented: $joining) {
            TextField("6-character code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Join") { Task { await friendSync.join(code) } }
        } message: {
            Text("Ask a friend for their group code.")
        }
        .confirmationDialog("Leave group \(store.groupCode ?? "")?", isPresented: $confirmingLeave,
                            titleVisibility: .visible) {
            Button("Leave Group", role: .destructive) { friendSync.leave() }
        } message: {
            Text("Your friends will no longer see your plates, and theirs disappear from this phone.")
        }
    }

    @ViewBuilder
    private var status: some View {
        if let error = friendSync.error {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
        } else if let lastSynced = friendSync.lastSynced {
            let friendCount = store.friends.count
            Text("\(friendCount) friend\(friendCount == 1 ? "" : "s") · updated ") + Text(lastSynced, style: .relative) + Text(" ago")
        } else {
            HStack {
                ProgressView()
                Text("Syncing…").foregroundStyle(.secondary)
            }
        }
    }
}

private struct LeaderboardRow: View {
    /// Nil in co-op, where nobody is ranked.
    let rank: Int?
    let player: Player
    let score: Int
    let isCurrent: Bool
    let isFriend: Bool

    var body: some View {
        HStack(spacing: 14) {
            if let rank {
                rankBadge(rank)
                    .frame(width: 36)
            } else {
                Circle().fill(player.color).frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(player.name).font(.headline)
                    if isFriend {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Friend")
                    }
                    if isCurrent {
                        Text("PLAYING")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(player.color.opacity(0.2), in: Capsule())
                            .foregroundStyle(player.color)
                    }
                    Spacer()
                    Text("\(score)")
                        .font(.title3.bold().monospacedDigit())
                    + Text(rank == nil ? "" : " / \(USState.all.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                ProgressView(value: Double(score), total: Double(USState.all.count))
                    .tint(player.color)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func rankBadge(_ rank: Int) -> some View {
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
        if let player = store.everyone.first(where: { $0.id == playerID }) {
            let isFriend = store.isFriend(player.id)
            let spotted = player.spotted
                .compactMap { code, date in USState.byCode[code].map { ($0, date) } }
                .sorted { $0.1 > $1.1 }
            let needed = USState.alphabetical.filter { !player.hasSpotted($0) }

            List {
                if !isFriend {
                    Section {
                        Button("Play as \(player.name)", systemImage: "steeringwheel") {
                            store.currentPlayerID = player.id
                        }
                        .disabled(store.currentPlayer?.id == player.id)
                    }
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
                if !isFriend {
                    Button("Rename") {
                        newName = player.name
                        renaming = true
                    }
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
