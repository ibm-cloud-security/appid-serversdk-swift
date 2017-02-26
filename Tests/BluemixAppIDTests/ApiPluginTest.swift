import XCTest
import Kitura
import SimpleLogger
import Credentials
@testable import KituraNet
@testable import Kitura
import Socket
import SwiftyJSON

@testable import BluemixAppID

class ApiPluginTest: XCTestCase {
    
    
    
    let options = [
        "oauthServerUrl": "https://appid-oauth.stage1.mybluemix.net/oauth/v3/768b5d51-37b0-44f7-a351-54fe59a67d18"
    ]
    
    let logger = Logger(forName:"ApiPluginTest")
    
    func testApiConfig() {
        //TODO: add tests with VCAP
        var config = APIKituraCredentialsPluginConfig(options:[:])
        XCTAssertEqual(config.serviceConfig.count, 0)
        XCTAssertNil(config.serverUrl)
        config = APIKituraCredentialsPluginConfig(options: ["oauthServerUrl": "someurl"])
        XCTAssertEqual(config.serverUrl, "someurl")
    }
    
    func setOnFailure(expected:String, failTest:Bool = false) -> ((_ code: HTTPStatusCode?, _ headers: [String:String]?) -> Void) {
        
        return { (code: HTTPStatusCode?, headers: [String:String]?) -> Void in
            if failTest {
                XCTFail()
            }
            XCTAssertEqual(code, .unauthorized)
            XCTAssertEqual(headers?["Www-Authenticate"], expected)
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
    "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJtb2JpbGVjbGllbnRhY2Nlc3Muc3RhZ2UxLm5nLmJsdWVtaXgubmV0IiwiZXhwIjoyNDg3MDg0ODc4LCJhdWQiOiIyNmNiMDEyZWIzMjdjNjEyZDkwYTY4MTkxNjNiNmJjYmQ0ODQ5Y2JiIiwiaWF0IjoxNDg3MDgxMjc4LCJhdXRoX2J5IjoiZmFjZWJvb2siLCJ0ZW5hbnQiOiI0ZGJhOTQzMC01NGU2LTRjZjItYTUxNi02ZjczZmViNzAyYmIiLCJzY29wZSI6ImFwcGlkX2RlZmF1bHQgYXBwaWRfcmVhZHByb2ZpbGUgYXBwaWRfcmVhZHVzZXJhdHRyIGFwcGlkX3dyaXRldXNlcmF0dHIifQ.RDUrrVlMMrhBHxMpKEzQwwQZ5i4hHLSloFVQHwo2SyDYlU83oDgAUXBsCqehXr19PEFPOL5kjXrEeU6V5W8nyRiz3iOBQX7z004-ddf_heY2HEuvAAjqwox9kMlhpYMlMGpwuYwtKYAEcC28qHvg5UKN4CPfzUmP6bSqK2X4A5J11d4oEYNzcHCJpiQgMqbJ_it6UFGXkiQU26SVUq74_gW0_AUHuPmQxCU3-abW1F_PenRE9mJhdcOG2iWYKv5qzP7-DUx0j02ar4ylXjcMmwK0xK3iigoD-ZN_MJs6tUGg2X5ZSk_6rNmtWUlpWZkQNQw4XOBL3K9OAu5pmE-YNg"
    
    let ID_TOKEN = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpPU0UifQ.eyJpc3MiOiJhcHBpZC1vYXV0aC5zdGFnZTEubXlibHVlbWl4Lm5ldCIsImF1ZCI6ImI1MmJlYjA5NDE2ODgyNjE2ZDdhYjEzMGI0ZTA3YzZiN2UyM2UyMTIiLCJleHAiOjE0ODc4NjIyNTMsInRlbmFudCI6Ijc2OGI1ZDUxLTM3YjAtNDRmNy1hMzUxLTU0ZmU1OWE2N2QxOCIsImlhdCI6MTQ4Nzg1ODY1MywiZW1haWwiOiJkb25sb25xd2VydHlAZ21haWwuY29tIiwibmFtZSI6IkRvbiBMb24iLCJwaWN0dXJlIjoiaHR0cHM6Ly9zY29udGVudC54eC5mYmNkbi5uZXQvdi90MS4wLTEvcDUweDUwLzEzNTAxNTUxXzI4NjQwNzgzODM3ODg5Ml8xNzg1NzY2MjExNzY2NzMwNjk3X24uanBnP29oPTE0OGQyZWVlNjRiYjE0YWZjZDg5MWIyZDVjMWQ2Zjg2Jm9lPTU5MkYzRUJDIiwic3ViIjoiYjRkZmYwMTUtMzM3MC00MDgyLWI1ZTAtN2RhYmVkOTFlMjA2IiwiaWRlbnRpdGllcyI6W3sicHJvdmlkZXIiOiJmYWNlYm9vayIsImlkIjoiMzc3NDQwMTU5Mjc1NjU5In1dLCJhbXIiOlsiZmFjZWJvb2siXSwib2F1dGhfY2xpZW50Ijp7Im5hbWUiOiJPZGVkQXBwSURhcHBpZCIsInR5cGUiOiJtb2JpbGVhcHAiLCJzb2Z0d2FyZV9pZCI6Ik9kZWRBcHBJRGFwcGlkSUQiLCJzb2Z0d2FyZV92ZXJzaW9uIjoiMS4wIiwiZGV2aWNlX2lkIjoiMTkzNDY0M0EtMDczRS00RkI5LTkwNzYtNDVGNzE3OTBENTYxIiwiZGV2aWNlX21vZGVsIjoiaVBob25lIiwiZGV2aWNlX29zIjoiaU9TIn19.Ftx-yfFOHcw1m29QqsTHp08bDi44k9BlWPKEM7O8bdFCpxN96n6qeVL-T_7WbS_RkV-nzPPGo5txUGVmXE_FhVeX4gh2JtSiTotMbCJlIJTf5BLGZQwKcPIGIMDrSD-MYlWbMWikP2xYtSpcc71wZ8M-Xrzft3apNrcpi68VcynQ7dCT6CpuhWw6KTW9LwfQ6I1tZc-Ol1cxEFAOVoTZ2z5or6dSWCUPdYzh4liZV3hzmpW2LMkLYnxSLVi_Tnjg_YsDuBoXHdUlLKRt4RmSFoZOmv0LKCm-J9PcuCfuUbkDyCp9Ncc1epWQqUj12Jqhnd6gnf2E4fKYmUFDgxfyIg"
    
    
    
    func testApiAuthenticate() {
        //no authorization header
        let api = APIKituraCredentialsPlugin(options:[:])
        let httpRequest = HTTPServerRequest(socket: try! Socket.create(family: .inet))
        let httpResponse = HTTPServerResponse(processor: IncomingHTTPSocketProcessor(socket: try! Socket.create(family: .inet), using: delegate()))
        var request = RouterRequest(request: httpRequest)
        var response = RouterResponse(response: httpResponse, router: Router(), request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(expected: "Bearer scope=\"appid_default\", error=\"invalid_token\""), onPass: onPass, inProgress:inProgress)
        
        //auth header does not start with bearer
        httpRequest.headers["Authorization"] =  [ACCESS_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, router: Router(), request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(expected: "Bearer scope=\"appid_default\", error=\"invalid_token\""), onPass: onPass, inProgress:inProgress)
        
        //auth header does not have correct structure
        httpRequest.headers["Authorization"] =  ["Bearer"]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, router: Router(), request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(expected: "Bearer scope=\"appid_default\", error=\"invalid_token\""), onPass: onPass, inProgress:inProgress)
        
        //expired access token
        httpRequest.headers["Authorization"] =  ["Bearer " + EXPIRED_ACCESS_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, router: Router(), request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(shouldFail: true), onFailure: setOnFailure(expected: "Bearer scope=\"appid_default\", error=\"invalid_token\""), onPass: onPass, inProgress:inProgress)
        
        //happy flow with no id token
        httpRequest.headers["Authorization"] =  ["Bearer " + ACCESS_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, router: Router(), request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "", name: "", provider: ""), onFailure: setOnFailure(expected: "", failTest: true), onPass: onPass, inProgress:inProgress)
        
        
        XCTAssertEqual(((request.userInfo as [String:Any])["appIdAuthorizationContext"] as? [String:Any])?["accessToken"] as? String , ACCESS_TOKEN)
        XCTAssertEqual(((request.userInfo as [String:Any])["appIdAuthorizationContext"] as? [String:Any])?["accessTokenPayload"] as? JSON , try? Utils.parseToken(from: ACCESS_TOKEN)["payload"])
        //test the scope part
        //expired id token
        
        //        httpRequest.headers["Authorization"] =  ["Bearer " + ACCESS_TOKEN + " " + EXPIRED_ID_TOKEN]
        //        request = RouterRequest(request: httpRequest)
        //        response = RouterResponse(response: httpResponse, router: Router(), request: request)
        //        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "", name: "", provider: ""), onFailure: setOnFailure(expected: "", failTest: true), onPass: onPass, inProgress:inProgress)
        
        //happy flow with id token
        httpRequest.headers["Authorization"] =  ["Bearer " + ACCESS_TOKEN + " " + ID_TOKEN]
        request = RouterRequest(request: httpRequest)
        response = RouterResponse(response: httpResponse, router: Router(), request: request)
        api.authenticate(request: request, response: response, options: [:], onSuccess: setOnSuccess(id: "b4dff015-3370-4082-b5e0-7dabed91e206", name: "Don Lon", provider: "facebook"), onFailure: setOnFailure(expected: "", failTest: true), onPass: onPass, inProgress:inProgress)
        XCTAssertEqual(((request.userInfo as [String:Any])["appIdAuthorizationContext"] as? [String:Any])?["accessToken"] as? String , ACCESS_TOKEN)
        XCTAssertEqual(((request.userInfo as [String:Any])["appIdAuthorizationContext"] as? [String:Any])?["accessTokenPayload"] as? JSON , try? Utils.parseToken(from: ACCESS_TOKEN)["payload"])
        XCTAssertEqual(((request.userInfo as [String:Any])["appIdAuthorizationContext"] as? [String:Any])?["identityToken"] as? String , ID_TOKEN)
        XCTAssertEqual(((request.userInfo as [String:Any])["appIdAuthorizationContext"] as? [String:Any])?["identityTokenPayload"] as? JSON , try? Utils.parseToken(from: ID_TOKEN)["payload"])
        
        
    }
    
    
    
    
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
}
