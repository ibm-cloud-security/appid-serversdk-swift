// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
/*
 Copyright 2017 IBM Corp.
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 http://www.apache.org/licenses/LICENSE-2.0
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
import PackageDescription

let package = Package(
    name: "BluemixAppID",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "BluemixAppID",
            targets: ["BluemixAppID"]
        )
    ],
    dependencies: [
      .package(url: "https://github.com/IBM-Swift/SwiftyJSON.git", .upToNextMinor(from: "17.0.0")),
      .package(url: "https://github.com/IBM-Swift/Kitura-Session.git", .upToNextMinor(from: "3.1.0")),
      .package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", .upToNextMinor(from: "2.1.0")),
      .package(url: "https://github.com/IBM-Swift/SwiftyRequest.git", .upToNextMinor(from: "1.1.0")),
      .package(url: "https://github.com/ibm-bluemix-mobile-services/bluemix-simple-logger-swift.git", .upToNextMinor(from: "0.5.0")),
      .package(url: "https://github.com/ibm-cloud-security/Swift-JWT-to-PEM.git", .upToNextMinor(from: "0.1.0")),
      .package(url: "https://github.com/IBM-Swift/BlueRSA.git", .upToNextMinor(from: "1.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "BluemixAppID",
            dependencies: ["Credentials", "SwiftyRequest", "SimpleLogger", "SwiftyJSON", "KituraSession", "SwiftJWKtoPEM", "CryptorRSA"]
        ),
        .testTarget(
            name: "BluemixAppIDTests",
            dependencies: ["BluemixAppID"]
        )
    ]
)
