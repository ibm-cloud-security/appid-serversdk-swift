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

class PublicKeyUtil {
    
    struct PublicKey: Codable {
        let e: String
        let kid: String
        let kty: String
        let n: String
    }
    
    enum Status {
        case success
        case failure
        case inProcess
        case uninitialized
    }

    var publicKeyUrl: String?

    var publicKeys: [String: String]?
    
    var currentStatus: Status = .uninitialized
    
    private let semaphore = DispatchSemaphore(value: 1)
    
    private let logger = Logger(forName: Constants.Utils.publicKey)
    
    init(url: String?) {
        if let url = url {
            publicKeyUrl = url + Constants.Endpoints.publicKeys
        }
        retrievePublicKeys()
    }

    ///
    /// Retrieves the public key with the provided kid
    ///
    /// - Parameter kid: A String denoting the key id of the public key to retrieve
    ///
    func getPublicKey(kid: String) -> String? {
        
        /// Attempt to find public key
        if let publicKeys = publicKeys {
            if let key = publicKeys[kid] {
                return key
            }
        }
        
        /// The requisite key was not found. Try to update key array.
        if currentStatus != .inProcess {
            
            currentStatus = .inProcess
            
            DispatchQueue.main.async {
                self.retrievePublicKeys()
            }
        }
        
        /// Wait for response
        semaphore.wait()
        
        switch currentStatus {
        case .success: return publicKeys?[kid]
        default: return nil
        }
    }

    
    ///
    /// Helper method to retrieve all App ID public keys
    ///
    func retrievePublicKeys() {
        
        guard let publicKeyUrl = self.publicKeyUrl else {
            logger.error("Cannot retrieve public keys. Missing OAuth server url.")
            return
        }
        
        sendRequest(url: publicKeyUrl) { data, response, error in
            
            guard error == nil, let response = response, let data = data else {
                self.logger.debug("An error occured in the public key retrieval response. Error: \(error?.localizedDescription ?? "")")
                self.currentStatus = .failure
                return
            }
            
            self.handlePubKeyResponse(status: response.statusCode, data: data)
            self.semaphore.signal()
        }
    }

    ///
    /// Public Key Response handler
    ///
    func handlePubKeyResponse(status: Int?, data: Data) {
        do {
            guard status == 200 else {
                logger.debug("Failed to obtain public key " +
                            "status code \(String(describing: status))\n" +
                            "body \(String(data: data, encoding: .utf8) ?? "")")
                throw AppIDError.publicKeyNotFound
            }

            guard let json = try? JSONDecoder().decode([String: [PublicKey]].self, from: data),
                  let tokens = json["keys"] else {
                logger.debug("Unable to decode data from public key response")
                throw AppIDError.publicKeyNotFound
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
            
            self.currentStatus = .success
            
            self.publicKeys = publicKeys

        } catch {
            currentStatus = .failure
        }
    }

    /// Testing:
    func sendRequest(url: String, completion: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        RestRequest(url: url).response(completionHandler: completion)
    }
}
