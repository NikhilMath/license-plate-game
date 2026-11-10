import SwiftUI

@main
struct LicensePlateGameApp: App {
    @State private var store: GameStore
    @State private var friendSync: FriendSync

    init() {
        let store = GameStore()
        _store = State(initialValue: store)
        _friendSync = State(initialValue: FriendSync(store: store))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(friendSync)
                .onChange(of: store.players) { old, new in
                    friendSync.playersChanged(from: old, to: new)
                }
                .onChange(of: store.mode) { friendSync.modeChanged() }
                .task(id: store.groupCode) {
                    while !Task.isCancelled {
                        await friendSync.sync()
                        try? await Task.sleep(for: .seconds(30))
                    }
                }
        }
    }
}

struct ContentView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if store.players.isEmpty {
            WelcomeView()
        } else {
            TabView {
                PlatesView()
                    .tabItem { Label("Plates", systemImage: "car.fill") }
                LeaderboardView()
                    .tabItem {
                        store.mode == .coop
                            ? Label("Team", systemImage: "person.3.fill")
                            : Label("Leaderboard", systemImage: "trophy.fill")
                    }
            }
        }
    }
}

struct WelcomeView: View {
    @Environment(GameStore.self) private var store
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            LicensePlateCard(state: USState.byCode["CA"]!, spotted: true, spotters: [])
                .frame(width: 200)
                .rotationEffect(.degrees(-6))
            Text("Plate Chase")
                .font(.largeTitle.bold())
            Text("Spot license plates from all 50 states and DC. Race your friends for the most, or team up to find them all.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($focused)
                .submitLabel(.go)
                .onSubmit(start)
            Button(action: start) {
                Text("Start Playing")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmed.isEmpty)
            Spacer()
            Spacer()
        }
        .padding(32)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private func start() {
        guard !trimmed.isEmpty else { return }
        store.addPlayer(named: trimmed)
    }
}
