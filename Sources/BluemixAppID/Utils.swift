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
import CryptorRSA

extension String {

    func base64decodedData() -> Data? {
        let missing = self.count % 4

        var ending = ""
        if missing > 0 {
            let amount = 4 - missing
            ending = String(repeating: "=", count: amount)
        }

        let base64 = self.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + ending

        return Data(base64Encoded: base64, options: Data.Base64DecodingOptions())
    }
}

@available(OSX 10.12, *)
class Utils {

    private static let logger = Logger(forName: Constants.Utils.appId)

    static func getAuthorizedIdentities(from idToken: JSON) -> AuthorizationContext? {
        logger.debug("APIStrategy getAuthorizedIdentities")
        return AuthorizationContext(idTokenPayload: idToken["payload"])
    }

    static func getAuthorizedIdentities(from idToken: [String: Any]) -> AuthorizationContext? {
        logger.debug("APIStrategy getAuthorizedIdentities")
        guard let json = try? JSONSerialization.data(withJSONObject: idToken, options: .prettyPrinted) else {
            return nil
        }
        return AuthorizationContext(idTokenPayload: JSON(data: json))
    }

    static func parseToken(from tokenString: String) throws -> JSON {

        let tokenComponents = tokenString.components(separatedBy: ".")

        guard tokenComponents.count == 3 else {
            logger.error("Invalid access token format")
            throw AppIDError.invalidTokenFormat
        }

        guard let jwtHeaderData = tokenComponents[0].base64decodedData(),
              let jwtPayloadData = tokenComponents[1].base64decodedData()
        else {
            logger.error("Invalid access token format")
            throw AppIDError.invalidTokenFormat
        }

        let jwtHeader = JSON(data: jwtHeaderData)
        let jwtPayload = JSON(data: jwtPayloadData)
        let jwtSignature = tokenComponents[2]

        var json = JSON([:])
        json["header"] = jwtHeader
        json["payload"] = jwtPayload
        json["signature"] = JSON(jwtSignature)
        return json
    }

    private static func parseTokenObject(from tokenString: String) throws -> Token {
        return try Token(with: tokenString)
    }

    @available(OSX 10.12, *)
    private static func isSignatureValid(_ token: Token, with pk: String) throws -> Bool {

        var isValid: Bool = false

        guard let tokenPublicKey = try? CryptorRSA.createPublicKey(withPEM: pk) else {
            throw AppIDError.publicKeyNotFound
        }

        // Signed message is the first two components of the token
        let messageString = token.rawHeader + "." + token.rawPayload
        let messageData = messageString.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
        let message = CryptorRSA.createPlaintext(with: messageData)

        // signature is 3rd component
        // add padding, URL decode, base64 decode
        guard let sigData = token.signature.base64decodedData() else {
            throw AppIDError.invalidTokenSignature
        }
        let signature = CryptorRSA.createSigned(with: sigData)

        isValid = try message.verify(with: tokenPublicKey, signature: signature, algorithm: .sha256)
        if !isValid {
	        logger.error("invalid signature on token")
        }

        return isValid
    }

    static func isTokenValid(token: String) -> Bool {
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

    ///
    /// Decodes and Validates the provided token
    ///
    /// - Parameter: tokenString - the jwt string to decode and validate validate
    /// - Parameter: publicKeyUtil - the public key utility used to retrieve keys
    /// - Parameter: options - the configuration options to use for token validation
    /// - Returns: the decoded jwt payload
    ///      throws AppIDError on token validation failure
    static func decodeAndValidate(tokenString: String,
                                  publicKeyUtil: PublicKeyUtil,
                                  options: AppIDPluginConfig,
                                  completion: @escaping ([String: Any]?, AppIDError?) -> Void) {

        func logAndReturn(_ error: AppIDError, completion: @escaping ([String: Any]?, AppIDError?) -> Void) {
            logger.debug("Unable to validate token: " + error.description)
            completion(nil, error)
        }

        guard let token = try? Utils.parseTokenObject(from: tokenString) else {
            return logAndReturn(.invalidTokenFormat, completion: completion)
        }

        guard let payload = token.payloadDict else {
            return logAndReturn(.invalidToken("Could not parse payload"), completion: completion)
        }

        guard token.alg == "RS256" else {
            return logAndReturn(.invalidAlgorithm, completion: completion)
        }

        guard let kid = token.kid else {
            return logAndReturn(.missingTokenKid, completion: completion)
        }

        publicKeyUtil.getPublicKey(kid: kid) { (key, error) in

            if let error = error {
                return logAndReturn(error, completion: completion)
            }

            guard let key = key else {
                return logAndReturn(.missingPublicKey, completion: completion)
            }

            // Validate Signature
            guard let isValid = try? isSignatureValid(token, with: key), isValid else {
                return logAndReturn(.missingTokenKid, completion: completion)
            }

            guard token.isExpired == false else {
                return logAndReturn(.expiredToken, completion: completion)
            }

            guard token.tenant == options.tenantId else {
                return logAndReturn(.invalidTenant, completion: completion)
            }

            /// The WebAppStrategy requires full token validation
            if options.shouldValidateAudAndIssuer {

                guard token.aud == options.clientId else {
                    return logAndReturn(.invalidAudience, completion: completion)
                }

                guard token.iss == options.tokenIssuer else {
                    return logAndReturn(.invalidIssuer, completion: completion)
                }
            }

            completion(payload, nil)
        }
    }

    static func parseJsonStringtoDictionary(_ jsonString: String) throws -> [String:Any] {
        do {
            guard let data = jsonString.data(using: String.Encoding.utf8),
                let responseJson =  try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw AppIDError.jsonParsingError
            }
            return responseJson as [String:Any]
        }
    }
}
