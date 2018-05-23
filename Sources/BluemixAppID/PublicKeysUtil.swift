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

import SimpleLogger
import SwiftyRequest
import SwiftJWKtoPEM
import Foundation

public class PublicKeyUtil {

    struct PublicKey: Codable {
        let e: String
        let kid: String
        let kty: String
        let n: String
    }

    public var publicKeyUrl: String?

    public var publicKeys: [String: String]?

    private let logger = Logger(forName: Constants.Utils.publicKey)

    public init(url: String?) {
        if let url = url {
            publicKeyUrl = url
        } else {
            logger.debug("Request public key url not supplied ")
        }

        updatePublicKeys { _, _ in }
    }

    ///
    /// Retrieves the public key with the provided kid
    ///
    /// - Parameter kid: A String denoting the key id of the public key to retrieve
    ///
    public func getPublicKey(kid: String, completion: @escaping (String?, AppIDError?) -> Void) {

        /// Attempt to find public key
        if let publicKeys = publicKeys {
            if let key = publicKeys[kid] {
                return completion(key, nil)
            }
        }

        /// Updates public keys
        updatePublicKeys { keys, error in
            if let key = keys?[kid] {
                return completion(key, nil)
            } else {
                return completion(nil, error ?? .publicKeyNotFound)
            }
        }
    }

    ///
    /// Helper method to retrieve all App ID public keys
    ///
    func updatePublicKeys(completion: @escaping ([String: String]?, AppIDError?) -> Void) {

        guard let publicKeyUrl = self.publicKeyUrl else {
            logger.error("Cannot retrieve public keys. Missing OAuth server url.")
            return completion(nil, .missingPublicKey)
        }

        sendRequest(url: publicKeyUrl) { data, response, error in

            guard error == nil, let response = response, let data = data else {
                self.logger.debug("An error occured in the public key retrieval response. Error: \(error?.localizedDescription ?? "")")
                return completion(nil, .missingPublicKey)
            }

            self.handlePubKeyResponse(status: response.statusCode, data: data, completion: completion)
            self.logger.debug("Retrieved keys")
        }
    }

    ///
    /// Public Key Response handler
    ///
    func handlePubKeyResponse(status: Int?, data: Data, completion: @escaping ([String: String]?, AppIDError?) -> Void) {
        
        guard status == 200 else {
            logger.debug("Failed to obtain public key " +
                "status code \(String(describing: status))\n" +
                "body \(String(data: data, encoding: .utf8) ?? "")")
            return completion(nil, .missingPublicKey)
        }

        guard let json = try? JSONDecoder().decode([String: [PublicKey]].self, from: data),
            let tokens = json["keys"] else {
                logger.debug("Unable to decode data from public key response")
                return completion(nil, .missingPublicKey)
        }

        // convert JWK key to PEM format
        let publicKeys = tokens.reduce([String: String]()) { (dict, key) in
            var dict = dict

            guard let pemKey = try? RSAKey(n: key.n, e: key.e).getPublicKey(certEncoding.pemPkcs8),
                let publicKey = pemKey else {
                    logger.debug("Failed to convert public key to pemPkcs: \(key)")
                    return dict
            }
            dict[key.kid] = publicKey

            return dict
        }

        logger.debug("Public keys retrieved and extracted")

        self.publicKeys = publicKeys
        completion(publicKeys, .publicKeyNotFound)
    }

    /// Testing:
    func sendRequest(url: String, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        RestRequest(url: url).response(completionHandler: completion)
    }
}
