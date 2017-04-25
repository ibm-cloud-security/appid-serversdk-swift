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
import SimpleLogger
import KituraSession

public class WebAppKituraCredentialsPlugin: CredentialsPluginProtocol {
    
    public static let Name = "appid-webapp-kitura-credentials-plugin"
    public static let AllowAnonymousLogin = "allowAnonymousLogin"
    public static let AllowCreateNewAnonymousUser = "allowCreateNewAnonymousUser"
    public static let ForceLogin = "forceLogin"
    public static let AuthContext = "APPID_AUTH_CONTEXT"
    
    private let DefaultScope = "appid_default"
    private let AuthorizationPath = "/authorization"
    private let TokenPath = "/token"
    private let serviceConfig:WebAppKituraCredentialsPluginConfig
    
    private let logger = Logger(forName: "WebAppKituraCredentialsPlugin")
    
    public let redirecting = true
    
    public var usersCache : NSCache<NSString, BaseCacheElement>?
    
    public var name: String {
        return WebAppKituraCredentialsPlugin.Name
    }
    
    public init(options:[String: Any]?) {
        logger.debug("Initializing WebAppKituraCredentialsPlugin")
        self.serviceConfig = WebAppKituraCredentialsPluginConfig(options: options)
    }
    
    public func authenticate (request: RouterRequest,
                              response: RouterResponse,
                              options: [String:Any],
                              onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                              inProgress: @escaping () -> Void) {
        
        if request.session == nil {
            logger.error("Can't find request.session. Ensure KituraSession middleware is in use")
            onFailure(nil,nil)
            return
        }
        
        if let error = request.queryParameters["error"] {
            logger.warn("Error returned in callback " + error)
            onFailure(nil,nil)
        } else if let code = request.queryParameters["code"] {
            return retrieveTokens(options: options, grantCode: code, onFailure: onFailure, request: request, onSuccess: onSuccess)
        } else {
            return handleAuthorization(request: request, response: response, options: options, onSuccess: onSuccess, onFailure: onFailure, onPass: onPass, inProgress: inProgress)
        }
    }
    
    private func restoreUserProfile(from session: SessionState) -> UserProfile? {
        let sessionUserProfile = session["userProfile"]
        if sessionUserProfile.type != .null  {
            if let dictionary = sessionUserProfile.dictionaryObject,
                let displayName = dictionary["displayName"] as? String,
                let provider = dictionary["provider"] as? String,
                let id = dictionary["id"] as? String {
                
                var userName: UserProfile.UserProfileName?
                if let familyName = dictionary["familyName"] as? String,
                    let givenName = dictionary["givenName"] as? String,
                    let middleName = dictionary["middleName"] as? String {
                    userName = UserProfile.UserProfileName(familyName: familyName, givenName: givenName, middleName: middleName)
                }
                
                var userEmails: Array<UserProfile.UserProfileEmail>?
                if let emails = dictionary["emails"] as? [String], let types = dictionary["emailTypes"] as? [String] {
                    userEmails = Array()
                    for (index, email) in emails.enumerated() {
                        let userEmail = UserProfile.UserProfileEmail(value: email, type: types[index])
                        userEmails!.append(userEmail)
                    }
                }
                
                var userPhotos: Array<UserProfile.UserProfilePhoto>?
                if let photos = dictionary["photos"] as? [String] {
                    userPhotos = Array()
                    for photo in photos {
                        let userPhoto = UserProfile.UserProfilePhoto(photo)
                        userPhotos!.append(userPhoto)
                    }
                }
                
                return UserProfile(id: id, displayName: displayName, provider: provider, name: userName, emails: userEmails, photos: userPhotos, extendedProperties: dictionary["extendedProperties"] as? [String:Any])
            }
        }
        return nil
    }
    
    private func handleAuthorization (request: RouterRequest,
                                      response: RouterResponse,
                                      options: [String:Any], // Options is read only
        onSuccess: @escaping (UserProfile) -> Void,
        onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
        onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
        inProgress: @escaping () -> Void) {
        
        logger.debug("WebAppKituraCredentialsPlugin :: handleAuthorization")
        let forceLogin:Bool = options[WebAppKituraCredentialsPlugin.ForceLogin] as? Bool ?? false
        let allowAnonymousLogin:Bool = options[WebAppKituraCredentialsPlugin.AllowAnonymousLogin] as? Bool ?? false
        let allowCreateNewAnonymousUser:Bool = options[WebAppKituraCredentialsPlugin.AllowCreateNewAnonymousUser] as? Bool ?? true
        // If user is already authenticated and new login is not enforced - end processing
        // Otherwise - persist original request url and redirect to authorization
        if (request.userProfile != nil && !forceLogin && !allowAnonymousLogin){
            logger.debug("ALREADY AUTHENTICATED!!!")
            return onSuccess(request.userProfile!)
        } else {
            //			request.session?[OriginalUrl] = JSON(request.originalURL)
        }
        let sessionProfile = request.session?["userProfile"]
        let requestProfile = request.userProfile
        if forceLogin != true && allowAnonymousLogin != true {
            if requestProfile != nil || (sessionProfile != nil && (sessionProfile!.count) > 0) {
                logger.debug("ALREADY AUTHENTICATED!!!")
                if let profile = restoreUserProfile(from: request.session!) {
                    return onSuccess(profile)
                }
            }
        }
        
        var authUrl = generateAuthorizationUrl(options: options)
        
        // If there's an existing anonymous access token on session - add it to the request url
        let appIdAuthContext = request.session?[WebAppKituraCredentialsPlugin.AuthContext].dictionary
        if let context = appIdAuthContext, context["accessTokenPayload"]?["amr"][0] == "appid_anon" {
            logger.debug("WebAppKituraCredentialsPlugin :: handleAuthorization :: added anonymous access_token to url")
            authUrl += "&appid_access_token=" + (context["accessToken"]?.string ?? "")
        }
        
        // If previous anonymous access token not found and new anonymous users are not allowed - fail
        if appIdAuthContext  == nil && allowAnonymousLogin == true && allowCreateNewAnonymousUser != true {
            logger.warn("Previous anonymous user not found. Not allowed to create new anonymous users.")
            return onFailure(nil,nil)
        }
        
        logger.debug("Redirecting to : " + authUrl)
        
        do {
            try response.redirect(authUrl)
            inProgress()
        } catch {
            onFailure(nil, nil)
        }
    }
    
    internal func handleTokenResponse(tokenRequest:ClientRequest?, tokenResponse:ClientResponse?, tokenData: Data?, tokenError: Swift.Error?, originalRequest:RouterRequest, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void, onSuccess: @escaping (UserProfile) -> Void) {
        if  tokenData == nil || tokenError != nil || tokenResponse?.status != 200 {
            let tokenData = tokenData != nil ? String(data: tokenData!, encoding: .utf8) : ""
            let tokenError = tokenError != nil ? tokenError!.localizedDescription : ""
            let code = tokenResponse?.status != nil ? String(tokenResponse!.status): ""
            self.logger.debug("WebAppKituraCredentialsPlugin :: Failed to obtain tokens" + "err:\(tokenError)\nstatus code \(code)\nbody \(String(describing: tokenData))")
            onFailure(nil,nil)
        } else {
            var body = JSON(data: tokenData!)
            var appIdAuthorizationContext:JSON = [:]
            
            
            var kituraUserId = ""
            var kituraDisplayName = ""
            var kituraProvider = ""
            
            if let accessTokenString = body["access_token"].string, let accessTokenPayload = try? Utils.parseToken(from: accessTokenString)["payload"] {
                // Parse access_token
                appIdAuthorizationContext["accessToken"].string = accessTokenString
                appIdAuthorizationContext["accessTokenPayload"] = accessTokenPayload
            } else {
                return onFailure(nil,nil)
            }
            
            if let identityTokenString = body["id_token"].string, let identityToken = try? Utils.parseToken(from: identityTokenString), let context = Utils.getAuthorizedIdentities(from: identityToken) {
                // Parse identity_token
                appIdAuthorizationContext["identityToken"].string = identityTokenString
                appIdAuthorizationContext["identityTokenPayload"] = identityToken["payload"]
                kituraUserId = context.userIdentity.id
                kituraDisplayName = context.userIdentity.displayName
                if context.userIdentity.authBy.count > 0 && context.userIdentity.authBy[0]["provider"].string != nil {
                    kituraProvider =  context.userIdentity.authBy[0]["provider"].stringValue
                } else {
                    kituraProvider =  ""
                }
            }
            
            originalRequest.session?[WebAppKituraCredentialsPlugin.AuthContext] = appIdAuthorizationContext
            
            let userProfile = UserProfile(id: kituraUserId, displayName: kituraDisplayName, provider: kituraProvider)
            onSuccess(userProfile)
            self.logger.debug("retrieveTokens :: tokens retrieved")
        }
    }
    
    
    private func retrieveTokens(options:[String:Any], grantCode:String, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void, request:RouterRequest, onSuccess: @escaping (UserProfile) -> Void) {
        logger.debug("WebAppKituraCredentialsPlugin :: retrieveTokens")
        let serviceConfig = self.serviceConfig
        
        let clientId = serviceConfig.clientId
        let secret = serviceConfig.secret
        let tokenEndpoint = serviceConfig.oAuthServerUrl + TokenPath
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
                                tokenRequest, tokenResponse, tokenData, tokenError in
                                self.handleTokenResponse(tokenRequest: tokenRequest, tokenResponse: tokenResponse, tokenData: tokenData, tokenError: tokenError, originalRequest: request, onFailure: onFailure, onSuccess: onSuccess)
                                
        }
    }
    
    private func generateAuthorizationUrl(options: [String:Any]) -> String {
        let serviceConfig = self.serviceConfig
        let clientId = serviceConfig.clientId
        let scopeAddition = (options["scope"] as? String) != nil ?  (" " + (options["scope"] as! String)) : ""
        let scope = DefaultScope + scopeAddition
        let authorizationEndpoint = serviceConfig.oAuthServerUrl + AuthorizationPath
        let redirectUri = serviceConfig.redirectUri
        var query = "client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri)&scope=\(scope)"
        if (options["allowAnonymousLogin"] as? Bool) == true {
            query += "&idp=appid_anon"
        }
        query = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? query
        let authUrl = "\(authorizationEndpoint)?\(query)"
        return authUrl
    }
    
    public func logout(request:RouterRequest) {
        //        request.session?.remove(key: OriginalUrl)
        request.session?.remove(key: WebAppKituraCredentialsPlugin.AuthContext)
    }
}
