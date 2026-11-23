#if DEBUG
import Foundation

/// Made-up players and friend groups for screen recordings, such as the demo video in
/// `marketing/demo-video`. Debug builds only: launch with the `-DemoMode` argument.
///
/// In demo mode the app starts from this data on every launch, saves to `demo.json` instead of
/// `game.json`, and never talks to CloudKit, so nothing reaches the real friend groups.
enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-DemoMode") }

    /// This phone's players. The first one is playing.
    static var players: [Player] {
        [
            player("Maya", 0, "AL AZ CA CO CT DC FL GA IL IN KY LA MD MA MI MN MO NV NJ NY NC OR PA SC TN VA WA WV WI"),
            player("Leo", 1, "VT OH CA NV AZ UT CO TX NM OK KS MO IL IN MI WI MN IA NE SD WY MT ID FL"),
            player("Dad", 2, "CA OR WA NV AZ TX FL GA NC SC VA MD DC PA NY NJ CT MA"),
        ]
    }

    static var groups: [FriendGroup] {
        [
            FriendGroup(code: "HQ7K3M", name: "Family", colorIndex: 0, friends: [
                player("Grandma", 3, "VT NH MA CT NY NJ PA MD DC VA WV NC SC GA FL AL TN KY OH MI IN IL WI MN IA MO LA AR TX KS NE"),
                player("Priya", 4, "CA OR WA ID NV UT AZ NM CO TX OK MT WY SC GA"),
            ]),
            FriendGroup(code: "R8TWNP", name: "Road Trip Crew", colorIndex: 1, friends: [
                player("Sam", 5, "CA OR WA NV AZ UT CO NM TX OK KS NE SD ND MN WI IL IN OH MI PA NY NJ MA CT RI ME"),
                player("Jordan", 6, "FL GA AL MS LA TX AR TN KY NC SC VA WV MD DE DC PA OH IN IL MO KS"),
                player("Riley", 7, "CA NV AZ UT ID MT WY CO NM OR WA AK"),
            ]),
        ]
    }

    static let activeGroupCode = "HQ7K3M"

    /// A player whose plates were spotted over the last few days, a few hours apart.
    private static func player(_ name: String, _ colorIndex: Int, _ codes: String) -> Player {
        let now = Date()
        var spotted: [String: Date] = [:]
        for (index, code) in codes.split(separator: " ").enumerated() {
            let hoursAgo = Double((index * 7 + colorIndex * 3) % 72 + 1)
            spotted[String(code)] = now.addingTimeInterval(-hoursAgo * 3600)
        }
        return Player(name: name, colorIndex: colorIndex, spotted: spotted)
    }
}
#endif
