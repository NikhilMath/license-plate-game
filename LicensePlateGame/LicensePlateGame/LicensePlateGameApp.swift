import SwiftUI

@main
struct LicensePlateGameApp: App {
    @State private var store = GameStore()
    @State private var gameCenter = GameCenter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(gameCenter)
                .task { gameCenter.authenticate() }
                .onChange(of: store.me?.count, initial: true) { _, count in
                    if let count { gameCenter.submit(count) }
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
                    .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
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
            Text("Spot license plates from all 50 states and DC. Whoever spots the most wins the road trip.")
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
