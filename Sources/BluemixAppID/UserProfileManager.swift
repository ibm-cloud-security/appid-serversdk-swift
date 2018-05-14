import Foundation
import Kitura
import Credentials
import KituraNet
import SwiftyJSON
import SimpleLogger
import KituraSession

@available(OSX 10.12, *)
public class UserProfileManager {
    private let VcapServices = "VCAP_SERVICES"
    private let VcapServicesCredntials = "credentials"
    private let VcapServicesServiceName = "AdvancedMobileAccess"
    private let UserProfileServerURL = "profilesUrl"
    private let AttributesEndpoint = "/api/v1/attributes"

    private let OAuthServerURL = "oauthServerUrl"
    private let UserInfoEndpoint = "/userinfo"

    private let logger = Logger(forName: "UserProfileManager")
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
        serviceConfig[OAuthServerURL] = options[OAuthServerURL] ?? vcapServiceCredentials?[OAuthServerURL]

        guard serviceConfig[UserProfileServerURL] != nil && serviceConfig[OAuthServerURL] != nil else {
            logger.error("Ensure your app is either bound to an App ID service instance or pass required profilesUrl parameter to the constructor")
            return
        }
    }


    public func setAttribute (accessToken: String,
                              attributeName: String,
                              attributeValue: String,
                              completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        handleAttributeRequest(attributeName: attributeName, attributeValue: attributeValue, method: "put", accessToken: accessToken, completionHandler: completionHandler)

    }


    public func getAttribute (accessToken: String,
                              attributeName: String,
                              completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {
        handleAttributeRequest(attributeName: attributeName, attributeValue: nil, method: "get", accessToken: accessToken, completionHandler: completionHandler)

    }

    public func getAllAttributes (accessToken: String,
                                  completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        handleAttributeRequest(attributeName: nil, attributeValue: nil, method: "get", accessToken: accessToken, completionHandler: completionHandler)

    }

    public func deleteAttribute (accessToken: String,
                                 attributeName: String,
                                 completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        handleAttributeRequest(attributeName: attributeName, attributeValue: nil, method: "delete", accessToken: accessToken, completionHandler: completionHandler)

    }


    public func getUserInfo(accessToken: String, identityToken: String? = nil, completionHandler: @escaping (Swift.Error?, [String: Any]?) -> Void) {

        handleUserInfoRequest(accessToken: accessToken) { (error, profile) in

            guard error == nil, let profile = profile else {
                self.logger.debug("Error: Unexpected error while retrieving User Info. Msg: \(error?.localizedDescription ?? "")")
                return completionHandler(error ?? RequestError.unexpectedError, nil)
            }

            if let identityToken = identityToken {

                guard let identityToken = try? Utils.parseToken(from: identityToken) else {
                    self.logger.debug("Error: Invalid identity Token")
                    return completionHandler(UserProfileError.invalidIdentityToken, nil)
                }

                if let sub = profile["sub"] as? String {
                    guard sub == identityToken["payload"]["sub"].string else {
                        self.logger.debug("Error: IdentityToken.sub does not match UserInfoResult.sub.")
                        return completionHandler(UserProfileError.conflictingSubjects, nil)
                    }
                }
            }

            completionHandler(nil, profile)
        }
    }

    private func handleUserInfoRequest(accessToken: String, completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        self.logger.debug("UserProfileManager :: handle Request - User Info")

        guard let url = serviceConfig[OAuthServerURL] as? String else {
            completionHandler(RequestError.invalidOauthServerUrl, nil)
            return
        }

        handleRequest(accessToken: accessToken, url: url + UserInfoEndpoint, method: "GET", body: nil, completionHandler: completionHandler)
    }

    private func handleAttributeRequest(attributeName: String?, attributeValue: String?, method:String, accessToken: String, completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        self.logger.debug("UserProfileManager :: handle Request - " + method + " " + (attributeName ?? "all"))

        guard let profileURL = serviceConfig[UserProfileServerURL] as? String else {
            completionHandler(RequestError.invalidProfileServerUrl, nil)
            return
        }

        var url = profileURL + AttributesEndpoint + "/"
        if let attributeName = attributeName {
            url += attributeName
        }

        handleRequest(accessToken: accessToken, url: url, method: method, body: attributeValue, completionHandler: completionHandler)
    }

    internal func handleRequest(accessToken: String, url: String, method: String, body: String?, completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {

        let request = HTTP.request(url) {response in
            if response?.status == 401 || response?.status == 403 {
                self.logger.error("Unauthorized")
                completionHandler(RequestError.unauthorized, nil)
            } else if response?.status == 404 {
                self.logger.error("Not found")
                completionHandler(RequestError.notFound, nil)
            } else if let responseStatus = response?.status, responseStatus >= 200 && responseStatus < 300 {
                var responseJson : [String:Any] = [:]
                do{
                    if let body = try response?.readString() {
                        responseJson =  try Utils.parseJsonStringtoDictionary(body)
                    }
                    completionHandler(nil, responseJson)
                } catch _ {
                    completionHandler(RequestError.parsingError, nil)
                }
            }
            else {
                self.logger.error("Unexpected error")
                completionHandler(RequestError.unexpectedError , nil)
            }
        }

        if let body = body {
            request.write(from: body)
        }

        request.set(.method(method))
        request.set(.headers(["Authorization":"Bearer " + accessToken]))
        request.end()
    }
}
