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

@Observable
final class GameStore {
    var players: [Player] = [] {
        didSet { save() }
    }
    var currentPlayerID: UUID? {
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

    /// Players sorted for the leaderboard: most plates first, earliest to reach that count breaks ties.
    var ranked: [Player] {
        players.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return ($0.spotted.values.max() ?? .distantFuture) < ($1.spotted.values.max() ?? .distantFuture)
        }
    }

    func spotters(of state: USState) -> [Player] {
        players.filter { $0.hasSpotted(state) }
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

    func resetAllPlates() {
        for i in players.indices { players[i].spotted = [:] }
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var players: [Player]
        var currentPlayerID: UUID?
    }

    private var isLoading = false

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        isLoading = true
        players = snapshot.players
        currentPlayerID = snapshot.currentPlayerID
        isLoading = false
    }

    private func save() {
        guard !isLoading else { return }
        let snapshot = Snapshot(players: players, currentPlayerID: currentPlayerID)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
