import XCTest
@testable import BluemixAppIDTests

XCTMain([
     testCase(BluemixAppIDTests.allTests),
     testCase(UserAttributesManagerTest.allTests),
     testCase(UtilsTest.allTests),
     testCase(WebAppPluginTest.allTests),
     testCase(ApiPluginTest.allTests)
])
