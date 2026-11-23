import SwiftUI
import Observation

struct Player: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorIndex: Int
    /// State code -> when this player spotted it.
    var spotted: [String: Date] = [:]

    var count: Int { spotted.count }
    var color: Color { Player.palette[colorIndex % Player.palette.count] }
    var initial: String { name.first.map { String($0).uppercased() } ?? "?" }

    func hasSpotted(_ state: USState) -> Bool { spotted[state.code] != nil }

    static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .red, .indigo, .mint, .brown]
}

/// How plates are scored. Competitive: everyone has their own list and races for the most.
/// Co-op: everyone fills one shared list together.
enum GameMode: String, Codable, CaseIterable, Identifiable {
    case competitive, coop

    var id: Self { self }
    var title: String { self == .coop ? "Co-op" : "Competitive" }
    var symbol: String { self == .coop ? "person.3.fill" : "trophy.fill" }
}

/// A friend group this phone has joined. This phone's players, and their plates, count in every
/// group it's in. Each group has its own friends and its own game mode.
struct FriendGroup: Identifiable, Codable, Hashable {
    let code: String
    /// This phone's name for the group. Names aren't shared, so friends may call it something else.
    var name: String?
    var colorIndex: Int
    /// Players on friends' phones, as last synced. Kept so the leaderboard works offline.
    var friends: [Player] = []
    /// The group's game mode. Any member can change it; the most recent change wins.
    var mode: GameMode = .competitive
    /// When `mode` was last changed, by this phone or a friend's.
    var modeChangedAt: Date = .distantPast

    var id: String { code }

    var gradient: [Color] { Self.gradients[colorIndex % Self.gradients.count] }

    /// Backgrounds for group cards. Dark enough for white text in light and dark mode.
    static let gradients: [[Color]] = [
        [Color(red: 0.20, green: 0.42, blue: 0.98), Color(red: 0.49, green: 0.25, blue: 0.93)],
        [Color(red: 0.98, green: 0.45, blue: 0.20), Color(red: 0.90, green: 0.18, blue: 0.42)],
        [Color(red: 0.05, green: 0.62, blue: 0.56), Color(red: 0.10, green: 0.40, blue: 0.80)],
        [Color(red: 0.85, green: 0.22, blue: 0.60), Color(red: 0.45, green: 0.20, blue: 0.85)],
        [Color(red: 0.15, green: 0.62, blue: 0.30), Color(red: 0.05, green: 0.45, blue: 0.48)],
        [Color(red: 0.92, green: 0.62, blue: 0.10), Color(red: 0.88, green: 0.30, blue: 0.12)],
    ]

    /// Background for the "This Phone" card, which has no group.
    static let phoneGradient: [Color] = [Color(red: 0.30, green: 0.35, blue: 0.46),
                                         Color(red: 0.13, green: 0.16, blue: 0.24)]
}

/// The standings in one place: this phone's players alone, or with one friend group.
struct Board {
    /// This phone's players, then the group's friends.
    let players: [Player]
    let mode: GameMode

    /// Most plates first; the earliest to reach that count breaks ties.
    var ranked: [Player] {
        players.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return ($0.spotted.values.max() ?? .distantFuture) < ($1.spotted.values.max() ?? .distantFuture)
        }
    }

    func spotters(of state: USState) -> [Player] {
        players.filter { $0.hasSpotted(state) }
    }

    /// Co-op: has anyone spotted this plate?
    func teamHasSpotted(_ state: USState) -> Bool {
        players.contains { $0.hasSpotted(state) }
    }

    /// Co-op: how many different plates the team has spotted.
    var teamCount: Int {
        USState.all.count { teamHasSpotted($0) }
    }

    /// Co-op credit: for each plate, the player who spotted it first.
    var firstSpotters: [String: UUID] {
        var best: [String: (id: UUID, date: Date)] = [:]
        for player in players {
            for (code, date) in player.spotted where USState.byCode[code] != nil {
                if let current = best[code], current.date <= date { continue }
                best[code] = (player.id, date)
            }
        }
        return best.mapValues(\.id)
    }

    /// Players with the number shown beside them, best first, and their rank ("1, 1, 3" for a tie).
    /// Competitive: plates spotted. Co-op: plates they were first on the team to spot.
    var scores: [(player: Player, score: Int, rank: Int)] {
        let scored: [(Player, Int)]
        if mode == .coop {
            let firsts = Dictionary(grouping: firstSpotters.values, by: { $0 }).mapValues(\.count)
            scored = ranked.map { ($0, firsts[$0.id] ?? 0) }.sorted { $0.1 > $1.1 }
        } else {
            scored = ranked.map { ($0, $0.count) }
        }
        return scored.enumerated().map { index, entry in
            (entry.0, entry.1, (scored.firstIndex { $0.1 == entry.1 } ?? index) + 1)
        }
    }

    /// Whether this plate counts as spotted for `player` in this board's mode.
    func isSpotted(_ state: USState, for player: Player) -> Bool {
        mode == .coop ? teamHasSpotted(state) : player.hasSpotted(state)
    }
}

@Observable
final class GameStore {
    var players: [Player] = [] {
        didSet { save() }
    }
    var currentPlayerID: UUID? {
        didSet { save() }
    }
    /// Friend groups this phone has joined, in the order they were added.
    private(set) var groups: [FriendGroup] = [] {
        didSet { save() }
    }
    /// The group shown on the Leaderboard and used on the Plates tab. Nil: just this phone.
    var activeGroupCode: String? {
        didSet { save() }
    }

    /// The game mode when no group is picked. Each group has its own.
    private(set) var localMode: GameMode = .competitive {
        didSet { save() }
    }
    private(set) var localModeChangedAt: Date = .distantPast {
        didSet { save() }
    }

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #if DEBUG
        if DemoData.isEnabled {
            fileURL = dir.appendingPathComponent("demo.json")
            loadDemo()
            return
        }
        #endif
        fileURL = dir.appendingPathComponent("game.json")
        load()
    }

    var currentPlayer: Player? {
        players.first { $0.id == currentPlayerID } ?? players.first
    }

    // MARK: Groups

    func group(_ code: String) -> FriendGroup? {
        groups.first { $0.code == code }
    }

    var activeGroup: FriendGroup? {
        activeGroupCode.flatMap { group($0) }
    }

    /// The standings for a group, or for this phone alone when `code` is nil.
    func board(for code: String?) -> Board {
        let group = code.flatMap { self.group($0) }
        return Board(players: players + (group?.friends ?? []), mode: group?.mode ?? localMode)
    }

    /// The standings for the active group.
    var board: Board { board(for: activeGroup?.code) }

    /// The name to show for a group: the one given on this phone, or its friends' names.
    func displayName(of group: FriendGroup) -> String {
        if let name = group.name, !name.isEmpty { return name }
        let names = group.friends.map(\.name)
        switch names.count {
        case 0: return "Group \(group.code)"
        case 1: return "With \(names[0])"
        case 2: return "\(names[0]) & \(names[1])"
        default: return "\(names[0]), \(names[1]) & \(names.count - 2) more"
        }
    }

    func addGroup(code: String, name: String?, mode: GameMode, modeChangedAt: Date) {
        guard group(code) == nil else { return }
        let used = Set(groups.map(\.colorIndex))
        let colorIndex = (0..<FriendGroup.gradients.count).first { !used.contains($0) } ?? groups.count
        groups.append(FriendGroup(code: code, name: name, colorIndex: colorIndex,
                                  mode: mode, modeChangedAt: modeChangedAt))
    }

    func renameGroup(_ code: String, to name: String) {
        guard let i = groups.firstIndex(where: { $0.code == code }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        groups[i].name = trimmed.isEmpty ? nil : trimmed
    }

    func removeGroup(_ code: String) {
        groups.removeAll { $0.code == code }
        if activeGroupCode == code { activeGroupCode = nil }
    }

    /// Replaces a group's friends, giving them colors not used by this phone's players.
    func setFriends(_ list: [Player], inGroup code: String) {
        guard let i = groups.firstIndex(where: { $0.code == code }) else { return }
        let used = Set(players.map(\.colorIndex))
        var free = (0..<Player.palette.count).filter { !used.contains($0) }
        if free.isEmpty { free = Array(0..<Player.palette.count) }
        let friends = list
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .enumerated()
            .map { index, friend in
                var friend = friend
                friend.colorIndex = free[index % free.count]
                return friend
            }
        if groups[i].friends != friends { groups[i].friends = friends }
    }

    // MARK: The active group's standings

    /// Players on this phone plus the active group's friends.
    var everyone: [Player] { board.players }

    var mode: GameMode { board.mode }

    var modeChangedAt: Date { activeGroup?.modeChangedAt ?? localModeChangedAt }

    var teamCount: Int { board.teamCount }

    func spotters(of state: USState) -> [Player] { board.spotters(of: state) }

    func isSpotted(_ state: USState, for player: Player) -> Bool { board.isSpotted(state, for: player) }

    /// Players on other phones can be viewed but not renamed, removed, or played as.
    func isFriend(_ id: UUID) -> Bool {
        !players.contains { $0.id == id }
    }

    /// A player on this phone or in any group, preferring the active group's copy.
    func player(withID id: UUID) -> Player? {
        everyone.first { $0.id == id } ?? groups.lazy.flatMap(\.friends).first { $0.id == id }
    }

    // MARK: Game mode

    /// The player picked a mode for the active group (or this phone). Stamped later than the
    /// change it replaces, even if a friend's clock runs ahead of this phone's, so the group
    /// doesn't flip it straight back.
    func chooseMode(_ newMode: GameMode) {
        guard newMode != mode else { return }
        let changedAt = max(Date(), modeChangedAt.addingTimeInterval(1))
        if let code = activeGroup?.code {
            setMode(newMode, changedAt: changedAt, inGroup: code)
        } else {
            localModeChangedAt = changedAt
            localMode = newMode
        }
    }

    /// Sets a group's mode with a known change time, as synced from the group.
    func setMode(_ newMode: GameMode, changedAt: Date, inGroup code: String) {
        guard let i = groups.firstIndex(where: { $0.code == code }) else { return }
        groups[i].modeChangedAt = changedAt
        if groups[i].mode != newMode { groups[i].mode = newMode }
    }

    // MARK: Players

    @discardableResult
    func addPlayer(named name: String) -> Player {
        let used = Set(players.map(\.colorIndex))
        let colorIndex = (0..<Player.palette.count).first { !used.contains($0) } ?? players.count
        let player = Player(name: name, colorIndex: colorIndex)
        players.append(player)
        if currentPlayerID == nil { currentPlayerID = player.id }
        return player
    }

    func rename(_ player: Player, to name: String) {
        guard let i = players.firstIndex(where: { $0.id == player.id }) else { return }
        players[i].name = name
    }

    func remove(_ player: Player) {
        players.removeAll { $0.id == player.id }
        if currentPlayerID == player.id { currentPlayerID = players.first?.id }
    }

    func setSpotted(_ state: USState, _ spotted: Bool, for player: Player) {
        guard let i = players.firstIndex(where: { $0.id == player.id }) else { return }
        players[i].spotted[state.code] = spotted ? Date() : nil
    }

    func resetAllPlates() {
        for i in players.indices { players[i].spotted = [:] }
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var players: [Player]
        var currentPlayerID: UUID?
        var groups: [FriendGroup]?
        var activeGroupCode: String?
        var localMode: GameMode?
        var localModeChangedAt: Date?

        // Saved by 1.1 and earlier, which had at most one group. Read once to migrate.
        var groupCode: String?
        var friends: [Player]?
        var mode: GameMode?
        var modeChangedAt: Date?
    }

    private var isLoading = false

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        isLoading = true
        defer { isLoading = false }
        players = snapshot.players
        currentPlayerID = snapshot.currentPlayerID
        if let groups = snapshot.groups {
            self.groups = groups
            activeGroupCode = snapshot.activeGroupCode
            localMode = snapshot.localMode ?? .competitive
            localModeChangedAt = snapshot.localModeChangedAt ?? .distantPast
        } else {
            let mode = snapshot.mode ?? .competitive
            let changedAt = snapshot.modeChangedAt ?? .distantPast
            if let code = snapshot.groupCode {
                groups = [FriendGroup(code: code, colorIndex: 0, friends: snapshot.friends ?? [],
                                      mode: mode, modeChangedAt: changedAt)]
                activeGroupCode = code
            }
            localMode = mode
            localModeChangedAt = changedAt
        }
    }

    #if DEBUG
    /// Starts from `DemoData` instead of the saved game.
    private func loadDemo() {
        isLoading = true
        defer { isLoading = false }
        players = DemoData.players
        currentPlayerID = players.first?.id
        groups = DemoData.groups
        activeGroupCode = DemoData.activeGroupCode
    }
    #endif

    private func save() {
        guard !isLoading else { return }
        let snapshot = Snapshot(players: players, currentPlayerID: currentPlayerID,
                                groups: groups, activeGroupCode: activeGroupCode,
                                localMode: localMode, localModeChangedAt: localModeChangedAt)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
