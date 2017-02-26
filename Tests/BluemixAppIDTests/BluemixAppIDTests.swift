import XCTest
@testable import BluemixAppID

class BluemixAppIDTests: XCTestCase {
   
    let fullOptions =  ["clientId": "someclient",
                        "secret": "somesecret",
                        "tenantId": "sometenant",
                        "oauthServerUrl": "someurl",
                        "redirectUri": "someredirect"]
    
    func testExample() {
        XCTAssertEqual(1,1)
    }
    
    
    func testWebConfig() {
        //TODO: add tests with VCAP
        var config = WebAppKituraCredentialsPluginConfig(options:[:])
        XCTAssertEqual(config.serviceConfig.count, 0)
        XCTAssertEqual(config.oAuthServerUrl, "")
        XCTAssertEqual(config.clientId, "")
        XCTAssertEqual(config.tenantId, "")
        XCTAssertEqual(config.secret, "")
        XCTAssertEqual(config.redirectUri, "")
        config = WebAppKituraCredentialsPluginConfig(options: fullOptions)
        XCTAssertEqual(config.oAuthServerUrl, "someurl")
        XCTAssertEqual(config.clientId, "someclient")
        XCTAssertEqual(config.tenantId, "sometenant")
        XCTAssertEqual(config.secret, "somesecret")
        XCTAssertEqual(config.redirectUri, "someredirect")
    }
    
//
//    static var allTests : [(String, (BluemixAppIDTests) -> () throws -> Void)] {
//        return [
//            ("testApiConfig", testApiConfig),
//        ]
//    }
}
