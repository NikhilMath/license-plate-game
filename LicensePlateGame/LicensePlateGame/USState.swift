import SwiftUI

enum Region: String, CaseIterable, Identifiable {
    case northeast = "Northeast"
    case southeast = "Southeast"
    case midwest = "Midwest"
    case southwest = "Southwest"
    case west = "West"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .northeast: Color(red: 0.13, green: 0.36, blue: 0.70)
        case .southeast: Color(red: 0.80, green: 0.33, blue: 0.16)
        case .midwest: Color(red: 0.16, green: 0.55, blue: 0.30)
        case .southwest: Color(red: 0.78, green: 0.55, blue: 0.08)
        case .west: Color(red: 0.50, green: 0.25, blue: 0.62)
        }
    }
}

struct USState: Identifiable, Hashable {
    let code: String
    let name: String
    let nickname: String
    let region: Region

    var id: String { code }

    /// Name printed across the top of the plate card.
    var plateTitle: String { code == "DC" ? "Washington DC" : name }

    static let all: [USState] = [
        USState(code: "AL", name: "Alabama", nickname: "Heart of Dixie", region: .southeast),
        USState(code: "AK", name: "Alaska", nickname: "The Last Frontier", region: .west),
        USState(code: "AZ", name: "Arizona", nickname: "Grand Canyon State", region: .southwest),
        USState(code: "AR", name: "Arkansas", nickname: "The Natural State", region: .southeast),
        USState(code: "CA", name: "California", nickname: "The Golden State", region: .west),
        USState(code: "CO", name: "Colorado", nickname: "Centennial State", region: .west),
        USState(code: "CT", name: "Connecticut", nickname: "Constitution State", region: .northeast),
        USState(code: "DE", name: "Delaware", nickname: "The First State", region: .southeast),
        USState(code: "DC", name: "District of Columbia", nickname: "The Nation's Capital", region: .southeast),
        USState(code: "FL", name: "Florida", nickname: "Sunshine State", region: .southeast),
        USState(code: "GA", name: "Georgia", nickname: "Peach State", region: .southeast),
        USState(code: "HI", name: "Hawaii", nickname: "Aloha State", region: .west),
        USState(code: "ID", name: "Idaho", nickname: "Gem State", region: .west),
        USState(code: "IL", name: "Illinois", nickname: "Land of Lincoln", region: .midwest),
        USState(code: "IN", name: "Indiana", nickname: "Hoosier State", region: .midwest),
        USState(code: "IA", name: "Iowa", nickname: "Hawkeye State", region: .midwest),
        USState(code: "KS", name: "Kansas", nickname: "Sunflower State", region: .midwest),
        USState(code: "KY", name: "Kentucky", nickname: "Bluegrass State", region: .southeast),
        USState(code: "LA", name: "Louisiana", nickname: "Pelican State", region: .southeast),
        USState(code: "ME", name: "Maine", nickname: "Vacationland", region: .northeast),
        USState(code: "MD", name: "Maryland", nickname: "Old Line State", region: .southeast),
        USState(code: "MA", name: "Massachusetts", nickname: "Bay State", region: .northeast),
        USState(code: "MI", name: "Michigan", nickname: "Great Lakes State", region: .midwest),
        USState(code: "MN", name: "Minnesota", nickname: "Land of 10,000 Lakes", region: .midwest),
        USState(code: "MS", name: "Mississippi", nickname: "Magnolia State", region: .southeast),
        USState(code: "MO", name: "Missouri", nickname: "Show-Me State", region: .midwest),
        USState(code: "MT", name: "Montana", nickname: "Big Sky Country", region: .west),
        USState(code: "NE", name: "Nebraska", nickname: "Cornhusker State", region: .midwest),
        USState(code: "NV", name: "Nevada", nickname: "Silver State", region: .west),
        USState(code: "NH", name: "New Hampshire", nickname: "Live Free or Die", region: .northeast),
        USState(code: "NJ", name: "New Jersey", nickname: "Garden State", region: .northeast),
        USState(code: "NM", name: "New Mexico", nickname: "Land of Enchantment", region: .southwest),
        USState(code: "NY", name: "New York", nickname: "Empire State", region: .northeast),
        USState(code: "NC", name: "North Carolina", nickname: "First in Flight", region: .southeast),
        USState(code: "ND", name: "North Dakota", nickname: "Peace Garden State", region: .midwest),
        USState(code: "OH", name: "Ohio", nickname: "Buckeye State", region: .midwest),
        USState(code: "OK", name: "Oklahoma", nickname: "Sooner State", region: .southwest),
        USState(code: "OR", name: "Oregon", nickname: "Beaver State", region: .west),
        USState(code: "PA", name: "Pennsylvania", nickname: "Keystone State", region: .northeast),
        USState(code: "RI", name: "Rhode Island", nickname: "Ocean State", region: .northeast),
        USState(code: "SC", name: "South Carolina", nickname: "Palmetto State", region: .southeast),
        USState(code: "SD", name: "South Dakota", nickname: "Mount Rushmore State", region: .midwest),
        USState(code: "TN", name: "Tennessee", nickname: "Volunteer State", region: .southeast),
        USState(code: "TX", name: "Texas", nickname: "Lone Star State", region: .southwest),
        USState(code: "UT", name: "Utah", nickname: "Beehive State", region: .west),
        USState(code: "VT", name: "Vermont", nickname: "Green Mountain State", region: .northeast),
        USState(code: "VA", name: "Virginia", nickname: "Old Dominion", region: .southeast),
        USState(code: "WA", name: "Washington", nickname: "Evergreen State", region: .west),
        USState(code: "WV", name: "West Virginia", nickname: "Mountain State", region: .southeast),
        USState(code: "WI", name: "Wisconsin", nickname: "Badger State", region: .midwest),
        USState(code: "WY", name: "Wyoming", nickname: "Equality State", region: .west),
    ]

    static let alphabetical: [USState] = all.sorted { $0.name < $1.name }

    static let byCode:[String: USState] = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })
}
