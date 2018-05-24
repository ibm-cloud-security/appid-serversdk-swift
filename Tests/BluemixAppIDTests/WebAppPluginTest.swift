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
import KituraSession
import SwiftyJSON
import XCTest
import Kitura
import SimpleLogger
@testable import Credentials
@testable import KituraNet
@testable import Kitura
@testable import KituraSession
import Socket
import SwiftyJSON
import Foundation

@testable import BluemixAppID

@available(OSX 10.12, *)
class WebAppPluginTest: XCTestCase {

    static var allTests: [(String, (WebAppPluginTest) -> () throws -> Void)] {
        return [
            ("testLogout", testLogout),
            ("testWebAuthenticate", testWebAuthenticate),
            ("testHandleTokenResponse401", testHandleTokenResponse401),
            ("testHandleTokenResponseError", testHandleTokenResponseError),
            ("testHandleTokenResponseNoData", testHandleTokenResponseNoData),
            ("testHandleTokenResponseSuccess", testHandleTokenResponseSuccess),
            ("testHandleTokenResponseMissingAccessToken", testHandleTokenResponseMissingAccessToken),
            ("testHandleTokenResponseAccessTokenWrongTenant", testHandleTokenResponseAccessTokenWrongTenant),
            ("testHandleTokenResponseAccessTokenWrongAudience", testHandleTokenResponseAccessTokenWrongAudience),
            ("testHandleTokenResponseAccessTokenWrongIssuer", testHandleTokenResponseAccessTokenWrongIssuer),
            ("testHandleTokenResponseMissingIdentityToken", testHandleTokenResponseMissingIdentityToken),
            ("testHandleTokenResponseInvalidIdentityToken", testHandleTokenResponseInvalidIdentityToken)
        ]
    }

    let options = [
        "clientId": "86148468-1d73-48ac-9b5c-aaa86a34597a",
        "secret": "ODczMjUxZDAtNGJhMy00MzFkLTkzOGUtYmY4YzU0N2U3MTY4",
        "tenantId": "50d0beed-add7-48dd-8b0a-c818cb456bb4",
        "oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/50d0beed-add7-48dd-8b0a-c818cb456bb4",
        "redirectUri": "http://localhost:1234/ibm/bluemix/appid/callback"
    ]

    var LOGIN_URL = "/ibm/bluemix/appid/login"
    var LOGIN_ANON_URL = "/ibm/bluemix/appid/loginanon"
    var CALLBACK_URL = "/ibm/bluemix/appid/callback"
    var LOGOUT_URL = "/ibm/bluemix/appid/logout"
    var LANDING_PAGE_URL = "/index.html"

    let logger = Logger(forName:"WebAppPluginTest")

    class MockWebAppKituraCredentialsPlugin: WebAppKituraCredentialsPlugin {

        init(options: [String: Any]?, responseCode: Int = 200, responseBody: String = "{\"keys\": [\(TestConstants.PUBLIC_KEY)]}") {
            super.init(options: options)
            self.publicKeyUtil = MockPublicKeyUtil(url: self.config.publicKeyServerURL,
                                                   responseCode: responseCode,
                                                   responseBody: responseBody)
        }
    }

    func setOnFailure(expectation: XCTestExpectation? = nil) -> ((_ code: HTTPStatusCode?, _ headers: [String:String]?) -> Void) {

        return { (code: HTTPStatusCode?, headers: [String:String]?) -> Void in
            if let expectation = expectation {
                XCTAssertNil(code)
                XCTAssertNil(headers)
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }
    }

    func setOnSuccess(id: String = "", name: String = "", provider: String = "", expectation: XCTestExpectation? = nil) -> ((_:UserProfile ) -> Void) {

        return { (profile: UserProfile) -> Void in
            if let expectation = expectation {
                XCTAssertEqual(profile.id, id)
                XCTAssertEqual(profile.displayName, name)
                XCTAssertEqual(profile.provider, provider)
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }

    }

    func onPass(code: HTTPStatusCode?, headers: [String:String]?) {

    }

    func setInProgress(expectation: XCTestExpectation? = nil) -> (() -> Void) {

        return { () -> Void in
            if let expectation = expectation {
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }

    }

    //stub class
    class delegate: ServerDelegate {
        func handle(request: ServerRequest, response: ServerResponse) {
            return
        }
    }

    func testLogout() {

        let web = MockWebAppKituraCredentialsPlugin(options: TestConstants.options)
        let httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
        let request = RouterRequest(request: httpRequest)
        request.session = SessionState(id: "someSession", store: InMemoryStore())
        XCTAssertNil(request.session?[Constants.AuthContext.name] as? [String:Any])

        request.session?[Constants.AuthContext.name] = [:]
        request.session?[Constants.AuthContext.name] = ["accessTokenPayload": try! Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"]]
        XCTAssertNotNil(request.session?[Constants.AuthContext.name] as? [String:Any])
        web.logout(request: request)
        XCTAssertNil(request.session?[Constants.AuthContext.name] as? [String:Any])
    }

    func testWebAuthenticate() {

        //handle auth flow

        let web = MockWebAppKituraCredentialsPlugin(options: TestConstants.options)
        let httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
        let httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate(), keepalive: .disabled), request: httpRequest)
        let request = RouterRequest(request: httpRequest)

        var routerStack = Stack<Router>()
        routerStack.push(Router())

        var response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)

        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectation: expectation(description: "test1")), onPass: onPass, inProgress:setInProgress())
        //no session

        request.session = SessionState(id: "someSession", store: InMemoryStore())

        class testRouterResponse: RouterResponse {
            public var redirectUri: String
            public var expectation: XCTestExpectation?
            public var routerStack = Stack<Router>()

            public init(response: ServerResponse, router: Router, request: RouterRequest, redirectUri: String, expectation: XCTestExpectation? = nil) {
                self.expectation = expectation
                self.redirectUri = redirectUri
                routerStack.push(Router())
                super.init(response: response, routerStack: routerStack, request: request)
            }
            public override func redirect(_ path: String, status: HTTPStatusCode = .movedTemporarily) -> RouterResponse {
                if let expectation = expectation {
                    XCTAssertEqual(path, redirectUri)
                    expectation.fulfill()
                } else {
                    XCTFail()
                }
                let httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
                let httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate(), keepalive: .disabled), request: httpRequest)
                let request = RouterRequest(request: httpRequest)
                let response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
                return response
            }
        }
        // redirect
        response = testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default", expectation: expectation(description: "test2"))
        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test2.5")))
        //error on query
        class testRouterRequest: RouterRequest {
            var urlTest: String

            public init(request: HTTPServerRequest, url: String) {
                self.urlTest = url
                super.init(request: request)
            }
            public override var urlURL: URL {
                return URL(string:urlTest)!
            }

        }

        let request2 = testRouterRequest(request: httpRequest, url: TestConstants.serverUrl + "?error=someerr")
        request2.session = SessionState(id: "someSession", store: InMemoryStore())
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request2)
        web.authenticate(request: request2, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectation: expectation(description: "test3")), onPass: onPass, inProgress:setInProgress())
//        let profile:[String:JSON] = ["id" : , "displayName" : , "provider" : ]
//        let json:JSON = JSON(jsonDictionary: profile)
        //redriect with anon scope
        var dictionary = [String: Any]()
        dictionary["displayName"] = "disp name"
        dictionary["provider"] = "prov"
        dictionary["id"] = "someid"
        request.session?["userProfile"] = dictionary

        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&idp=appid_anon", expectation: expectation(description: "test4"))
        web.authenticate(request: request, response: response, options: ["allowAnonymousLogin": true], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test4.5")))

        request.session?["userProfile"] = nil
        //session has user profile on it
        request.session?["userProfile"] = dictionary
            web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "someid", name: "disp name", provider: "prov", expectation: expectation(description: "test5")), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress())

        request.session?["userProfile"] = nil

        //requst has user profile on it
        request.userProfile = UserProfile(id:"1", displayName: "2", provider: "3")
        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "1", name: "2", provider: "3", expectation: expectation(description: "test6")), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress())

        //request has user profile but force login is true + no auth context + allow anonymous login + not allow create new anonymous
        request.userProfile = UserProfile(id:"1", displayName: "2", provider: "3")
        web.authenticate(request: request, response: response, options: ["forceLogin": true, "allowAnonymousLogin": true, "allowCreateNewAnonymousUser": false], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectation: expectation(description: "test7")), onPass: onPass, inProgress:setInProgress())
        //a previous access token exists - not anonymous context
        request.session?["userProfile"] = dictionary
        request.session?[Constants.AuthContext.name] = [:]
        request.session?[Constants.AuthContext.name] = ["accessTokenPayload": try! Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"]]
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default", expectation: expectation(description: "test8"))
        web.authenticate(request: request, response: response, options: ["forceLogin": true], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test8.5")))

        request.session?["userProfile"] = nil
        //a previous access token exists - with anonymous context
        request.session?[Constants.AuthContext.name] = [:]
        var authContext = request.session?[Constants.AuthContext.name] as? [String : Any]
        authContext?["accessTokenPayload"] = try! Utils.parseToken(from: TestConstants.ANON_TOKEN)["payload"].dictionaryObject
        authContext?["accessToken"] = "someaccesstoken"
        request.session?[Constants.AuthContext.name] = authContext
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken", expectation: expectation(description: "test9"))
        web.authenticate(request: request, response: response, options: ["forceLogin": true], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test9.5")))

        // session is encoded and decoded and data persists
        request.session?[Constants.AuthContext.name] = [:]
        var sessionContext = request.session?[Constants.AuthContext.name] as? [String : Any]
        sessionContext?["accessTokenPayload"] = try! Utils.parseToken(from: TestConstants.ANON_TOKEN)["payload"].dictionaryObject
        sessionContext?["accessToken"] = "someaccesstoken"
        request.session?[Constants.AuthContext.name] = authContext
        request.session?.save { error in
            if let error = error {
                XCTFail("error saving to session: \(error)")
            } else {
                request.session?.reload { error in
                    if let error = error {
                        XCTFail("error loading from session: \(error)")
                    } else {
                        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken", expectation: self.expectation(description: "test10"))
                        web.authenticate(request: request, response: response, options: ["forceLogin": true], onSuccess: self.setOnSuccess(), onFailure: self.setOnFailure(), onPass: self.onPass, inProgress:self.setInProgress(expectation: self.expectation(description: "test10.5")))
                    }
                }
            }
        }
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
        //code on query

        //        let request3 = testRouterRequest(request: httpRequest, url: "http://someurl?code=somecode")
        //        request3.session = SessionState(id: "someSession", store: InMemoryStore())
        //        response = RouterResponse(response: httpResponse, router: Router(), request: request3)
        //        web.authenticate(request: request3, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectation: expectation(description: "test3.5")), onPass: onPass, inProgress:setInProgress())

    }

    func testHandleTokenResponse401() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponse401")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 401)
            .response(string: "somedata")
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect()

        awaitExpectations()
    }

    func testHandleTokenResponseError() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseError")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 401)
            .response(error: NSError(domain: "", code: 1, userInfo: nil))
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect()

        awaitExpectations()
    }

    func testHandleTokenResponseNoData() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseNoData")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 200)
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect()

        awaitExpectations()
    }

    func testHandleTokenResponseMissingAccessToken() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseMissingAccessToken")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 200)
            .response(string: "{\n\"id_token\" : \"\(TestConstants.ID_TOKEN)\"\n}\n\n")
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongTenant() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseAccessTokenWrongTenant")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 200)
            .response(string: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_TENANT)\"\n}\n\n")
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongAudience() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseAccessTokenWrongAudience")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 200)
            .response(string: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_AUD)\"\n}\n\n")
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongIssuer() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseAccessTokenWrongIssuer")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 200)
            .response(string: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_ISS)\"\n}\n\n")
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect()

        awaitExpectations()
    }

    func testHandleTokenResponseMissingIdentityToken() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseSuccess")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 401)
            .response(string: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\"\n}\n\n")
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect(accessToken: TestConstants.ACCESS_TOKEN)

        awaitExpectations()
    }

    func testHandleTokenResponseInvalidIdentityToken() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseInvalidIdentityToken")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 401)
            .response(string: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\",\n\"id_token\" : \"invalid token\"\n}\n\n")
            .setFailure()
            .execute(expectation(description: builder.name))
            .expect(accessToken: TestConstants.ACCESS_TOKEN)

        awaitExpectations()
    }

    func testHandleTokenResponseSuccess() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseSuccess")

        builder
            .setWebMock(with: TestConstants.options)
            .setSession()
            .status(code: 200)
            .response(string: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\",\n\"id_token\" : \"\(TestConstants.ID_TOKEN)\"\n}\n\n")
            .setSuccess(id: "subject", name: "test name", provider: "someprov")
            .execute(expectation(description: builder.name))
            .expect(accessToken: TestConstants.ACCESS_TOKEN, identityToken: TestConstants.ID_TOKEN)

        awaitExpectations()
    }

    func awaitExpectations() {
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
    }

    // Remove off_ for running
    func off_testRunWebAppServer() {
        logger.debug("Starting")

        let router = Router()
        let session = Session(secret: "Some secret")
        router.all(middleware: session)
        router.all("/", middleware: StaticFileServer(path: "./Tests/BluemixAppIDTests/public"))

        let webappKituraCredentialsPlugin = WebAppKituraCredentialsPlugin(options: options)
        let kituraCredentials = Credentials()
        let kituraCredentialsAnonymous = Credentials(options: [
            Constants.AppID.allowAnonymousLogin: true,
            Constants.AppID.allowCreateNewAnonymousUser: true
            ])

        kituraCredentials.register(plugin: webappKituraCredentialsPlugin)
        kituraCredentialsAnonymous.register(plugin: webappKituraCredentialsPlugin)

        router.get(LOGIN_URL,
                   handler: kituraCredentials.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
                                                           successRedirect: LANDING_PAGE_URL,
                                                           failureRedirect: LANDING_PAGE_URL
        ))

        router.get(LOGIN_ANON_URL,
                   handler: kituraCredentialsAnonymous.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
                                                                    successRedirect: LANDING_PAGE_URL,
                                                                    failureRedirect: LANDING_PAGE_URL
        ))

        router.get(CALLBACK_URL,
                   handler: kituraCredentials.authenticate(credentialsType: webappKituraCredentialsPlugin.name,
                                                           successRedirect: LANDING_PAGE_URL,
                                                           failureRedirect: LANDING_PAGE_URL
        ))

        router.get(LOGOUT_URL, handler: { (request, response, _) in
            kituraCredentials.logOut(request: request)
            kituraCredentialsAnonymous.logOut(request: request)
            webappKituraCredentialsPlugin.logout(request: request)
            _ = try? response.redirect(self.LANDING_PAGE_URL)
        })

        router.get("/protected", handler: { (request, response, next) in
            let appIdAuthContext = request.session?[Constants.AuthContext.name] as? [String : Any]
            let identityTokenPayload = appIdAuthContext?["identityTokenPayload"]

            guard appIdAuthContext != nil, identityTokenPayload != nil else {
                response.status(.unauthorized)
                return next()
            }
            print("accessToken:: \(String(describing: appIdAuthContext?["accessToken"]))")
            print("identityToken:: \(String(describing: appIdAuthContext?["identityToken"]))")
            if let payload = identityTokenPayload as? [String : Any] {
                response.send(json: payload)
            }
            next()
        })

        Kitura.addHTTPServer(onPort: 1234, with: router)
        Kitura.run()
    }
}

@available(OSX 10.12, *)
extension WebAppPluginTest {

    @available(OSX 10.12, *)
    class TokenResponseBuilder {
        public let name: String
        private var web: MockWebAppKituraCredentialsPlugin?
        private var httpRequest: HTTPServerRequest
        public var routerRequest: RouterRequest

        private var responseCode: Int = 200
        private var tokenData: String?
        private var tokenError: Swift.Error?
        private var onSuccess: (String, String, String)?
        private var onFailure: Bool = false

        init(name: String) {
            self.name = name
            self.httpRequest = HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
            self.routerRequest = RouterRequest(request: httpRequest)
        }

        func status(code: Int) -> TokenResponseBuilder {
            self.responseCode = code
            return self
        }

        func response(string: String) -> TokenResponseBuilder {
            self.tokenData = string
            return self
        }

        func response(error: Swift.Error) -> TokenResponseBuilder {
            self.tokenError = error
            return self
        }

        func setWebMock(with options: [String: Any]) -> TokenResponseBuilder {
            self.web = MockWebAppKituraCredentialsPlugin(options: TestConstants.options)
            return self
        }

        func setSession() -> TokenResponseBuilder {
            routerRequest.session = SessionState(id: "someSession", store: InMemoryStore())
            return self
        }

        func setSuccess(id: String, name: String, provider: String) -> TokenResponseBuilder {
            self.onSuccess = (id, name, provider)
            return self
        }

        func setFailure() -> TokenResponseBuilder {
            self.onFailure = true
            return self
        }

        @discardableResult
        func execute(_ expect: XCTestExpectation) -> TokenResponseBuilder {
            web?.handleTokenResponse(httpCode: responseCode,
                                     tokenData: tokenData?.data(using: .utf8),
                                     tokenError: tokenError,
                                     originalRequest: routerRequest,
                                     onFailure: setOnFailure(expectation: self.onFailure ? expect : nil),
                                     onSuccess: setOnSuccess(id: onSuccess?.0 ?? "",
                                                             name: onSuccess?.1 ?? "",
                                                             provider: onSuccess?.2 ?? "",
                                                             expectation: self.onFailure ? nil : expect))

            return self
        }

        func expect(accessToken: String? = nil, identityToken: String? = nil) {

            if accessToken == nil && identityToken == nil {
                XCTAssertNil(routerRequest.session?["APPID_AUTH_CONTEXT"])
                return
            }

            let jsonData = JSON(routerRequest.session?["APPID_AUTH_CONTEXT"] as Any)
            guard let dict = jsonData.dictionary else { return }

            if let expectedAccessToken = accessToken {
                XCTAssertEqual(dict["accessToken"]?.string, expectedAccessToken)
                XCTAssertEqual(dict["accessTokenPayload"], try? Utils.parseToken(from: expectedAccessToken)["payload"])
            }
            if let expectedIdentityToken = identityToken {
                XCTAssertEqual(dict["identityToken"]?.string, expectedIdentityToken)
                XCTAssertEqual(dict["identityTokenPayload"], try? Utils.parseToken(from: expectedIdentityToken)["payload"])
            } else {
                XCTAssertNil(dict["identityToken"])
                XCTAssertNil(dict["identityTokenPayload"])
            }
        }

        private func setOnFailure(expectation: XCTestExpectation? = nil) -> ((_ code: HTTPStatusCode?, _ headers: [String: String]?) -> Void) {

            return { (code: HTTPStatusCode?, headers: [String:String]?) -> Void in
                if let expectation = expectation {
                    XCTAssertNil(code)
                    XCTAssertNil(headers)
                    expectation.fulfill()
                } else {
                    XCTFail()
                }
            }
        }

        private func setOnSuccess(id: String = "", name: String = "", provider: String = "", expectation: XCTestExpectation? = nil) -> ((_: UserProfile ) -> Void) {

            return { (profile: UserProfile) -> Void in
                if let expectation = expectation {
                    XCTAssertEqual(profile.id, id)
                    XCTAssertEqual(profile.displayName, name)
                    XCTAssertEqual(profile.provider, provider)
                    expectation.fulfill()
                } else {
                    XCTFail()
                }
            }
        }
    }
}
