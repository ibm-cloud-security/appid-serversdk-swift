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
import SimpleLogger

public class APIKituraCredentialsPlugin: CredentialsPluginProtocol {
    
    public static let name = "appid-api-kitura-credentials-plugin"
    
    private let Bearer = "Bearer"
    private let AuthHeader = "Authorization"
    private let DefaultScope = "appid_default"
    public  let AuthContext = "APPID_AUTH_CONTEXT"
    private let logger = Logger(forName: "APIKituraCredentialsPlugin")
    
    private var serviceConfig:APIKituraCredentialsPluginConfig?
    
    public init(options:[String: Any]?) {
        logger.debug("Intializing APIKituraCredentialsPlugin")
        logger.warn("This is a beta version of APIKituraCredentialsPlugin, it should not be used for production environments!");
        self.serviceConfig = APIKituraCredentialsPluginConfig(options: options)
    }
    
    public var name: String {
        return APIKituraCredentialsPlugin.name
    }
    
    public var redirecting = false
    
    public var usersCache : NSCache<NSString, BaseCacheElement>?
    
    public func sendFailure(scope:String, error:String?, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void, response: RouterResponse) {
        logger.debug("ApiKituraCredentialsPlugin : sendFailure")
        response.send("Unauthorized")
        var msg = Bearer + " scope=\"" + scope + "\""
        if error != nil {
            msg += ", error=\"" + error! + "\""
        }
        
        onFailure(.unauthorized, ["Www-Authenticate": msg])
    }
    
    
    public func authenticate (request: RouterRequest,
                              response: RouterResponse,
                              options: [String:Any],
                              onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              inProgress: @escaping () -> Void) {
        
        logger.debug("ApiKituraCredentialsPlugin : authenticate")
        let authorizationHeader = request.headers[AuthHeader]
        var requiredScope = DefaultScope
        if (options["scope"] as? String) != nil {
            requiredScope += " " + (options["scope"] as! String)
        }
        
        guard let authorizationHeaderUnwrapped = authorizationHeader else {
            logger.warn("ApiKituraCredentialsPlugin : authorization header not found")
            sendFailure(scope:requiredScope, error:"invalid_token", onFailure: onFailure, response: response)
            return
        }
        
        let authHeaderComponents:[String] = authorizationHeaderUnwrapped.components(separatedBy: " ")
        
        guard authHeaderComponents[0] == Bearer else {
            logger.warn("ApiKituraCredentialsPlugin : invalid authorization header format")
            sendFailure(scope:requiredScope, error:"invalid_token", onFailure: onFailure, response: response)
            return
        }
        
        // authHeader format :: "Bearer accessToken idToken"
        guard authHeaderComponents.count == 3 || authHeaderComponents.count == 2 else {
            logger.warn("ApiKituraCredentialsPlugin : invalid authorization header format")
            sendFailure(scope:requiredScope, error:"invalid_token", onFailure: onFailure, response: response)
            return
        }
        
        let accessTokenString:String = authHeaderComponents[1]
        let accessToken = try? Utils.parseToken(from: accessTokenString)
        let idTokenString:String? = authHeaderComponents.count == 3 ? authHeaderComponents[2] : nil
        
        guard Utils.isTokenValid(token: accessTokenString) else {
            sendFailure(scope:requiredScope, error:"invalid_token", onFailure: onFailure, response: response)
            return
        }
        
        let requiredScopeElements = requiredScope.components(separatedBy: " ")
        let suppliedScopeElements = accessToken?["payload"]["scope"].string?.components(separatedBy: " ")
        if suppliedScopeElements != nil {
            for i in 0..<requiredScopeElements.count {
                let requiredScopeElement = requiredScopeElements[i]
                var found = false
                for j in 0..<suppliedScopeElements!.count {
                    let suppliedScopeElement = suppliedScopeElements?[j]
                    if (requiredScopeElement == suppliedScopeElement) {
                        found = true
                        break
                    }
                }
                if (!found){
                    let receivedScope = accessToken?["scope"].string ?? ""
                    logger.warn("ApiKituraCredentialsPlugin : access_token does not contain required scope. Expected " + requiredScope + " received " + receivedScope)
                    sendFailure(scope:requiredScope, error:"insufficient_scope", onFailure: onFailure, response: response)
                    return
                }
            }
        }
        
        var authorizationContext:[String:Any] = [
            "accessToken": accessTokenString,
            "accessTokenPayload": accessToken?["payload"] as Any
        ]
        
        var userId = ""
        var displayName = ""
        var provider = ""
        
        if authHeaderComponents.count == 3 {
            let identityTokenString = authHeaderComponents[2]
            if Utils.isTokenValid(token: identityTokenString) == true {
                logger.debug("Id token is malformed")
                
                if let idTokenString = idTokenString, let idToken = try? Utils.parseToken(from: idTokenString), let authContext = Utils.getAuthorizedIdentities(from: idToken){
                    logger.debug("Id token is present and successfully parsed")
                    // idToken is present and successfully parsed
                    request.userInfo[AuthContext] = authContext
                    authorizationContext["identityToken"] = identityTokenString
                    authorizationContext["identityTokenPayload"] = idToken["payload"]
                    userId = (authContext.userIdentity.id)
                    displayName = (authContext.userIdentity.displayName)
                    provider = authContext.userIdentity.authBy.count > 0 ? authContext.userIdentity.authBy[0]["provider"].stringValue : ""
                } else if idTokenString == nil {
                    logger.debug("Missing id token")
                } else {
                    logger.debug("id token is malformed")
                }
            } else {
                logger.debug("Missing id token")
            }
        }
        request.userInfo[AuthContext] = authorizationContext
        onSuccess(UserProfile(id: userId, displayName: displayName, provider: provider))
    }
}
