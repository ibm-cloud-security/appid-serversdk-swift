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
            ("testApiConfig", testApiConfig),
            ("testApiAuthenticate", testApiAuthenticate),
        ]
    }

    let options = [
        "oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/768b5d51-37b0-44f7-a351-54fe59a67d18"
    ]

    let logger = Logger(forName:"ApiPluginTest")

    func testApiConfig() {
        unsetenv("VCAP_SERVICES")
        unsetenv("redirectUri")
        var config = APIKituraCredentialsPluginConfig(options:[:])
        XCTAssertEqual(config.serviceConfig.count, 0)
        XCTAssertEqual(config.serverUrl, nil)
        config = APIKituraCredentialsPluginConfig(options: ["oauthServerUrl": "someurl"])
        XCTAssertEqual(config.serverUrl, "someurl")

        //with VCAP_SERVICES
        setenv("VCAP_SERVICES", "{\n  \"AppID\": [\n    {\n      \"credentials\": {\n      \"oauthServerUrl\": \"https://testvcap/oauth/v3/test\"},    }\n  ]\n}", 1)
        config = APIKituraCredentialsPluginConfig(options: nil)

        XCTAssertEqual(config.serverUrl, "https://testvcap/oauth/v3/test")
        config = APIKituraCredentialsPluginConfig(options: ["oauthServerUrl": "someurl"])
        XCTAssertEqual(config.serverUrl, "someurl")
        unsetenv("VCAP_SERVICES")
    }

    func testApiAuthenticate() {
        let api = APIKituraCredentialsPlugin(options:["oauthServerUrl": "testServerUrl"])
        let parser = HTTPParser(isRequest: true)
        let httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: parser)
        let httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate(), keepalive: .disabled), request: httpRequest)
        let routerStack = Stack<Router>()

        print("no authorization header")
        var request = RouterRequest(request: httpRequest)
        var response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass(expected: "Bearer realm=\"AppID\"", expectation: expectation(description: "test2")), inProgress:inProgress)

        print("auth header does not start with bearer")
        parser.headers["Authorization"] =  [TestConstants.ACCESS_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass(expectedCode: .badRequest, expected: "Bearer scope=\"appid_default\", error=\"invalid_request\"", expectation: expectation(description: "test2")), inProgress:inProgress)

        print("auth header does not have correct structure")
        parser.headers["Authorization"] =  ["Bearer"]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .badRequest, expected: "Bearer scope=\"appid_default\", error=\"invalid_request\"", expectation: expectation(description: "test3")), onPass: onPass(), inProgress:inProgress)

        print("expired access token")
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.EXPIRED_ACCESS_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expected: "Bearer scope=\"appid_default\", error=\"invalid_token\"", expectation: expectation(description: "test4")), onPass: onPass(), inProgress:inProgress)

        print("happy flow with no id token")
        parser.headers["Authorization"] = ["Bearer " + TestConstants.ACCESS_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: ["scope" : "appid_readuserattr"] , onSuccess: setOnSuccess(id: "", name: "", provider: "", expectation: expectation(description: "test5.01")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessToken"] as? String , TestConstants.ACCESS_TOKEN)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessTokenPayload"] as? JSON , try? Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"])

        print("insufficient scope error")
        parser.headers["Authorization"] = ["Bearer " + TestConstants.ACCESS_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: ["scope" : "SomeScope"], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .forbidden, expected: "Bearer scope=\"appid_default SomeScope\", error=\"insufficient_scope\"", expectation: expectation(description: "test5.1")), onPass: onPass(), inProgress:inProgress)

        print("expired id token")
        httpRequest.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.EXPIRED_ID_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(expectation: expectation(description: "test5.5")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)

        print("happy flow with id token")
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.ID_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "subject", name: "test name", provider: "someprov", expectation: expectation(description: "test6")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessToken"] as? String , TestConstants.ACCESS_TOKEN)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessTokenPayload"] as? JSON , try? Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"])
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["identityToken"] as? String , TestConstants.ID_TOKEN)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["identityTokenPayload"] as? JSON , try? Utils.parseToken(from: TestConstants.ID_TOKEN)["payload"])

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
