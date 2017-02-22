import PackageDescription

let package = Package(
    name: "AppIDUser",
    dependencies: [
        .Package(url: "https://github.com/ibm-cloud-security/appid-serversdk-swift.git", majorVersion: 0, minor:7)
    ])
