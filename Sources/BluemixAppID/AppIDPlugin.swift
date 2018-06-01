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
import SimpleLogger
import Credentials
import KituraNet

@available(OSX 10.12, *)
public class AppIDPlugin {
    
    let logger: Logger

    var publicKeyUtil: PublicKeyUtil

    let config: AppIDPluginConfig

    init(logger: Logger, config: AppIDPluginConfig) {
        self.logger = logger
        self.config = config
        self.publicKeyUtil = PublicKeyUtil(url: config.publicKeyServerURL)
    }

    /// Parses / validates the given identity token
    ///
    /// - Parameter idTokenString: The id token to parse and validate
    /// - Returns: The id token identityContext dictionary and the user's profile
    ///
    func parseIdentityToken(idTokenString: String?) -> ([String: Any], UserProfile) {

        var profile = UserProfile(id: "", displayName: "", provider: "")

        var identityContext: [String: Any] = [:]

        guard let idTokenString = idTokenString else {
            logger.debug("Identity token does not exist")
            return (identityContext, profile)
        }

        guard let payload = try? Utils.decodeAndValidate(tokenString: idTokenString, publicKeyUtil: publicKeyUtil, options: config),
            let authContext = Utils.getAuthorizedIdentities(from: payload) else {
                logger.debug("Identity token is malformed")
                return (identityContext, profile)
        }

        logger.debug("Identity token successfully parsed")

        identityContext["identityToken"] = idTokenString
        identityContext["identityTokenPayload"] = payload as Any

        let provider = authContext.userIdentity.authBy.count > 0 ?
            authContext.userIdentity.authBy[0]["provider"].stringValue : ""

        profile = UserProfile(id: authContext.userIdentity.id,
                              displayName: authContext.userIdentity.displayName,
                              provider: provider)

        return (identityContext, profile)

    }
    
    /// Parses / validates the given identity token
    ///
    /// - Parameter scope: The expected scopes of the request
    /// - Parameter error: The OAuth Error code
    /// - Parameter description: An optional error description
    /// - Parameter completion: onFailure error handler
    /// - Returns: The id token identityContext dictionary and the user's profile
    ///
    func sendUnauthorized(scope: String,
                                  error: OauthError,
                                  description: String? = nil,
                                  completion: @escaping (HTTPStatusCode?, [String: String]?) -> Void) {
        
        logger.debug("Sending unauthorized response")

        var msg = Constants.bearer + " scope=\"" + scope + "\", error=\"" + error.rawValue + "\""
        var status: HTTPStatusCode!
        
        if let description = description {
            msg +=  ", error_description=\"" + description + "\""
        }
        
        switch error {
        case .invalidRequest     : status = .badRequest
        case .invalidToken       : status = .unauthorized
        case .insufficientScope  : status = .forbidden
        case .missingAuth        :
            status = .unauthorized
            msg = Constants.bearer + " realm=\"AppID\""
        }

        completion(status, ["Www-Authenticate": msg])
    }
}
