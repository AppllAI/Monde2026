import SwiftUI

// =============================================================
//  App.swift
//  Point d'entrée de l'application.
// =============================================================

@main
struct Monde2026App: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .preferredColorScheme(.dark)
                .tint(Theme.amber)
        }
    }
}

struct RootView: View {
    @ObservedObject var store: GameStore

    @State private var launched = false

    var body: some View {
        Group {
            if store.hasGame {
                GameView(store: store)
            } else {
                StartView(store: store)
            }
        }
        .task {
            // Options de test automatique (aucun effet en jeu normal).
            guard !launched else { return }
            launched = true
            if LaunchOptions.selfTest {
                await Task.detached(priority: .userInitiated) { SelfTest.run() }.value
            }
            if let id = LaunchOptions.autostart {
                UserDefaults.standard.set(true, forKey: "tutorialSeen")
                store.newGame(as: id)
                store.speed = LaunchOptions.autoSpeed
                store.autoPause = false
            }
        }
    }
}
