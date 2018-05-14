import XCTest
@testable import BluemixAppIDTests

XCTMain([
     testCase(BluemixAppIDTests.allTests),
     testCase(UserProfileManagerTest.allTests),
     testCase(UtilsTest.allTests),
     testCase(WebAppPluginTest.allTests),
     testCase(ApiPluginTest.allTests)
])
