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
                if let inspect = LaunchOptions.value("-inspect") {
                    store.selectedCountry = inspect
                    store.focusOn(inspect)
                    store.refreshMap()
                }
                if let mode = LaunchOptions.value("-mapmode").flatMap(MapMode.init(rawValue:)) {
                    store.mapMode = mode
                }
                if let days = LaunchOptions.value("-advance").flatMap(Int.init) {
                    store.step(days: days)
                    store.panel = nil
                }
                if LaunchOptions.arguments.contains("-selectarmy"), let sim = store.sim {
                    let mine = sim.armies(of: id)
                    if let a = mine.first(where: { $0.engaged }) ?? mine.first { store.selectArmy(a.id) }
                }
                if LaunchOptions.arguments.contains("-openbattle"), let b = store.sim?.playerBattles().first {
                    store.openBattle(b.province)
                }
                if LaunchOptions.arguments.contains("-maptray") { store.mapTray = true }
                switch LaunchOptions.value("-panel") {
                case "industry"?: store.panel = .production
                case "army"?: store.panel = .military
                default: break
                }
            }
        }
    }
}
