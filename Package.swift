// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HerLetterStudio",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "HerLetterStudio", targets: ["HerLetterStudio"])],
    targets: [
        .target(name: "LetterCore", resources: [.copy("Resources/Fonts"), .copy("Resources/Walkthrough")]),
        .executableTarget(name: "HerLetterStudio", dependencies: ["LetterCore"]),
        .executableTarget(name: "LetterCoreChecks", dependencies: ["LetterCore"], path: "Tests/LetterCoreTests")
    ]
)
