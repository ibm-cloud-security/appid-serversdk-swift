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
import SwiftyJSON

@available(OSX 10.12, *)
public class Token {
    
    public var raw: String
    
    public var rawHeader: String
    public var rawPayload: String
    public var signature: String
    
    public var kid: String? {
        return header["kid"].string
    }
    
    public var alg: String? {
        return header["alg"].string
    }
    
    public var exp: Double? {
        return payload["exp"].double
    }
    
    public var aud: String? {
        return payload["aud"].string
    }
    
    public var iss: String? {
        return payload["iss"].string
    }
    
    public var tenant: String? {
        return payload["tenant"].string
    }

    public var payloadDict: [String: Any]? {
        return payload.dictionaryObject
    }
    
    internal var header: JSON
    internal var payload: JSON
    
    public init(with raw: String) throws {
        
        let tokenComponents = raw.components(separatedBy: ".")
        
        guard tokenComponents.count == 3 else {
            throw AppIDError.invalidTokenFormat
        }
        
        self.raw = raw
        self.rawHeader = tokenComponents[0]
        self.rawPayload = tokenComponents[1]
        self.signature = tokenComponents[2]
        
        guard let headerDecodedData = rawHeader.base64decodedData(),
              let payloadDecodedData = rawPayload.base64decodedData() else {
            throw AppIDError.invalidTokenFormat
        }
        
        self.header = JSON(data: headerDecodedData)
        self.payload = JSON(data: payloadDecodedData)
    }
}
