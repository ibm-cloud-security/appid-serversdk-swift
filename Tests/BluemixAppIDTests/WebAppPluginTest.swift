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
import SwiftyRequest
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
            ("testHandleTokenResponseInvalidIdentityToken", testHandleTokenResponseInvalidIdentityToken),
            ("testStateParameterMismatch", testStateParameterMismatch),
            ("testStateParameterNotReturned", testStateParameterNotReturned),
            ("testStateParameterNotSaved", testStateParameterNotSaved)
        ]
    }

    let logger = Logger(forName:"WebAppPluginTest")
    let expectedState = "abc123"
    
    func testLogout() {

        let web = MockWebAppKituraCredentialsPlugin(options: TestConstants.options)
        let httpRequest = HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
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
        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateNoSession")

        builder.expectFailure(with: expectation(description: "No Session"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateRedirect() {
        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateRedirect")

        builder.requireSession()
        builder.expectInProgress(with: expectation(description: "Redirect"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateErrorInQuery() {
        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateErrorInQuery")

        builder.requireSession()
        builder.mockRequest(url: TestConstants.serverUrl + "?error=someerr")
        builder.expectFailure(with: expectation(description: "Error Response"))
        builder.execute()

        awaitExpectations()

    }

    func testWebAuthenticateRedirectWithAnonScope() {
        let dict: [String: Any] = [ "displayName": "disp name", "provider": "prov", "id": "someid" ]
        let redirectUri = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId +
        "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&idp=appid_anon&state=\(expectedState)"

        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateRedirectWithAnonScope")

        builder.requireSession()
        builder.setSessionUserProfile(dict: dict)
        builder.setSessionState(expectedState)
        builder.authenticateOptions = ["allowAnonymousLogin": true]
        builder.mockResponse(redirectUri: redirectUri, expectation: expectation(description: "expectation"))
        builder.expectInProgress(with: expectation(description: "in progress"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateSessionHasUserProfile() {
        let dict: [String: Any] = [ "displayName": "disp name", "provider": "prov", "id": "someid" ]

        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateSessionHasUserProfile")

        builder.requireSession()
        builder.setSessionUserProfile(dict: dict)
        builder.expectSuccess(id: "someid", name: "disp name", provider: "prov", with: expectation(description: "Returned profile"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateRequestHasUserProfile() {
        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateRequestHasUserProfile")

        builder.requireSession()
        builder.setRequestUserProfile(id: "1", name: "2", provider: "3")
        builder.expectSuccess(id: "1", name: "2", provider: "3", with: expectation(description: "Returned profile"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticateFailure() {
        //request has user profile but force login is true + no auth context + allow anonymous login + not allow create new anonymous
        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateFailure")

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
        let redirectUrl = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&state=\(expectedState)"

        let builder = AuthorizationRequestHandler(name: "testWebAuthenticatePrevAccessTokenNotAnon")

        builder.authenticateOptions = ["forceLogin": true]
        builder.requireSession()
        builder.mockResponse(redirectUri: redirectUrl, expectation: expectation(description: "Redirect"))
        builder.setSessionUserProfile(dict: dict)
        builder.setSessionState(expectedState)
        builder.setAuthContextUserProfile(dict: ["accessTokenPayload": try! Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"]])
        builder.expectInProgress(with: expectation(description: "Success"))
        builder.execute()

        awaitExpectations()
    }

    func testWebAuthenticatePrevAccessTokenWithAnon() {
        //a previous access token exists - with anonymous context
        let authContext: [String: Any] = ["accessTokenPayload": try! Utils.parseToken(from: TestConstants.ANON_TOKEN)["payload"].dictionaryObject as Any,
                                          "accessToken": "someaccesstoken"]

        let redirectUri = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken&state=\(expectedState)"

        let builder = AuthorizationRequestHandler(name: "testWebAuthenticatePrevAccessTokenWithAnon")

        builder.authenticateOptions = ["forceLogin": true]
        builder.requireSession()
        builder.setSessionState(expectedState)
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

        
        let redirectUri = TestConstants.serverUrl + "/authorization?client_id=" + TestConstants.clientId + "&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken&state=\(expectedState)"

        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateSessionPersists")

        builder.authenticateOptions = ["forceLogin": true]
        builder.requireSession()
        builder.setSessionState(expectedState)
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
        let builder = AuthorizationRequestHandler(name: "testWebAuthenticateFailure")

        builder.requireSession()
        builder.mockRequest(url: "http://someurl?code=somecode")
        builder.expectFailure(with: expectation(description: "failure"))
        builder.execute()
        
        awaitExpectations()
    }

    func testHandleTokenResponse401() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponse401")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 401, body: "somedata")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseError() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseError")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 401, body: "somedata", error: AppIDError.jsonParsingError)
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseNoData() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseNoData")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 200)
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseMissingAccessToken() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseMissingAccessToken")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 200, body: "{\n\"id_token\" : \"\(TestConstants.ID_TOKEN)\"\n}\n\n")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongTenant() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseAccessTokenWrongTenant")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 200, body: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_TENANT)\"\n}\n\n")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongAudience() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseAccessTokenWrongAudience")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 200, body: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_AUD)\"\n}\n\n")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseAccessTokenWrongIssuer() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseAccessTokenWrongIssuer")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 200, body: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN_WRONG_ISS)\"\n}\n\n")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext()

        awaitExpectations()
    }

    func testHandleTokenResponseMissingIdentityToken() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseSuccess")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 401, body: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\"\n}\n\n")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext(accessToken: TestConstants.ACCESS_TOKEN)

        awaitExpectations()
    }

    func testHandleTokenResponseInvalidIdentityToken() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseInvalidIdentityToken")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 200, body: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\",\n\"id_token\" : \"invalid token\"\n}\n\n")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext(accessToken: TestConstants.ACCESS_TOKEN)

        awaitExpectations()
    }

    func testHandleTokenResponseSuccess() {
        let builder = AuthorizationCallbackHandler(name: "testHandleTokenResponseSuccess")

        builder.setDefaultSessionAndState()
        builder.setTokenResponse(status: 200, body: "{\n\"access_token\" : \"\(TestConstants.ACCESS_TOKEN)\",\n\"id_token\" : \"\(TestConstants.ID_TOKEN)\"\n}\n\n")
        builder.expectSuccess(id: "subject", name: "test name", provider: "someprov", with: expectation(description: builder.name))
        builder.execute()
        builder.validateAuthContext(accessToken: TestConstants.ACCESS_TOKEN, identityToken: TestConstants.ID_TOKEN)

        awaitExpectations()
    }

    func testStateParameterMismatch() {
        let builder = AuthorizationCallbackHandler(name: "testStateParameterMismatch")
        
        builder.requireSession()
        builder.setSessionState("original_state")
        builder.setRedirectUriState("wrong_state")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        
        awaitExpectations()
    }

    func testStateParameterNotSaved() {
        let builder = AuthorizationCallbackHandler(name: "testStateParameterNotSaved")
        
        builder.setRedirectUriState("wrong_state")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        
        awaitExpectations()
    }
    
    func testStateParameterNotReturned() {
        let builder = AuthorizationCallbackHandler(name: "testStateParameterNotReturned")
        
        builder.requireSession()
        builder.setSessionState("original_state")
        builder.expectFailure(with: expectation(description: builder.name))
        builder.execute()
        
        awaitExpectations()
    }
    
    func awaitExpectations() {
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
    }
    
    // Remove off_ to run sample app
    func off_testRunWebAppServer() {
        logger.debug("Starting")

        let options = [
            "apikey": "8UtThbBNmt7S3V3uNJYiLogq0ETqGIkqi51vYR2Pd12a",
            "clientId": "bd79b940-bb8b-4f34-a205-d585cd14eedf",
            "iam_apikey_description": "Auto generated apikey during resource-key operation for Instance - crn:v1:bluemix:public:appid:us-south:a/bb525b5d9d27128460eaaa9e4a2ca718:798288dc-79cb-4faf-9825-dad68cd4ed6f::",
            "iam_apikey_name": "auto-generated-apikey-bd79b940-bb8b-4f34-a205-d585cd14eedf",
            "iam_role_crn": "crn:v1:bluemix:public:iam::::serviceRole:Reader",
            "iam_serviceid_crn": "crn:v1:bluemix:public:iam-identity::a/bb525b5d9d27128460eaaa9e4a2ca718::serviceid:ServiceId-790a1c5e-32b3-488f-9ebf-e7b424dad882",
            "managementUrl": "https://appid-management.ng.bluemix.net/management/v4/798288dc-79cb-4faf-9825-dad68cd4ed6f",
            "oauthServerUrl": "https://appid-oauth.ng.bluemix.net/oauth/v3/798288dc-79cb-4faf-9825-dad68cd4ed6f",
            "profilesUrl": "https://appid-profiles.ng.bluemix.net",
            "secret": "YjYxZDg1NTAtNmVkYi00YTA4LTg0ODYtZTYyZGY3NGY3ODU0",
            "tenantId": "798288dc-79cb-4faf-9825-dad68cd4ed6f",
            "redirectUri": "http://localhost:8080/ibm/bluemix/appid/callback"
        ]

        let LOGIN_URL = "/ibm/bluemix/appid/login"
        let LOGIN_ANON_URL = "/ibm/bluemix/appid/loginanon"
        let CALLBACK_URL = "/ibm/bluemix/appid/callback"
        let LOGOUT_URL = "/ibm/bluemix/appid/logout"
        let LANDING_PAGE_URL = "/index.html"

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

        Kitura.addHTTPServer(onPort: 8080, with: router)
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
        
        var generatedState: String
        var requestState: String?
        
        var tokenData: String?
        var tokenStatus: Int = 200
        var tokenError: Swift.Error?
        
        init(options: [String: Any]?, responseCode: Int = 200, responseBody: String = "{\"keys\": [\(TestConstants.PUBLIC_KEY)]}", state: String = "abc123") {
            self.generatedState = state
            super.init(options: options)
            self.publicKeyUtil = MockPublicKeyUtil(url: self.config.publicKeyServerURL,
                                                   responseCode: responseCode,
                                                   responseBody: responseBody)
        }
        
        /// Overrides the token request callback
        override func executeRequest(_ request: RestRequest, completion: @escaping (Data?, HTTPURLResponse?, Swift.Error?) -> Void) {
            completion(tokenData?.data(using: .utf8),
                       HTTPURLResponse(url: URL(string: "http://test.com")!, statusCode: tokenStatus, httpVersion: nil, headerFields: nil),
                       tokenError)
        }
        
        /// Overrides the high entropy state parameter
        override func generateState(of length: Int) -> String {
            return generatedState
        }
        
        /// Overrides the state found in the requests query parameters
        override func getRequestState(from request: RouterRequest) -> String? {
            return requestState
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
        
        let name: String
        
        var web: MockWebAppKituraCredentialsPlugin?

        var httpRequest: HTTPServerRequest
        var httpResponse: HTTPServerResponse

        var request: RouterRequest
        var response: RouterResponse

        var routerStack = Stack<Router>()

        var onSuccess: (UserProfile) -> Void = setOnSuccess()
        var inProgress: () -> Void = setInProgress()
        var onFailure: (HTTPStatusCode?, [String: String]?) -> Void = setOnFailure()
        
        init(name: String) {
            
            self.name = name
            
            web = MockWebAppKituraCredentialsPlugin(options: TestConstants.options)
            
            httpRequest = HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
            httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet),
                                                                                     using: delegate(),
                                                                                     keepalive: .disabled),
                                                   request: httpRequest)
            routerStack.push(Router())

            request = RouterRequest(request: httpRequest)
            response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        }

        // Sets the test to expect a failure. Only one expect method should be called per test
        func expectFailure(with expect: XCTestExpectation) {
            onFailure = WebResponseHandler.setOnFailure(expectation: expect)
        }

        // Sets the test to expect a failure. Only one expect method should be called per test
        func expectInProgress(with expect: XCTestExpectation) {
            inProgress = WebResponseHandler.setInProgress(expectation: expect)
        }

        // Sets the test to expect a success with the specified user profile fields.
        // Only one expect method should be called per test
        func expectSuccess(id: String, name: String, provider: String, with expect: XCTestExpectation) {
            onSuccess = WebResponseHandler.setOnSuccess(id: id, name: name, provider: provider, expectation: expect)
        }

        // Creates the MockWebAppKituraCredentialsPlugin
        // Used to pass different configuration options
        func setWebMock(options: [String: Any]) {
            web = MockWebAppKituraCredentialsPlugin(options: options)
        }

        /// Mock Router Request to return provided url
        func mockRequest(url: String) {
            request = MockRouterRequest(request: httpRequest, url: url)
            response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        }

        /// Mock Router Response to validate redirect uri matches the one sent
        func mockResponse(redirectUri: String, expectation: XCTestExpectation? = nil) {
            response = MockRouterResponse(response: httpResponse,
                                          router: Router(),
                                          request: request,
                                          redirectUri: redirectUri,
                                          expectation: expectation)
        }

        /// Sets the request session if needed
        func requireSession() {
            request.session = SessionState(id: "someSession", store: InMemoryStore())
        }

        /// Adds the userProfile dict to the session
        func setSessionUserProfile(dict: [String: Any]) {
            request.session?["userProfile"] = dict
        }

        /// Adds the state paramter to the session
        func setSessionState(_ state: String) {
            request.session?["state"] = state
        }
        
        /// Adds the user profile object to the request with the provided params
        func setRequestUserProfile(id: String, name: String, provider: String) {
            request.userProfile = UserProfile(id: id, displayName: name, provider: provider)
        }

        /// Adds authroization context to the provided dictionary context
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
    
    // Manages Authentication Request Handling Tests
    class AuthorizationRequestHandler: WebResponseHandler {

        public var authenticateOptions: [String: Any] = [:]

        override init(name: String) {
            super.init(name: name)
        }

        func execute() {
            guard let web = web else { return XCTFail() }
            web.authenticate(request: request, response: response, options: authenticateOptions, onSuccess: onSuccess,
                             onFailure: onFailure, onPass: WebAppPluginTest.WebResponseHandler.onPass, inProgress: inProgress)
        }
    }

    // Manages the Authentication Callback Response Tests
    class AuthorizationCallbackHandler: WebResponseHandler {
        
        override init(name: String) {
            super.init(name: name)
        }

        func execute() {
            guard let web = web else { return XCTFail() }
            web.handleAuthorizationCallback(code: "123",
                                            request: request,
                                            onSuccess: onSuccess,
                                            onFailure: onFailure)
        }

        func setTokenResponse(status: Int = 200, body: String? = nil, error: Swift.Error? = nil) {
            self.web?.tokenStatus = status
            self.web?.tokenError = error
            self.web?.tokenData = body
        }
        
        func setRedirectUriState(_ state: String) {
            self.web?.requestState = state
        }
        
        func setDefaultSessionAndState() {
            requireSession()
            setRedirectUriState("state")
            setSessionState("state")
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
