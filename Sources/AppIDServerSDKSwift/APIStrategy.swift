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
import KituraNet
import Credentials

public class APIStrategy: CredentialsPluginProtocol {
    
    
    private static let HEADER_AUTHORIZATION = "Authorization"
    private static let BEARER = "Bearer"
    private static let AUTH_HEADER = "Authorization"
    private var serviceConfig:APIStrategyConfig?
    private var options:[String:Any]?
    static let AUTHORIZATION_HEADER = "Authorization"
    static let STRATEGY_NAME = "appid-api-strategy"
    static let DEFAULT_SCOPE = "appid_default"
    
    
    public init(options:[String: Any]?) {
        //    logger.debug("Initializing")
        self.options = options ?? [:]
        self.serviceConfig = APIStrategyConfig(options: options)
    }
    
    
    
    public var name: String {
        return APIStrategy.STRATEGY_NAME
    }
    
    public var redirecting = false
    
    public var usersCache : NSCache<NSString, BaseCacheElement>?
    
    public func sendFailure(scope:String, error:String?, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void, response: RouterResponse) {
        //        self.logger.debug("authenticate :: failure")
        response.send("Unauthorized")
        var msg = APIStrategy.BEARER + " scope=\"" + scope + "\""
        if error != nil {
            msg += ", error=\"" + error! + "\""
        }
        
        onFailure(.unauthorized, ["WWW-Authenticate": msg])
    }
    
    
    public func authenticate (request: RouterRequest,
                              response: RouterResponse,
                              options: [String:Any],
                              onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              inProgress: @escaping () -> Void) {
        
        //    logger.debug("authorizationContext:from:completionHandler:")
        let authorizationHeader = request.headers[APIStrategy.AUTH_HEADER]
        var requiredScope = APIStrategy.DEFAULT_SCOPE
        if (options["scope"] as? String) != nil {
            requiredScope += " " + (options["scope"] as! String)
        }
        
        guard let authorizationHeaderUnwrapped = authorizationHeader else {
            //     logger.error(MCAErrorInternal.AuthorizationHeaderNotFound.rawValue)
            sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        
        let authHeaderComponents:[String] = authorizationHeaderUnwrapped.components(separatedBy: " ")
        
        guard authHeaderComponents[0] == APIStrategy.BEARER else {
            //      logger.error(MCAErrorInternal.InvalidAuthHeaderFormat.rawValue)
            sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        
        // authHeader format :: "Bearer accessToken idToken"
        guard authHeaderComponents.count == 3 || authHeaderComponents.count == 2 else {
            //      logger.error(MCAErrorInternal.InvalidAuthHeaderFormat.rawValue)
            sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        
        let accessTokenString:String = authHeaderComponents[1]
        let accessToken = TokenUtils.parseToken(from: accessTokenString)
        let idToken:String? = authHeaderComponents.count == 3 ? authHeaderComponents[2] : nil
        
        guard TokenUtils.isTokenValid(token: accessTokenString) else {
            sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        
        let requiredScopeElements = requiredScope.components(separatedBy: " ")
        let suppliedScopeElements = (accessToken?["scope"] as? String)?.components(separatedBy: " ")
        if suppliedScopeElements != nil {
            for i in 0...requiredScopeElements.count {
                let requiredScopeElement = requiredScopeElements[i]
                var found = false
                for j in 0...suppliedScopeElements!.count {
                    let suppliedScopeElement = suppliedScopeElements?[j]
                    if (requiredScopeElement == suppliedScopeElement) {
                        found = true
                        break
                    }
                }
                if (!found){
                    //       logger.warn("access_token does not contain required scope. Expected ::", requiredScope, " Received ::", accessToken.scope);
                    sendFailure(scope:requiredScope, error:"Insufficient scope", onFailure: onFailure, response: response)
                    return
                }
            }
        }
        
        
        var authorizationContext:[String:Any] = [
            "accessToken": accessTokenString,
            "accessTokenPayload": accessToken as Any
        ]
        
        
        var userId = "##N/A##"
        var displayName = "##N/A##"
        var provider = "##N/A##"
        
        
        if authHeaderComponents.count == 3 {
            let identityTokenString = authHeaderComponents[2]
            if TokenUtils.isTokenValid(token: identityTokenString) == false {
                //logger.debug(bad id token)
            } else {
                //logger.debug(no id token)
            }
            if let idToken = idToken, let authContext = getAuthorizedIdentities(from: idToken){
                // idToken is present and successfully parsed
                
                authorizationContext["identityToken"] = identityTokenString
                authorizationContext["identityTokenPayload"] = idToken
                userId = (authContext["sub"] as? String) ?? "##N/A##"
                displayName = (authContext["name"] as? String) ?? "##N/A##"
                let amr = (authContext["amr"] as? [String])
                provider =  amr != nil ? amr![0] : "##N/A##"
            } else if idToken == nil {
                // idToken is not present
            } else {
                //            return
            }
        }
        request.userInfo["appIdAuthorizationContext"] = authorizationContext
        onSuccess(UserProfile(id: userId, displayName: displayName, provider: provider))
    }
    
       
    private func getAuthorizedIdentities(from idToken:String) -> [String: Any]? {
        //        logger.debug("getAuthorizedIdentities:from:")
        
        if let jwt = TokenUtils.parseToken(from: idToken) {
            return jwt["payload"] as? [String: Any]
        }
        return nil
        
    }
    
    }
