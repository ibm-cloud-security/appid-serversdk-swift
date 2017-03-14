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

internal class WebAppKituraCredentialsPluginConfig {
    
    private let VCAP_SERVICES = "VCAP_SERVICES"
    private let VCAP_SERVICES_CREDENTIALS = "credentials"
    private let VCAP_SERVICES_SERVICE_NAME = "AdvancedMobileAccess"
    private let VCAP_APPLICATION = "VCAP_APPLICATION"
    private let TENANT_ID = "tenantId"
    private let CLIENT_ID = "clientId"
    private let SECRET = "secret"
    private let REDIRECT_URI = "redirectUri"
    private let OAUTH_SERVER_URL = "oauthServerUrl"
	
	private let logger = Logger(forName: "WebAppKituraCredentialsPlugin")
    
    var serviceConfig: [String:Any] = [:]
    
    
    var config:[String:Any] {
        get {
            return serviceConfig
        }
    }
    
    var tenantId:String {
        get {
            return serviceConfig[TENANT_ID] as? String ?? ""
        }
    }
    
    var clientId:String {
        get {
            return serviceConfig[CLIENT_ID] as? String ?? ""
        }
    }
    
    var secret:String {
        get {
            return serviceConfig[SECRET] as? String ?? ""
        }
    }
    var oAuthServerUrl:String {
        get {
            return serviceConfig[OAUTH_SERVER_URL] as? String ?? ""
        }
    }
    var redirectUri:String {
        get {
            return serviceConfig[REDIRECT_URI] as? String ?? ""
        }
    }
    
    
    
    public init(options:[String:Any]?) {
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
        
        serviceConfig[TENANT_ID] = options[TENANT_ID] ?? vcapServiceCredentials?[TENANT_ID]
        serviceConfig[CLIENT_ID] = options[CLIENT_ID] ?? vcapServiceCredentials?[CLIENT_ID]
        serviceConfig[SECRET] = options[SECRET] ?? vcapServiceCredentials?[SECRET]
        serviceConfig[OAUTH_SERVER_URL] = options[OAUTH_SERVER_URL] ?? vcapServiceCredentials?[OAUTH_SERVER_URL]
        
        serviceConfig[REDIRECT_URI] = options[REDIRECT_URI] ?? ProcessInfo.processInfo.environment[REDIRECT_URI]
        
        if serviceConfig[REDIRECT_URI] == nil {
            let vcapApplication = ProcessInfo.processInfo.environment[VCAP_APPLICATION]
            if vcapApplication != nil {
                let vcapApplicationJson = JSON.parse(string: vcapApplication!)
				let applicationUris = vcapApplicationJson["application_uris"]
				let uri = applicationUris.count > 0 ? applicationUris[0] : ""
                serviceConfig[REDIRECT_URI] = "https://\(uri.stringValue)/ibm/bluemix/appid/callback"
            }
        }
        
        guard serviceConfig[CLIENT_ID] != nil && serviceConfig[SECRET] != nil && serviceConfig[OAUTH_SERVER_URL] != nil && serviceConfig[TENANT_ID] != nil && serviceConfig[REDIRECT_URI] != nil else {
            logger.error("Failed to initialize WebAppKituraCredentialsPluginConfig. All requests to protected endpoints will be rejected")
            logger.error("Ensure your app is either bound to an App ID service instance or pass required parameters in the strategy constructor")
            return
        }
        
        
        
    }
    
}
