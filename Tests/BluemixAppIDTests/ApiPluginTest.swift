/*
 Copyright 2018 IBM Corp.
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
import XCTest
import Kitura
import SimpleLogger
import Credentials
@testable import KituraNet
@testable import Kitura
import Socket
import SwiftyJSON
import Foundation
@testable import BluemixAppID

@available(OSX 10.12, *)
class ApiPluginTest: XCTestCase {

    static var allTests : [(String, (ApiPluginTest) -> () throws -> Void)] {
        return [
            ("testApiConfigEmpty", testApiConfigEmpty),
            ("testApiConfigOptions", testApiConfigOptions),
            ("testApiConfigVCAP", testApiConfigVCAP),
            ("testApiConfigVcapAndOptions", testApiConfigVcapAndOptions),
            ("testAuthFlowNoAuthHeader", testAuthFlowNoAuthHeader),
            ("testAuthFlowMissingBearerHeader", testAuthFlowMissingBearerHeader),
            ("testAuthFlowMalformedHEader", testAuthFlowMalformedHEader),
            ("testAuthFlowExpiredAccessToken", testAuthFlowExpiredAccessToken),
            ("testAuthFlowHappyFlowNoIDToken", testAuthFlowHappyFlowNoIDToken),
            ("testAuthFlowInsufficientScope", testAuthFlowInsufficientScope),
            ("testAuthFlowExpiredIDToken", testAuthFlowExpiredIDToken),
            ("testAuthFlowHappyFlowWithIDToken", testAuthFlowHappyFlowWithIDToken),
            ("testAuthFlowPublicKeys400", testAuthFlowPublicKeys400),
            ("testAuthFlowPublicKeysMalformedResponse", testAuthFlowPublicKeysMalformedResponse)
        ]
    }

    let options = [
        "oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/768b5d51-37b0-44f7-a351-54fe59a67d18"
    ]

    let logger = Logger(forName:"ApiPluginTest")

    class MockAPIKituraCredentialsPlugin: APIKituraCredentialsPlugin {

        let publicKeyResponseCode: Int
        let publicKeyResponse: String

        override func retrievePubKey(onFailure: ((String) -> Void)?, completion: (([String : String]) -> Void)?) {
            handlePubKeyResponse(publicKeyResponseCode, publicKeyResponse.data(using: .utf8)!, onFailure, completion)
        }

        init(options: [String: Any]?, responseCode: Int = 200, responseBody: String = "{\"keys\": [\(TestConstants.PUBLIC_KEY)]}") {

            publicKeyResponseCode = responseCode
            publicKeyResponse = responseBody

            super.init(options: options)
        }
    }

    var parser: HTTPParser!
    var httpRequest: HTTPServerRequest!
    var httpResponse: HTTPServerResponse!
    var routerStack: Stack<Router>!
    var request: RouterRequest!
    var response: RouterResponse!

    override func setUp() {
        unsetenv("VCAP_SERVICES")
        unsetenv("redirectUri")
        parser = HTTPParser(isRequest: true)
        httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: parser)
        httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate(), keepalive: .disabled), request: httpRequest)
        routerStack = Stack<Router>()
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
    }

    func testApiConfigEmpty() {
        let config = APIKituraCredentialsPluginConfig(options:[:])
        XCTAssertEqual(config.serviceConfig.count, 0)
        XCTAssertNil(config.serverUrl)
    }

    func testApiConfigOptions() {
        let config = APIKituraCredentialsPluginConfig(options: ["oauthServerUrl": "someurl"])
        XCTAssertEqual(config.serverUrl, "someurl")
    }

    func testApiConfigVCAP() {
        setenv("VCAP_SERVICES", "{\n  \"AppID\": [\n    {\n      \"credentials\": {\n      \"oauthServerUrl\": \"https://testvcap/oauth/v3/test\"},    }\n  ]\n}", 1)
        let config = APIKituraCredentialsPluginConfig(options: nil)

        XCTAssertEqual(config.serverUrl, "https://testvcap/oauth/v3/test")
    }

    func testApiConfigVcapAndOptions() {
        setenv("VCAP_SERVICES", "{\n  \"AppID\": [\n    {\n      \"credentials\": {\n      \"oauthServerUrl\": \"https://testvcap/oauth/v3/test\"},    }\n  ]\n}", 1)
        let config = APIKituraCredentialsPluginConfig(options: ["oauthServerUrl": "someurl"])
        XCTAssertEqual(config.serverUrl, "someurl")
    }

    func testAuthFlowNoAuthHeader() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass(expected: "Bearer realm=\"AppID\"", expectation: expectation(description: "testAuthFlowNoAuthHeader")), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowMissingBearerHeader() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        parser.headers["Authorization"] =  [TestConstants.ACCESS_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass(expectedCode: .badRequest, expected: "Bearer scope=\"appid_default\", error=\"invalid_request\"", expectation: expectation(description: "testAuthFlowMissingBearerHeader")), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowMalformedHEader() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        parser.headers["Authorization"] =  ["Bearer"]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .badRequest, expected: "Bearer scope=\"appid_default\", error=\"invalid_request\"", expectation: expectation(description: "testAuthFlowMalformedHEader")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowExpiredAccessToken() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.EXPIRED_ACCESS_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expected: "Bearer scope=\"appid_default\", error=\"invalid_token\"", expectation: expectation(description: "testAuthFlowExpiredAccessToken")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowHappyFlowNoIDToken() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        parser.headers["Authorization"] = ["Bearer " + TestConstants.ACCESS_TOKEN]

        api.authenticate(request: request, response: response, options: ["scope" : "appid_readuserattr"] , onSuccess: setOnSuccess(id: "", name: "", provider: "", expectation: expectation(description: "testAuthFlowHappyFlowNoIDToken")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessToken"] as? String , TestConstants.ACCESS_TOKEN)
        XCTAssertEqual(JSON(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessTokenPayload"] as Any), try? Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"])

        awaitExpectations()
    }

    func testAuthFlowInsufficientScope() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        parser.headers["Authorization"] = ["Bearer " + TestConstants.ACCESS_TOKEN]

        api.authenticate(request: request, response: response, options: ["scope" : "SomeScope"], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .forbidden, expected: "Bearer scope=\"appid_default SomeScope\", error=\"insufficient_scope\"", expectation: expectation(description: "testAuthFlowInsufficientScope")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowExpiredIDToken() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        httpRequest.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.EXPIRED_ID_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(expectation: expectation(description: "testAuthFlowExpiredIDToken")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowHappyFlowWithIDToken() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.ID_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "subject", name: "test name", provider: "someprov", expectation: expectation(description: "testAuthFlowHappyFlowWithIDToken")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessToken"] as? String , TestConstants.ACCESS_TOKEN)
        XCTAssertEqual(JSON(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessTokenPayload"] as Any) , try? Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"])
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["identityToken"] as? String , TestConstants.ID_TOKEN)
        XCTAssertEqual(JSON(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["identityTokenPayload"] as Any) , try? Utils.parseToken(from: TestConstants.ID_TOKEN)["payload"])

        awaitExpectations()
    }

    func testAuthFlowPublicKeys400() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"], responseCode: 400)
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.ID_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .unauthorized, expected: "Bearer scope=\"appid_default\", error=\"internal_server_error\"", expectation: expectation(description: "testAuthFlowBadResponseFromPublicKeysEndpoint")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowPublicKeysMalformedResponse() {
        let api = MockAPIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"], responseCode: 200, responseBody: "bad json")
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.ID_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .unauthorized, expected: "Bearer scope=\"appid_default\", error=\"internal_server_error\"", expectation: expectation(description: "testAuthFlowPublicKeysMalformedResponse")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func awaitExpectations() {
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
    }
}

@available(OSX 10.12, *)
extension ApiPluginTest {

    // Remove off_ for running
    func off_testRunApiServer(){
        logger.debug("Starting")

        let router = Router()
        let apiKituraCredentialsPlugin = APIKituraCredentialsPlugin(options: options)
        let kituraCredentials = Credentials()
        kituraCredentials.register(plugin: apiKituraCredentialsPlugin)
        router.all("/api/protected", middleware: [BodyParser(), kituraCredentials])
        router.get("/api/protected") { (req, res, next) in
            let name = req.userProfile?.displayName ?? "Anonymous"
            res.status(.OK)
            res.send("Hello from protected resource, \(name)")
            next()
        }

        Kitura.addHTTPServer(onPort: 1234, with: router)
        Kitura.run()
    }

    func setOnFailure(expectedCode: HTTPStatusCode = .unauthorized, expected:String = "", expectation:XCTestExpectation? = nil) -> ((_ code: HTTPStatusCode?, _ headers: [String:String]?) -> Void) {

        return { (code: HTTPStatusCode?, headers: [String:String]?) -> Void in
            if expectation == nil {
                XCTFail()
            } else {
                XCTAssertEqual(code, expectedCode)
                XCTAssertEqual(headers?["Www-Authenticate"], expected)
                expectation?.fulfill()
            }
        }
    }

    func setOnSuccess(id:String = "", name:String = "", provider:String = "", expectation:XCTestExpectation? = nil) -> ((_:UserProfile ) -> Void) {

        return { (profile:UserProfile) -> Void in
            if expectation == nil {
                XCTFail()
            } else {
                XCTAssertEqual(profile.id, id)
                XCTAssertEqual(profile.displayName, name)
                XCTAssertEqual(profile.provider, provider)
                expectation?.fulfill()
            }
        }

    }

    func onPass(expectedCode: HTTPStatusCode = .unauthorized, expected: String = "", expectation: XCTestExpectation? = nil) -> (HTTPStatusCode?, [String: String]?) -> Void {

        return { (code : HTTPStatusCode?, headers : [String: String]?) in
            if expectation == nil {
                XCTFail()
            } else {
                XCTAssertEqual(code, expectedCode)
                XCTAssertEqual(headers?["Www-Authenticate"], expected)
                expectation?.fulfill()
            }
        }
    }

    func inProgress() {

    }

    class delegate: ServerDelegate {
        func handle(request: ServerRequest, response: ServerResponse) {
            return
        }
    }
}
