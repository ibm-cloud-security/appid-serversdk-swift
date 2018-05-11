/* *     Copyright 2016, 2017 IBM Corp.
 *     Licensed under the Apache License, Version 2.0 (the "License");
 *     you may not use this file except in compliance with the License.
 *     You may obtain a copy of the License at
 *     http://www.apache.org/licenses/LICENSE-2.0
 *     Unless required by applicable law or agreed to in writing, software
 *     distributed under the License is distributed on an "AS IS" BASIS,
 *     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *     See the License for the specific language governing permissions and
 *     limitations under the License.
 */

import Foundation

public enum UserAttributeError: Error {
    case userAttributeFailure(String)

    var description: String {
        switch self {
        case .userAttributeFailure(let msg) :
            return msg
        }
    }
}


public enum UserInfoError: Error {
    case invalidIdentityToken
    case invalidUserInfoResponse
    case conflictingSubjects
    
    var description: String {
        switch self {
        case .invalidIdentityToken: return "Invalid Identity Token"
        case .invalidUserInfoResponse: return "Invalid User Info Response"
        case .conflictingSubjects: return "Conflicting Subjects. UserInfoResponse.sub must match IdentityToken.sub"
        }
    }
}

public enum RequestError: Error {
    case unauthorized
    case notFound
    case parsingError
    case unexceptedError
    case invalidOauthServerUrl
    case invalidProfileServerUrl
    
    var description: String {
        switch self {
        case .unauthorized: return "Invalid IdentityToken"
        case .notFound: return "Invalid IdentityToken"
        case .parsingError: return "Invalid IdentityToken"
        case .unexceptedError: return "Invalid IdentityToken"
        case .invalidOauthServerUrl: return "Invalid OAuth Server Url"
        case .invalidProfileServerUrl: return "Invalid Profile Server Url"
        }
    }
}
