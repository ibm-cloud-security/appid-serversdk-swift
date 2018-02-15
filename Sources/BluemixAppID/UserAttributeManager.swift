import Foundation
import Kitura
import Credentials
import KituraNet
import SwiftyJSON
import SimpleLogger
import KituraSession



public class UserAttributeManager {
    private let VcapServices = "VCAP_SERVICES"
    private let VcapServicesCredntials = "credentials"
    private let VcapServicesServiceName = "AdvancedMobileAccess"
    private let UserProfileServerURL = "profilesUrl"
    private let AttributesEndpoint = "/api/v1/attributes"
    private let logger = Logger(forName: "UserAttributeManager")
    var serviceConfig: [String:Any] = [:]

    public init(options:[String:Any]?) {
        let options = options ?? [:]
        let vcapString = ProcessInfo.processInfo.environment[VcapServices] ?? ""
        let vcapServices = JSON.parse(string: vcapString)
        var vcapServiceCredentials: [String:Any]? = [:]
        if let dict = vcapServices.dictionary {
            for (key,value) in dict {
                if key.hasPrefix(VcapServicesServiceName) {
                    vcapServiceCredentials = (value.array?[0])?.dictionaryObject?[VcapServicesCredntials] as? [String : Any]
                    break
                }
            }
        }

        serviceConfig[UserProfileServerURL] = options[UserProfileServerURL] ?? vcapServiceCredentials?[UserProfileServerURL]

        guard serviceConfig[UserProfileServerURL] != nil else {
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
        guard let profileURL = serviceConfig[UserProfileServerURL] as? String else {
            completionHandler(UserAttributeError.userAttributeFailure("Failed to get UserProfileServerURL from serviceConfig as String"), nil)
            return
        }
        var url:String = profileURL + AttributesEndpoint + "/"
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
