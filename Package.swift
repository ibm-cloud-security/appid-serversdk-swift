import PackageDescription

let package = Package(
    name: "AppIDServerSDKSwift",
	dependencies:[
		.Package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", majorVersion: 1, minor: 6)
	]
)
