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

@available(OSX 10.12, *)
class UserProfileManagerTests: XCTestCase {

    static var allTests : [(String, (UserProfileManagerTests) -> () throws -> Void)] {
        return [
            ("testInit", testInit),
            ("testSetAttribute", testSetAttribute),
            ("testGetAttribute", testGetAttribute),
            ("testDeleteAttribute", testDeleteAttribute),
            ("testGetAllAttributes", testGetAllAttributes),
            ("testUserInfoHappyFlow", testUserInfoHappyFlow),
            ("testUserInfoHappyFlowSubjectMatching", testUserInfoHappyFlowSubjectMatching),
            ("testUserInfo401", testUserInfo401),
            ("testUserInfo403", testUserInfo403),
            ("testUserInfo404", testUserInfo404),
            ("testUserInfoInvalidIdentityToken", testUserInfoInvalidIdentityToken),
            ("testUserInfoSubjectMismatch", testUserInfoSubjectMismatch),
        ]
    }
    class MockUserProfileManager : UserProfileManager {

        override func handleRequest(accessToken: String, url: String, method: String, body: String?,completionHandler: @escaping (Swift.Error?, [String:Any]?) -> Void) {
            if accessToken.range(of:"return_error") != nil {
                completionHandler(UserProfileError.userAttributeFailure("Unexpected error"), nil)
            }
            else if accessToken.range(of:"return_code") != nil {
                if let statusCode = Int(accessToken.components(separatedBy: "_")[2]) {
                    switch statusCode {
                    case 401,403:
                        completionHandler(UserProfileError.userAttributeFailure("Unauthorized"), nil)
                        break
                    case 404:
                        completionHandler(UserProfileError.userAttributeFailure("Not found"), nil)
                        break
                    default:
                        completionHandler(UserProfileError.userAttributeFailure("Unexpected error"), nil)
                    }
                }
            }
            else {
                if accessToken == UserProfileManagerTests.AccessTokenSuccessMismatchedSubjects {
                    completionHandler(nil, ["sub": "subject", "body":"body"])
                } else {
                    completionHandler(nil, ["sub": "subject123", "body":"body"])
                }
            }
        }

    }

    let AccessTokenStatusCode401 = "accessToken,return_code_401"
    let AccessTokenStatusCode403 = "accessToken,return_code_403"
    let AccessTokenStatusCode404 = "accessToken,return_code_404"
    let AccessTokenSuccess = "accessToken"
    static let AccessTokenSuccessMismatchedSubjects = "accessToken_mismatched_subjects"
    let IdentityTokenSubject123 = "ifQ.eyJzdWIiOiJzdWJqZWN0MTIzIn0.Q"
    let AccessTokenFailure = "accessToken,return_error"
    let logger = Logger(forName:"UserProfileManagerTest")
    let fullOptions =  ["clientId": "someclient",
                        "secret": "somesecret",
                        "tenantId": "sometenant",
                        "oauthServerUrl": "someurl",
                        "redirectUri": "http://someredirect",
                        "profilesUrl": "https://someUrl"]

    var userProfileManager = MockUserProfileManager(options: ["clientId": "someclient",
                                                                                           "secret": "somesecret",
                                                                                           "tenantId": "sometenant",
                                                                                           "oauthServerUrl": "someurl",
                                                                                           "redirectUri": "http://someredirect",
                                                                                           "profilesUrl": "https://someUrl"])
    var expectation:XCTestExpectation?


    func setOnFailure(expectation: XCTestExpectation? = nil, error: Swift.Error? = nil,_ expectedMsg: String = "") {
        if let fulfillExpectation = expectation {
            XCTAssert(error.debugDescription.range(of: expectedMsg) != nil)
            fulfillExpectation.fulfill()
        } else {
            XCTFail()
        }

    }

    func setOnSuccess(expectation:XCTestExpectation? = nil, body:[String:Any] = [:],_ expectedMsg: String = "") {
        if let fulfillExpectation = expectation {
            XCTAssert(body.description.range(of: expectedMsg) != nil)
            fulfillExpectation.fulfill()
        } else {
            XCTFail()
        }

    }


    func testInit() {

        // check failure - profileUrl was not provided neither trought VCAP nor options
        XCTAssertNil(MockUserProfileManager(options: [:]).serviceConfig["profilesUrl"])

        // check success - profileUrl was provided trought VCAP
        unsetenv("VCAP_SERVICES")
        unsetenv("VCAP_APPLICATION")
        setenv("VCAP_SERVICES", "{\n  \"AdvancedMobileAccess\": [\n    {\n      \"credentials\": {\n        \"clientId\": \"vcapclient\",\n        \"secret\": \"vcapsecret\",\n        \"tenantId\": \"vcaptenant\",\n        \"oauthServerUrl\": \"vcapserver\",\n \"profilesUrl\": \"vcapprofile\"\n     }\n    }\n  ]\n}", 1)
        userProfileManager = MockUserProfileManager(options: [:])
        XCTAssertNotNil(userProfileManager.serviceConfig["profilesUrl"])

        // check success - profileUrl was provided trought options
        XCTAssertNotNil(MockUserProfileManager(options: fullOptions).serviceConfig["profilesUrl"])
    }

    func testSetAttribute() {

        // expired accessToken - should fail "Unexpected error"
        userProfileManager.setAttribute(accessToken : AccessTokenFailure, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"), error: error, "Unexpected error")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userProfileManager.setAttribute(accessToken : AccessTokenStatusCode401, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Unauthorized 403"
        userProfileManager.setAttribute(accessToken : AccessTokenStatusCode403, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Not found 404"
        userProfileManager.setAttribute(accessToken : AccessTokenStatusCode404, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: error, "Not found")
            } else {
                self.setOnSuccess()
            }
        })

        // valid accessToken - should succeed and return the body
        userProfileManager.setAttribute(accessToken : AccessTokenSuccess, attributeName : "name", attributeValue : "abc", completionHandler : { (err, res) in
            if let response = res {
                self.setOnSuccess(expectation: self.expectation(description: "body"), body: response, "body")
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
        userProfileManager.getAttribute(accessToken : AccessTokenFailure, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"), error: error, "Unexpected error")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userProfileManager.getAttribute(accessToken : AccessTokenStatusCode401, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Unauthorized 403"
        userProfileManager.getAttribute(accessToken : AccessTokenStatusCode403, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Not found 404"
        userProfileManager.getAttribute(accessToken : AccessTokenStatusCode404, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: error, "Not found")
            } else {
                self.setOnSuccess()
            }
        })

        // valid accessToken - should succeed and return the body
        userProfileManager.getAttribute(accessToken : AccessTokenSuccess, attributeName : "name", completionHandler : { (err, res) in
            if let response = res {
                self.setOnSuccess(expectation: self.expectation(description: "body"), body: response, "body")
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
        userProfileManager.deleteAttribute(accessToken : AccessTokenFailure, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"), error: error, "Unexpected error")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userProfileManager.deleteAttribute(accessToken : AccessTokenStatusCode401, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }

        })

        // expired accessToken - should fail "Unauthorized 403"
        userProfileManager.deleteAttribute(accessToken : AccessTokenStatusCode403, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Not found 404"
        userProfileManager.deleteAttribute(accessToken : AccessTokenStatusCode404, attributeName : "name", completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: error, "Not found")
            } else {
                self.setOnSuccess()
            }
        })

        // valid accessToken - should succeed and return the body
        userProfileManager.deleteAttribute(accessToken : AccessTokenSuccess, attributeName : "name", completionHandler : { (err, res) in
            if let response = res {
                self.setOnSuccess(expectation: self.expectation(description: "body"), body: response, "body")
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
        userProfileManager.getAllAttributes(accessToken : AccessTokenFailure, completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unexpected error"), error: error, "Unexpected error")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Unauthorized 401"
        userProfileManager.getAllAttributes(accessToken : AccessTokenStatusCode401, completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Unauthorized 403"
        userProfileManager.getAllAttributes(accessToken : AccessTokenStatusCode403, completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Unauthorized"), error: error, "Unauthorized")
            } else {
                self.setOnSuccess()
            }
        })

        // expired accessToken - should fail "Not found 404"
        userProfileManager.getAllAttributes(accessToken : AccessTokenStatusCode404, completionHandler : { (err, res) in
            if let error = err {
                self.setOnFailure(expectation: self.expectation(description: "Not found"), error: error, "Not found")
            } else {
                self.setOnSuccess()
            }
        })

        // valid accessToken - should succeed and return the body
        userProfileManager.getAllAttributes(accessToken : AccessTokenSuccess, completionHandler : { (err, res) in
            if let response = res {
                self.setOnSuccess(expectation: self.expectation(description: "body"), body: response, "body")
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

    func testUserInfoHappyFlow() {
        userProfileManager.getUserInfo(accessToken: AccessTokenSuccess,
                                    identityToken: nil,
                                    completionHandler: successHandler("body"))
        awaitExpectation()
    }

    func testUserInfoHappyFlowSubjectMatching() {
        userProfileManager.getUserInfo(accessToken: AccessTokenSuccess,
                                    identityToken: IdentityTokenSubject123,
                                    completionHandler: successHandler("subject123"))
        awaitExpectation()
    }

    func testUserInfo401() {
        userProfileManager.getUserInfo(accessToken: AccessTokenStatusCode401,
                                    identityToken: nil,
                                    completionHandler: errorHandler("Unauthorized"))
        awaitExpectation()
    }

    func testUserInfo403() {
        userProfileManager.getUserInfo(accessToken: AccessTokenStatusCode403,
                                    identityToken: nil,
                                    completionHandler: errorHandler("Unauthorized"))
        awaitExpectation()
    }

    func testUserInfo404() {
        userProfileManager.getUserInfo(accessToken: AccessTokenStatusCode404,
                                    identityToken: nil,
                                    completionHandler: errorHandler("Not found"))
        awaitExpectation()
    }

    func testUserInfoInvalidIdentityToken() {
        userProfileManager.getUserInfo(accessToken: AccessTokenSuccess,
                                    identityToken: "invalid token",
                                    completionHandler: errorHandler("UserProfileError.invalidIdentityToken"))
        awaitExpectation()
    }

    func testUserInfoSubjectMismatch() {
        userProfileManager.getUserInfo(accessToken: UserProfileManagerTests.AccessTokenSuccessMismatchedSubjects,
                                    identityToken: IdentityTokenSubject123,
                                    completionHandler: errorHandler("UserProfileError.conflictingSubjects"))
        awaitExpectation()
    }


    func successHandler(_ expectedBody: String) -> (Swift.Error?, [String: Any]?) -> Void {
        let expectation = self.expectation(description: expectedBody)
        return { (err: Swift.Error?, res: [String: Any]?) in
            if let response = res {
                self.setOnSuccess(expectation: expectation, body: response, expectedBody)
            } else {
                self.setOnFailure()
            }
        }
    }

    func errorHandler(_ expectedMsg: String) -> (Swift.Error?, [String: Any]?) -> Void {
        let expectation = self.expectation(description: expectedMsg)
        return { (err: Swift.Error?, body: [String: Any]?) in
            if let error = err {
                self.setOnFailure(expectation: expectation, error: error, expectedMsg)
            } else {
                self.setOnSuccess()
            }
        }
    }

    func awaitExpectation() {
        waitForExpectations(timeout: 1) { error in
            if let error = error {
                XCTFail("err: \(error)")
            }
        }
    }
    
}
