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
class ApiPluginTests: XCTestCase {

    static var allTests : [(String, (ApiPluginTests) -> () throws -> Void)] {
        return [
            ("testAuthFlowNoAuthHeader", testAuthFlowNoAuthHeader),
            ("testAuthFlowMissingBearerHeader", testAuthFlowMissingBearerHeader),
            ("testAuthFlowMalformedHEader", testAuthFlowMalformedHEader),
            ("testAuthFlowExpiredAccessToken", testAuthFlowExpiredAccessToken),
            ("testAuthFlowAccessTokenWrongAud", testAuthFlowAccessTokenWrongAud),
            ("testAuthFlowAccessTokenWrongIss", testAuthFlowAccessTokenWrongIss),
            ("testAuthFlowAccessTokenWrongTenant", testAuthFlowAccessTokenWrongTenant),
            ("testAuthFlowHappyFlowNoIDToken", testAuthFlowHappyFlowNoIDToken),
            ("testAuthFlowInsufficientScope", testAuthFlowInsufficientScope),
            ("testAuthFlowExpiredIDToken", testAuthFlowExpiredIDToken),
            ("testAuthFlowHappyFlowWithIDToken", testAuthFlowHappyFlowWithIDToken),
            ("testAuthFlowPublicKeys400", testAuthFlowPublicKeys400),
            ("testAuthFlowPublicKeysMalformedResponse", testAuthFlowPublicKeysMalformedResponse)
        ]
    }

    let logger = Logger(forName:"ApiPluginTest")

    class MockAPIKituraCredentialsPlugin: APIKituraCredentialsPlugin {

        init(options: [String: Any]?, responseCode: Int = 200, responseBody: String = "{\"keys\": [\(TestConstants.PUBLIC_KEY)]}") {
            super.init(options: options)
            self.publicKeyUtil = MockPublicKeyUtil(url: self.config.publicKeyServerURL,
                                                    responseCode: responseCode,
                                                    responseBody: responseBody)
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

    func testAuthFlowNoAuthHeader() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass(expected: "Bearer realm=\"AppID\"", expectation: expectation(description: "testAuthFlowNoAuthHeader")), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowMissingBearerHeader() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] =  [TestConstants.ACCESS_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass(expectedCode: .badRequest, expected: "Bearer scope=\"appid_default\", error=\"invalid_request\"", expectation: expectation(description: "testAuthFlowMissingBearerHeader")), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowMalformedHEader() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] =  ["Bearer"]
        
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .badRequest, expected: "Bearer scope=\"appid_default\", error=\"invalid_request\"", expectation: expectation(description: "testAuthFlowMalformedHEader")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowExpiredAccessToken() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.EXPIRED_ACCESS_TOKEN]
        let error = generateExpectedError(error: .invalidToken, description: AppIDError.expiredToken.description)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expected: error, expectation: expectation(description: "testAuthFlowExpiredAccessToken")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowAccessTokenWrongIss() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN_WRONG_ISS]
        let error = generateExpectedError(error: .invalidToken, description: AppIDError.invalidIssuer.description)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expected: error, expectation: expectation(description: "testAuthFlowAccessTokenWrongIss")), onPass: onPass(), inProgress:inProgress)
        
        awaitExpectations()
    }
    
    func testAuthFlowAccessTokenWrongAud() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN_WRONG_AUD]
        let error = generateExpectedError(error: .invalidToken, description: AppIDError.invalidAudience.description)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expected: error, expectation: expectation(description: "testAuthFlowAccessTokenWrongAud")), onPass: onPass(), inProgress:inProgress)
        
        awaitExpectations()
    }
    
    func testAuthFlowAccessTokenWrongTenant() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN_WRONG_TENANT]
        let error = generateExpectedError(error: .invalidToken, description: AppIDError.invalidTenant.description)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expected: error, expectation: expectation(description: "testAuthFlowAccessTokenWrongTenant")), onPass: onPass(), inProgress:inProgress)
        
        awaitExpectations()
    }
    
    func testAuthFlowInsufficientScope() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] = ["Bearer " + TestConstants.ACCESS_TOKEN]
        
        api.authenticate(request: request, response: response, options: ["scope" : "SomeScope"], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .forbidden, expected: generateExpectedError(expectedScope:"appid_default SomeScope", error: .insufficientScope), expectation: expectation(description: "testAuthFlowInsufficientScope")), onPass: onPass(), inProgress:inProgress)
        
        awaitExpectations()
    }
    
    func testAuthFlowHappyFlowNoIDToken() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] = ["Bearer " + TestConstants.ACCESS_TOKEN]

        api.authenticate(request: request, response: response, options: ["scope" : "appid_readuserattr"] , onSuccess: setOnSuccess(id: "", name: "", provider: "", expectation: expectation(description: "testAuthFlowHappyFlowNoIDToken")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessToken"] as? String , TestConstants.ACCESS_TOKEN)
        XCTAssertEqual(JSON(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessTokenPayload"] as Any), try? Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"])

        awaitExpectations()
    }

    func testAuthFlowExpiredIDToken() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        httpRequest.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.EXPIRED_ID_TOKEN]
        
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(expectation: expectation(description: "testAuthFlowExpiredIDToken")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowHappyFlowWithIDToken() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options)
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.ID_TOKEN]

        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "subject", name: "test name", provider: "someprov", expectation: expectation(description: "testAuthFlowHappyFlowWithIDToken")), onFailure: setOnFailure(), onPass: onPass(), inProgress:inProgress)
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessToken"] as? String , TestConstants.ACCESS_TOKEN)
        XCTAssertEqual(JSON(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["accessTokenPayload"] as Any) , try? Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"])
        XCTAssertEqual(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["identityToken"] as? String , TestConstants.ID_TOKEN)
        XCTAssertEqual(JSON(((request.userInfo as [String:Any])["APPID_AUTH_CONTEXT"] as? [String:Any])?["identityTokenPayload"] as Any) , try? Utils.parseToken(from: TestConstants.ID_TOKEN)["payload"])

        awaitExpectations()
    }

    func testAuthFlowPublicKeys400() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options, responseCode: 400)
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.ID_TOKEN]

        let error = generateExpectedError(error: .invalidToken, description: AppIDError.missingPublicKey.description)
        
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .unauthorized, expected: error, expectation: expectation(description: "testAuthFlowBadResponseFromPublicKeysEndpoint")), onPass: onPass(), inProgress:inProgress)

        awaitExpectations()
    }

    func testAuthFlowPublicKeysMalformedResponse() {
        let api = MockAPIKituraCredentialsPlugin(options: TestConstants.options, responseCode: 200, responseBody: "bad json")
        parser.headers["Authorization"] =  ["Bearer " + TestConstants.ACCESS_TOKEN + " " + TestConstants.ID_TOKEN]
        
        let error = generateExpectedError(error: .invalidToken, description: AppIDError.missingPublicKey.description)
        
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectedCode: .unauthorized, expected: error, expectation: expectation(description: "testAuthFlowPublicKeysMalformedResponse")), onPass: onPass(), inProgress:inProgress)

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
extension ApiPluginTests {

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

    func generateExpectedError(expectedScope: String = "appid_default", error: OauthError, description: String? = nil) -> String {
        var err = "Bearer scope=\"\(expectedScope)\", error=\"\(error.rawValue)\""
        if let description = description {
            err += ", error_description=\"\(description)\""
        }
        return err
    }
    
    class delegate: ServerDelegate {
        func handle(request: ServerRequest, response: ServerResponse) {
            return
        }
    }
}
