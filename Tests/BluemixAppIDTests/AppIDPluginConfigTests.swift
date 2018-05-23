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

import XCTest
@testable import BluemixAppID

@available(OSX 10.12, *)
class AppIDPluginConfigTests: XCTestCase {
    
    static var allTests : [(String, (AppIDPluginConfigTests) -> () throws -> Void)] {
        return [
            ("testConfigEmpty", testConfigEmpty),
            ("testRedirectUrl", testRedirectUrl),
            ("testConfigOptions", testConfigOptions),
            ("testConfigVCAP", testConfigVCAP),
            ("testConfigVcapAndOptions", testConfigVcapAndOptions),
            ("testCloudVCAP", testCloudVCAP)
        ]
    }
    
    override func setUp() {
        unsetenv("VCAP_SERVICES")
        unsetenv("VCAP_APPLICATION")
        unsetenv("redirectUri")
    }
    
    func testCloudVCAP() {
        setenv("VCAP_SERVICES", "{\n  \"AdvancedMobileAccess\": [\n    {\n      \"credentials\": {\n        \"clientId\": \"vcapclient\",\n        \"secret\": \"vcapsecret\",\n        \"tenantId\": \"vcaptenant\",\n        \"oauthServerUrl\": \"vcapserver\"\n      }\n    }\n  ]\n}", 1)
        setenv("VCAP_APPLICATION", "{\n  \"application_uris\": [\n  \"1\"]\n}", 1)
        let config = AppIDPluginConfig(options: nil)
        XCTAssertEqual(config.serverUrl, "vcapserver")
        XCTAssertEqual(config.clientId, "vcapclient")
        XCTAssertEqual(config.tenantId, "vcaptenant")
        XCTAssertEqual(config.secret, "vcapsecret")
        XCTAssertEqual(config.redirectUri, "https://1/ibm/bluemix/appid/callback")
        
    }
    
    func testRedirectUrl() {
        setenv("redirectUri", "redirect", 1)
        setenv("VCAP_SERVICES", "{\n  \"AdvancedMobileAccess\": [\n    {\n      \"credentials\": {\n        \"clientId\": \"vcapclient\",\n        \"secret\": \"vcapsecret\",\n        \"tenantId\": \"vcaptenant\",\n        \"oauthServerUrl\": \"vcapserver\"\n      }\n    }\n  ]\n}", 1)
        setenv("VCAP_APPLICATION", "{\n  \"application_uris\": [\n  \"1\"]\n}", 1)
        let config = AppIDPluginConfig(options: nil)
        XCTAssertEqual(config.serverUrl, "vcapserver")
        XCTAssertEqual(config.clientId, "vcapclient")
        XCTAssertEqual(config.tenantId, "vcaptenant")
        XCTAssertEqual(config.secret, "vcapsecret")
        XCTAssertEqual(config.redirectUri, "redirect")
    }
    
    func testConfigEmpty() {
        let config = AppIDPluginConfig(options: nil)
        XCTAssertEqual(config.serviceConfig.count, 0)
        XCTAssertNil(config.serverUrl)
        XCTAssertNil(config.serverUrl)
        XCTAssertNil(config.clientId)
        XCTAssertNil(config.tenantId)
        XCTAssertNil(config.secret)
        XCTAssertNil(config.redirectUri)
    }

    func testConfigOptions() {
        let config = AppIDPluginConfig(options: TestConstants.options)
        XCTAssertEqual(config.serverUrl, TestConstants.serverUrl)
        XCTAssertEqual(config.clientId, TestConstants.clientId)
        XCTAssertEqual(config.tenantId, TestConstants.tenantId)
        XCTAssertEqual(config.secret, "somesecret")
        XCTAssertEqual(config.redirectUri, "http://someredirect")
    }

    func testConfigVCAP() {
        setenv("VCAP_SERVICES", "{\n  \"AppID\": [\n    {\n      \"credentials\": {\n      \"oauthServerUrl\": \"https://testvcap/oauth/v3/test\"},    }\n  ]\n}", 1)
        let config = AppIDPluginConfig(options: nil)
        
        XCTAssertEqual(config.serverUrl, "https://testvcap/oauth/v3/test")
    }

    func testConfigVcapAndOptions() {
        setenv("VCAP_SERVICES", "{\n  \"AppID\": [\n    {\n      \"credentials\": {\n      \"oauthServerUrl\": \"https://testvcap/oauth/v3/test\"},    }\n  ]\n}", 1)
        let config = AppIDPluginConfig(options: ["oauthServerUrl": "someurl"], required: \.serverUrl, \.tenantId)
        XCTAssertEqual(config.serverUrl, "someurl")
    }
}
