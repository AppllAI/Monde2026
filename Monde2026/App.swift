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

    var body: some View {
        if store.hasGame {
            GameView(store: store)
        } else {
            StartView(store: store)
        }
    }
}
