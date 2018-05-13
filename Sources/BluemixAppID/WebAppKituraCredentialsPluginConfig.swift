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

internal class WebAppKituraCredentialsPluginConfig: AppIDPluginConfig {

	private let logger = Logger(forName: Constants.WebAppPlugin.name)

    override init(options: [String: Any]?) {
        super.init(options: options)

        guard tenantId != nil, clientId != nil, secret != nil, serverUrl != nil, redirectUri != nil else {

            logger.error("Failed to initialize WebAppKituraCredentialsPluginConfig." +
                         " All requests to protected endpoints will be rejected." +
                         " Ensure your app is either bound to an App ID service instance" +
                         " or pass required parameters in the strategy constructor")

                return
        }
    }
}
