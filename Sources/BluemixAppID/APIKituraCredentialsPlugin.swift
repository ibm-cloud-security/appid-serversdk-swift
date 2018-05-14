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
import SimpleLogger
import SwiftyRequest
import SwiftJWKtoPEM
import SwiftyJSON

@available(OSX 10.12, *)
public class APIKituraCredentialsPlugin: CredentialsPluginProtocol {

    private let logger = Logger(forName: Constants.APIPlugin.name)

    // kid : pemPkcs
    private var appIDpubKeys: [String: String]?

    private let serviceConfig: APIKituraCredentialsPluginConfig

    public var redirecting = false

    public var usersCache: NSCache<NSString, BaseCacheElement>?

    public var name: String {
        return Constants.APIPlugin.name
    }

    public init(options: [String: Any]?) {
        logger.debug("Intializing " + Constants.APIPlugin.name)
        logger.warn("This is a beta version of APIKituraCredentialsPlugin." +
                    "It should not be used for production environments!")

        serviceConfig = APIKituraCredentialsPluginConfig(options: options)

        retrievePubKey()
    }

    public func authenticate (request: RouterRequest,
                              response: RouterResponse,
                              options: [String: Any],
                              onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                              inProgress: @escaping () -> Void) {

        logger.debug("authenticate")

        var requiredScope = Constants.AppID.defaultScope

        if let opts = options["scope"] as? String {
            requiredScope += " " + opts
        }

        guard let authHeaderComponents = request.headers[Constants.authHeader]?.components(separatedBy: " ") else {
            logger.warn("Authorization header not found")
            sendUnauthorized(scope: requiredScope, error: .missingAuth, completion: onPass, response: response)
            return
        }

        guard authHeaderComponents.first == Constants.bearer else {
            logger.warn("Unrecognized Authorization Method")
            sendUnauthorized(scope: requiredScope, error: .invalidRequest, completion: onPass, response: response)
            return
        }
        // authHeader format :: "Bearer accessToken idToken"
        guard authHeaderComponents.count == 3 || authHeaderComponents.count == 2 else {
            logger.warn("Invalid authorization header format")
            sendUnauthorized(scope: requiredScope, error: .invalidRequest, completion: onFailure, response: response)
            return
        }

        let processHeader = { (appIDpubKeys: [String: String]) in
            self.processHeaderComponents(appIDpubKeys: appIDpubKeys,
                                         authHeaderComponents: authHeaderComponents,
                                         requiredScope: requiredScope,
                                         request: request,
                                         response: response,
                                         onSuccess: onSuccess,
                                         onFailure: onFailure)
        }

        let failure = { (err: String) in
            self.logger.debug("An error occurred: \(err)")
            self.sendUnauthorized(scope: requiredScope, error: .internalServerError, completion: onFailure, response: response)
        }

        // if public key doesn't exist, retrieve, else process components.
        guard let appIDpubKeys = self.appIDpubKeys else {
            logger.debug("The public key was not found. Will retrieve from server.")
            retrievePubKey(onFailure: failure, completion: processHeader)
            return
        }

        processHeader(appIDpubKeys)
    }

    /// Process access and identity tokens from header components
    private func processHeaderComponents(appIDpubKeys: [String: String],
                                         authHeaderComponents: [String],
                                         requiredScope: String,
                                         request: RouterRequest,
                                         response: RouterResponse,
                                         onSuccess: @escaping (UserProfile) -> Void,
                                         onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void) {

        /// Parse / Validate Access Token

        let accessTokenString: String = authHeaderComponents[1]

        guard let accessToken = try? Utils.parseToken(from: accessTokenString, using: appIDpubKeys) else {
            logger.debug("access token not created")
            sendUnauthorized(scope: requiredScope, error: .invalidToken, completion: onFailure, response: response)
            return
        }

        guard Utils.isTokenValid(token: accessTokenString) else {
            sendUnauthorized(scope: requiredScope, error: .invalidToken, completion: onFailure, response: response)
            return
        }

        /// Validate Access token scopes
        guard validateScope(requiredScope: requiredScope, accessToken: accessToken) else {
            sendUnauthorized(scope: requiredScope, error: .insufficientScope, completion: onFailure, response: response)
            return
        }

        /// Parse / Validate Identity Token, if necessary

        let (identityContext, profile) = parseIdentityToken(authHeaderComponents: authHeaderComponents,
                                                            appIDpubKeys: appIDpubKeys)

        var authorizationContext: [String: Any] = [
            "accessToken": accessTokenString,
            "accessTokenPayload": accessToken["payload"].dictionaryObject as Any
        ]

        /// Merge authorization context and identity context, if necessary
        identityContext.forEach { authorizationContext[$0] = $1 }

        request.userInfo[Constants.AuthContext.name] = authorizationContext
        onSuccess(profile)
    }

    /// Parses / validates the identity token, if one exists
    private func parseIdentityToken(authHeaderComponents: [String], appIDpubKeys: [String: String]) -> ([String: Any], UserProfile) {

        var profile = UserProfile(id: "", displayName: "", provider: "")

        var identityContext: [String: Any] = [:]

        if let idTokenString = authHeaderComponents.count == 3 ? authHeaderComponents[2] : nil {

            if Utils.isTokenValid(token: idTokenString),
                let idToken = try? Utils.parseToken(from: idTokenString, using: appIDpubKeys),
                let authContext = Utils.getAuthorizedIdentities(from: idToken) {

                logger.debug("Id token is present and has been successfully parsed")

                identityContext["identityToken"] = idTokenString
                identityContext["identityTokenPayload"] = idToken["payload"].dictionaryObject as Any

                let provider = authContext.userIdentity.authBy.count > 0 ?
                                    authContext.userIdentity.authBy[0]["provider"].stringValue : ""

                profile = UserProfile(id: authContext.userIdentity.id,
                                      displayName: authContext.userIdentity.displayName,
                                      provider: provider)

            } else {
                logger.debug("Id token is malformed")
            }
        } else {
            logger.debug("Missing id token")
        }

        return (identityContext, profile)
    }

    /// Validates that the required scopes were supplied in the access token
    private func validateScope(requiredScope: String, accessToken: SwiftyJSON.JSON) -> Bool {
        let requiredScopeElements = requiredScope.components(separatedBy: " ")
        let suppScopeElements = accessToken["payload"]["scope"].string?.components(separatedBy: " ")

        if requiredScopeElements.count > 0 && suppScopeElements == nil {
            logger.warn("Access token does not contain the required scopes")
            return false
        }

        if let suppliedScopeElements = suppScopeElements {
            let suppliedScopeElement = Set(suppliedScopeElements)
            for requiredScopeElement in requiredScopeElements {
                if !suppliedScopeElement.contains(requiredScopeElement) {
                    let receivedScope = accessToken["scope"].string ?? ""
                    logger.warn("Access token does not contain required scope. Expected " +
                                requiredScope +
                                " received " +
                                receivedScope)
                    return false
                }
            }
        }

        return true
    }

    /// Retrieve the public key from the server
    internal func retrievePubKey(onFailure: ((String) -> Void)? = nil, completion: (([String: String]) -> Void)? = nil) {

        guard let url = self.serviceConfig.publicKeyServerURL else {
            logger.debug("Invalid public key server url.")
            onFailure?("Invalid public key server url")
            return
        }

        RestRequest(url: url).response { data, response, error in

            if let err = error {
                self.logger.debug("An error occured in the public key retrieval response. Error: \(err)")
                onFailure?("\(err)")
            } else if let response = response, let data = data {
                self.handlePubKeyResponse(response.statusCode, data, onFailure, completion)
            } else {
                self.logger.debug("An internal error occured. Request failed.")
                onFailure?("Could not retrieve public key")
            }
        }
    }

    /// Parse response token
    internal func handlePubKeyResponse(_ httpCode: Int?,
                                      _ data: Data,
                                      _ failure: ((String) -> Void)? = nil,
                                      _ completion: (([String: String]) -> Void)? = nil) {
        do {
            guard httpCode == 200 else {
                logger.debug("Failed to obtain public key " +
                    "status code \(String(describing: httpCode))\n" +
                    "body \(String(data: data, encoding: .utf8) ?? "")")
                throw AppIDErrorInternal.publicKeyNotFound
            }

            guard let json = try? JSONDecoder().decode([String: [PublicKey]].self, from: data),
                  let tokens = json["keys"] else {
                logger.debug("Unable to decode data from public key response")
                throw AppIDErrorInternal.publicKeyNotFound
            }

            // convert JWK key to PEM format
            let publicKeys = tokens.reduce([String: String]()) { (dict, key) in
                var dict = dict

                guard let pemKey = try? RSAKey(n: key.n, e: key.e).getPublicKey(certEncoding.pemPkcs8),
                      let publicKey = pemKey else {
                    logger.debug("Failed to convert public key to pemPkcs: \(key)")
                    return dict
                }
                dict[key.kid] = publicKey
                return dict
            }

            logger.debug("Public keys retrieved and extracted")
            appIDpubKeys = publicKeys
            completion?(publicKeys)
        } catch {
            failure?(AppIDErrorInternal.publicKeyNotFound.rawValue)
        }
    }

    /// Handle authorization failure
    private func sendUnauthorized(scope: String,
                                  error: OauthError,
                                  completion: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                                  response: RouterResponse) {
        logger.debug("sendUnauthorized")

        var msg = Constants.bearer + " scope=\"" + scope + "\", error=\"" + error.rawValue + "\""
        var status: HTTPStatusCode!

        switch error {
        case .invalidRequest     : status = .badRequest
        case .invalidToken       : status = .unauthorized
        case .insufficientScope  : status = .forbidden
        case .internalServerError: status = .unauthorized
        case .missingAuth        :
            status = .unauthorized
            msg = Constants.bearer + " realm=\"AppID\""
        }

        completion(status, ["Www-Authenticate": msg])
    }
}
