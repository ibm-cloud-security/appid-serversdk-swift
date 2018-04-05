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

public class AuthorizationContext {
    
    public var userIdentity:UserIdentity {
        get {
            return UserIdentity(json: json)
        }
    }
    
    public var expirationDate: Double {
        get {
            return json["exp"].doubleValue
        }
    }
    
    public var issuer: String {
        get {
            return json["iss"].stringValue
        }
    }
    
    public var audience: String {
        get {
            return json["aud"].stringValue
        }
    }
    
    public var subject: String {
        get {
            return json["sub"].stringValue
        }
    }
    
    public var issuedAt: Double {
        get {
            return json["iat"].doubleValue
        }
    }
    
    internal let json:JSON
    
    public init(idTokenPayload: JSON) {
        self.json = idTokenPayload
    }
    
    public static func from(jsonString:String) throws -> AuthorizationContext? {
        
        if let jsonData = jsonString.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            let json = JSON(data: jsonData)
            return AuthorizationContext(idTokenPayload: json)
        } else {
            throw AppIDError.failedParsingAuthContext
        }
    }
}
