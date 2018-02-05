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
import XCTest
import Kitura
import SimpleLogger
import Credentials
import KituraSession
import SwiftyJSON
import XCTest
import Kitura
import SimpleLogger
@testable import Credentials
@testable import KituraNet
@testable import Kitura
@testable import KituraSession
import Socket
import SwiftyJSON


@testable import BluemixAppID

class UtilsTest: XCTestCase {

    static var allTests : [(String, (UtilsTest) -> () throws -> Void)] {
        return [
            ("testIsTokenValid", testIsTokenValid),
            ("testUserIdentity", testUserIdentity),
            ("testAuthorizationContext", testAuthorizationContext),
        ]
    }

    func testIsTokenValid() {
        XCTAssertFalse(Utils.isTokenValid(token: TestConstants.MALFORMED_ACCESS_TOKEN))
        XCTAssertFalse(Utils.isTokenValid(token: TestConstants.EXPIRED_ACCESS_TOKEN))
        XCTAssertTrue(Utils.isTokenValid(token: TestConstants.ACCESS_TOKEN))
        XCTAssertFalse(Utils.isTokenValid(token: "asd"))
    }
    
    func testUserIdentity() {
        let id = UserIdentity(json: try! Utils.parseToken(from: TestConstants.ID_TOKEN)["payload"])
        XCTAssertEqual(id.authBy[0].dictionary?["provider"]?.string, "someprov")
        XCTAssertEqual(id.displayName, "test name")
        XCTAssertEqual(id.email, "email@email.com")
        XCTAssertEqual(id.id, "subject")
        XCTAssertEqual(id.picture, "testImageUrl")

    }
    
    func testAuthorizationContext() {
        let context = Utils.getAuthorizedIdentities(from: try! Utils.parseToken(from: TestConstants.ID_TOKEN))
        XCTAssertEqual(context?.audience, "aud1")
        XCTAssertEqual(context?.expirationDate, 2487862253)
        XCTAssertEqual(context?.issuedAt, 1487858653)
        XCTAssertEqual(context?.issuer, "appid")
        XCTAssertEqual(context?.subject, "subject")
        let id = context?.userIdentity
        XCTAssertEqual(id?.authBy[0].dictionary?["provider"]?.string, "someprov")
        XCTAssertEqual(id?.displayName, "test name")
        XCTAssertEqual(id?.email, "email@email.com")
        XCTAssertEqual(id?.id, "subject")
        XCTAssertEqual(id?.picture, "testImageUrl")
    }
    
}
