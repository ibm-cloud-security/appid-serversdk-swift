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
import SwiftyJSON

internal class AppIDPluginConfig {

    private let logger = Logger(forName: Constants.APIPlugin.name)

    var serviceConfig: [String: Any] = [:]

    var isTesting: Bool {
        return serverUrl == "testServerUrl"
    }

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

    public init(options: [String: Any]?) {

        logger.debug("Intializing")

        let options = options ?? [:]
        let vcapString = ProcessInfo.processInfo.environment[Constants.VCAP.services] ?? ""
        let vcapServices = JSON.parse(string: vcapString)
        var vcapServiceCredentials: [String: Any]? = [:]

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
    }
}
