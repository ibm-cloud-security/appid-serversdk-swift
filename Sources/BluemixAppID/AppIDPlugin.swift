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

///
/// App ID Plugin parent class
/// - Contains shared methods used in api and web strategies
///
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
    /// - Parameter completion: Handler returning the user context information or an error
    ///
    func parseIdentityToken(idTokenString: String?, completion: @escaping (([String: Any], UserProfile)?, AppIDError?) -> Void) {

        guard let idTokenString = idTokenString else {
            logger.debug("Identity token does not exist")
            return completion(nil, AppIDError.invalidToken("Identity token does not exist"))
        }

        Utils.decodeAndValidate(tokenString: idTokenString, publicKeyUtil: publicKeyUtil, options: config) { payload, error in

            guard let payload = payload, error == nil else {
                self.logger.debug("Identity token is malformed")
                return completion(nil, error ?? AppIDError.invalidToken("Identity token could not be decoded"))
            }

            guard let authContext = Utils.getAuthorizedIdentities(from: payload) else {
                self.logger.debug("Identity token is malformed")
                return completion(nil, error ?? AppIDError.invalidToken("Identity token could not be decoded"))
            }

            self.logger.debug("Identity token successfully parsed")

            let identityContext = [
                "identityToken": idTokenString,
                "identityTokenPayload": payload as Any
            ]

            let provider = authContext.userIdentity.authBy.count > 0 ?
                authContext.userIdentity.authBy[0]["provider"].stringValue : ""

            let profile = UserProfile(id: authContext.userIdentity.id,
                                      displayName: authContext.userIdentity.displayName,
                                      provider: provider)

            return completion((identityContext, profile), nil)
        }
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
