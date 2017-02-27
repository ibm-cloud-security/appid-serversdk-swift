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
