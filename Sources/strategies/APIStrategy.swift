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
        var authorizationHeader = request.headers[APIStrategy.AUTH_HEADER]
        var requiredScope = APIStrategy.DEFAULT_SCOPE
        print("1")
        if (options["scope"] as? String) != nil {
            requiredScope += " " + (options["scope"] as! String)
        }
        
        guard authorizationHeader != nil else {
       //     logger.error(MCAErrorInternal.AuthorizationHeaderNotFound.rawValue)
            sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        print("12")
        let authHeaderComponents:[String]! = authorizationHeader?.components(separatedBy: " ")
        
        guard authHeaderComponents[0] == APIStrategy.BEARER else {
      //      logger.error(MCAErrorInternal.InvalidAuthHeaderFormat.rawValue)
sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        print("123")
        // authHeader format :: "Bearer accessToken idToken"
        guard authHeaderComponents?.count == 3 || authHeaderComponents?.count == 2 else {
      //      logger.error(MCAErrorInternal.InvalidAuthHeaderFormat.rawValue)
sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        print("1234")
        let accessTokenString:String = authHeaderComponents[1]
        var accessToken = parseToken(from: accessTokenString)
        let idToken:String? = authHeaderComponents.count == 3 ? authHeaderComponents[2] : nil
        
        guard isAccessTokenValid(accessToken: accessTokenString) else {
sendFailure(scope:requiredScope, error:"Invalid token", onFailure: onFailure, response: response)
            return
        }
        print("12345")
        
        var requiredScopeElements = requiredScope.components(separatedBy: " ")
        var suppliedScopeElements = (accessToken?["scope"] as? String)?.components(separatedBy: " ")
        if suppliedScopeElements != nil {
        for i in 0...requiredScopeElements.count {
            var requiredScopeElement = requiredScopeElements[i]
            var found = false
            for j in 0...suppliedScopeElements!.count {
                var suppliedScopeElement = suppliedScopeElements?[j]
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
        var userProfile:UserProfile
        userProfile = UserProfile(id: "1", displayName: "2", provider: "3")
        onSuccess(userProfile)
//        if let idToken = idToken, let authContext = try? getAuthorizedIdentities(from: idToken){
//            // idToken is present and successfully parsed
//            return completionHandler(nil, authContext)
//        } else if idToken == nil {
//            // idToken is not present
//            return completionHandler(nil, nil)
//        } else {
//            // idToken parsing failed
//            return completionHandler(MCAError.Unauthorized, nil)
////        }
    }
    
    private func isAccessTokenValid(accessToken:String) -> Bool{
    //    logger.debug("isAccessTokenValid:")
        if let jwt = parseToken(from: accessToken) {
            let jwtPayload = jwt["payload"] as? [String: Any]
            let jwtExpirationTimestamp = jwtPayload?["exp"] as? Double
            return Date(timeIntervalSince1970: jwtExpirationTimestamp!) > Date()
        } else {
            return false
        }
    }
    
//    private func getAuthorizedIdentities(from idToken:String) throws -> AuthorizationContext{
//        logger.debug("getAuthorizedIdentities:from:")
//        
//        if let jwt = try? parseToken(from: idToken) {
//            return AuthorizationContext(idTokenPayload: jwt["payload"])
//        } else {
//            throw MCAError.Unauthorized
//        }
//        
//    }
    
    private func parseToken(from tokenString:String) -> [String: Any]? {
        //logger.debug("parseToken:from:")
        
        let accessTokenComponents = tokenString.components(separatedBy: ".")
        
        guard accessTokenComponents.count == 3 else {
          //  logger.error(MCAErrorInternal.InvalidAccessTokenFormat.rawValue)
          // throw MCAErrorInternal.InvalidAccessTokenFormat
            return nil
        }
        
        let jwtHeaderData = accessTokenComponents[0].base64decodedData()
        let jwtPayloadData = accessTokenComponents[1].base64decodedData()
        let jwtSignature = accessTokenComponents[2]
        
        guard jwtHeaderData != nil && jwtPayloadData != nil else {
     //       logger.error(MCAErrorInternal.InvalidAccessTokenFormat.rawValue)
      //      throw MCAErrorInternal.InvalidAccessTokenFormat
            return nil
        }
        
        let jwtHeader =  try! JSONSerialization.jsonObject(with: jwtHeaderData!, options: [])
        let jwtPayload = try! JSONSerialization.jsonObject(with: jwtPayloadData!, options: [])
        
        var json:[String:Any] = [:]
        json["header"] = jwtHeader
        json["payload"] = jwtPayload
        json["signature"] = jwtSignature
        return json
    }
}
