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

import Foundation
import Kitura
import Credentials
import KituraNet
import KituraRequest
import SwiftyJSON
import LoggerAPI

public class WebAppStrategy: CredentialsPluginProtocol {
    
    public static var STRATEGY_NAME = "appid-webapp-strategy"
    public static var DEFAULT_SCOPE = "appid_default"
    public static var ORIGINAL_URL = "APPID_ORIGINAL_URL"
    public static var AUTH_CONTEXT = "APPID_AUTH_CONTEXT"
    public static var AUTHORIZATION_PATH = "/authorization"
    public static var TOKEN_PATH = "/token"
    private var serviceConfig:WebAppStrategyConfig
    
    public var redirecting = true
    
    public var usersCache : NSCache<NSString, BaseCacheElement>?
    
    
    public var name: String {
        return WebAppStrategy.STRATEGY_NAME
    }
    
    
    public init(options:[String: Any]?) {
        Log.debug("Initializing WebAppStrategy")
        
        self.serviceConfig = WebAppStrategyConfig(options: options)
    }
    
    
    private func handleAuthorization (request: RouterRequest, response: RouterResponse, options: [String:Any], onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void) {
        
        Log.debug("WebAppStrategy :: handleAuthorization")
        var options = options
        options["allowCreateNewAnonymousUser"] = options["allowCreateNewAnonymousUser"] ?? true
        options["failureRedirect"] = options["failureRedirect"] ?? "/"
        var authUrl = generateAuthorizationUrl(options: options)
        
        // If there's an existing anonymous access token on session - add it to the request url
        let appIdAuthContext = request.session?[WebAppStrategy.AUTH_CONTEXT].dictionary
        if let context = appIdAuthContext, context["accessTokenPayload"]?["amr"][0] == "appid_anon" {
            Log.debug("WebAppStrategy :: handleAuthorization :: added anonymous access_token to url")
            authUrl += "&appid_access_token=" + (context["accessToken"]?.string ?? "")
        }
        
        // If previous anonymous access token not found and new anonymous users are not allowed - fail
        let allowAnonLogin = options["allowAnonymousLogin"] as? Bool ?? false
        let allowCreate = options["allowCreateNewAnonymousUser"] as? Bool ?? true
        if appIdAuthContext  == nil && allowAnonLogin == true && allowCreate != true {
            Log.info("Previous anonymous user not found. Not allowed to create new anonymous users.")
            onFailure(nil,nil) //TODO: make it better
            return
        }
        
        Log.debug("Redirecting to : " + authUrl)
        
        do {
            try response.redirect(authUrl)
        } catch let err {
            onFailure(nil, nil) //TODO: should msg be better here?
        }
    }
    
    
    
    private func retrieveTokens(options:[String:Any], grantCode:String, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void, originalRequest:RouterRequest, onSuccess: @escaping (UserProfile) -> Void) {
        Log.debug("WebAppStrategy :: retrieveTokens")
        let serviceConfig = self.serviceConfig
        
        let clientId = serviceConfig.clientId
        let secret = serviceConfig.secret
        let tokenEndpoint = serviceConfig.oAuthServerUrl + WebAppStrategy.TOKEN_PATH
        let redirectUri = serviceConfig.redirectUri
        let authorization = clientId + ":" + secret
        KituraRequest.request(.post, tokenEndpoint,
                              parameters: [
                                "client_id": clientId,
                                "grant_type": "authorization_code",
                                "redirect_uri": redirectUri,
                                "code": grantCode
            ],
                              headers: ["Authorization" : "basic " + Data(authorization.utf8).base64EncodedString()]).response {
                                request, response, data, error in
                                
                                if  data == nil || error != nil || response?.status != 200 {
                                    let data = data != nil ? String(data: data!, encoding: .utf8) : ""
                                    let error = error != nil ? error!.localizedDescription : ""
                                    let code = response?.status != nil ? String(response!.status): ""
                                    Log.debug("WebAppStrategy :: Failed to obtain tokens" + "err:\(error)\nstatus code \(code)\nbody \(data)")
                                    onFailure(nil,nil) //TODO: send correct err
                                } else {
                                    var body = JSON(data: data!)
                                    var appIdAuthorizationContext:JSON = [:]
                                    
                                    var userId = "##N/A##"
                                    var displayName = "##N/A##"
                                    var provider = "##N/A##"
                                    
                                    if let accessTokenString = body["access_token"].string, let accessTokenPayload = Utils.parseToken(from: accessTokenString)?["payload"] {
                                        // Parse access_token
                                        
                                        appIdAuthorizationContext["accessToken"].string = accessTokenString
                                        appIdAuthorizationContext["accessTokenPayload"] = accessTokenPayload
                                    }
                                    
                                    
                                    if let identityTokenString = body["id_token"].string, let identityTokenPayload = Utils.parseToken(from: identityTokenString)?["payload"] {
                                        // Parse identity_token
                                        appIdAuthorizationContext["identityToken"].string = identityTokenString
                                        appIdAuthorizationContext["identityTokenPayload"] = identityTokenPayload
                                        userId = identityTokenPayload["sub"].string ?? "##N/A##"
                                        displayName = identityTokenPayload["name"].string ?? "##N/A##"
                                        let amr = identityTokenPayload["amr"].array
                                        provider =  amr?[0].string ?? "##N/A##"
                                    }
                                    
                                    originalRequest.session?[WebAppStrategy.AUTH_CONTEXT] = appIdAuthorizationContext
                                    var options = options
                                    //TODO: not sure correct move about options
                                    // Find correct successRedirect
                                    let successRedirect:Bool = options["successRedirect"] as? Bool ?? false
                                    if successRedirect == true {
                                        options["successRedirect"] = options["successRedirect"]
                                    } else if (originalRequest.session != nil) && ((originalRequest.session?[WebAppStrategy.ORIGINAL_URL]) != nil) {
                                        options["successRedirect"] = originalRequest.session?[WebAppStrategy.ORIGINAL_URL]
                                    } else {
                                        options["successRedirect"] = "/"
                                    }
                                    
                                    //TODO: extend user profile
                                    onSuccess(UserProfile(id: userId, displayName: displayName, provider: provider))
                                    Log.debug("completeAuthorizationFlow :: success")
                                    Log.debug("retrieveTokens :: tokens retrieved")
                                    
                                }
                                
                                
        }
    }
    public func authenticate (request: RouterRequest,
                              response: RouterResponse,
                              options: [String:Any],
                              onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              inProgress: @escaping () -> Void) {
        
        
        if request.session == nil {
            Log.error("Can't find request.session. Ensure KituraSession middleware is in use")
            onFailure(nil,nil) //TODO: should msg be better here?
            return
        }
        
        
        if let error = request.queryParameters["error"] {
            Log.warning("Error returned in callback " + error)
            onFailure(nil,nil) //TODO: should msg be better here?
        } else if let code = request.queryParameters["code"] {
            return retrieveTokens(options: options, grantCode: code, onFailure: onFailure, originalRequest: request, onSuccess: onSuccess)
        } else {
            return handleAuthorization(request: request, response: response, options: options, onFailure: onFailure)
        }
    }
    
    
    private func generateAuthorizationUrl(options: [String:Any]) -> String {
        let serviceConfig = self.serviceConfig
        let clientId = serviceConfig.clientId
        let scopeAddition = (options["scope"] as? String) != nil ?  (" " + (options["scope"] as! String)) : ""
        let scope = WebAppStrategy.DEFAULT_SCOPE + scopeAddition
        let authorizationEndpoint = serviceConfig.oAuthServerUrl + WebAppStrategy.AUTHORIZATION_PATH
        let redirectUri = serviceConfig.redirectUri
        var authUrl = Utils.urlEncode("\(authorizationEndpoint)?client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri)&scope=\(scope)")
        
        if (options["allowAnonymousLogin"] as? Bool) == true {
            authUrl += "&idp=appid_anon"
        }
        
        return authUrl
    }
    
    public static func logout(request:RouterRequest) {
        //TODO: only desroying session logs out. solve it
        //     request.session?.destroy(callback: {(err: NSError?) in })
        request.session?.remove(key: WebAppStrategy.ORIGINAL_URL)
        request.session?.remove(key: WebAppStrategy.AUTH_CONTEXT)
    }
    
    
    
}
