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
@testable import BluemixAppID

class MockPublicKeyUtil: PublicKeyUtil {
    let publicKeyResponseCode: Int
    let publicKeyResponse: String
    
    init(url: String?, responseCode: Int = 200, responseBody: String = "{\"keys\": [\(TestConstants.PUBLIC_KEY)]}") {
        publicKeyResponseCode = responseCode
        publicKeyResponse = responseBody
        super.init(url: url)
    }
    
    override func sendRequest(url: String, completion: @escaping (Data?, HTTPURLResponse?, Swift.Error?) -> Void) {
        let res = HTTPURLResponse(url: URL(string: "http://test.com")!,
                                  statusCode: publicKeyResponseCode,
                                  httpVersion: nil,
                                  headerFields: nil)
        completion(publicKeyResponse.data(using: .utf8)!, res, nil)
    }
}
