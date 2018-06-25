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
import Credentials
import KituraNet
import SwiftyRequest
import SwiftyJSON
import SimpleLogger
import KituraSession

@available(OSX 10.12, *)
public class WebAppKituraCredentialsPlugin: AppIDPlugin, CredentialsPluginProtocol {

    public let redirecting = true

    public var usersCache: NSCache<NSString, BaseCacheElement>?

    public var name: String {
        return Constants.WebAppPlugin.name
    }

    public init(options: [String: Any]?) {
        let config = AppIDPluginConfig(options: options, required: \.serverUrl, \.clientId, \.tenantId, \.secret, \.redirectUri)
        super.init(logger: Logger(forName: Constants.WebAppPlugin.name), config: config)
    }

    public func authenticate (request: RouterRequest,
                              response: RouterResponse,
                              options: [String: Any],
                              onSuccess: @escaping (UserProfile) -> Void,
                              onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                              onPass: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                              inProgress: @escaping () -> Void) {

        if request.session == nil {
            logger.error("Can't find request.session. Ensure KituraSession middleware is in use")
            onFailure(nil, nil)
            return
        }

        if let error = request.queryParameters["error"] {
            logger.warn("Error returned in callback " + error)
            onFailure(nil, nil)
        } else if let code = request.queryParameters["code"] {
            return handleAuthorizationCallback(code: code, request: request, onSuccess: onSuccess, onFailure: onFailure)
        } else {
            return handleAuthorization(request: request,
                                       response: response,
                                       options: options,
                                       onSuccess: onSuccess,
                                       onFailure: onFailure,
                                       onPass: onPass,
                                       inProgress: inProgress)
        }
    }

    public func logout(request: RouterRequest) {
        // request.session?.remove(key: OriginalUrl)
        request.session?.remove(key: Constants.context)
        request.session?.remove(key: Constants.AuthContext.name)
    }

    //////////////////////////
    // Internal for testing //
    //////////////////////////

    /// Generates a high entropy random state parameter
    internal func generateState(of length: Int) -> String {
        return String.generateStateParameter(of: length)
    }

    /// Executes a ResRequest
    internal func executeRequest(_ request: RestRequest, completion: @escaping (Data?, HTTPURLResponse?, Swift.Error?) -> Void) {
        request.response(completionHandler: completion)
    }

    /// Getter for the a RouterRequest state query parameter
    internal func getRequestState(from request: RouterRequest) -> String? {
        return request.parsedURL.queryParameters[Constants.state]
    }
}

@available(OSX 10.12, *)
extension WebAppKituraCredentialsPlugin {

    fileprivate func restoreUserProfile(from session: SessionState) -> UserProfile? {
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

            var userEmails: [UserProfile.UserProfileEmail]?
            if let emails = dictionary["emails"] as? [String], let types = dictionary["emailTypes"] as? [String] {
                userEmails = emails.enumerated().map { UserProfile.UserProfileEmail(value: $1, type: types[$0]) }
            }

            var userPhotos: [UserProfile.UserProfilePhoto]?
            if let photos = dictionary["photos"] as? [String] {
                userPhotos = photos.map { UserProfile.UserProfilePhoto($0) }
            }

            return UserProfile(id: id,
                              displayName: displayName,
                              provider: provider,
                              name: userName,
                              emails: userEmails,
                              photos: userPhotos,
                              extendedProperties: dictionary["extendedProperties"] as? [String:Any])
        }

        return nil
    }

    /// Handles execution of the initial authorization request for authorization code flow.
    fileprivate func handleAuthorization (request: RouterRequest,
                                      response: RouterResponse,
                                      options: [String: Any], // Options is read only
                                      onSuccess: @escaping (UserProfile) -> Void,
                                      onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                                      onPass: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                                      inProgress: @escaping () -> Void) {

        logger.debug("WebAppKituraCredentialsPlugin :: handleAuthorization")
        let forceLogin: Bool = options[Constants.AppID.forceLogin] as? Bool ?? false
        let allowAnonymousLogin: Bool = options[Constants.AppID.allowAnonymousLogin] as? Bool ?? false
        let allowCreateNewAnonymousUser: Bool = options[Constants.AppID.allowCreateNewAnonymousUser] as? Bool ?? true
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
        if let appIdAuthContext = request.session?[Constants.AuthContext.name] as? [String : Any] {
            let payload = appIdAuthContext["accessTokenPayload"] as? [String : Any]
            if (payload?["amr"] as? [String])?[0] ==  "appid_anon" {
                logger.debug("WebAppKituraCredentialsPlugin :: handleAuthorization :: added anonymous access_token to url")
                authUrl += "&appid_access_token=" + ((appIdAuthContext["accessToken"] as? String) ?? "")
            }
        } else if allowAnonymousLogin && !allowCreateNewAnonymousUser {
            // If previous anonymous access token not found and new anonymous users are not allowed - fail
            logger.warn("Previous anonymous user not found. Not allowed to create new anonymous users.")
            return onFailure(nil, nil)
        }

        // Store and add high entropy state
        let state = generateState(of: 10)

        authUrl += "&state=\(state)"
        logger.debug(authUrl)
        request.session?[Constants.context] = [Constants.state: state, Constants.isAnonymous: authUrl.range(of: "idp=appid_anon") != nil]

        logger.debug("Redirecting to : " + authUrl)

        do {
            try response.redirect(authUrl)
            inProgress()
        } catch {
            onFailure(nil, nil)
        }
    }

    /// Handles the initial authorization request callback for authorization code flow.
    internal func handleAuthorizationCallback(code: String,
                                              request: RouterRequest,
                                              onSuccess: @escaping (UserProfile) -> Void,
                                              onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void) {

        /// Validate state parameter in session matches response state
        guard let context = request.session?[Constants.context] as? [String: Any],
            let isAnonymous = context[Constants.isAnonymous] as? Bool else {
            logger.error("The session is missing the required context")
            return onFailure(nil, nil)
        }

        guard let storedState = context[Constants.state] as? String else {
            logger.error("The expected state parameter was not found in the request session")
            return onFailure(nil, nil)
        }

        /// The anonymous flow does not currently return a state parameter.
        if !isAnonymous {

            guard let returnedState = getRequestState(from: request) else {
                logger.error("The redirect URI does not have required state")
                return onFailure(nil, nil)
            }

            guard storedState == returnedState else {
                logger.error("Stored State does not match redirect uri state query parameter")
                return onFailure(nil, nil)
            }
        }

        retrieveTokens(grantCode: code, request: request, onSuccess: onSuccess, onFailure: onFailure)
    }

    /// Retrieves tokens using the callback grant code
    fileprivate func retrieveTokens(grantCode: String,
                                    request: RouterRequest,
                                    onSuccess: @escaping (UserProfile) -> Void,
                                    onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void) {

        logger.debug("WebAppKituraCredentialsPlugin :: retrieveTokens")

        guard let clientId = config.clientId,
              let secret = config.secret,
              let serverUrl = config.serverUrl else {

                onFailure(nil, nil)
                return
        }

        let tokenEndpoint = serverUrl + Constants.Endpoints.token
        let redirectUri = config.redirectUri
        let authorization = clientId + ":" + secret

        let restReq = RestRequest(method: .post, url: tokenEndpoint, containsSelfSignedCert: false)
        restReq.headerParameters = ["Authorization": "basic " + Data(authorization.utf8).base64EncodedString()]
        let params = [ "client_id": clientId,
                       "grant_type": "authorization_code",
                       "redirect_uri": redirectUri,
                       "code": grantCode ]
        if let json = try? JSONSerialization.data(withJSONObject: params, options: []) {
            restReq.messageBody = json
        } else {
            logger.debug("Failed to parse data into JSON.")
        }

        self.executeRequest(restReq) { (tokenData, tokenResponse, tokenError) in
            self.handleTokenResponse(httpCode: tokenResponse?.statusCode,
                                     tokenData: tokenData,
                                     tokenError: tokenError,
                                     originalRequest: request,
                                     onFailure: onFailure,
                                     onSuccess: onSuccess)
        }
    }

    /// Parses and validates token request response
    fileprivate func handleTokenResponse(httpCode: Int?,
                                         tokenData: Data?,
                                         tokenError: Swift.Error?,
                                         originalRequest: RouterRequest,
                                         onFailure: @escaping (HTTPStatusCode?, [String: String]?) -> Void,
                                         onSuccess: @escaping (UserProfile) -> Void) {

        let code = httpCode.map { String(describing: $0) } ?? "<no http code>"
        if let tokenError = tokenError {
            let errorMessage = String(describing: tokenError)
            self.logger.debug("WebAppKituraCredentialsPlugin :: Failed to obtain tokens. error message " +
                ": \(errorMessage)\nstatus code : \(code)\ntoken body : \(String(describing: tokenData))")
            return onFailure(nil, nil)
        }

        guard let tokenData = tokenData else {
            self.logger.debug("WebAppKituraCredentialsPlugin :: Failed to obtain tokens." +
                " No token error message. No token data. status code : \(code)")
            return onFailure(nil, nil)
        }

        guard httpCode == 200 else {
            self.logger.debug("WebAppKituraCredentialsPlugin :: Failed to obtain tokens." +
                " Status code wasn't 200. No token error message. status code :" +
                " \(code)\n token body : \(String(describing: tokenData))")
            return onFailure(nil, nil)
        }

        var body = JSON(data: tokenData)

        /// Parse access_token
        guard let accessTokenString = body["access_token"].string else {
            return onFailure(nil, nil)
        }

        Utils.decodeAndValidate(tokenString: accessTokenString, publicKeyUtil: publicKeyUtil, options: config) {
            payload, error in

            guard let payload = payload, error == nil else {
                return onFailure(nil, nil)
            }

            var authorizationContext: [String: Any] = [
                "accessToken": accessTokenString,
                "accessTokenPayload": payload as Any
            ]

            /// Parse / Validate Identity Token, if necessary
            self.parseIdentityToken(idTokenString: body["id_token"].string) { context, error in

                /// On error (Web strategy only), we will fail
                guard let context = context, error == nil else {
                    return onFailure(nil, nil)
                }

                /// Merge authorization context and identity context, if necessary
                context.0.forEach { authorizationContext[$0] = $1 }

                originalRequest.session?[Constants.AuthContext.name] = authorizationContext
                onSuccess(context.1)

                self.logger.debug("retrieveTokens :: tokens retrieved")
            }
        }
    }

    fileprivate func generateAuthorizationUrl(options: [String:Any]) -> String {

        var scopeAddition: String?
        if let addition = options["scope"] as? String {
            scopeAddition = " " + addition
        }

        let scope = Constants.AppID.defaultScope + (scopeAddition ?? "")
        let authorizationEndpoint = (config.serverUrl ?? "") + Constants.Endpoints.authorization
        var query = "client_id=\(config.clientId ?? "")&response_type=code&redirect_uri=\(config.redirectUri ?? "")&scope=\(scope)"
        if (options["allowAnonymousLogin"] as? Bool) == true {
            query += "&idp=appid_anon"
        }
        query = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let authUrl = "\(authorizationEndpoint)?\(query)"
        self.logger.debug("AUTHURL: \(authUrl)")
        return authUrl
    }

}
