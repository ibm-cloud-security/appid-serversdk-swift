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

extension String{
    
    func base64decodedData() -> Data? {
        let missing = self.characters.count % 4
        
        var ending = ""
        if missing > 0 {
            let amount = 4 - missing
            ending = String(repeating: "=", count: amount)
        }
        
        let base64 = self.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + ending
        
        return Data(base64Encoded: base64, options: Data.Base64DecodingOptions())
    }
}

public  class Utils {
    
    private static let logger = Logger(forName: "BluemixAppIDUtils");
    
    public static func getAuthorizedIdentities(from idToken:JSON) -> AuthorizationContext? {
        logger.debug("APIStrategy getAuthorizedIdentities")
        return  AuthorizationContext(idTokenPayload: idToken["payload"])
    }
    
    public static func parseToken(from tokenString:String) throws -> JSON {
        logger.debug("parseToken")
        
        let tokenComponents = tokenString.components(separatedBy: ".")
        
        guard tokenComponents.count == 3 else {
            logger.error("Invalid access token format")
            throw AppIDErrorInternal.InvalidAccessTokenFormat
        }
        
        let jwtHeaderData = tokenComponents[0].base64decodedData()
        let jwtPayloadData = tokenComponents[1].base64decodedData()
        let jwtSignature = tokenComponents[2]
        
        guard jwtHeaderData != nil && jwtPayloadData != nil else {
            logger.error("Invalid access token format")
            throw AppIDErrorInternal.InvalidAccessTokenFormat
        }
        
        let jwtHeader = JSON(data: jwtHeaderData!)
        let jwtPayload = JSON(data: jwtPayloadData!)
        
        var json = JSON([:])
        json["header"] = jwtHeader
        json["payload"] = jwtPayload
        json["signature"] = JSON(jwtSignature)
        return json
    }
    
    public static func isTokenValid(token:String) -> Bool {
        logger.debug("isTokenValid")
        if let jwt = try? parseToken(from: token) {
            let jwtPayload = jwt["payload"].dictionary
            
            guard let jwtExpirationTimestamp = jwtPayload?["exp"]?.double else {
                return false
            }
            
            return Date(timeIntervalSince1970: jwtExpirationTimestamp) > Date()
        } else {
            return false
        }
    }
    
    public static func parseJsonStringtoDictionary(_ jsonString:String) throws -> [String:Any] {
        do {
            guard let data = jsonString.data(using: String.Encoding.utf8), let responseJson =  try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
                throw AppIDError.jsonUtilsError
            }
            return responseJson as [String:Any]
        }
    }
    
    
}
