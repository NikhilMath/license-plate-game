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

    func hasSpotted(_ state: USState) -> Bool { spotted[state.code] != nil }

    static let palette: [Color] = [.blue, .orange, .green, .pink, .purple, .teal, .red, .indigo, .mint, .brown]
}

/// How plates are scored. Competitive: everyone has their own list and races for the most.
/// Co-op: everyone fills one shared list together.
enum GameMode: String, Codable, CaseIterable, Identifiable {
    case competitive, coop

    var id: Self { self }
    var title: String { self == .coop ? "Co-op" : "Competitive" }
}

@Observable
final class GameStore {
    var players: [Player] = [] {
        didSet { save() }
    }
    var currentPlayerID: UUID? {
        didSet { save() }
    }
    /// Code of the friend group this phone has joined, if any.
    var groupCode: String? {
        didSet { save() }
    }
    /// Players on friends' phones, as last synced. Kept so the leaderboard works offline.
    private(set) var friends: [Player] = [] {
        didSet { save() }
    }

    /// The game mode. In a friend group it's shared: the most recent change by any member wins.
    private(set) var mode: GameMode = .competitive {
        didSet { save() }
    }
    /// When `mode` was last changed, by this phone or a friend's.
    private(set) var modeChangedAt: Date = .distantPast {
        didSet { save() }
    }

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("game.json")
        load()
    }

    var currentPlayer: Player? {
        players.first { $0.id == currentPlayerID } ?? players.first
    }

    /// Players on this phone plus friends' players.
    var everyone: [Player] { players + friends }

    func isFriend(_ id: UUID) -> Bool {
        friends.contains { $0.id == id }
    }

    /// Players sorted for the leaderboard: most plates first, earliest to reach that count breaks ties.
    var ranked: [Player] {
        everyone.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return ($0.spotted.values.max() ?? .distantFuture) < ($1.spotted.values.max() ?? .distantFuture)
        }
    }

    func spotters(of state: USState) -> [Player] {
        everyone.filter { $0.hasSpotted(state) }
    }

    // MARK: Game mode

    func setMode(_ newMode: GameMode, changedAt: Date = Date()) {
        modeChangedAt = changedAt
        if mode != newMode { mode = newMode }
    }

    /// Co-op: has anyone spotted this plate?
    func teamHasSpotted(_ state: USState) -> Bool {
        everyone.contains { $0.hasSpotted(state) }
    }

    /// Co-op: how many different plates the team has spotted.
    var teamCount: Int {
        USState.all.count { teamHasSpotted($0) }
    }

    /// Co-op credit: for each plate, the player who spotted it first.
    var firstSpotters: [String: UUID] {
        var best: [String: (id: UUID, date: Date)] = [:]
        for player in everyone {
            for (code, date) in player.spotted where USState.byCode[code] != nil {
                if let current = best[code], current.date <= date { continue }
                best[code] = (player.id, date)
            }
        }
        return best.mapValues(\.id)
    }

    /// Whether this plate counts as spotted for `player` in the current mode.
    func isSpotted(_ state: USState, for player: Player) -> Bool {
        mode == .coop ? teamHasSpotted(state) : player.hasSpotted(state)
    }

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

    /// Replaces the friends list, giving friends colors not used by this phone's players.
    func setFriends(_ list: [Player]) {
        let used = Set(players.map(\.colorIndex))
        var free = (0..<Player.palette.count).filter { !used.contains($0) }
        if free.isEmpty { free = Array(0..<Player.palette.count) }
        friends = list
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .enumerated()
            .map { index, friend in
                var friend = friend
                friend.colorIndex = free[index % free.count]
                return friend
            }
    }

    func resetAllPlates() {
        for i in players.indices { players[i].spotted = [:] }
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var players: [Player]
        var currentPlayerID: UUID?
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
        players = snapshot.players
        currentPlayerID = snapshot.currentPlayerID
        groupCode = snapshot.groupCode
        friends = snapshot.friends ?? []
        mode = snapshot.mode ?? .competitive
        modeChangedAt = snapshot.modeChangedAt ?? .distantPast
        isLoading = false
    }

    private func save() {
        guard !isLoading else { return }
        let snapshot = Snapshot(players: players, currentPlayerID: currentPlayerID,
                                groupCode: groupCode, friends: friends,
                                mode: mode, modeChangedAt: modeChangedAt)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
