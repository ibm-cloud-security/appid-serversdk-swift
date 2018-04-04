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
public class Utils {

    private static let logger = Logger(forName: "BluemixAppIDUtils");

    public static func getAuthorizedIdentities(from idToken:JSON) -> AuthorizationContext? {
        logger.debug("APIStrategy getAuthorizedIdentities")
        return  AuthorizationContext(idTokenPayload: idToken["payload"])
    }

    @available(OSX 10.12, *)
    public static func parseToken(from tokenString: String, using publicKeys: [String: String]? = nil) throws -> JSON {

        let tokenComponents = tokenString.components(separatedBy: ".")

        guard tokenComponents.count == 3 else {
            logger.error("Invalid access token format")
            throw AppIDErrorInternal.InvalidAccessTokenFormat
        }

        guard let jwtHeaderData = tokenComponents[0].base64decodedData(),
              let jwtPayloadData = tokenComponents[1].base64decodedData()
        else {
            logger.error("Invalid access token format")
            throw AppIDErrorInternal.InvalidAccessTokenFormat
        }

        let jwtHeader = JSON(data: jwtHeaderData)
        let jwtPayload = JSON(data: jwtPayloadData)
        let jwtSignature = tokenComponents[2]

        // if public keys are passed, then verify signature
        if let publicKeys = publicKeys {
            for (kid, key) in publicKeys {
                if kid == jwtHeader["kid"].string, try !isSignatureValid(tokenComponents, with: key) {
                    throw AppIDErrorInternal.InvalidAccessTokenSignature
                }
            }
        }

        var json = JSON([:])
        json["header"] = jwtHeader
        json["payload"] = jwtPayload
        json["signature"] = JSON(jwtSignature)
        return json
    }

    @available(OSX 10.12, *)
    private static func isSignatureValid(_ tokenParts: [String], with pk: String) throws -> Bool {

        var isValid: Bool = false

        let tokenPublicKey = try? CryptorRSA.createPublicKey(withPEM: pk)
        guard tokenPublicKey != nil else {
            throw AppIDErrorInternal.PublicKeyNotFound
        }

        // Signed message is the first two components of the token
        let messageString = String(tokenParts[0] + "." + tokenParts[1])
        let messageData = messageString.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
        let message = CryptorRSA.createPlaintext(with: messageData)

        // signature is 3rd component
        // add padding, URL decode, base64 decode
        guard let sigData = String(tokenParts[2]).base64decodedData() else {
            throw AppIDErrorInternal.InvalidAccessTokenSignature
        }
        let signature = CryptorRSA.createSigned(with: sigData)

        isValid = try message.verify(with: tokenPublicKey!, signature: signature, algorithm: .sha256)
        if !isValid {
	        logger.error("invalid signature on token")
        }

        return isValid
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

struct PublicKey: Codable {
    let e: String
    let kid: String
    let kty: String
    let n: String
}
