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

    static var allTests : [(String, (WebAppPluginTest) -> () throws -> Void)] {
        return [
            ("testWebConfig", testWebConfig),
            ("testLogout", testLogout),
            ("testWebAuthenticate", testWebAuthenticate),
            ("testHandleTokenResponse", testHandleTokenResponse),
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
    
    let fullOptions =  ["clientId": "someclient",
                        "secret": "somesecret",
                        "tenantId": "sometenant",
                        "oauthServerUrl": "someurl",
                        "redirectUri": "http://someredirect"]
    
    func testWebConfig() {
        unsetenv("VCAP_SERVICES")
        unsetenv("VCAP_APPLICATION")
        var config = WebAppKituraCredentialsPluginConfig(options:[:])
        XCTAssertEqual(config.serviceConfig.count, 0)
        XCTAssertEqual(config.oAuthServerUrl, "")
        XCTAssertEqual(config.clientId, "")
        XCTAssertEqual(config.tenantId, "")
        XCTAssertEqual(config.secret, "")
        XCTAssertEqual(config.redirectUri, "")
        
        setenv("VCAP_SERVICES", "{\n  \"AdvancedMobileAccess\": [\n    {\n      \"credentials\": {\n        \"clientId\": \"vcapclient\",\n        \"secret\": \"vcapsecret\",\n        \"tenantId\": \"vcaptenant\",\n        \"oauthServerUrl\": \"vcapserver\"\n      }\n    }\n  ]\n}", 1)
        setenv("VCAP_APPLICATION", "{\n  \"application_uris\": [\n  \"1\"]\n}", 1)
        config = WebAppKituraCredentialsPluginConfig(options: [:])
        XCTAssertEqual(config.oAuthServerUrl, "vcapserver")
        XCTAssertEqual(config.clientId, "vcapclient")
        XCTAssertEqual(config.tenantId, "vcaptenant")
        XCTAssertEqual(config.secret, "vcapsecret")
        XCTAssertEqual(config.redirectUri, "https://1/ibm/bluemix/appid/callback")
        
        
        setenv("redirectUri", "redirect", 1)
        config = WebAppKituraCredentialsPluginConfig(options: nil)
        XCTAssertEqual(config.oAuthServerUrl, "vcapserver")
        XCTAssertEqual(config.clientId, "vcapclient")
        XCTAssertEqual(config.tenantId, "vcaptenant")
        XCTAssertEqual(config.secret, "vcapsecret")
        XCTAssertEqual(config.redirectUri, "redirect")
        
        config = WebAppKituraCredentialsPluginConfig(options: fullOptions)
        XCTAssertEqual(config.oAuthServerUrl, "someurl")
        XCTAssertEqual(config.clientId, "someclient")
        XCTAssertEqual(config.tenantId, "sometenant")
        XCTAssertEqual(config.secret, "somesecret")
        XCTAssertEqual(config.redirectUri, "http://someredirect")
        unsetenv("VCAP_SERVICES")
        unsetenv("VCAP_APPLICATION")
        
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
    
    func setOnSuccess(id:String = "", name:String = "", provider:String = "",expectation:XCTestExpectation? = nil) -> ((_:UserProfile ) -> Void) {
        
        return { (profile:UserProfile) -> Void in
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
    
    
    func setInProgress(expectation:XCTestExpectation? = nil) -> (() -> Void) {
        
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
        
        let web = WebAppKituraCredentialsPlugin(options: fullOptions)
        let httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
        let request = RouterRequest(request: httpRequest)
        request.session = SessionState(id: "someSession", store: InMemoryStore())
        XCTAssertNil(request.session?[WebAppKituraCredentialsPlugin.AuthContext] as? [String:Any])
        
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = [:]
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = ["accessTokenPayload" : try! Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"]]
        XCTAssertNotNil(request.session?[WebAppKituraCredentialsPlugin.AuthContext] as? [String:Any])
        web.logout(request: request)
        XCTAssertNil(request.session?[WebAppKituraCredentialsPlugin.AuthContext] as? [String:Any])
    }
    
    func testWebAuthenticate() {
        
        //handle auth flow
        
        let web = WebAppKituraCredentialsPlugin(options: fullOptions)
        let httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
        let httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate(), keepalive: .disabled), request: httpRequest)
        let request = RouterRequest(request: httpRequest)

        var routerStack = Stack<Router>()
        routerStack.push(Router())

        var response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request)
        
        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectation: expectation(description: "test1")), onPass: onPass, inProgress:setInProgress())
        //no session
        
        request.session = SessionState(id: "someSession", store: InMemoryStore())
        
        
        class testRouterResponse : RouterResponse {
            public var redirectUri:String
            public var expectation:XCTestExpectation?
            public var routerStack = Stack<Router>()

            public init(response: ServerResponse, router: Router, request: RouterRequest, redirectUri:String, expectation:XCTestExpectation? = nil) {
                self.expectation = expectation
                self.redirectUri = redirectUri
                routerStack.push(Router())
                super.init(response: response, routerStack: routerStack, request: request)
            }
            public override func redirect(_ path: String, status: HTTPStatusCode = .movedTemporarily)  -> RouterResponse {
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
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=http://someredirect&scope=appid_default", expectation: expectation(description: "test2"))
        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test2.5")))
        //error on query
        class testRouterRequest : RouterRequest {
            var urlTest:String
            
            public init(request:HTTPServerRequest, url:String) {
                self.urlTest = url
                super.init(request: request)
            }
            public override var urlURL: URL {
                return URL(string:urlTest)!
            }
            
            
        }
        
        let request2 = testRouterRequest(request: httpRequest, url: "http://someurl?error=someerr")
        request2.session = SessionState(id: "someSession", store: InMemoryStore())
        response = RouterResponse(response: httpResponse, routerStack: routerStack, request: request2)
        web.authenticate(request: request2, response: response, options: [:], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectation: expectation(description: "test3")), onPass: onPass, inProgress:setInProgress())
//        let profile:[String:JSON] = ["id" : , "displayName" : , "provider" : ]
//        let json:JSON = JSON(jsonDictionary: profile)
        //redriect with anon scope
        var dictionary = [String:Any]()
        dictionary["displayName"] = "disp name"
        dictionary["provider"] = "prov"
        dictionary["id"] = "someid"
        request.session?["userProfile"] = dictionary

        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=http://someredirect&scope=appid_default&idp=appid_anon", expectation: expectation(description: "test4"))
        web.authenticate(request: request, response: response, options: ["allowAnonymousLogin" : true], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test4.5")))
        
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
        web.authenticate(request: request, response: response, options: ["forceLogin" : true, "allowAnonymousLogin" : true, "allowCreateNewAnonymousUser": false], onSuccess: setOnSuccess(), onFailure: setOnFailure(expectation: expectation(description: "test7")), onPass: onPass, inProgress:setInProgress())
        //a previous access token exists - not anonymous context
        request.session?["userProfile"] = dictionary
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = [:]
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = ["accessTokenPayload" : try! Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"]]
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=http://someredirect&scope=appid_default", expectation: expectation(description: "test8"))
        web.authenticate(request: request, response: response, options: ["forceLogin": true], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test8.5")))
        
        request.session?["userProfile"] = nil
        //a previous access token exists - with anonymous context
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = [:]
        var authContext = request.session?[WebAppKituraCredentialsPlugin.AuthContext] as? [String : Any]
        authContext?["accessTokenPayload"] = try! Utils.parseToken(from: TestConstants.ANON_TOKEN)["payload"].dictionaryObject
        authContext?["accessToken"] = "someaccesstoken"
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = authContext
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken", expectation: expectation(description: "test9"))
        web.authenticate(request: request, response: response, options: ["forceLogin": true], onSuccess: setOnSuccess(), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(expectation: expectation(description: "test9.5")))
        
        // session is encoded and decoded and data persists
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = [:]
        var sessionContext = request.session?[WebAppKituraCredentialsPlugin.AuthContext] as? [String : Any]
        sessionContext?["accessTokenPayload"] = try! Utils.parseToken(from: TestConstants.ANON_TOKEN)["payload"].dictionaryObject
        sessionContext?["accessToken"] = "someaccesstoken"
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = authContext
        request.session?.save { error in
            if let error = error {
                XCTFail("error saving to session: \(error)")
            } else {
                request.session?.reload { error in
                    if let error = error {
                        XCTFail("error loading from session: \(error)")
                    } else {
                        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=http://someredirect&scope=appid_default&appid_access_token=someaccesstoken", expectation: self.expectation(description: "test10"))
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
    
    
    
    
    
    func testHandleTokenResponse() {
        
        //status is not 200
        
        let web = WebAppKituraCredentialsPlugin(options: fullOptions)
        var response = 401
        let httpRequest =  HTTPServerRequest(socket: try! Socket.create(family: .inet), httpParser: nil)
        
        
        let routerRequest = RouterRequest(request: httpRequest)
        routerRequest.session = SessionState(id: "someSession", store: InMemoryStore())
        web.handleTokenResponse(httpCode: response, tokenData: "somedata".data(using: .utf8), tokenError: nil, originalRequest: routerRequest, onFailure:setOnFailure(expectation: expectation(description: "test1")), onSuccess: setOnSuccess())
        
        //no data in response
        response = 200
        web.handleTokenResponse(httpCode: response, tokenData: nil, tokenError: nil, originalRequest: routerRequest, onFailure:setOnFailure(expectation: expectation(description: "test2")), onSuccess: setOnSuccess())
        
        //        //error in response
        //        web.handleTokenResponse(tokenRequest: request, tokenResponse: response, tokenData: "somedata".data(using: .utf8), tokenError: Swift.Error., originalRequest: routerRequest, onFailure:setOnFailure(expectation: expectation(description: "test3")), onSuccess: setOnSuccess())
        
        //success
        web.handleTokenResponse(httpCode: response, tokenData: "{\n\"access_token\" : \"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJtb2JpbGVjbGllbnRhY2Nlc3Muc3RhZ2UxLm5nLmJsdWVtaXgubmV0IiwiZXhwIjoyNDg3MDg0ODc4LCJhdWQiOiIyNmNiMDEyZWIzMjdjNjEyZDkwYTY4MTkxNjNiNmJjYmQ0ODQ5Y2JiIiwiaWF0IjoxNDg3MDgxMjc4LCJhdXRoX2J5IjoiZmFjZWJvb2siLCJ0ZW5hbnQiOiI0ZGJhOTQzMC01NGU2LTRjZjItYTUxNi02ZjczZmViNzAyYmIiLCJzY29wZSI6ImFwcGlkX2RlZmF1bHQgYXBwaWRfcmVhZHByb2ZpbGUgYXBwaWRfcmVhZHVzZXJhdHRyIGFwcGlkX3dyaXRldXNlcmF0dHIifQ.qU_9KueH3qKLdxqHNdoQ7XOGdjY323WQK9VhzhlhrSkw7dmYkt7bIFVIvr37RJsi7X47v4nsxNewgClmt6tXDcSsQDrvzsq-lFGH2Ot3MFliQxweCzlOTy4EJPHMZtBRHbT6u_7nvegQBTZ1uAqTEQ_0L0eiqGf9BmpY0lDkZNv3Ro73bNku__jdY8M60X-P6trDYHBLOcMdQU0RjTrKm-OQx0jgidKbuTKXlZ2HSASH6knaS1pc7Z89JHeOqg0mF8D4vzD_vwe_yI-XuKg9q3HaFqddaOvVf1tC2cjuy8l54EoyZTLr5aMiPQaboV6DNfyY1YRCfvJd5d7Y1UA5ug\",\n\"id_token\" : \"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJhcHBpZCIsImF1ZCI6ImF1ZDEiLCJleHAiOjI0ODc4NjIyNTMsInRlbmFudCI6InRlc3RUZW5hbnQiLCJpYXQiOjE0ODc4NTg2NTMsImVtYWlsIjoiZW1haWxAZW1haWwuY29tIiwibmFtZSI6InRlc3QgbmFtZSIsInBpY3R1cmUiOiJ0ZXN0SW1hZ2VVcmwiLCJzdWIiOiJzdWJqZWN0IiwiaWRlbnRpdGllcyI6W3sicHJvdmlkZXIiOiJzb21lcHJvdiIsImlkIjoic29tZWlkIn1dLCJhbXIiOlsiZmFjZWJvb2siXSwib2F1dGhfY2xpZW50Ijp7Im5hbWUiOiJzb21lY2xpZW50IiwidHlwZSI6Im1vYmlsZWFwcCIsInNvZnR3YXJlX2lkIjoic29tZUlkIiwic29mdHdhcmVfdmVyc2lvbiI6IjEuMCIsImRldmljZV9pZCI6IjE5MzQ2NDNBLTA3M0UtNEZCOS05MDc2LTQ1RjcxNzkwRDU2MSIsImRldmljZV9tb2RlbCI6ImlQaG9uZSIsImRldmljZV9vcyI6ImlPUyJ9fQ==.sdw2tBI51ltYuwWQGjBDpN1dqLVwOiQOIoC2R1bT5VaUkfFOTLBC_4SFg1eEjdl5FIIxlP4r6oDcOgEccNnAUq-VMn5n6xsGUVdtKEflZ978eEIQ3u7hFjIOVTR853wHABvDvw6Ebv5INY5TFR8xHBF1VMBmlkP5u4Cd6ga90UfqFCPZNQ_0X6pP4rQa0D5FlJX0RaRe3smIepHn5hXsKaFi9TLOf-SXpaEbyuyWh12uKCEqR7b9gm2SsZ9_h0OITpveOa8ns21DxVPV2IL-rCFz57En1Ov2BI6X2NZKihXnClugzmazMs1Dsdw6QIptNaNDTgfvlYp2vWhtGJ0FEw\"\n}\n\n".data(using: .utf8), tokenError: nil, originalRequest: routerRequest, onFailure:setOnFailure(), onSuccess: setOnSuccess(id: "subject", name: "test name", provider: "someprov", expectation: expectation(description: "test2")))
        // no access token in data
        web.handleTokenResponse(httpCode: response, tokenData: "{\n\"id_token\" : \"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJhcHBpZCIsImF1ZCI6ImF1ZDEiLCJleHAiOjI0ODc4NjIyNTMsInRlbmFudCI6InRlc3RUZW5hbnQiLCJpYXQiOjE0ODc4NTg2NTMsImVtYWlsIjoiZW1haWxAZW1haWwuY29tIiwibmFtZSI6InRlc3QgbmFtZSIsInBpY3R1cmUiOiJ0ZXN0SW1hZ2VVcmwiLCJzdWIiOiJzdWJqZWN0IiwiaWRlbnRpdGllcyI6W3sicHJvdmlkZXIiOiJzb21lcHJvdiIsImlkIjoic29tZWlkIn1dLCJhbXIiOlsiZmFjZWJvb2siXSwib2F1dGhfY2xpZW50Ijp7Im5hbWUiOiJzb21lY2xpZW50IiwidHlwZSI6Im1vYmlsZWFwcCIsInNvZnR3YXJlX2lkIjoic29tZUlkIiwic29mdHdhcmVfdmVyc2lvbiI6IjEuMCIsImRldmljZV9pZCI6IjE5MzQ2NDNBLTA3M0UtNEZCOS05MDc2LTQ1RjcxNzkwRDU2MSIsImRldmljZV9tb2RlbCI6ImlQaG9uZSIsImRldmljZV9vcyI6ImlPUyJ9fQ==.sdw2tBI51ltYuwWQGjBDpN1dqLVwOiQOIoC2R1bT5VaUkfFOTLBC_4SFg1eEjdl5FIIxlP4r6oDcOgEccNnAUq-VMn5n6xsGUVdtKEflZ978eEIQ3u7hFjIOVTR853wHABvDvw6Ebv5INY5TFR8xHBF1VMBmlkP5u4Cd6ga90UfqFCPZNQ_0X6pP4rQa0D5FlJX0RaRe3smIepHn5hXsKaFi9TLOf-SXpaEbyuyWh12uKCEqR7b9gm2SsZ9_h0OITpveOa8ns21DxVPV2IL-rCFz57En1Ov2BI6X2NZKihXnClugzmazMs1Dsdw6QIptNaNDTgfvlYp2vWhtGJ0FEw\"\n}\n\n".data(using: .utf8), tokenError: nil, originalRequest: routerRequest, onFailure:setOnFailure(expectation: expectation(description: "test3")), onSuccess: setOnSuccess())
        
        let jsonData = JSON(routerRequest.session?["APPID_AUTH_CONTEXT"] as Any)
        guard let dict = jsonData.dictionary else {return}
        XCTAssertEqual(dict["accessToken"]?.string, TestConstants.ACCESS_TOKEN)
        XCTAssertEqual(dict["accessTokenPayload"], try? Utils.parseToken(from: TestConstants.ACCESS_TOKEN)["payload"])
        XCTAssertEqual(dict["identityToken"]?.string , TestConstants.ID_TOKEN)
        XCTAssertEqual(dict["identityTokenPayload"], try? Utils.parseToken(from: TestConstants.ID_TOKEN)["payload"])
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
        
        
    }
    
    // Remove off_ for running
    func off_testRunWebAppServer(){
        logger.debug("Starting")
        
        let router = Router()
        let session = Session(secret: "Some secret")
        router.all(middleware: session)
        router.all("/", middleware: StaticFileServer(path: "./Tests/BluemixAppIDTests/public"))
        
        let webappKituraCredentialsPlugin = WebAppKituraCredentialsPlugin(options: options)
        let kituraCredentials = Credentials()
        let kituraCredentialsAnonymous = Credentials(options: [
            WebAppKituraCredentialsPlugin.AllowAnonymousLogin: true,
            WebAppKituraCredentialsPlugin.AllowCreateNewAnonymousUser: true
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
        
        router.get(LOGOUT_URL, handler:  { (request, response, next) in
            kituraCredentials.logOut(request: request)
            kituraCredentialsAnonymous.logOut(request: request)
            webappKituraCredentialsPlugin.logout(request: request)
            _ = try? response.redirect(self.LANDING_PAGE_URL)
        })
        
        router.get("/protected", handler: { (request, response, next) in
            let appIdAuthContext = request.session?[WebAppKituraCredentialsPlugin.AuthContext] as? [String : Any]
            let identityTokenPayload = appIdAuthContext?["identityTokenPayload"]
            
            guard appIdAuthContext != nil, identityTokenPayload != nil else {
                response.status(.unauthorized)
                return next()
            }
            print("accessToken:: \(String(describing: appIdAuthContext?["accessToken"]))")
            print("identityToken:: \(String(describing: appIdAuthContext?["identityToken"]))")
            response.send(json: identityTokenPayload as? [String : Any])
            next()
        })
        
        Kitura.addHTTPServer(onPort: 1234, with: router)
        Kitura.run()
    }
}
