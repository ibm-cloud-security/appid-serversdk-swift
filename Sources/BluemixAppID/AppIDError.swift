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

internal enum AppIDError: Error {
    
    // Token Fields
    case invalidAlgorithm
    case missingTokenKid
    case invalidIssuer
    case invalidTenant
    case invalidAudience
    case expiredToken
    case missingPublicKey
    
    // General
    case authorizationHeaderNotFound
    case invalidAuthHeaderFormat
    case invalidTokenFormat
    case invalidTokenSignature
    case publicKeyNotFound
    case jsonParsingError
    case invalidToken(String)
    
    var description: String {
        
        switch self {
        case .missingTokenKid: return "Provided token does not contain the required kid field"
        case .invalidAlgorithm: return "Invalid Algorithm Field. Expected RS256."
        case .invalidIssuer: return "Invalid Issuer Field"
        case .invalidTenant: return "Invalid Tenant Field"
        case .invalidAudience: return "Invalid Audience Field"
        case .expiredToken: return "Token has expired"
        case .missingPublicKey: return "Could not retrieve the required public key"
        case .authorizationHeaderNotFound: return "Authorization header not found"
        case .invalidAuthHeaderFormat: return "Invalid authorization header format. Expected format 'Bearer accessToken idToken'"
        case .invalidTokenFormat: return "Invalid token format"
        case .invalidTokenSignature: return "Invalid token signature"
        case .publicKeyNotFound: return "Public key not found"
        case .jsonParsingError: return "Unable to parse JSON"
        case .invalidToken(let reason): return "Invalid Token: " + reason
            
        }
    }
}
