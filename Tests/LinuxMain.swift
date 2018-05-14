import XCTest
@testable import BluemixAppIDTests

XCTMain([
     testCase(BluemixAppIDTests.allTests),
     testCase(UserProfileManagerTests.allTests),
     testCase(UtilsTest.allTests),
     testCase(WebAppPluginTest.allTests),
     testCase(ApiPluginTest.allTests)
])
