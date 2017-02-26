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


@testable import BluemixAppID

class WebAppPluginTest: XCTestCase {
    
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
                        "redirectUri": "someredirect"]
    
    
    func testWebConfig() {
        //TODO: add tests with VCAP
        var config = WebAppKituraCredentialsPluginConfig(options:[:])
        XCTAssertEqual(config.serviceConfig.count, 0)
        XCTAssertEqual(config.oAuthServerUrl, "")
        XCTAssertEqual(config.clientId, "")
        XCTAssertEqual(config.tenantId, "")
        XCTAssertEqual(config.secret, "")
        XCTAssertEqual(config.redirectUri, "")
        config = WebAppKituraCredentialsPluginConfig(options: fullOptions)
        XCTAssertEqual(config.oAuthServerUrl, "someurl")
        XCTAssertEqual(config.clientId, "someclient")
        XCTAssertEqual(config.tenantId, "sometenant")
        XCTAssertEqual(config.secret, "somesecret")
        XCTAssertEqual(config.redirectUri, "someredirect")
    }
    
    
    func setOnFailure(shouldFail:Bool = false) -> ((_ code: HTTPStatusCode?, _ headers: [String:String]?) -> Void) {
        
        return { (code: HTTPStatusCode?, headers: [String:String]?) -> Void in
            if shouldFail {
                XCTFail()
            }
            XCTAssertNil(code)
            XCTAssertNil(headers)
        }
    }
    func onFailure(_ code: HTTPStatusCode?, _ headers: [String:String]?) -> Void {
        
    }
    func setOnSuccess(id:String = "", name:String = "", provider:String = "", shouldFail:Bool = false) -> ((_:UserProfile ) -> Void) {
        
        return { (profile:UserProfile) -> Void in
            if shouldFail {
                XCTFail()
            }
            XCTAssertEqual(profile.id, id)
            XCTAssertEqual(profile.displayName, name)
            XCTAssertEqual(profile.provider, provider)
        }
        
    }
    
    func onPass(code: HTTPStatusCode?, headers: [String:String]?) {
        
    }
    
    
    func setInProgress(shouldFail:Bool = false) -> (() -> Void) {
        
        return { () -> Void in
            if shouldFail {
                XCTFail()
            }
        }
        
    }
    
    func inProgress() {
        
    }
    
    class delegate: ServerDelegate {
        /// Handle new incoming requests to the server
        ///
        /// - Parameter request: The ServerRequest class instance for working with this request.
        ///                     The ServerRequest object enables you to get the query parameters, headers, and body amongst other
        ///                     information about the incoming request.
        /// - Parameter response: The ServerResponse class instance for working with this request.
        ///                     The ServerResponse object enables you to build and send your response to the client who sent
        ///                     the request. This includes headers, the body, and the response code.
        func handle(request: ServerRequest, response: ServerResponse) {
            return
        }
    }
    let EXPIRED_ACCESS_TOKEN = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJtb2JpbGVjbGllbnRhY2Nlc3Muc3RhZ2UxLm5nLmJsdWVtaXgubmV0IiwiZXhwIjoxNDg3MDg0ODc4LCJhdWQiOiIyNmNiMDEyZWIzMjdjNjEyZDkwYTY4MTkxNjNiNmJjYmQ0ODQ5Y2JiIiwiaWF0IjoxNDg3MDgxMjc4LCJhdXRoX2J5IjoiZmFjZWJvb2siLCJ0ZW5hbnQiOiI0ZGJhOTQzMC01NGU2LTRjZjItYTUxNi02ZjczZmViNzAyYmIiLCJzY29wZSI6ImFwcGlkX2RlZmF1bHQgYXBwaWRfcmVhZHByb2ZpbGUgYXBwaWRfcmVhZHVzZXJhdHRyIGFwcGlkX3dyaXRldXNlcmF0dHIifQ.RDUrrVlMMrhBHxMpKEzQwwQZ5i4hHLSloFVQHwo2SyDYlU83oDgAUXBsCqehXr19PEFPOL5kjXrEeU6V5W8nyRiz3iOBQX7z004-ddf_heY2HEuvAAjqwox9kMlhpYMlMGpwuYwtKYAEcC28qHvg5UKN4CPfzUmP6bSqK2X4A5J11d4oEYNzcHCJpiQgMqbJ_it6UFGXkiQU26SVUq74_gW0_AUHuPmQxCU3-abW1F_PenRE9mJhdcOG2iWYKv5qzP7-DUx0j02ar4ylXjcMmwK0xK3iigoD-ZN_MJs6tUGg2X5ZSk_6rNmtWUlpWZkQNQw4XOBL3K9OAu5pmE-YNg"
    let ACCESS_TOKEN =
    "eyJhbsGciOiJSUasdzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJhcHBpZC1vYXV0aC5zdGFnZTEubXlibHVlbWl4Lm5ldCIsImV4cCI6MTQ4Nzg2MjI1MywiYXVkIjoiYjUyYmViMDk0MTY4ODI2MTZkN2FiMTMwYjRlMDdjNmI3ZTIzZTIxMiIsInN1YiI6ImI0ZGZmMDE1LTMzNzAtNDA4Mi1iNWUwLTdkYWJlZDkxZTIwNiIsImFtciI6WyJmYWNlYm9vayJdLCJpYXQiOjE0ODc4NTg2NTMsInRlbmFudCI6Ijc2OGI1ZDUxLTM3YjAtNDRmNy1hMzUxLTU0ZmU1OWE2N2QxOCIsInNjb3BlIjoiYXBwaWRfZGVmYXVsdCBhcHBpZF9yZWFkcHJvZmlsZSBhcHBpZF9yZWFkdXNlcmF0dHIgYXBwaWRfd3JpdGV1c2VyYXR0ciJ9.VMgVj3mtd-25XekXp7oiH9py10BJhCCdBqXMSmdsmZEpc8-rvg_ltYcqJjnNQ1MWx0YEbOhU5yYmdQFXjK_ghAMCVYfuhpwbNeSd4BjCIQ0An6nT9_5NXAm7a2WRSsGMAQmZ6DDgUXBWbsJImFpev7fPwFtrb3EDmM7Ne6vA_fL_vOfmd6a46z3SMO_rYvVFZ_zVmNBHMkRXacXth36DMm_P1Wy3QF9rT8SMwBzVD_dGCD-IRVSkeYl1f3dXV_06o0UYeG8N8MXEahhKfJK2-24Lsy22FeI6piPnRYtqKleJE5d2Yblb3dX4-uutoAWSNjTnqcnaEnp_EHAxBwMowA"
    
    let ID_TOKEN = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJhcHBpZC1vYXV0aC5zdGFnZTEubXlibHVlbWl4Lm5ldCIsImF1ZCI6ImI1MmJlYjA5NDE2ODgyNjE2ZDdhYjEzMGI0ZTA3YzZiN2UyM2UyMTIiLCJleHAiOjE0ODc4NjIyNTMsInRlbmFudCI6Ijc2OGI1ZDUxLTM3YjAtNDRmNy1hMzUxLTU0ZmU1OWE2N2QxOCIsImlhdCI6MTQ4Nzg1ODY1MywiZW1haWwiOiJkb25sb25xd2VydHlAZ21haWwuY29tIiwibmFtZSI6IkRvbiBMb24iLCJwaWN0dXJlIjoiaHR0cHM6Ly9zY29udGVudC54eC5mYmNkbi5uZXQvdi90MS4wLTEvcDUweDUwLzEzNTAxNTUxXzI4NjQwNzgzODM3ODg5Ml8xNzg1NzY2MjExNzY2NzMwNjk3X24uanBnP29oPTE0OGQyZWVlNjRiYjE0YWZjZDg5MWIyZDVjMWQ2Zjg2Jm9lPTU5MkYzRUJDIiwic3ViIjoiYjRkZmYwMTUtMzM3MC00MDgyLWI1ZTAtN2RhYmVkOTFlMjA2IiwiaWRlbnRpdGllcyI6W3sicHJvdmlkZXIiOiJmYWNlYm9vayIsImlkIjoiMzc3NDQwMTU5Mjc1NjU5In1dLCJhbXIiOlsiZmFjZWJvb2siXSwib2F1dGhfY2xpZW50Ijp7Im5hbWUiOiJPZGVkQXBwSURhcHBpZCIsInR5cGUiOiJtb2JpbGVhcHAiLCJzb2Z0d2FyZV9pZCI6Ik9kZWRBcHBJRGFwcGlkSUQiLCJzb2Z0d2FyZV92ZXJzaW9uIjoiMS4wIiwiZGV2aWNlX2lkIjoiMTkzNDY0M0EtMDczRS00RkI5LTkwNzYtNDVGNzE3OTBENTYxIiwiZGV2aWNlX21vZGVsIjoiaVBob25lIiwiZGV2aWNlX29zIjoiaU9TIn19.Ftx-yfFOHcw1m29QqsTHp08bDi44k9BlWPKEM7O8bdFCpxN96n6qeVL-T_7WbS_RkV-nzPPGo5txUGVmXE_FhVeX4gh2JtSiTotMbCJlIJTf5BLGZQwKcPIGIMDrSD-MYlWbMWikP2xYtSpcc71wZ8M-Xrzft3apNrcpi68VcynQ7dCT6CpuhWw6KTW9LwfQ6I1tZc-Ol1cxEFAOVoTZ2z5or6dSWCUPdYzh4liZV3hzmpW2LMkLYnxSLVi_Tnjg_YsDuBoXHdUlLKRt4RmSFoZOmv0LKCm-J9PcuCfuUbkDyCp9Ncc1epWQqUj12Jqhnd6gnf2E4fKYmUFDgxfyIg"
    
    let ANON_TOKEN = "eyJhbsGciOiJSUasdzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJhcHBpZC1vYXV0aC5zdGFnZTEubXlibHVlbWl4Lm5ldCIsImV4cCI6MTQ4Nzg2MjI1MywiYXVkIjoiYjUyYmViMDk0MTY4ODI2MTZkN2FiMTMwYjRlMDdjNmI3ZTIzZTIxMiIsInN1YiI6ImI0ZGZmMDE1LTMzNzAtNDA4Mi1iNWUwLTdkYWJlZDkxZTIwNiIsImFtciI6WyJhcHBpZF9hbm9uIl0sImlhdCI6MTQ4Nzg1ODY1MywidGVuYW50IjoiNzY4YjVkNTEtMzdiMC00NGY3LWEzNTEtNTRmZTU5YTY3ZDE4Iiwic2NvcGUiOiJhcHBpZF9kZWZhdWx0IGFwcGlkX3JlYWRwcm9maWxlIGFwcGlkX3JlYWR1c2VyYXR0ciBhcHBpZF93cml0ZXVzZXJhdHRyIn0=.VMgVj3mtd-25XekXp7oiH9py10BJhCCdBqXMSmdsmZEpc8-rvg_ltYcqJjnNQ1MWx0YEbOhU5yYmdQFXjK_ghAMCVYfuhpwbNeSd4BjCIQ0An6nT9_5NXAm7a2WRSsGMAQmZ6DDgUXBWbsJImFpev7fPwFtrb3EDmM7Ne6vA_fL_vOfmd6a46z3SMO_rYvVFZ_zVmNBHMkRXacXth36DMm_P1Wy3QF9rT8SMwBzVD_dGCD-IRVSkeYl1f3dXV_06o0UYeG8N8MXEahhKfJK2-24Lsy22FeI6piPnRYtqKleJE5d2Yblb3dX4-uutoAWSNjTnqcnaEnp_EHAxBwMowA"
    
    func testWebAuthenticate() {
        let web = WebAppKituraCredentialsPlugin(options: fullOptions)
        let httpRequest = HTTPServerRequest(socket: try! Socket.create(family: .inet))
        let httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate()))
        let request = RouterRequest(request: httpRequest)
        var response = RouterResponse(response: httpResponse, router: Router(), request: request)
        
        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(shouldFail: true))
        //no session
        
        request.session = SessionState(id: "someSession", store: InMemoryStore())
        //with session but error in query
        //        request.urlURL = "http://error=someerr"
        class testRouterResponse : RouterResponse {
            public var redirectUri:String
            public init(response: ServerResponse, router: Router, request: RouterRequest, redirectUri:String) {
                self.redirectUri = redirectUri
                super.init(response: response,router: router, request: request)
            }
            public override func redirect(_ path: String, status: HTTPStatusCode = .movedTemporarily)  -> RouterResponse {
                XCTAssertEqual(path, redirectUri)
                let httpRequest = HTTPServerRequest(socket: try! Socket.create(family: .inet))
                let httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate()))
                let request = RouterRequest(request: httpRequest)
                let response = RouterResponse(response: httpResponse, router: Router(), request: request)
                return response
                
            }
        }
        // redirect
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=someredirect&scope=appid_default")
        
        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(shouldFail: true))
        
        //redriect with anon scope
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=someredirect&scope=appid_default&idp=appid_anon")
        
        web.authenticate(request: request, response: response, options: ["allowAnonymousLogin" : true], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(shouldFail: true))
        
        //requst has user profile on it
        request.userProfile = UserProfile(id:"1", displayName: "2", provider: "3")
        web.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(shouldFail: true), onPass: onPass, inProgress:setInProgress())
        
        //request has user profile but force login is true +
        //no auth context + allow anonymous login + not allow create new anonymous
        //TODO: add expectations
        request.userProfile = UserProfile(id:"1", displayName: "2", provider: "3")
        
        web.authenticate(request: request, response: response, options: ["forceLogin" : true, "allowAnonymousLogin" : true, "allowCreateNewAnonymousUser": false], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(), onPass: onPass, inProgress:setInProgress(shouldFail: true))
        
        //a previous access token exists - not anonymous context
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = [:]
        
        request.session?[WebAppKituraCredentialsPlugin.AuthContext]["accessTokenPayload"] = try! Utils.parseToken(from: ACCESS_TOKEN)["payload"]
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=someredirect&scope=appid_default")
        
        web.authenticate(request: request, response: response, options: ["forceLogin": true], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(shouldFail: true), onPass: onPass, inProgress:setInProgress(shouldFail: true))
        
        //a previous access token exists - with anonymous context
        request.session?[WebAppKituraCredentialsPlugin.AuthContext] = [:]
        
        request.session?[WebAppKituraCredentialsPlugin.AuthContext]["accessTokenPayload"] = try! Utils.parseToken(from: ANON_TOKEN)["payload"]
        request.session?[WebAppKituraCredentialsPlugin.AuthContext]["accessToken"] = "someaccesstoken"
        response =  testRouterResponse(response: httpResponse, router: Router(), request: request, redirectUri: "someurl/authorization?client_id=someclient&response_type=code&redirect_uri=someredirect&scope=appid_default&appid_access_token=someaccesstoken")
        
        web.authenticate(request: request, response: response, options: ["forceLogin": true], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(shouldFail: true), onPass: onPass, inProgress:setInProgress(shouldFail: true))
        
        //retrieve tokens flow
        //mock request
        
        //handle auth flow
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
            let appIdAuthContext:JSON? = request.session?[WebAppKituraCredentialsPlugin.AuthContext]
            let identityTokenPayload:JSON? = appIdAuthContext?["identityTokenPayload"]
            
            guard appIdAuthContext?.dictionary != nil, identityTokenPayload?.dictionary != nil else {
                response.status(.unauthorized)
                return next()
            }
            
            print("accessToken:: \(appIdAuthContext!["accessToken"])")
            print("identityToken:: \(appIdAuthContext!["identityToken"])")
            response.send(json: identityTokenPayload!)
            next()
        })
        
        Kitura.addHTTPServer(onPort: 1234, with: router)
        Kitura.run()
    }
}
