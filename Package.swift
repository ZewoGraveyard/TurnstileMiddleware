import PackageDescription

let package = Package(
    name: "TurnstileMiddleware",
    dependencies: [
        .Package(url: "https://github.com/Zewo/HTTP.git", majorVersion: 0, minor: 14),
        .Package(url: "https://github.com/stormpath/Turnstile.git", majorVersion: 1)
    ]
)
