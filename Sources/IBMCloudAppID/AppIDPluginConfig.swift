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
import LoggerAPI
import SwiftyJSON

/// App ID Configuration Plugin - VCAP / Options parser
///
class AppIDPluginConfig {

    var serviceConfig: [String: Any] = [:]

    var tenantId: String? {
        return serviceConfig[Constants.Credentials.tenantId] as? String
    }

    var clientId: String? {
        return serviceConfig[Constants.Credentials.clientId] as? String
    }

    var secret: String? {
        return serviceConfig[Constants.Credentials.secret] as? String
    }

    var redirectUri: String? {
        return serviceConfig[Constants.Credentials.redirectUri] as? String
    }

    var serverUrl: String? {
        return serviceConfig[Constants.Credentials.oauthServerUrl] as? String
    }

    var userProfileServerUrl: String? {
        return serviceConfig[Constants.Credentials.userProfileServerUrl] as? String
    }

    var tokenIssuer: String? {
        guard let sUrl = serverUrl, let url = URL(string: sUrl) else {
            return nil
        }
        let hostURL: String?
        if url.absoluteString.contains("oauth/v4") {
            hostURL = url.absoluteString
        } else {
            hostURL = url.host
        }
        guard host = hostURL, let port = url.port else {
            return hostURL
        }
        return "\(host):\(port)"
    }

    var publicKeyServerURL: String? {

        // public key url = OAUTH_SERVER_URL/publickey
        // e.g. https://appid-oauth.ng.bluemix.net/oauth/v3/a8589e38-081e-4128-a777-b1cd76ee1875/publickey
        if let serverUrl = serverUrl {
            if serverUrl.last == "/" {
                var endpoint = Constants.Endpoints.publicKeys
                endpoint.removeFirst()
                return serverUrl + endpoint
            } else {
                return serverUrl + Constants.Endpoints.publicKeys
            }
        }
        return nil
    }

    /// Whether the Audience and Issuer should be validated (Required by Web Strategy)
    var shouldValidateAudAndIssuer: Bool = true

    init(options: [String: Any]?, validateEntireToken: Bool = true, required: KeyPath<AppIDPluginConfig, String?>...) {

        self.shouldValidateAudAndIssuer = validateEntireToken

        Log.debug("Intializing configuration")

        let options = options ?? [:]
        let vcapString = ProcessInfo.processInfo.environment[Constants.VCAP.services] ?? ""
        let vcapServices = JSON.parse(string: vcapString)
        var vcapServiceCredentials: [String: Any]? = [:]

        /// Parse vcap services
        if let dict = vcapServices.dictionary {
            for (key, value) in dict {
                if key.hasPrefix(Constants.VCAP.serviceName) || key.hasPrefix(Constants.VCAP.serviceNameV1) {
                    vcapServiceCredentials = (value.array?[0])?.dictionaryObject?[Constants.VCAP.credentials] as? [String : Any]
                    break
                }
            }
        }

        let credentials = [Constants.Credentials.clientId,
                           Constants.Credentials.tenantId,
                           Constants.Credentials.secret,
                           Constants.Credentials.oauthServerUrl,
                           Constants.Credentials.userProfileServerUrl]

        /// Create service config. Options override vcap services.
        for field in credentials {
            serviceConfig[field] = options[field] ?? vcapServiceCredentials?[field]
        }

        serviceConfig[Constants.Credentials.redirectUri] =
            options[Constants.Credentials.redirectUri] ??
            ProcessInfo.processInfo.environment[Constants.Credentials.redirectUri]

        if serviceConfig[Constants.Credentials.redirectUri] == nil {
            if let vcapApplication = ProcessInfo.processInfo.environment[Constants.VCAP.application] {
                let vcapApplicationJson = JSON.parse(string: vcapApplication)
                let applicationUris = vcapApplicationJson["application_uris"]
                let uri = applicationUris.count > 0 ? applicationUris[0] : ""
                serviceConfig[Constants.Credentials.redirectUri] = "https://\(uri.stringValue)/ibm/bluemix/appid/callback"
            }
        }

        /// Assert configuration has required fields
        for path in required {
            if self[keyPath: path] == nil {
                Log.error("Failed to fully initialize configuration." +
                    " To ensure complete functionality, ensure your app is either bound to an" +
                    " App ID service instance or pass the required parameters to the constructor")
                break
            }
        }

        Log.info("ServerUrl: " + (serverUrl ?? "unset"))
        Log.info("ProfilesUrl: " + (userProfileServerUrl ?? "unset"))
    }

}
