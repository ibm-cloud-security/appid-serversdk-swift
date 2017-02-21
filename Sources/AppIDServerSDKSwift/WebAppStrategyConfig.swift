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

class WebAppStrategyConfig {
    
    static let VCAP_SERVICES = "VCAP_SERVICES"
    static let VCAP_SERVICES_CREDENTIALS = "credentials"
    static let VCAP_SERVICES_SERVICE_NAME = "AdvancedMobileAccess"
    static let VCAP_APPLICATION = "VCAP_APPLICATION"
    static let TENANT_ID = "tenantId"
    static let SERVER_URL = "serverUrl"
    static let CLIENT_ID = "clientId"
    static let SECRET = "secret"
    static let AUTHORIZATION_ENDPOINT = "authorizationEndpoint"
    static let TOKEN_ENDPOINT = "tokenEndpoint"
    static let REDIRECT_URI = "redirectUri"
    static let OAUTH_SERVER_URL = "oauthServerUrl"

    var serviceConfig: [String:Any] = [:]
    
    
    var config:[String:Any] {
        get {
            return serviceConfig
        }
    }
    
    var tenantId:String {
        get {
            return serviceConfig[WebAppStrategyConfig.TENANT_ID] as? String ?? ""
        }
    }
    
    var clientId:String {
        get {
            return serviceConfig[WebAppStrategyConfig.CLIENT_ID] as? String ?? ""
        }
    }
    
    var secret:String {
        get {
            return serviceConfig[WebAppStrategyConfig.SECRET] as? String ?? ""
        }
    }
    var oAuthServerUrl:String {
        get {
            return serviceConfig[WebAppStrategyConfig.OAUTH_SERVER_URL] as? String ?? ""
        }
    }
    var redirectUri:String {
        get {
            return serviceConfig[WebAppStrategyConfig.REDIRECT_URI] as? String ?? ""
        }
    }
    
    
    
    public init(options:[String:Any]?) {
        let options = options ?? [:]
        let vcapString = ProcessInfo.processInfo.environment[APIStrategyConfig.VCAP_SERVICES] ?? ""
        let vcapServices = JSON.parse(string: vcapString)
        var vcapServiceCredentials: [String:Any]? = [:]
        // var serviceConfig = {}
        // Find AppID service config
        
        for (key,value) in vcapServices { //TODO: debug and see if this happends
            // Does service name starts with VCAP_SERVICES_SERVICE_NAME
            if key.hasPrefix(APIStrategyConfig.VCAP_SERVICES_SERVICE_NAME) {
                vcapServiceCredentials = (value.array?[0])?.dictionaryObject?[WebAppStrategyConfig.VCAP_SERVICES_CREDENTIALS] as? [String : Any]
                break
            }
        }

        serviceConfig[WebAppStrategyConfig.TENANT_ID] = options[WebAppStrategyConfig.TENANT_ID] ?? vcapServiceCredentials?[WebAppStrategyConfig.TENANT_ID]
        serviceConfig[WebAppStrategyConfig.CLIENT_ID] = options[WebAppStrategyConfig.CLIENT_ID] ?? vcapServiceCredentials?[WebAppStrategyConfig.CLIENT_ID]
        serviceConfig[WebAppStrategyConfig.SECRET] = options[WebAppStrategyConfig.SECRET] ?? vcapServiceCredentials?[WebAppStrategyConfig.SECRET]
        serviceConfig[WebAppStrategyConfig.AUTHORIZATION_ENDPOINT] = options[WebAppStrategyConfig.AUTHORIZATION_ENDPOINT] ?? vcapServiceCredentials?[WebAppStrategyConfig.AUTHORIZATION_ENDPOINT]
        serviceConfig[WebAppStrategyConfig.TOKEN_ENDPOINT] = options[WebAppStrategyConfig.TOKEN_ENDPOINT] ?? vcapServiceCredentials?[WebAppStrategyConfig.TOKEN_ENDPOINT]
        serviceConfig[WebAppStrategyConfig.REDIRECT_URI] = options[WebAppStrategyConfig.REDIRECT_URI] ?? vcapServiceCredentials?[WebAppStrategyConfig.REDIRECT_URI]
        
        
        if serviceConfig[WebAppStrategyConfig.REDIRECT_URI] == nil {
            let vcapApplication = ProcessInfo.processInfo.environment[WebAppStrategyConfig.VCAP_SERVICES]
            if vcapApplication != nil {
                var vcapApplicationJson = JSON.parse(string: vcapApplication!)
                serviceConfig[WebAppStrategyConfig.REDIRECT_URI] = "https://" + ((vcapApplicationJson.dictionaryObject?["application_uris"] as? Array)?[0])! + "/ibm/bluemix/appid/callback";
            }
        }
        
        guard serviceConfig[WebAppStrategyConfig.CLIENT_ID] != nil && serviceConfig[WebAppStrategyConfig.SECRET] != nil && serviceConfig[WebAppStrategyConfig.AUTHORIZATION_ENDPOINT] != nil && serviceConfig[WebAppStrategyConfig.TOKEN_ENDPOINT] != nil && serviceConfig[WebAppStrategyConfig.TENANT_ID] != nil && serviceConfig[WebAppStrategyConfig.REDIRECT_URI] != nil else {
            //            logger.error("Failed to initialize webapp-strategy. All requests to protected endpoints will be rejected");
            //            logger.error("Ensure your node.js app is either bound to an AppID service instance or pass required parameters in the strategy constructor ");
            return
        }
        
        
        
    }
    
}
