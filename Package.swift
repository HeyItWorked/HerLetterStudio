// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LetterStudio",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "LetterStudio", targets: ["LetterStudio"])],
    targets: [
        .target(name: "LetterCore", resources: [.copy("Resources/Fonts")]),
        .executableTarget(name: "LetterStudio", dependencies: ["LetterCore"]),
        .executableTarget(name: "LetterCoreChecks", dependencies: ["LetterCore"], path: "Tests/LetterCoreTests")
    ]
)
