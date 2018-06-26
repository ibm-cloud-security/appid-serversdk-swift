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

    /// Generates a random state
    ///
    /// - parameter: length - denotes the size of the random string
    /// - returns: a random string of the specified size
    static func generateStateParameter(of length: Int) -> String {

        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = allowedChars.count
        var randomString = ""

        for _ in 0..<length {
            var randomNum = 0
            #if os(Linux)
                randomNum = Int(random() % allowedCharsCount) + 0
            #else
                randomNum = Int(arc4random_uniform(UInt32(allowedCharsCount)))
            #endif
            let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
            let newCharacter = allowedChars[randomIndex]
            randomString += String(newCharacter)
        }

        return randomString
    }

}
