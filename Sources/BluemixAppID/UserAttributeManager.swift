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
import SwiftyJSON
import SimpleLogger
import KituraSession

@available(OSX 10.12, *)
public class UserAttributeManager {

    private let logger = Logger(forName: "UserAttributeManager")

    var serviceConfig: AppIDPluginConfig

    public init(options: [String: Any]?) {

        serviceConfig = AppIDPluginConfig(options: options)

        guard serviceConfig.userProfileServerUrl != nil, serviceConfig.serverUrl != nil else {
            logger.error("Ensure your app is either bound to an App ID service instance or pass required profilesUrl parameter to the constructor")
            return
        }
    }


    public func setAttribute (accessToken: String,
                              attributeName: String,
                              attributeValue: String,
                              completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        handleRequest(attributeName: attributeName, attributeValue: attributeValue, method: "put", accessToken: accessToken, completionHandler: completionHandler)

    }


    public func getAttribute (accessToken: String,
                              attributeName: String,
                              completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {
        handleRequest(attributeName: attributeName, attributeValue: nil, method: "get", accessToken: accessToken, completionHandler: completionHandler)

    }

    public func getAllAttributes (accessToken: String,
                                  completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        handleRequest(attributeName: nil, attributeValue: nil, method: "get", accessToken: accessToken, completionHandler: completionHandler)

    }

    public func deleteAttribute (accessToken: String,
                                 attributeName: String,
                                 completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        handleRequest(attributeName: attributeName, attributeValue: nil, method: "delete", accessToken: accessToken, completionHandler: completionHandler)

    }


    internal func handleRequest(attributeName: String?, attributeValue: String?, method:String, accessToken: String,completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        self.logger.debug("UserAttributeManager :: handle Request - " + method + " " + (attributeName ?? "all"))

        guard let profileURL = serviceConfig.userProfileServerUrl else {
            completionHandler(UserAttributeError.userAttributeFailure("Failed to get UserProfileServerURL from serviceConfig as String"), nil)
            return
        }

        var url = profileURL + Constants.Endpoints.attributes + "/"
        if let attributeName = attributeName {
            url += attributeName
        }

        let request = HTTP.request(url, callback: {response in
            if response?.status == 401 || response?.status == 403 {
                self.logger.error("Unauthorized")
                completionHandler(UserAttributeError.userAttributeFailure("Unauthorized"), nil)
            } else if response?.status == 404 {
                self.logger.error("Not found")
                completionHandler(UserAttributeError.userAttributeFailure("Not found"), nil)
            } else if let responseStatus = response?.status, responseStatus >= 200 && responseStatus < 300 {
                var responseJson : [String:Any] = [:]
                do{
                    if let body = try response?.readString() {
                        responseJson =  try Utils.parseJsonStringtoDictionary(body)
                    }
                    completionHandler(nil, responseJson)
                } catch _ {
                    completionHandler(UserAttributeError.userAttributeFailure("Failed to parse server response - failed to parse json"), nil)
                }
            }
            else {
                self.logger.error("Unexpected error")
                completionHandler(UserAttributeError.userAttributeFailure("Unexpected error") , nil)
            }
        })

        if let attributeValue = attributeValue {
            request.write(from: attributeValue)// add attributeValue to body if setAttribute() was called
        }

        request.set(.method(method))
        request.set(.headers(["Authorization":"Bearer " + accessToken]))
        request.end()
    }

}
