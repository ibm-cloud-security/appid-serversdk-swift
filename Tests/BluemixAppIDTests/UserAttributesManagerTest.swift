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
import Foundation
import Credentials
import KituraSession
import SwiftyJSON
import Kitura
import SimpleLogger
@testable import Credentials
@testable import KituraNet
@testable import Kitura
@testable import KituraSession
import Socket

@testable import BluemixAppID

class UserAttributesManagerTest: XCTestCase {
    
    static var allTests : [(String, (UserAttributesManagerTest) -> () throws -> Void)] {
        return [
            ("testInit", testInit),
            ("testSetAttribute", testSetAttribute),
            ("testGetAttribute", testGetAttribute),
            ("testDeleteAttribute", testDeleteAttribute),
            ("testGetAllAttributes", testGetAllAttributes),
        ]
    }
    
    class MockUserAttributeManger : UserAttributeManager {

        override func handleRequest(attributeName: String?, attributeValue: String?, method:String, accessToken: String,completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {
            if accessToken.range(of:"return_error") != nil {
                completionHandler(UserAttributeError.userAttributeFailure("Unexpected error"), nil)
            }
            else if accessToken.range(of:"return_code") != nil {
                let statusCode : Int! = Int(accessToken.components(separatedBy: "_")[2])
                switch statusCode {
                case 401,403:
                    completionHandler(UserAttributeError.userAttributeFailure("Unauthorized"), nil)
                    break
                case 404:
                    completionHandler(UserAttributeError.userAttributeFailure("Not found"), nil)
                    break
                default:
                    completionHandler(UserAttributeError.userAttributeFailure("Unexpected error"), nil)
                }
            }
            else {
                completionHandler(nil, ["body":"body"])
            }
        }

    }

    let AccessTokenStatusCode401 = "accessToken,return_code_401"
    let AccessTokenStatusCode403 = "accessToken,return_code_403"
    let AccessTokenStatusCode404 = "accessToken,return_code_404"
    let AccessTokenSuccess = "accessToken"
    let AccessTokenFailure = "accessToken,return_error"
    let logger = Logger(forName:"UserAttributesManagerTest")
    let fullOptions =  ["clientId": "someclient",
                        "secret": "somesecret",
                        "tenantId": "sometenant",
                        "oauthServerUrl": "someurl",
                        "redirectUri": "http://someredirect",
                        "profilesUrl": "https://someUrl"]

    var userAttManager : MockUserAttributeManger? = MockUserAttributeManger.init(options: ["clientId": "someclient",
                                                                                           "secret": "somesecret",
                                                                                           "tenantId": "sometenant",
                                                                                           "oauthServerUrl": "someurl",
                                                                                           "redirectUri": "http://someredirect",
                                                                                           "profilesUrl": "https://someUrl"])
    var expectation:XCTestExpectation?


    func setOnFailure(expectation: XCTestExpectation? = nil, error: Swift.Error? = nil,_ expectedMsg: String = "") {
        if expectation == nil {
            XCTFail()
        } else {
            XCTAssert(error.debugDescription.range(of: expectedMsg) != nil)
            expectation!.fulfill()
        }

    }

    func setOnSuccess(expectation:XCTestExpectation? = nil, body:[String:Any] = [:],_ expectedMsg: String = "") {
        if expectation == nil {
            XCTFail()
        } else {
            XCTAssert(body.description.range(of: expectedMsg) != nil)
            expectation!.fulfill()
        }

    }


    func testInit() {

        // check failure - profileUrl was not provided neither trought VCAP nor options
        XCTAssertNil(MockUserAttributeManger.init(options: [:]).serviceConfig["profilesUrl"])

        // check success - profileUrl was provided trought VCAP
        unsetenv("VCAP_SERVICES")
        unsetenv("VCAP_APPLICATION")
        setenv("VCAP_SERVICES", "{\n  \"AdvancedMobileAccess\": [\n    {\n      \"credentials\": {\n        \"clientId\": \"vcapclient\",\n        \"secret\": \"vcapsecret\",\n        \"tenantId\": \"vcaptenant\",\n        \"oauthServerUrl\": \"vcapserver\",\n \"profilesUrl\": \"vcapprofile\"\n     }\n    }\n  ]\n}", 1)
        userAttManager = MockUserAttributeManger.init(options: [:])
        XCTAssertNotNil(userAttManager!.serviceConfig["profilesUrl"])

        // check success - profileUrl was provided trought options
        XCTAssertNotNil(MockUserAttributeManger.init(options: fullOptions).serviceConfig["profilesUrl"])
    }

    func testSetAttribute() {

        // expired accessToken - should fail "Unexpected error"
        userAttManager?.setAttribute(accessToken : AccessTokenFailure, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"),error: err!, "Unexpected error")
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userAttManager?.setAttribute(accessToken : AccessTokenStatusCode401, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"),error: err!,"Unauthorized")
            }
        })

        // expired accessToken - should fail "Unauthorized 403"
        userAttManager?.setAttribute(accessToken : AccessTokenStatusCode403, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"),error: err!, "Unauthorized")
            }
        })

        // expired accessToken - should fail "Not found 404"
        userAttManager?.setAttribute(accessToken : AccessTokenStatusCode404, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: err!, "Not found")
            }
        })

        // valid accessToken - should succeed and return the body
        userAttManager?.setAttribute(accessToken : AccessTokenSuccess, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess(expectation: self.expectation(description: "body"),body: res!, "body")
            } else {
                self.setOnFailure()
            }
        })

        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
    }

    func testGetAttribute() {

        // expired accessToken - should fail "Unexpected error"
        userAttManager?.getAttribute(accessToken : AccessTokenFailure, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"), error: err!, "Unexpected error")
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userAttManager?.getAttribute(accessToken : AccessTokenStatusCode401, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: err!, "Unauthorized")
            }
        })

        // expired accessToken - should fail "Unauthorized 403"
        userAttManager?.getAttribute(accessToken : AccessTokenStatusCode403, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: err!, "Unauthorized")
            }
        })

        // expired accessToken - should fail "Not found 404"
        userAttManager?.getAttribute(accessToken : AccessTokenStatusCode404, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: err!, "Not found")
            }
        })

        // valid accessToken - should succeed and return the body
        userAttManager?.getAttribute(accessToken : AccessTokenSuccess, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess(expectation: self.expectation(description: "body"), body: res!, "body")
            } else {
                self.setOnFailure()
            }
        })

        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }

    }


    func testDeleteAttribute() {

        // expired accessToken - should fail "Unexpected error"
        userAttManager?.deleteAttribute(accessToken : AccessTokenFailure, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"), error: err!, "Unexpected error")
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userAttManager?.deleteAttribute(accessToken : AccessTokenStatusCode401, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: err!, "Unauthorized")
            }
        })

        // expired accessToken - should fail "Unauthorized 403"
        userAttManager?.deleteAttribute(accessToken : AccessTokenStatusCode403, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: err!, "Unauthorized")
            }
        })

        // expired accessToken - should fail "Not found 404"
        userAttManager?.deleteAttribute(accessToken : AccessTokenStatusCode404, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: err!, "Not found")
            }
        })

        // valid accessToken - should succeed and return the body
        userAttManager?.deleteAttribute(accessToken : AccessTokenSuccess, attributeName : "name", completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess(expectation: self.expectation(description: "body"), body: res!, "body")
            } else {
                self.setOnFailure()
            }
        })

        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
    }

    func testGetAllAttributes() {

        // expired accessToken - should fail "Unexpected error"
        userAttManager?.getAllAttributes(accessToken : AccessTokenFailure, completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"), error: err!, "Unexpected error")
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userAttManager?.getAllAttributes(accessToken : AccessTokenStatusCode401, completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: err!, "Unauthorized")
            }
        })

        // expired accessToken - should fail "Unauthorized 403"
        userAttManager?.getAllAttributes(accessToken : AccessTokenStatusCode403, completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: err!, "Unauthorized")
            }
        })

        // expired accessToken - should fail "Not found 404"
        userAttManager?.getAllAttributes(accessToken : AccessTokenStatusCode404, completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess()
            } else {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: err!, "Not found")
            }
        })

        // valid accessToken - should succeed and return the body
        userAttManager?.getAllAttributes(accessToken : AccessTokenSuccess, completionHandler : { (err, res) in
            if err == nil {
                self.setOnSuccess(expectation: self.expectation(description: "body"), body: res!, "body")
            } else {
                self.setOnFailure()
            }
        })

        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
    }

}
