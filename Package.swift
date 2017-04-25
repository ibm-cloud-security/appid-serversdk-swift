import PackageDescription

let package = Package(
  name: "BluemixAppID",
  dependencies:[
    .Package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", majorVersion: 1),
    .Package(url: "https://github.com/IBM-Swift/Kitura-Request.git", majorVersion: 0),
    .Package(url: "https://github.com/ibm-bluemix-mobile-services/bluemix-simple-logger-swift.git", majorVersion: 0)
  ]
)
