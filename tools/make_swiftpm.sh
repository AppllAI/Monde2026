#!/bin/bash
# Fabrique Monde2026.swiftpm : le jeu sous forme de projet Swift Playgrounds (iPad).
set -e
OUT=${1:-build-ipad}
VERSION=$(grep MARKETING_VERSION project.yml | head -1 | sed 's/[^0-9.]//g')
rm -rf "$OUT"
P="$OUT/Monde2026.swiftpm"
mkdir -p "$P/Sources/Resources"
cp Monde2026/*.swift "$P/Sources/"
cp Resources/* "$P/Sources/Resources/"
cat > "$P/Package.swift" <<PKG
// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Monde 2026",
    platforms: [.iOS("17.0")],
    products: [
        .iOSApplication(
            name: "Monde 2026",
            targets: ["AppModule"],
            bundleIdentifier: "com.brrrr999.monde2026",
            displayVersion: "$VERSION",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .map),
            accentColor: .presetColor(.orange),
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [
                .portrait, .landscapeRight, .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources",
            resources: [.copy("Resources/map.bin"), .copy("Resources/terrain.json")]
        )
    ],
    swiftLanguageVersions: [.v5]
)
PKG
(cd "$OUT" && zip -qr Monde2026-iPad.zip Monde2026.swiftpm)
echo "Paquet prêt : $OUT/Monde2026-iPad.zip (version $VERSION)"
