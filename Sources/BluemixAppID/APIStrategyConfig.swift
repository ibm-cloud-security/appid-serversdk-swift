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
import LoggerAPI

internal class APIStrategyConfig {
    static let VCAP_SERVICES = "VCAP_SERVICES";
    static let VCAP_SERVICES_CREDENTIALS = "credentials";
    static let VCAP_SERVICES_SERVICE_NAME = "AdvancedMobileAccess";
    static let VCAP_APPLICATION = "VCAP_APPLICATION";
    static let TENANT_ID = "tenantId";
    static let SERVER_URL = "serverUrl";
    var serviceConfig: [String:Any] = [:]
	
	public init(options:[String:Any]?) {
        Log.debug("Intializing APIStrategyConfig")
        let options = options ?? [:]
        let vcapString = ProcessInfo.processInfo.environment[APIStrategyConfig.VCAP_SERVICES] ?? ""
        let vcapServices = JSON.parse(string: vcapString)
        var vcapServiceCredentials: [String:Any]? = [:]
        if vcapServices.dictionary != nil {
            for (key,value) in vcapServices.dictionary! {
                if key.hasPrefix(APIStrategyConfig.VCAP_SERVICES_SERVICE_NAME) {
                    vcapServiceCredentials = (value.array?[0])?.dictionaryObject?[APIStrategyConfig.VCAP_SERVICES_CREDENTIALS] as? [String : Any]
                    break
                }
            }
        }
        
        serviceConfig[APIStrategyConfig.TENANT_ID] = options[APIStrategyConfig.TENANT_ID] ?? vcapServiceCredentials?[APIStrategyConfig.TENANT_ID] ?? nil
        serviceConfig[APIStrategyConfig.SERVER_URL] = options[APIStrategyConfig.SERVER_URL] ?? vcapServiceCredentials?[APIStrategyConfig.SERVER_URL] ?? nil
        
        if serviceConfig[APIStrategyConfig.TENANT_ID] == nil || serviceConfig[APIStrategyConfig.SERVER_URL] == nil {
            Log.error("Failed to initialize api-strategy. All requests to protected endpoints will be rejected")
            Log.error("Ensure your app is either bound to an AppID service instance or pass required parameters in the strategy constructor ")
        }
        
        Log.info(APIStrategyConfig.TENANT_ID + "=" + ((serviceConfig[APIStrategyConfig.TENANT_ID] as? String) ?? ""))
        Log.info(APIStrategyConfig.SERVER_URL + "=" + ((serviceConfig[APIStrategyConfig.SERVER_URL] as? String) ?? ""))
        
        
    }
    
    
    var config:[String:Any] {
        get {
            return serviceConfig
        }
    }
    
    var tenantId:String? {
        get {
            return serviceConfig[APIStrategyConfig.TENANT_ID] as? String;
        }
    }
    
    var serverUrl:String? {
        get {
            return serviceConfig[APIStrategyConfig.SERVER_URL] as? String
        }
    }
    
}
