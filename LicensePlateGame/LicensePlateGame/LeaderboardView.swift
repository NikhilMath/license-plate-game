import SwiftUI

struct LeaderboardView: View {
    @Environment(GameStore.self) private var store
    @Environment(FriendSync.self) private var friendSync

    @State private var showingAddPlayer = false
    @State private var newName = ""
    @State private var confirmingReset = false
    @State private var removing: Player?

    @State private var creatingGroup = false
    @State private var joiningGroup = false
    @State private var groupName = ""
    @State private var groupCode = ""
    @State private var renaming: FriendGroup?
    @State private var leaving: FriendGroup?

    var body: some View {
        NavigationStack {
            let board = store.board
            let coop = board.mode == .coop
            let scores = board.scores
            let tint = store.activeGroup?.gradient ?? [Color.green, Color.teal]

            ScrollView {
                VStack(spacing: 18) {
                    GroupCarousel(onCreate: startCreating, onJoin: startJoining)
                        .padding(.bottom, -6)

                    if let error = friendSync.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        GroupHeroCard(onCreate: startCreating, onJoin: startJoining,
                                      onRename: { group in
                                          groupName = group.name ?? ""
                                          renaming = group
                                      },
                                      onLeave: { leaving = $0 })
                        Text(modeFooter(coop: coop))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal)

                    SectionTitle(title: coop ? "Team" : "Standings",
                                 detail: "\(scores.count) player\(scores.count == 1 ? "" : "s")")

                    if coop {
                        TeamProgressCard(board: board, scores: scores, tint: tint)
                        StandingsCard(title: "Found First", entries: scores, ranked: false,
                                      currentID: store.currentPlayer?.id, isFriend: store.isFriend,
                                      menu: playerMenu)
                    } else {
                        PodiumCard(entries: Array(scores.prefix(3)), currentID: store.currentPlayer?.id,
                                   onAddPlayer: startAddingPlayer, menu: playerMenu)
                        if scores.count > 3 {
                            StandingsCard(title: nil, entries: Array(scores.dropFirst(3)), ranked: true,
                                          currentID: store.currentPlayer?.id, isFriend: store.isFriend,
                                          menu: playerMenu)
                        }
                    }

                    Text(footer(coop: coop))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 28)
                .animation(.snappy, value: scores.map(\.player.id))
            }
            .background(Color(.systemGroupedBackground))
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
                    Button("Add Player", systemImage: "person.badge.plus", action: startAddingPlayer)
                }
            }
            .alert("Add Player", isPresented: $showingAddPlayer) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { store.addPlayer(named: name) }
                }
            }
            .alert("New Group", isPresented: $creatingGroup) {
                TextField("Name, like Family", text: $groupName)
                Button("Cancel", role: .cancel) {}
                Button("Create") { Task { await friendSync.createGroup(named: groupName) } }
            } message: {
                Text("You'll get a code to text your friends. Your plates count in every group you're in.")
            }
            .alert("Join a Group", isPresented: $joiningGroup) {
                TextField("6-character code", text: $groupCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Join") { Task { await friendSync.join(groupCode) } }
            } message: {
                Text("Ask a friend for their group code.")
            }
            .alert("Rename Group", isPresented: isPresent($renaming), presenting: renaming) { group in
                TextField("Group name", text: $groupName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { store.renameGroup(group.code, to: groupName) }
            } message: { _ in
                Text("Only this phone sees this name. Leave it blank to show your friends' names.")
            }
            .confirmationDialog("Leave \(leaving.map(store.displayName(of:)) ?? "group")?",
                                isPresented: isPresent($leaving), titleVisibility: .visible,
                                presenting: leaving) { group in
                Button("Leave Group", role: .destructive) { friendSync.leave(group.code) }
            } message: { _ in
                Text("Friends in this group will no longer see your plates, and theirs disappear from this phone. Your other groups aren't affected.")
            }
            .confirmationDialog("Remove \(removing?.name ?? "player")?", isPresented: isPresent($removing),
                                titleVisibility: .visible, presenting: removing) { player in
                Button("Remove Player", role: .destructive) {
                    withAnimation(.snappy) { store.remove(player) }
                }
            } message: { _ in
                Text("Their plates are deleted from this phone and every group.")
            }
            .confirmationDialog("Start a new road trip?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset All Plates", role: .destructive) { store.resetAllPlates() }
            } message: {
                Text("Everyone on this phone keeps their name, but every spotted plate is cleared, in every group.")
            }
        }
    }

    // MARK: Actions

    private func startAddingPlayer() {
        newName = ""
        showingAddPlayer = true
    }

    private func startCreating() {
        groupName = ""
        creatingGroup = true
    }

    private func startJoining() {
        groupCode = ""
        joiningGroup = true
    }

    /// Long-press options for a player on this phone. Friends' players have none.
    @ViewBuilder
    private func playerMenu(_ player: Player) -> some View {
        if !store.isFriend(player.id) {
            Button("Play as \(player.name)", systemImage: "steeringwheel") {
                store.currentPlayerID = player.id
            }
            .disabled(store.currentPlayer?.id == player.id)
            Button("Remove Player", systemImage: "trash", role: .destructive) { removing = player }
                .disabled(store.players.count == 1)
        }
    }

    private func isPresent<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }

    // MARK: Text

    private func modeFooter(coop: Bool) -> String {
        let scope = store.activeGroup == nil ? "" : " Changing this changes it for everyone in this group."
        return (coop
                ? "Everyone works on one shared list. A plate is done as soon as anyone spots it."
                : "Everyone keeps their own list. Whoever spots the most plates wins.") + scope
    }

    private func footer(coop: Bool) -> String {
        (coop ? "Each plate counts for whoever spotted it first. " : "")
            + "Tap a player to see their plates. Touch and hold a player on this phone to remove them."
            + (store.activeGroup == nil ? "" : " Friends' plates update about every 30 seconds. Pull down to refresh.")
    }
}

// MARK: - Sections

private struct SectionTitle: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Spacer()
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, -6)
    }
}

private enum Medal {
    static func colors(forRank rank: Int) -> [Color] {
        switch rank {
        case 1: [Color(red: 1.00, green: 0.82, blue: 0.30), Color(red: 0.93, green: 0.58, blue: 0.08)]
        case 2: [Color(red: 0.82, green: 0.85, blue: 0.90), Color(red: 0.56, green: 0.60, blue: 0.68)]
        default: [Color(red: 0.91, green: 0.63, blue: 0.42), Color(red: 0.68, green: 0.40, blue: 0.22)]
        }
    }
}

/// The top three on pedestals: first in the middle, second on the left, third on the right.
private struct PodiumCard<MenuItems: View>: View {
    let entries: [(player: Player, score: Int, rank: Int)]
    let currentID: UUID?
    let onAddPlayer: () -> Void
    @ViewBuilder let menu: (Player) -> MenuItems

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            slot(1)
            slot(0)
            slot(2)
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func slot(_ place: Int) -> some View {
        if place < entries.count {
            let entry = entries[place]
            let medal = Medal.colors(forRank: entry.rank)
            NavigationLink(value: entry.player.id) {
                VStack(spacing: 6) {
                    ZStack(alignment: .top) {
                        PlayerAvatar(player: entry.player, size: entry.rank == 1 ? 70 : 56, ring: medal[0])
                            .overlay(alignment: .bottomTrailing) {
                                if entry.player.id == currentID {
                                    Image(systemName: "steeringwheel")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(entry.player.color, in: Circle())
                                        .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2))
                                        .offset(x: 3, y: 3)
                                }
                            }
                            .padding(.top, 16)
                        if entry.rank == 1 && entry.score > 0 {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundStyle(LinearGradient(colors: medal, startPoint: .top, endPoint: .bottom))
                                .shadow(color: medal[1].opacity(0.4), radius: 3, y: 1)
                                .offset(y: -4)
                        }
                    }
                    Text(entry.player.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    (Text("\(entry.score)").font(.headline.monospacedDigit())
                     + Text(" plates").font(.caption).foregroundColor(.secondary))
                        .contentTransition(.numericText())
                    pedestal(rank: entry.rank, colors: medal)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu { menu(entry.player) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.rank.ordinal) place, \(entry.player.name), \(entry.score) plates")
        } else {
            Button(action: onAddPlayer) {
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 56, height: 56)
                        .overlay(Circle().strokeBorder(Color.secondary.opacity(0.4),
                                                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        .padding(.top, 16)
                    Text("Add player")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(" ").font(.headline)
                    UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: place == 1 ? 64 : 44)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private func pedestal(rank: Int, colors: [Color]) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(height: [92, 64, 44][min(rank, 3) - 1])
            .overlay(alignment: .top) {
                Text("\(rank)")
                    .font(.system(size: rank == 1 ? 34 : 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .padding(.top, 6)
            }
    }
}

/// Co-op: the team's progress ring and who found how many, as one colored bar.
private struct TeamProgressCard: View {
    let board: Board
    let scores: [(player: Player, score: Int, rank: Int)]
    let tint: [Color]

    var body: some View {
        let total = USState.all.count
        let count = board.teamCount
        let fraction = Double(count) / Double(total)

        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(tint[0].opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(AngularGradient(colors: tint, center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(360 * max(fraction, 0.01))),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("\(count)")
                        .font(.title.bold().monospacedDigit())
                        .contentTransition(.numericText())
                    Text("of \(total)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            .animation(.snappy, value: count)

            VStack(alignment: .leading, spacing: 8) {
                Text(count == total ? "Every plate found!" : "\(total - count) plates to go")
                    .font(.headline)
                ContributionBar(entries: scores.filter { $0.score > 0 }, total: total)
                Text(count == 0 ? "Spot the first plate to get the team going." : "Colors show who found each plate first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

private struct ContributionBar: View {
    let entries: [(player: Player, score: Int, rank: Int)]
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let gaps = CGFloat(max(entries.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(entries, id: \.player.id) { entry in
                    Rectangle()
                        .fill(entry.player.color)
                        .frame(width: max(0, (geo.size.width - gaps) * CGFloat(entry.score) / CGFloat(total)))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 10)
        .background(Color.secondary.opacity(0.15))
        .clipShape(Capsule())
        .animation(.snappy, value: entries.map(\.score))
    }
}

/// A card of player rows.
private struct StandingsCard<MenuItems: View>: View {
    let title: String?
    let entries: [(player: Player, score: Int, rank: Int)]
    /// Show rank numbers (competitive). Co-op lists players without ranking them.
    let ranked: Bool
    let currentID: UUID?
    let isFriend: (UUID) -> Bool
    @ViewBuilder let menu: (Player) -> MenuItems

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }
            ForEach(Array(entries.enumerated()), id: \.element.player.id) { index, entry in
                if index > 0 {
                    Divider().padding(.leading, ranked ? 104 : 70)
                }
                NavigationLink(value: entry.player.id) {
                    StandingRow(rank: ranked ? entry.rank : nil, player: entry.player, score: entry.score,
                                isCurrent: entry.player.id == currentID, isFriend: isFriend(entry.player.id))
                }
                .buttonStyle(.plain)
                .contextMenu { menu(entry.player) }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal)
    }
}

private struct StandingRow: View {
    /// Nil in co-op, where nobody is ranked.
    let rank: Int?
    let player: Player
    let score: Int
    let isCurrent: Bool
    let isFriend: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
            }
            PlayerAvatar(player: player, size: 42)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.headline)
                        .lineLimit(1)
                    if isFriend {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Friend")
                    }
                    if isCurrent {
                        Text("PLAYING")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(player.color.opacity(0.18), in: Capsule())
                            .foregroundStyle(player.color)
                    }
                }
                ScoreBar(fraction: Double(score) / Double(USState.all.count), color: player.color)
            }
            Spacer(minLength: 8)
            (Text("\(score)").font(.title3.bold().monospacedDigit())
             + Text(rank == nil ? "" : "/\(USState.all.count)").font(.caption).foregroundColor(.secondary))
                .contentTransition(.numericText())
            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Player detail

struct PlayerDetailView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let playerID: UUID

    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingRemove = false

    var body: some View {
        if let player = store.player(withID: playerID) {
            let isFriend = store.isFriend(player.id)
            let total = USState.all.count
            let spotted = player.spotted
                .compactMap { code, date in USState.byCode[code].map { ($0, date) } }
                .sorted { $0.1 > $1.1 }
            let needed = USState.alphabetical.filter { !player.hasSpotted($0) }

            List {
                Section {
                    HStack(spacing: 16) {
                        PlayerAvatar(player: player, size: 64)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(player.count) of \(total) plates")
                                .font(.title3.bold())
                            ScoreBar(fraction: Double(player.count) / Double(total), color: player.color, height: 8)
                            Label(isFriend ? "On a friend's phone" : "On this phone",
                                  systemImage: isFriend ? "person.2.fill" : "iphone")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    if !isFriend {
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
                if !isFriend && store.players.count > 1 {
                    Section {
                        Button("Remove \(player.name)", role: .destructive) { confirmingRemove = true }
                    } footer: {
                        Text("Their plates are deleted from this phone and every group.")
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
            .confirmationDialog("Remove \(player.name)?", isPresented: $confirmingRemove, titleVisibility: .visible) {
                Button("Remove Player", role: .destructive) {
                    store.remove(player)
                    dismiss()
                }
            }
        } else {
            ContentUnavailableView("Player removed", systemImage: "person.slash")
        }
    }
}
