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
import SwiftyJSON
import SimpleLogger

internal class APIKituraCredentialsPluginConfig {
    private let vcapServices = "VCAP_SERVICES"
    private let vcapServicesCredentials = "credentials"
    private let vcapServicesName = "AdvancedMobileAccess"
    private let vcapApplication = "VCAP_APPLICATION"
    private let oauthServerURL = "oauthServerUrl"
    private let pubkeyServerURL = "pubKeyServerUrl"
    private let logger = Logger(forName: "APIKituraCredentialsPluginConfig")
    var serviceConfig: [String:Any] = [:]
    public init(options:[String:Any]?) {
        logger.debug("Intializing APIKituraCredentialsPluginConfig")
        let options = options ?? [:]
        let vcapString = ProcessInfo.processInfo.environment[self.vcapServices] ?? ""
        let vcapServices = JSON.parse(string: vcapString)
        var vcapServiceCredentials: [String:Any]? = [:]
        if vcapServices.dictionary != nil {
            for (key,value) in vcapServices.dictionary! {
                if key.hasPrefix(vcapServicesName) {
                    vcapServiceCredentials = (value.array?[0])?.dictionaryObject?[vcapServicesCredentials] as? [String : Any]
                    break
                }
            }
        }
        serviceConfig[oauthServerURL] = options[oauthServerURL] ?? vcapServiceCredentials?[oauthServerURL] ?? nil
        if serviceConfig[oauthServerURL] == nil {
            logger.error("Failed to initialize APIKituraCredentialsPlugin. All requests to protected endpoints will be rejected")
            logger.error("Ensure your app is either bound to an AppID service instance or pass required parameters in the strategy constructor ")
        }
        
        logger.info(oauthServerURL + "=" + ((serviceConfig[oauthServerURL] as? String) ?? ""))
    }
    
    var config:[String:Any] {
        get {
            return serviceConfig
        }
    }
    
    var serverUrl:String? {
        get {
            return serviceConfig[oauthServerURL] as? String
        }
    }
    
    var publicKeyServerURL:String? {
        get {
            var keyURL: String? = nil
            
            // public key url = OAUTH_SERVER_URL/publickey
            // e.g. https://appid-oauth.ng.bluemix.net/oauth/v3/a8589e38-081e-4128-a777-b1cd76ee1875/publickey
            if let serverUrl = serviceConfig[oauthServerURL] as? String {
                if serverUrl.last == "/" {
	                keyURL = serverUrl + "./publickey"
                } else {
	                keyURL = serverUrl + "/publickey"
                }
            }
            return keyURL
        }
    }
}
