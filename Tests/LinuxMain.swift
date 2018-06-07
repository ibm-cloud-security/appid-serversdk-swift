import XCTest
@testable import IBMCloudAppIDTests

XCTMain([
     testCase(IBMCloudAppIDTests.allTests),
     testCase(UserProfileManagerTests.allTests),
     testCase(UtilsTest.allTests),
     testCase(WebAppPluginTest.allTests),
     testCase(ApiPluginTests.allTests),
     testCase(AppIDPluginConfigTests.allTests)
])
