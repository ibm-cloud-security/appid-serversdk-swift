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
import SwiftyRequest
import SwiftyJSON
import SimpleLogger
import KituraSession

@available(OSX 10.12, *)
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
        if let sessionUserProfile = session["userProfile"],
           let dictionary = sessionUserProfile as? [String : Any],
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
                userEmails = emails.enumerated().map { UserProfile.UserProfileEmail(value: $1, type: types[$0]) }
            }
            
            var userPhotos: Array<UserProfile.UserProfilePhoto>?
            if let photos = dictionary["photos"] as? [String] {
                userPhotos = photos.map { UserProfile.UserProfilePhoto($0) }
            }
            
            return UserProfile(id: id, displayName: displayName, provider: provider, name: userName, emails: userEmails, photos: userPhotos, extendedProperties: dictionary["extendedProperties"] as? [String:Any])
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
        if let requestUserProfile = request.userProfile, !forceLogin && !allowAnonymousLogin {
            logger.debug("ALREADY AUTHENTICATED!!!")
            return onSuccess(requestUserProfile)
        } else {
            //			request.session?[OriginalUrl] = JSON(request.originalURL)
        }
        let sessionProfile = request.session?["userProfile"] as? [String]
        let requestProfile = request.userProfile
        if forceLogin != true && allowAnonymousLogin != true {
            if requestProfile != nil || sessionProfile?.isEmpty == false {
                logger.debug("ALREADY AUTHENTICATED!!!")
                if let session = request.session, let profile = restoreUserProfile(from: session) {
                    return onSuccess(profile)
                }
            }
        }
        
        var authUrl = generateAuthorizationUrl(options: options)
        
        // If there's an existing anonymous access token on session - add it to the request url
        if let appIdAuthContext = request.session?[WebAppKituraCredentialsPlugin.AuthContext] as? [String : Any] {
            let payload = appIdAuthContext["accessTokenPayload"] as? [String : Any]
            if (payload?["amr"] as? [String])?[0] ==  "appid_anon" {
                logger.debug("WebAppKituraCredentialsPlugin :: handleAuthorization :: added anonymous access_token to url")
                authUrl += "&appid_access_token=" + ((appIdAuthContext["accessToken"] as? String) ?? "")
            }
        } else if allowAnonymousLogin && !allowCreateNewAnonymousUser {
            // If previous anonymous access token not found and new anonymous users are not allowed - fail
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
    
    internal func handleTokenResponse(httpCode: Int?, tokenData: Data?, tokenError: Swift.Error?, originalRequest:RouterRequest, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void, onSuccess: @escaping (UserProfile) -> Void) {
        
        let code = httpCode.map { String(describing: $0) } ?? "<no http code>"
        if let tokenError = tokenError {
            let errorMessage = String(describing: tokenError)
            self.logger.debug("WebAppKituraCredentialsPlugin :: Failed to obtain tokens. error message : \(errorMessage)\nstatus code : \(code)\ntoken body : \(String(describing: tokenData))")
            return onFailure(nil,nil)
        }
        guard let tokenData = tokenData else {
            self.logger.debug("WebAppKituraCredentialsPlugin :: Failed to obtain tokens. No token error message. No token data. status code : \(code)")
            return onFailure(nil,nil)
        }
        guard httpCode == 200 else {
            self.logger.debug("WebAppKituraCredentialsPlugin :: Failed to obtain tokens. status code wasn't 200. No token error message. status code : \(code)\n token body : \(String(describing: tokenData))")
            return onFailure(nil,nil)
        }
        
        var body = JSON(data: tokenData)
        var appIdAuthorizationContext: [String:Any] = [:]
        
        
        var kituraUserId = ""
        var kituraDisplayName = ""
        var kituraProvider = ""
        
        if let accessTokenString = body["access_token"].string, let accessTokenPayload = try? Utils.parseToken(from: accessTokenString)["payload"] {
            // Parse access_token
            appIdAuthorizationContext["accessToken"] = accessTokenString
            appIdAuthorizationContext["accessTokenPayload"] = accessTokenPayload.dictionaryObject
        } else {
            return onFailure(nil,nil)
        }
        
        if let identityTokenString = body["id_token"].string, let identityToken = try? Utils.parseToken(from: identityTokenString), let context = Utils.getAuthorizedIdentities(from: identityToken) {
            // Parse identity_token
            appIdAuthorizationContext["identityToken"] = identityTokenString
            appIdAuthorizationContext["identityTokenPayload"] = identityToken["payload"].dictionaryObject
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
    
    
    private func retrieveTokens(options:[String:Any], grantCode:String, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void, request:RouterRequest, onSuccess: @escaping (UserProfile) -> Void) {
        logger.debug("WebAppKituraCredentialsPlugin :: retrieveTokens")
        let serviceConfig = self.serviceConfig
        
        let clientId = serviceConfig.clientId
        let secret = serviceConfig.secret
        let tokenEndpoint = serviceConfig.oAuthServerUrl + TokenPath
        let redirectUri = serviceConfig.redirectUri
        let authorization = clientId + ":" + secret
        
        let restReq = RestRequest(method: .post, url: tokenEndpoint, containsSelfSignedCert: false)
        restReq.headerParameters = ["Authorization" : "basic " + Data(authorization.utf8).base64EncodedString()]
        let params = [ "client_id": clientId, "grant_type": "authorization_code", "redirect_uri": redirectUri, "code": grantCode ]
        if let json = try? JSONSerialization.data(withJSONObject: params, options: []) {
            restReq.messageBody = json
        } else {
            logger.debug("Failed to parse data into JSON.")
        }
        
        restReq.response { (tokenData, tokenResponse, tokenError) in
            if let e = tokenError {
                self.logger.debug("An error occured in the token response. Error: \(e)")
            }
            else if let tokenResponse = tokenResponse, let tokenData = tokenData {
                self.handleTokenResponse(httpCode: tokenResponse.statusCode, tokenData: tokenData, tokenError: tokenError, originalRequest: request, onFailure: onFailure, onSuccess: onSuccess)
            }
            else {
                self.logger.debug("An internal error occured. Request failed.")
            }
        }

        
        
    }
    
    private func generateAuthorizationUrl(options: [String:Any]) -> String {
        let serviceConfig = self.serviceConfig
        let clientId = serviceConfig.clientId
        var scopeAddition : String?
        if let addition = options["scope"] as? String {
            scopeAddition = " " + addition
        }
        let scope = DefaultScope + (scopeAddition ?? "")
        let authorizationEndpoint = serviceConfig.oAuthServerUrl + AuthorizationPath
        let redirectUri = serviceConfig.redirectUri
        var query = "client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri)&scope=\(scope)"
        if (options["allowAnonymousLogin"] as? Bool) == true {
            query += "&idp=appid_anon"
        }
        query = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let authUrl = "\(authorizationEndpoint)?\(query)"
        self.logger.debug("AUTHURL: \(authUrl)")
        return authUrl
    }
    
    public func logout(request:RouterRequest) {
        //        request.session?.remove(key: OriginalUrl)
        request.session?.remove(key: WebAppKituraCredentialsPlugin.AuthContext)
    }
}
