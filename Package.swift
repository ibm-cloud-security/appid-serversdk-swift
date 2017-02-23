import PackageDescription

let package = Package(
    name: "BluemixAppID",
	dependencies:[
		.Package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", majorVersion: 1, minor: 6),
        .Package(url: "https://github.com/IBM-Swift/Kitura-Request.git", majorVersion: 0)
	]
)
