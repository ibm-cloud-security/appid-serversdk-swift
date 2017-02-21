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

public class WebAppStrategy: CredentialsPluginProtocol {

    public static var STRATEGY_NAME = "appid-webapp-strategy"
    public static var DEFAULT_SCOPE = "appid_default"
    public static var ORIGINAL_URL = "APPID_ORIGINAL_URL"
    public static var AUTH_CONTEXT = "APPID_AUTH_CONTEXT"
    public static var AUTHORIZATION_PATH = "/authorization"
    public static var TOKEN_PATH = "/token"
    private var serviceConfig:WebAppStrategyConfig
    private var options:[String:Any]
    
    public var redirecting = true
    
    public var usersCache : NSCache<NSString, BaseCacheElement>?
    
    
    public var name: String {
        return WebAppStrategy.STRATEGY_NAME
    }
    
    
    public init(options:[String: Any]?) {
        //    logger.debug("Initializing")
        self.options = options ?? [:]
        self.serviceConfig = WebAppStrategyConfig(options: options)
    }
    
    
    private func handleAuthorization (request: RouterRequest, response: RouterResponse, options: [String:Any], onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void) {
//        logger.debug("handleAuthorization");
        var options = options
        options["allowCreateNewAnonymousUser"] = options["allowCreateNewAnonymousUser"] ?? true
        options["failureRedirect"] = options["failureRedirect"] ?? "/"
        var authUrl = generateAuthorizationUrl(options: options)
        
        // If there's an existing anonymous access token on session - add it to the request url
        var appIdAuthContext = request.session?[WebAppStrategy.AUTH_CONTEXT]
        if appIdAuthContext != nil && appIdAuthContext?["accessTokenPayload"]["amr"][0] == "appid_anon" {
//            logger.debug("handleAuthorization :: added anonymous access_token to url");
            authUrl += "&appid_access_token=" + appIdAuthContext?.dictionaryObject?["accessToken"]
        }
        
        // If previous anonymous access token not found and new anonymous users are not allowed - fail
        var allowAnonLogin = options["allowAnonymousLogin"] as? Bool != nil ? options["allowAnonymousLogin"] as! Bool : false
        var allowCreate = options["allowCreateNewAnonymousUser"] as? Bool != nil ? options["allowCreateNewAnonymousUser"] as! Bool : true
        if appIdAuthContext  == nil && allowAnonLogin == true && allowCreate != true {
//            logger.info("Previous anonymous user not found. Not allowed to create new anonymous users.");
               onFailure(nil,nil) //TODO: make it better
            return
//            strategy.fail(new Error("Not allowed to create new anonymous users."));
//            return
        }
    
//        logger.debug("handleAuthorization :: redirecting to", authUrl);
        do {
        try response.redirect(authUrl)
        } catch let err {
            onFailure(nil, nil)
        }
    }
    
    private func handleCallback(request:RouterRequest, options: [String:Any]) {
////        logger.debug("handleCallback");
//        options["failureRedirect"] = options["failureRedirect"] ?? "/"
//        var code = request.queryParameters.code
//        retrieveTokens(options, strategy, code).then(function(appIdAuthContext){
//            // Save authorization context to HTTP session
//            req.session[WebAppStrategy.AUTH_CONTEXT] = appIdAuthContext;
//            
//            // Find correct successRedirect
//            if (options.successRedirect) {
//                options.successRedirect = options.successRedirect;
//            } else if (req.session && req.session[WebAppStrategy.ORIGINAL_URL]) {
//                options.successRedirect = req.session[WebAppStrategy.ORIGINAL_URL];
//            } else {
//                options.successRedirect = "/";
//            }
//            
//            logger.debug("completeAuthorizationFlow :: success");
//            strategy.success(TokenUtil.decode(appIdAuthContext.identityToken) || null);
//        }).catch(strategy.fail);
    }
    
    
    private func retrieveTokens(options:[String:Any], grantCode:String, onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void) {
//        logger.debug("retrieveTokens");
        var serviceConfig = self.serviceConfig;
        
        var clientId = serviceConfig.clientId
        var secret = serviceConfig.secret
        var tokenEndpoint = serviceConfig.oAuthServerUrl + WebAppStrategy.TOKEN_PATH
        var redirectUri = serviceConfig.redirectUri
        var authorization = clientId + ":" + secret
        KituraRequest.request(.post, authorization + "@" + tokenEndpoint, parameters: [
            "client_id": clientId,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri,
            "code": grantCode
            ]).response {
                request, response, data, error in
                // do something with data

            if  data == nil || error != nil || response?.status != 200 {
//                logger.error("Failed to obtain tokens ::", err, response.statusCode, body);
                onFailure(nil,nil) //TODO: send correct err
            } else {
                var body = JSON(data: data!)
                var accessTokenString = body["access_token"]
                var identityTokenString = body["id_token"]
                
                // Parse access_token
                var appIdAuthorizationContext = [
                    "accessToken": accessTokenString,
                    "accessTokenPayload": TokenUtil.decode(accessTokenString)
                ]
                
                // Parse id_token
                if identityTokenString != nil {
                    appIdAuthorizationContext["identityToken"] = identityTokenString
                    appIdAuthorizationContext["identityTokenPayload"] = TokenUtil.decode(identityTokenString);
                }
//                logger.debug("retrieveTokens :: tokens retrieved");
                
                return appIdAuthorizationContext
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

        
        guard let session = request.session else {
//            logger.error("Can't find req.session. Ensure express-session middleware is in use");
                onFailure(nil,nil) //TODO: should msg be better here?
        }
        
        
        if let error = request.queryParameters["error"] {
            //logger.warn("Error returned in callback ::", error);
             onFailure(nil,nil) //TODO: should msg be better here?
        } else if let code = request.queryParameters["code"] {
            return handleCallback(request: request, options: options)
        } else {
            return handleAuthorization(request: request, response: response, options: options, onFailure: onFailure)
        }
    }
    
    
        private func generateAuthorizationUrl(options: [String:Any]) -> String {
        var serviceConfig = self.serviceConfig
        var clientId = serviceConfig.clientId
        var scope = WebAppStrategy.DEFAULT_SCOPE + ((options["scope"] as? String) != nil ? (" " + (options["scope"] as! String)) : "")
        var authorizationEndpoint = serviceConfig.oAuthServerUrl + WebAppStrategy.AUTHORIZATION_PATH;
        var redirectUri = serviceConfig.redirectUri
        var authUrl = encodeURI(authorizationEndpoint +
        "?client_id=" + clientId +
        "&response_type=code" +
        "&redirect_uri=" + redirectUri +
        "&scope=" + scope)
        
        if (options["allowAnonymousLogin"] as? Bool) == true {
        authUrl += "&idp=appid_anon";
        }
        
        return authUrl;
    }
    
    
}
