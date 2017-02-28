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
    private let VCAP_SERVICES = "VCAP_SERVICES"
    private let VCAP_SERVICES_CREDENTIALS = "credentials"
    private let VCAP_SERVICES_SERVICE_NAME = "AdvancedMobileAccess"
    private let VCAP_APPLICATION = "VCAP_APPLICATION"
    private let OAUTH_SERVER_URL = "oauthServerUrl"
	private let logger = Logger(forName: "APIKituraCredentialsPluginConfig")
    var serviceConfig: [String:Any] = [:]
	
	public init(options:[String:Any]?) {
        logger.debug("Intializing APIKituraCredentialsPluginConfig")
        let options = options ?? [:]
        let vcapString = ProcessInfo.processInfo.environment[VCAP_SERVICES] ?? ""
        let vcapServices = JSON.parse(string: vcapString)
        var vcapServiceCredentials: [String:Any]? = [:]
        if vcapServices.dictionary != nil {
            for (key,value) in vcapServices.dictionary! {
                if key.hasPrefix(VCAP_SERVICES_SERVICE_NAME) {
                    vcapServiceCredentials = (value.array?[0])?.dictionaryObject?[VCAP_SERVICES_CREDENTIALS] as? [String : Any]
                    break
                }
            }
        }
        
        serviceConfig[OAUTH_SERVER_URL] = options[OAUTH_SERVER_URL] ?? vcapServiceCredentials?[OAUTH_SERVER_URL] ?? nil
        
        if serviceConfig[OAUTH_SERVER_URL] == nil {
            logger.error("Failed to initialize APIKituraCredentialsPlugin. All requests to protected endpoints will be rejected")
            logger.error("Ensure your app is either bound to an AppID service instance or pass required parameters in the strategy constructor ")
        }
        
        logger.info(OAUTH_SERVER_URL + "=" + ((serviceConfig[OAUTH_SERVER_URL] as? String) ?? ""))
    }
	
    var config:[String:Any] {
        get {
            return serviceConfig
        }
    }
    
    var serverUrl:String? {
        get {
            return serviceConfig[OAUTH_SERVER_URL] as? String
        }
    }
    
}
