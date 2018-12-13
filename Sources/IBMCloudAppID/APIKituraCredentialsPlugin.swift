/*
 Copyright 2018 IBM Corp.
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
import LoggerAPI
import SwiftyRequest
import SwiftJWKtoPEM
import SwiftyJSON

@available(OSX 10.12, *)
public class APIKituraCredentialsPlugin: AppIDPlugin, CredentialsPluginProtocol {

    public var redirecting = false

    public var usersCache: NSCache<NSString, BaseCacheElement>?

    public var name: String {
        return Constants.APIPlugin.name
    }

    public init(options: [String: Any]?) {
        let config = AppIDPluginConfig(options: options, validateEntireToken: false, required: \.serverUrl, \.clientId, \.tenantId)
        super.init(config: config)

        Log.warning("This is a beta version of APIKituraCredentialsPlugin." +
                    "It should not be used for production environments!")

    }

    public func authenticate (request: RouterRequest,
                              response: RouterResponse,
                              options: [String: Any],
                              onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                              inProgress: @escaping () -> Void) {

        Log.debug("authenticate")

        var requiredScope = Constants.AppID.defaultScope

        if let opts = options["scope"] as? String {
            requiredScope += " " + opts
        }

        guard let authHeaderComponents = request.headers[Constants.authHeader]?.components(separatedBy: " ") else {
            Log.warning("Authorization header not found")
            sendUnauthorized(scope: requiredScope, error: .missingAuth, completion: onPass)
            return
        }

        guard authHeaderComponents.first == Constants.bearer else {
            Log.warning("Unrecognized Authorization Method")
            sendUnauthorized(scope: requiredScope, error: .invalidRequest, completion: onPass)
            return
        }
        // authHeader format :: "Bearer accessToken idToken"
        guard authHeaderComponents.count == 3 || authHeaderComponents.count == 2 else {
            Log.warning("Invalid authorization header format")
            sendUnauthorized(scope: requiredScope, error: .invalidRequest, completion: onFailure)
            return
        }

        self.processHeaderComponents(authHeaderComponents: authHeaderComponents,
                                     requiredScope: requiredScope,
                                     request: request,
                                     response: response,
                                     onSuccess: onSuccess,
                                     onFailure: onFailure)
    }

}

@available(OSX 10.12, *)
extension APIKituraCredentialsPlugin {

    /// Process access and identity tokens from header components
    fileprivate func processHeaderComponents(authHeaderComponents: [String],
                                         requiredScope: String,
                                         request: RouterRequest,
                                         response: RouterResponse,
                                         onSuccess: @escaping (UserProfile) -> Void,
                                         onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void) {

        let accessTokenString: String = authHeaderComponents[1]
        let idToken = authHeaderComponents.count == 3 ? authHeaderComponents[2] : nil

        /// Parse / Validate Access Token
        Utils.decodeAndValidate(tokenString: accessTokenString, publicKeyUtil: publicKeyUtil, options: config) {
            payload, error in

            guard let payload = payload, error == nil else {
                return self.sendUnauthorized(scope: requiredScope,
                                             error: .invalidToken,
                                             description: error?.description,
                                             completion: onFailure)
            }

            /// Validate access token scopes
            guard self.validateScope(requiredScope: requiredScope, payload: payload) else {
                return self.sendUnauthorized(scope: requiredScope, error: .insufficientScope, completion: onFailure)
            }

            var authorizationContext: [String: Any] = [
                "accessToken": accessTokenString,
                "accessTokenPayload": payload as Any
            ]

            /// Parse / Validate Identity Token, if necessary
            self.parseIdentityToken(idTokenString: idToken) { (context, error) in

                /// On error (API strategy only), we will not return identity token information, but only a default profile
                guard let context = context, error == nil else {
                    request.userInfo[Constants.AuthContext.name] = authorizationContext
                    onSuccess(UserProfile(id: "", displayName: "", provider: ""))
                    return
                }

                /// Merge authorization context and identity context, if necessary
                context.0.forEach { authorizationContext[$0] = $1 }
                request.userInfo[Constants.AuthContext.name] = authorizationContext
                onSuccess(context.1)
            }
        }
    }

    /// Validates that the required scopes were supplied in the access token
    fileprivate func validateScope(requiredScope: String, payload: [String: Any]) -> Bool {
        let requiredScopeElements = requiredScope.components(separatedBy: " ")

        if requiredScopeElements.count == 0 {
            return true
        }

        guard let scope = payload["scope"] as? String else {
            Log.warning("Access token does not contain the required scopes")
            return false
        }

        let suppliedScopeElement = Set(scope.components(separatedBy: " "))
        for requiredScopeElement in requiredScopeElements {
            if !suppliedScopeElement.contains(requiredScopeElement) {
                Log.warning("Access token does not contain required scope. Expected " +
                            " \(requiredScope) + received + \(scope)")
                return false
            }
        }

        return true
    }

}
