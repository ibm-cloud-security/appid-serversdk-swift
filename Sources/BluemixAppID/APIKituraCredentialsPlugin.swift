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
import SwiftyRequest
import Swift-JWT-to-PEM

@available(OSX 10.12, *)
public class APIKituraCredentialsPlugin: CredentialsPluginProtocol {
    
    public static let name = "appid-api-kitura-credentials-plugin"
    
    private let Bearer = "Bearer"
    private let AuthHeader = "Authorization"
    private let DefaultScope = "appid_default"
    public  let AuthContext = "APPID_AUTH_CONTEXT"
    private let logger = Logger(forName: "APIKituraCredentialsPlugin")
    private var appIDpubKey: String?
    
    private var serviceConfig:APIKituraCredentialsPluginConfig?
    
    public init(options:[String: Any]?) {
        logger.debug("Intializing APIKituraCredentialsPlugin")
        logger.warn("This is a beta version of APIKituraCredentialsPlugin, it should not be used for production environments!");
        self.serviceConfig = APIKituraCredentialsPluginConfig(options: options)
        
        // get the public key
        retrievePubKey()
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
        
        
        func processHeaderComponents() -> Void {
            let accessTokenString:String = authHeaderComponents[1]
            guard let accessToken = try? Utils.parseToken(from: accessTokenString, using: self.appIDpubKey!) else {
                logger.debug("ApiKituraCredentialsPlugin : access token not created")
                sendFailure(scope:requiredScope, error:"invalid_token", onFailure: onFailure, response: response)
                return
            }
            let idTokenString:String? = authHeaderComponents.count == 3 ? authHeaderComponents[2] : nil
            
            guard Utils.isTokenValid(token: accessTokenString) else {
                sendFailure(scope:requiredScope, error:"invalid_token", onFailure: onFailure, response: response)
                return
            }
            
            let requiredScopeElements = requiredScope.components(separatedBy: " ")
            let suppliedScopeElements = accessToken["payload"]["scope"].string?.components(separatedBy: " ")
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
                        let receivedScope = accessToken["scope"].string ?? ""
                        logger.warn("ApiKituraCredentialsPlugin : access_token does not contain required scope. Expected " + requiredScope + " received " + receivedScope)
                        sendFailure(scope:requiredScope, error:"insufficient_scope", onFailure: onFailure, response: response)
                        return
                    }
                }
            }
            
            var authorizationContext:[String:Any] = [
                "accessToken": accessTokenString,
                "accessTokenPayload": accessToken["payload"] as Any
            ]
            
            var userId = ""
            var displayName = ""
            var provider = ""
            
            if authHeaderComponents.count == 3 {
                let identityTokenString = authHeaderComponents[2]
                if Utils.isTokenValid(token: identityTokenString) == true {
                    logger.debug("Id token is malformed")
                    
                    if let idTokenString = idTokenString, let idToken = try? Utils.parseToken(from: idTokenString, using: self.appIDpubKey!), let authContext = Utils.getAuthorizedIdentities(from: idToken){
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

        // if public key doesn't exist, retrieve, else process components.
        if self.appIDpubKey == nil {
			logger.debug("ApiKituraCredentialsPlugin : public key not found. Will retrieve from server.")
            
            retrievePubKey(completion: processHeaderComponents)
        } else {
            processHeaderComponents()
        }
    }
    
    private func retrievePubKey( completion: (() -> Void)? = nil ) {
        
        // Super duper ugly code - should be changed
        if (self.serviceConfig?.publicKeyServerURL)! == "testServerUrl/publickey" {
            let debug_jwk = """
{"kty":"RSA","n":"s8SVzmkIslnxYmr0fa_i88fTS_a6wH3tNzRjE1M2SUHjz0E7IJ2-2Jjqwsefu0QcYDnH_oiwnLGn_m-etw1toAIC30UeeKiskM1pqRi6Z8LTRZIS3WYHRFGqa3IfVEBf_sjlxjNqfG8y9c4fJ_pRYGxpzCbjeXsDefs0zfSXmlQcWL1MwIIDHN0ZnAcmpjSsOzo0wPQGb_n8MIfT-rUr90bxch9-51wOEVXROE5nQpjkW9n6aCECeySDIK0nvILsgXMWUNW3oAIF35tK9yaUkGxXVNju-RGJLipnIIDU5apJY8lmKTVmzBMglY2fgXpNKbgQmMBlUJ4L1X05qUzw5w","e":"AQAB","kid":"appId-1504675475000"}
"""
            self.logger.debug("Using Test key! Signature verification will FAIL! You should only see this during unit tests. If you see this otherwise, you have not set oauthServerUrl option in the APIKituraCredentialPluginConfig.")
            self.handlePubKeyResponse(200, debug_jwk.data(using: .utf8), nil, completion)
            self.logger.debug("An internal error occured. Request failed.")
            return
        }
            
        let restReq = RestRequest(method: .get, url: (self.serviceConfig?.publicKeyServerURL)!, containsSelfSignedCert: false)
        
        restReq.response { (data, response, error) in

            if let e = error {
                self.logger.debug("An error occured in the public key retreival response. Error: \(e)")
            }
            else if let response = response, let data = data {
                self.handlePubKeyResponse(response.statusCode, data, error, completion)
            }
            else {
                self.logger.debug("An internal error occured. Request failed.")
            }
        }
    }
    
    internal func handlePubKeyResponse(_ httpCode: Int?, _ data: Data?, _ error: Swift.Error?, _ completion: (() -> Void)? = nil ) {
        if  data == nil || error != nil || httpCode != 200  {
            let data = data != nil ? String(data: data!, encoding: .utf8) : ""
            let error = error != nil ? error!.localizedDescription : ""
            let code = httpCode != nil ? String(httpCode!): ""
            self.logger.debug("APIKituraCredentialsPlugin :: Failed to obtain public key " + "err:\(error)\nstatus code \(code)\nbody \(String(describing: data))")
            logger.warn("ApiKituraCredentialsPlugin : Unable to retrieve public key")
            completion?()
            return
        }
        
        if let data = data {
            do {
                guard let token = String(data: data, encoding: .utf8) else {
                    logger.warn("ApiKituraCredentialsPlugin : Unable to retrieve public key")
                    return
                }
                // convert JWK key to PEM format
                let key = try RSAKey(jwk: token)
                self.appIDpubKey = try key.getPublicKey(certEncoding.pemPkcs8)
                
            } catch {
                self.logger.debug("APIKituraCredentialsPlugin :: Failed to extract public key " + "public key: \(String(describing: data))")
                logger.warn("ApiKituraCredentialsPlugin : Unable to extract public key")
            }
        }
        self.logger.debug("retrievePubKey :: public key retrieved and extracted")
        completion?()
    }

}

