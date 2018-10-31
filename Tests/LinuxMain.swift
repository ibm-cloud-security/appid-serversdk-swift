import XCTest
@testable import IBMCloudAppIDTests

#if swift(>=4.1)
XCTMain([
     testCase(IBMCloudAppIDTests.allTests),
     testCase(UtilsTest.allTests),
     testCase(WebAppPluginTest.allTests),
     // The following tests fail on linux 4.0 due to the bug raised here:
     // https://bugs.swift.org/browse/SR-6968
     // This has been fixed in versions 4.1 onwards.
     testCase(AppIDPluginConfigTests.allTests),
     testCase(UserProfileManagerTests.allTests),
     testCase(ApiPluginTests.allTests),
])
#else
XCTMain([
     testCase(IBMCloudAppIDTests.allTests),
     testCase(UtilsTest.allTests),
     testCase(WebAppPluginTest.allTests),
])
#endif
