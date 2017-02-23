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
/// This class represents the base user identity class, with default methods and keys
import SwiftyJSON

public class UserIdentity {
    
    public var id: String{
        get {
            return json["sub"].stringValue
        }
    }
    
    public var authBy: Array<JSON> {
        get {
            return json["identities"].arrayValue
        }
    }
    
    public var displayName: String {
        get {
            return json["name"].stringValue
        }
    }
    
    public var picture: String {
        get {
            return json["picture"].stringValue
        }
    }
    
    public var email: String {
        get {
            return json["email"].stringValue
        }
    }
    
    
    internal var json:JSON
    
    internal init(json:JSON) {
        self.json = json
    }
}
