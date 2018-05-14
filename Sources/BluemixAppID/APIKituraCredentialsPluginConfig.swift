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
import SwiftyJSON
import SimpleLogger

internal class APIKituraCredentialsPluginConfig: AppIDPluginConfig {

    private let logger = Logger(forName: Constants.APIPlugin.name)

    internal var publicKeyServerURL: String? {

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

    override init(options: [String: Any]?) {
        logger.debug("Intializing")

        super.init(options: options)

        if serviceConfig[Constants.Credentials.oauthServerUrl] == nil {
            logger.error("Failed to initialize APIKituraCredentialsPlugin." +
                         " All requests to protected endpoints will be rejected" +
                         " Ensure your app is either bound to an AppID service instance" +
                         " or pass required parameters in the strategy constructor ")
        }

        logger.info(Constants.Credentials.oauthServerUrl + "=" + ((serviceConfig[Constants.Credentials.oauthServerUrl] as? String) ?? ""))
    }
}
