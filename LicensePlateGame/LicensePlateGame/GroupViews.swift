import SwiftUI

/// A round badge with a player's initial in their color.
struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 40
    /// A border drawn inside the edge, to separate overlapping avatars or mark a medal.
    var ring: Color?

    var body: some View {
        Text(player.initial)
            .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(player.color)
                    .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.3), .clear],
                                                          startPoint: .top, endPoint: .bottom)))
            }
            .overlay {
                if let ring { Circle().strokeBorder(ring, lineWidth: max(2, size * 0.06)) }
            }
            .accessibilityHidden(true)
    }
}

/// A row of overlapping avatars, with a "+3" chip when there are more than fit.
struct AvatarStack: View {
    let players: [Player]
    var size: CGFloat = 28
    var border: Color = .white
    var limit = 4

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(players.prefix(limit)) { player in
                PlayerAvatar(player: player, size: size, ring: border)
            }
            if players.count > limit {
                Text("+\(players.count - limit)")
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(.black.opacity(0.35), in: Circle())
                    .overlay(Circle().strokeBorder(border, lineWidth: max(2, size * 0.06)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A slim rounded progress bar.
struct ScoreBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        Capsule()
            .fill(color.opacity(0.15))
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.75), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: fraction > 0 ? max(height, geo.size.width * min(fraction, 1)) : 0)
                }
            }
            .frame(height: height)
            .animation(.snappy, value: fraction)
            .accessibilityHidden(true)
    }
}

extension Int {
    /// "1st", "2nd", "3rd"…
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Group carousel

/// A horizontal strip of cards: this phone, each friend group, and one to add a group.
/// Tapping a card makes it the active group for the Leaderboard and Plates tabs.
struct GroupCarousel: View {
    @Environment(GameStore.self) private var store
    @Environment(FriendSync.self) private var friendSync
    let onCreate: () -> Void
    let onJoin: () -> Void

    private static let phoneID = "this-phone"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    tile(for: nil)
                    ForEach(store.groups) { group in
                        tile(for: group)
                    }
                    addTile
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(store.activeGroup?.code ?? Self.phoneID, anchor: .center) }
            .onChange(of: store.activeGroupCode) { _, code in
                withAnimation(.snappy) { proxy.scrollTo(code ?? Self.phoneID, anchor: .center) }
            }
        }
    }

    private func tile(for group: FriendGroup?) -> some View {
        let board = store.board(for: group?.code)
        let isSelected = store.activeGroup?.code == group?.code
        return Button {
            withAnimation(.snappy) { store.activeGroupCode = group?.code }
        } label: {
            GroupTile(title: group.map { store.displayName(of: $0) } ?? "This Phone",
                      symbol: group == nil ? "iphone" : "person.2.fill",
                      summary: summary(of: board),
                      gradient: group?.gradient ?? FriendGroup.phoneGradient,
                      ring: group?.gradient[0] ?? Color(.systemGray),
                      players: board.players,
                      isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .id(group?.code ?? Self.phoneID)
        .sensoryFeedback(.selection, trigger: isSelected) { _, new in new }
    }

    private func summary(of board: Board) -> (text: String, symbol: String) {
        if board.mode == .coop {
            return ("\(board.teamCount) of \(USState.all.count) found", "person.3.fill")
        }
        if board.players.count > 1, let me = store.currentPlayer,
           let entry = board.scores.first(where: { $0.player.id == me.id }) {
            return ("You're \(entry.rank.ordinal) of \(board.players.count)", "trophy.fill")
        }
        let count = store.currentPlayer?.count ?? 0
        return ("\(count) plate\(count == 1 ? "" : "s")", "car.fill")
    }

    private var addTile: some View {
        Menu {
            Button("Create Group", systemImage: "plus.circle", action: onCreate)
            Button("Join with Code", systemImage: "number", action: onJoin)
        } label: {
            VStack(spacing: 6) {
                if friendSync.isWorking {
                    ProgressView()
                        .frame(height: 28)
                } else {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .frame(height: 28)
                }
                Text("Add Group")
                    .font(.subheadline.bold())
                Text("Create or join")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.accentColor)
            .frame(width: 120, height: 118)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
            .scaleEffect(0.95)
        }
        .disabled(friendSync.isWorking)
        .accessibilityLabel("Add a friend group")
    }
}

private struct GroupTile: View {
    let title: String
    let symbol: String
    let summary: (text: String, symbol: String)
    let gradient: [Color]
    /// The outline shown when selected.
    let ring: Color
    let players: [Player]
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.footnote.bold())
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.22), in: Circle())
                Spacer()
                AvatarStack(players: players, size: 24, border: .white.opacity(0.9), limit: 3)
            }
            Spacer(minLength: 8)
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Label(summary.text, systemImage: summary.symbol)
                .font(.caption.weight(.semibold))
                .labelStyle(TightLabelStyle())
                .lineLimit(1)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 168, height: 118, alignment: .leading)
        .background(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(ring, lineWidth: 3)
                .padding(-5)
                .opacity(isSelected ? 1 : 0)
        }
        .shadow(color: gradient[0].opacity(isSelected ? 0.45 : 0.15), radius: isSelected ? 10 : 4, y: 4)
        .scaleEffect(isSelected ? 1 : 0.95)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Group header card

/// The big card at the top of the Leaderboard for the active group (or this phone): its name,
/// members, code and invite, sync status, and game mode.
struct GroupHeroCard: View {
    @Environment(GameStore.self) private var store
    @Environment(FriendSync.self) private var friendSync
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onRename: (FriendGroup) -> Void
    let onLeave: (FriendGroup) -> Void

    @State private var copied = false

    var body: some View {
        let group = store.activeGroup
        let board = store.board
        let gradient = group?.gradient ?? FriendGroup.phoneGradient

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group == nil ? "Local game" : "Friend group")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(1)
                        .opacity(0.75)
                    Text(group.map { store.displayName(of: $0) } ?? "This Phone")
                        .font(.title2.bold())
                        .lineLimit(2)
                }
                Spacer()
                if let group { menu(for: group) }
            }

            HStack(spacing: 10) {
                AvatarStack(players: board.players, size: 32, border: .white, limit: 5)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(board.players.count) player\(board.players.count == 1 ? "" : "s")")
                        .font(.subheadline.bold())
                    status(for: group)
                        .font(.caption)
                        .opacity(0.8)
                }
            }

            if let group {
                codeRow(for: group, tint: gradient[0])
            } else if store.groups.isEmpty {
                invitePitch(tint: gradient[0])
            }

            ModeSwitch(selection: board.mode, tint: gradient[0]) { mode in
                store.chooseMode(mode)
                friendSync.modeChanged()
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: group == nil ? "iphone" : "car.side.fill")
                    .font(.system(size: 140, weight: .bold))
                    .foregroundStyle(.white.opacity(0.08))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 30, y: 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: gradient[0].opacity(0.35), radius: 14, y: 8)
        }
        .animation(.snappy, value: group?.code)
    }

    private func menu(for group: FriendGroup) -> some View {
        Menu {
            Button("Rename Group", systemImage: "pencil") { onRename(group) }
            Button("Copy Code", systemImage: "doc.on.doc") { copy(group.code) }
            Divider()
            Button("Leave Group", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                onLeave(group)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.2), in: Circle())
        }
        .accessibilityLabel("Group options")
    }

    @ViewBuilder
    private func status(for group: FriendGroup?) -> some View {
        if let group {
            if let lastSynced = friendSync.lastSynced[group.code] {
                Text("Updated ") + Text(lastSynced, style: .relative) + Text(" ago")
            } else if friendSync.error != nil {
                Text("Not synced yet")
            } else {
                Text("Syncing…")
            }
        } else if store.groups.isEmpty {
            Text("Everyone on this phone")
        } else {
            Text("Your plates count in every group too")
        }
    }

    private func codeRow(for group: FriendGroup, tint: Color) -> some View {
        HStack(spacing: 10) {
            Button { copy(group.code) } label: {
                HStack(spacing: 8) {
                    Text(group.code)
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .tracking(2)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.footnote.bold())
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Group code \(group.code.map(String.init).joined(separator: " ")). Copy")

            Spacer()

            ShareLink(item: "Play Plate Chase with me! Open the app, go to Leaderboard, tap Add Group, then Join with Code, and enter \(group.code)") {
                Label("Invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .foregroundStyle(tint)
                    .background(.white, in: Capsule())
            }
        }
    }

    private func invitePitch(tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Play with friends on their own phones, as a team or against each other. Make a group and text them the code, or join theirs. You can be in as many groups as you like.")
                .font(.subheadline)
                .opacity(0.9)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(action: onCreate) {
                    Label("Create Group", systemImage: "plus")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(tint)
                        .background(.white, in: Capsule())
                }
                Button(action: onJoin) {
                    Label("Join", systemImage: "number")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.2), in: Capsule())
                }
                if friendSync.isWorking { ProgressView().tint(.white) }
            }
            .buttonStyle(.plain)
            .disabled(friendSync.isWorking)
        }
    }

    private func copy(_ code: String) {
        UIPasteboard.general.string = code
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

/// Two pills for the game mode, on a colored card.
struct ModeSwitch: View {
    let selection: GameMode
    let tint: Color
    let onSelect: (GameMode) -> Void

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(GameMode.allCases) { mode in
                let isOn = mode == selection
                Button { if !isOn { onSelect(mode) } } label: {
                    Label(mode.title, systemImage: mode.symbol)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isOn ? tint : .white)
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(.white)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.black.opacity(0.18), in: Capsule())
        .animation(.snappy, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game mode")
    }
}
