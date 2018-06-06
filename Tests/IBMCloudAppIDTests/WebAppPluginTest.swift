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

@testable import IBMCloudAppID

@available(OSX 10.12, *)
class WebAppPluginTest: XCTestCase {

    static var allTests: [(String, (WebAppPluginTest) -> () throws -> Void)] {
        return [
            ("testLogout", testLogout),
            ("testWebAuthenticateCodeOnQuery", testWebAuthenticateCodeOnQuery),
            ("testWebAuthenticateSessionPersists", testWebAuthenticateSessionPersists),
            ("testWebAuthenticatePrevAccessTokenWithAnon", testWebAuthenticatePrevAccessTokenWithAnon),
            ("testWebAuthenticatePrevAccessTokenNotAnon", testWebAuthenticatePrevAccessTokenNotAnon),
            ("testWebAuthenticateFailure", testWebAuthenticateFailure),
            ("testWebAuthenticateRequestHasUserProfile", testWebAuthenticateRequestHasUserProfile),
            ("testWebAuthenticateSessionHasUserProfile", testWebAuthenticateSessionHasUserProfile),
            ("testWebAuthenticateRedirectWithAnonScope", testWebAuthenticateRedirectWithAnonScope),
            ("testWebAuthenticateErrorInQuery", testWebAuthenticateErrorInQuery),
            ("testWebAuthenticateRedirect", testWebAuthenticateRedirect),
            ("testWebAuthenticateNoSession", testWebAuthenticateNoSession),
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

    let logger = Logger(forName:"WebAppPluginTest")

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

    func testWebAuthenticateNoSession() {
        let builder = WebResponseBuilder(name: "testWebAuthenticateNoSession")

        builder.setWebMock(options: TestConstants.options)
        builder.expectFailure(with: expectation(description: "No Session"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateRedirect() {
        let builder = WebResponseBuilder(name: "testWebAuthenticateRedirect")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.expectInProgress(with: expectation(description: "Redirect"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateErrorInQuery() {
        let builder = WebResponseBuilder(name: "testWebAuthenticateErrorInQuery")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.mockRequest(url: TestConstants.serverUrl + "?error=someerr")
        builder.expectFailure(with: expectation(description: "Error Response"))
        builder.execute()

        awaitExpectations()

    }

    func testWebAuthenticateRedirectWithAnonScope() {
        let dict: [String: Any] = [ "displayName": "disp name", "provider": "prov", "id": "someid" ]
        let redirectUri = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId +
        "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&idp=appid_anon"

        let builder = WebResponseBuilder(name: "testWebAuthenticateRedirectWithAnonScope")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.setSessionUserProfile(dict: dict)
        builder.authenticateOptions = ["allowAnonymousLogin": true]
        builder.mockResponse(redirectUri: redirectUri, expectation: expectation(description: "expectation"))
        builder.expectInProgress(with: expectation(description: "in progress"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateSessionHasUserProfile() {
        let dict: [String: Any] = [ "displayName": "disp name", "provider": "prov", "id": "someid" ]

        let builder = WebResponseBuilder(name: "testWebAuthenticateSessionHasUserProfile")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.setSessionUserProfile(dict: dict)
        builder.expectSuccess(id: "someid", name: "disp name", provider: "prov", with: expectation(description: "Returned profile"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateRequestHasUserProfile() {
        let builder = WebResponseBuilder(name: "testWebAuthenticateRequestHasUserProfile")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.setRequestUserProfile(id: "1", name: "2", provider: "3")
        builder.expectSuccess(id: "1", name: "2", provider: "3", with: expectation(description: "Returned profile"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateFailure() {
        //request has user profile but force login is true + no auth context + allow anonymous login + not allow create new anonymous
        let builder = WebResponseBuilder(name: "testWebAuthenticateFailure")

        builder.setWebMock(options: TestConstants.options)
        builder.authenticateOptions = ["forceLogin": true, "allowAnonymousLogin": true, "allowCreateNewAnonymousUser": false]
        builder.requireSession()
        builder.setRequestUserProfile(id: "1", name: "2", provider: "3")
        builder.expectFailure(with: expectation(description: "test7"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticatePrevAccessTokenNotAnon() {
        //a previous access token exists - not anonymous context
        let dict: [String: Any] = [ "displayName": "disp name", "provider": "prov", "id": "someid" ]
        let redirectUrl = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default"

        let builder = WebResponseBuilder(name: "testWebAuthenticatePrevAccessTokenNotAnon")

        builder.setWebMock(options: TestConstants.options)
        builder.authenticateOptions = ["forceLogin": true]
        builder.requireSession()
        builder.mockResponse(redirectUri: redirectUrl, expectation: expectation(description: "Redirect"))
        builder.setSessionUserProfile(dict: dict)
        builder.setAuthContextUserProfile(dict: ["accessTokenPayload": try! Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"]])
        builder.expectInProgress(with: expectation(description: "Success"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticatePrevAccessTokenWithAnon() {
        //a previous access token exists - with anonymous context
        let authContext: [String: Any] = ["accessTokenPayload": try! Utils.parseToken(from: TestConstants.ANON_TOKEN)["payload"].dictionaryObject as Any,
                                          "accessToken": "someaccesstoken"]

        let redirectUri = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken"

        let builder = WebResponseBuilder(name: "testWebAuthenticatePrevAccessTokenWithAnon")
        builder.setWebMock(options: TestConstants.options)
        builder.authenticateOptions = ["forceLogin": true]
        builder.requireSession()
        builder.mockResponse(redirectUri: redirectUri, expectation: expectation(description: "Redirecting"))
        builder.setAuthContextUserProfile(dict: authContext)
        builder.expectInProgress(with: expectation(description: "success"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateSessionPersists() {
        // session is encoded and decoded and data persists
        let authContext: [String: Any] = ["accessTokenPayload": try! Utils.parseToken(from: TestConstants.ANON_TOKEN)["payload"].dictionaryObject as Any,
                                          "accessToken": "someaccesstoken"]

        let redirectUri = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken"

        let builder = WebResponseBuilder(name: "testWebAuthenticateSessionPersists")
        builder.setWebMock(options: TestConstants.options)
        builder.authenticateOptions = ["forceLogin": true]
        builder.requireSession()
        builder.mockResponse(redirectUri: redirectUri, expectation: expectation(description: "10"))
        builder.setAuthContextUserProfile(dict: authContext)
        builder.expectInProgress(with: expectation(description: "Session persisted"))

        builder.request.session?.save { error in
            if let error = error {
                XCTFail("error saving to session: \(error)")
            } else {
                builder.request.session?.reload { error in
                    if let error = error {
                        XCTFail("error loading from session: \(error)")
                    } else {
                        builder.execute()
                    }
                }
            }
        }

        awaitExpectations()
    }

    func testWebAuthenticateCodeOnQuery() {
        let builder = WebResponseBuilder(name: "testWebAuthenticateFailure")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.mockRequest(url: "http://someurl?code=somecode")
        builder.expectFailure(with: expectation(description: "failure"))
        builder.execute()
        awaitExpectations()
    }

    func testHandleTokenResponse401() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponse401")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 401
        builder.data = "somedata"
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseError() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseError")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 401
        builder.error = NSError(domain: "", code: 1, userInfo: nil)
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseNoData() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseNoData")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 200
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseMissingAccessToken() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseMissingAccessToken")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 200
        builder.data = "{\n\"id_token\" : \"\(TestConstants.ID_TOKEN)\"\n}\n\n"
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongTenant() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseAccessTokenWrongTenant")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 200
        builder.data = "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_TENANT)\"\n}\n\n"
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongAudience() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseAccessTokenWrongAudience")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 200
        builder.data = "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_AUD)\"\n}\n\n"
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongIssuer() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseAccessTokenWrongIssuer")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 200
        builder.data = "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_ISS)\"\n}\n\n"
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseMissingIdentityToken() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseSuccess")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 401
        builder.data = "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\"\n}\n\n"
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext(accessToken: TestConstants.ACCESS_TOKEN)

        awaitExpectations()
    }

    func testHandleTokenResponseInvalidIdentityToken() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseInvalidIdentityToken")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 401
        builder.data = "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\",\n\"id_token\" : \"invalid token\"\n}\n\n"
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext(accessToken: TestConstants.ACCESS_TOKEN)

        awaitExpectations()
    }

    func testHandleTokenResponseSuccess() {
        let builder = TokenResponseBuilder(name: "testHandleTokenResponseSuccess")

        builder.setWebMock(options: TestConstants.options)
        builder.requireSession()
        builder.status = 200
        builder.data = "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\",\n\"id_token\" : \"\(TestConstants.ID_TOKEN)\"\n}\n\n"
        builder.expectSuccess(id: "subject", name: "test name", provider: "someprov", with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext(accessToken: TestConstants.ACCESS_TOKEN, identityToken: TestConstants.ID_TOKEN)

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

        let options = [
            "clientId": "86148468-1d73-48ac-9b5c-aaa86a34597a",
            "secret": "ODczMjUxZDAtNGJhMy00MzFkLTkzOGUtYmY4YzU0N2U3MTY4",
            "tenantId": "50d0beed-add7-48dd-8b0a-c818cb456bb4",
            "oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/50d0beed-add7-48dd-8b0a-c818cb456bb4",
            "redirectUri": "http://localhost:1234/ibm/bluemix/appid/callback"
        ]

        let LOGIN_URL = "/ibm/bluemix/appid/login"
        let LOGIN_ANON_URL = "/ibm/bluemix/appid/loginanon"
        let CALLBACK_URL = "/ibm/bluemix/appid/callback"
        let LOGOUT_URL = "/ibm/bluemix/appid/logout"
        let LANDING_PAGE_URL = "/index.html"

        let router = Router()
        let session = Session(secret: "Some secret")
        router.all(middleware: session)
        router.all("/", middleware: StaticFileServer(path: "./Tests/IBMCloudAppIDTests/public"))

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
            _ = try? response.redirect(LANDING_PAGE_URL)
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

//////////////////////
// Mocking Classes ///
//////////////////////

@available(OSX 10.12, *)
extension WebAppPluginTest {

    /// Mocks Web Strategy
    class MockWebAppKituraCredentialsPlugin: WebAppKituraCredentialsPlugin {

        init(options: [String: Any]?, responseCode: Int = 200, responseBody: String = "{\"keys\": [\(TestConstants.PUBLIC_KEY)]}") {
            super.init(options: options)
            self.publicKeyUtil = MockPublicKeyUtil(url: self.config.publicKeyServerURL,
                                                   responseCode: responseCode,
                                                   responseBody: responseBody)
        }
    }

    /// Mock Server Delegate
    class delegate: ServerDelegate {
        func handle(request: ServerRequest, response: ServerResponse) {
            return
        }
    }

    /// Mocks Router Request
    class MockRouterRequest: RouterRequest {
        var urlTest: String

        public init(request: HTTPServerRequest, url: String) {
            self.urlTest = url
            super.init(request: request)
        }
        public override var urlURL: URL {
            return URL(string:urlTest)!
        }

    }

    /// Mocks Router Response
    class MockRouterResponse: RouterResponse {
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

    /// Core Web Strategy Testing Handler
    class WebResponseHandler {

        var web: MockWebAppKituraCredentialsPlugin?

        var httpRequest: HTTPServerRequest
        var httpResponse: HTTPServerResponse

        var request: RouterRequest
        var response: RouterResponse

        var routerStack = Stack<Router>()

        var onSuccess: (UserProfile) -> Void = setOnSuccess()
        var inProgress: () -> Void = setInProgress()
        var onFailure: (HTTPStatusCode?, [String: String]?) -> Void = setOnFailure()

        init() {
            httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
            httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet),
                                                                                     using: delegate(),
                                                                                     keepalive: .disabled),
                                                   request: httpRequest)
            routerStack.push(Router())

            request = RouterRequest(request: httpRequest)
            response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        }

        func expectFailure(with expect: XCTestExpectation) {
            onFailure = WebResponseHandler.setOnFailure(expectation: expect)
        }

        func expectInProgress(with expect: XCTestExpectation) {
            inProgress = WebResponseHandler.setInProgress(expectation: expect)
        }

        func expectSuccess(id: String, name: String, provider: String, with expect: XCTestExpectation) {
            onSuccess = WebResponseHandler.setOnSuccess(id: id, name: name, provider: provider, expectation: expect)
        }

        func setWebMock(options: [String: Any]) {
            web = MockWebAppKituraCredentialsPlugin(options: options)
        }

        func mockRequest(url: String) {
            request = MockRouterRequest(request: httpRequest, url: url)
            response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        }

        func mockResponse(redirectUri: String, expectation: XCTestExpectation? = nil) {
            response = MockRouterResponse(response: httpResponse,
                                          router: Router(),
                                          request: request,
                                          redirectUri: redirectUri,
                                          expectation: expectation)
        }

        func requireSession() {
            request.session = SessionState(id: "someSession", store: InMemoryStore())
        }

        func setSessionUserProfile(dict: [String: Any]) {
            request.session?["userProfile"] = dict
        }

        func setRequestUserProfile(id: String, name: String, provider: String) {
            request.userProfile = UserProfile(id: id, displayName: name, provider: provider)
        }

        func setAuthContextUserProfile(dict: [String: Any]) {
            request.session?[Constants.AuthContext.name] = dict
        }

        /// Callback Constructors

        static func setOnFailure(expectation: XCTestExpectation? = nil) -> ((_ code: HTTPStatusCode?, _ headers: [String: String]?) -> Void) {
            return { (code: HTTPStatusCode?, headers: [String: String]?) -> Void in
                if let expectation = expectation {
                    XCTAssertNil(code)
                    XCTAssertNil(headers)
                    expectation.fulfill()
                } else {
                    XCTFail()
                }
            }
        }

        static func setOnSuccess(id: String = "", name: String = "", provider: String = "", expectation: XCTestExpectation? = nil) -> ((_: UserProfile ) -> Void) {
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

        static func onPass(code: HTTPStatusCode?, headers: [String:String]?) {

        }

        static func setInProgress(expectation: XCTestExpectation? = nil) -> (() -> Void) {
            return { () -> Void in
                if let expectation = expectation {
                    expectation.fulfill()
                } else {
                    XCTFail()
                }
            }
        }
    }
}

@available(OSX 10.12, *)
extension WebAppPluginTest {

    // Mocks Authentication Request Handling
    class WebResponseBuilder: WebResponseHandler {

        public let name: String

        public var authenticateOptions: [String: Any] = [:]

        init(name: String) {
            self.name = name
            super.init()
        }

        func execute() {
            guard let web = web else { return XCTFail() }
            web.authenticate(request: request, response: response, options: authenticateOptions, onSuccess: onSuccess,
                             onFailure: onFailure, onPass: WebAppPluginTest.WebResponseHandler.onPass, inProgress: inProgress)
        }
    }

    // Mocks Token Response Handling
    class TokenResponseBuilder: WebResponseHandler {

        let name: String

        var status: Int = 200
        var data: String?
        var error: Swift.Error?

        init(name: String) {
            self.name = name
            super.init()
        }

        func execute() {
            guard let web = web else { return XCTFail() }
            web.handleTokenResponse(httpCode: status, tokenData: data?.data(using: .utf8), tokenError: error,
                                    originalRequest: request, onFailure: onFailure, onSuccess: onSuccess)
        }

        func validateAuthContext(accessToken: String? = nil, identityToken: String? = nil) {

            if accessToken == nil && identityToken == nil {
                XCTAssertNil(request.session?["APPID_AUTH_CONTEXT"])
                return
            }

            let jsonData = JSON(request.session?["APPID_AUTH_CONTEXT"] as Any)
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
    }
}
