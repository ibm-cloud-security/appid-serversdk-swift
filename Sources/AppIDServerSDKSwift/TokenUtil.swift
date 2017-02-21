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

public class TokenUtils {
    
    public static func parseToken(from tokenString:String) -> [String: Any]? {
        //logger.debug("parseToken:from:")
        
        let accessTokenComponents = tokenString.components(separatedBy: ".")
        
        guard accessTokenComponents.count == 3 else {
            //  logger.error(MCAErrorInternal.InvalidAccessTokenFormat.rawValue)
            // throw MCAErrorInternal.InvalidAccessTokenFormat
            return nil
        }
        
        let jwtHeaderData = accessTokenComponents[0].base64decodedData()
        let jwtPayloadData = accessTokenComponents[1].base64decodedData()
        let jwtSignature = accessTokenComponents[2]
        
        guard jwtHeaderData != nil && jwtPayloadData != nil else {
            //       logger.error(MCAErrorInternal.InvalidAccessTokenFormat.rawValue)
            //      throw MCAErrorInternal.InvalidAccessTokenFormat
            return nil
        }
        
        let jwtHeader =  try! JSONSerialization.jsonObject(with: jwtHeaderData!, options: [])
        let jwtPayload = try! JSONSerialization.jsonObject(with: jwtPayloadData!, options: [])
        
        var json:[String:Any] = [:]
        json["header"] = jwtHeader
        json["payload"] = jwtPayload
        json["signature"] = jwtSignature
        return json
    }
    
    public static func isAccessTokenValid(accessToken:String) -> Bool{
        //    logger.debug("isAccessTokenValid:")
        if let jwt = parseToken(from: accessToken) {
            let jwtPayload = jwt["payload"] as? [String: Any]
            let jwtExpirationTimestamp = jwtPayload?["exp"] as? Double
            return Date(timeIntervalSince1970: jwtExpirationTimestamp!) > Date()
        } else {
            return false
        }
    }

}
