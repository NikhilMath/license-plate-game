import GameKit
import Observation
import UIKit

struct GlobalEntry: Identifiable {
    let id: String
    let rank: Int
    let name: String
    let score: Int
    let isLocalPlayer: Bool
}

/// Signs in to Game Center, posts this phone's owner's plate count, and loads the worldwide leaderboard.
@Observable
final class GameCenter {
    /// Must match the leaderboard ID created in App Store Connect.
    static let leaderboardID = "com.nikhilmath.licenseplategame.plates"

    enum Status: Equatable {
        case signingIn
        case signedIn
        case signedOut(String)
    }

    var status: Status = .signingIn
    var entries: [GlobalEntry] = []
    var loadError: String?
    var isLoading = false

    var isSignedIn: Bool { status == .signedIn }
    var playerName: String { GKLocalPlayer.local.displayName }

    private var pendingScore: Int?

    func authenticate() {
        status = .signingIn
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let viewController {
                Self.topViewController()?.present(viewController, animated: true)
                return
            }
            if GKLocalPlayer.local.isAuthenticated {
                self.status = .signedIn
                GKAccessPoint.shared.isActive = false
                if let score = self.pendingScore {
                    self.submit(score)
                }
                Task { await self.loadEntries() }
            } else {
                self.status = .signedOut(error?.localizedDescription ?? "Not signed in to Game Center.")
            }
        }
    }

    /// Posts a score; if Game Center isn't ready yet it's sent as soon as sign-in finishes.
    func submit(_ score: Int) {
        pendingScore = score
        guard isSignedIn else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                                    leaderboardIDs: [Self.leaderboardID])
                if pendingScore == score { pendingScore = nil }
                await loadEntries()
            } catch {
                await MainActor.run { loadError = Self.describe(error) }
            }
        }
    }

    @MainActor
    func loadEntries() async {
        guard isSignedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let board = try await GKLeaderboard.loadLeaderboards(IDs: [Self.leaderboardID]).first else {
                loadError = "The leaderboard isn't set up in App Store Connect yet."
                return
            }
            let (local, top, _) = try await board.loadEntries(for: .global, timeScope: .allTime,
                                                             range: NSRange(location: 1, length: 50))
            var list = top
            if let local, !list.contains(where: { $0.player.gamePlayerID == local.player.gamePlayerID }) {
                list.append(local)
            }
            let me = GKLocalPlayer.local.gamePlayerID
            entries = list.map {
                GlobalEntry(id: $0.player.gamePlayerID, rank: $0.rank, name: $0.player.displayName,
                            score: $0.score, isLocalPlayer: $0.player.gamePlayerID == me)
            }
            loadError = nil
        } catch {
            loadError = Self.describe(error)
        }
    }

    func showGameCenterLeaderboard() {
        if #available(iOS 18.0, *) {
            GKAccessPoint.shared.trigger(leaderboardID: Self.leaderboardID, playerScope: .global, timeScope: .allTime)
        } else {
            GKAccessPoint.shared.trigger(state: .leaderboards) {}
        }
    }

    private static func describe(_ error: Error) -> String {
        let code = (error as NSError).code
        if (error as NSError).domain == GKErrorDomain,
           code == GKError.Code.gameUnrecognized.rawValue || code == GKError.Code.invalidParameter.rawValue {
            return "The leaderboard isn't set up in App Store Connect yet."
        }
        return error.localizedDescription
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
