///*
// Copyright 2017 IBM Corp.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// */
//
//import Foundation
//
//
//
//public class publicKeyUtils {
//    static let PUBLIC_KEY_PATH = "/imf-authserver/authorization/v1/apps/{tenantId}/publickey";
//    static let TIMEOUT = 15 * 1000
//    static var publicKeyJson:[String: Any]? = nil
//
//public static func retrievePublicKey(tenantId: String, serverUrl: String) {
//    serverUrl = (serverUrl + PUBLIC_KEY_PATH).replace("{tenantId}", tenantId);
//    logger.debug("Getting public key from", serverUrl);
//    var deferred = Q.defer();
//    request({
//        method: "GET",
//        url: serverUrl,
//        json: true,
//        timeout: TIMEOUT
//    }, function (error, response, body){
//        if (error || response.statusCode !== 200){
//            logger.error("Failed to retrieve public key. All requests to protected endpoints will be rejected.");
//            return deferred.reject("Failed to retrieve public key");
//        } else {
//            publicKeyJson = body;
//            logger.info("Public key retrieved");
//            return deferred.resolve();
//        }
//    });
//    return deferred.promise;
//}
//
//public static func getPublicKeyPem() {
//    if publicKeyJson != nil {
//        return pemFromModExp(publicKeyJson["n"], publicKeyJson["e"])
//    } else {
//        logger.warn("Trying to get public key before it was retrieved. All requests to protected endpoints will be rejected. ")
//    }
//
//}
//
//}
