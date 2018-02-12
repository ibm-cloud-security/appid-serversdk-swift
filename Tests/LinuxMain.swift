import XCTest
@testable import BluemixAppIDTests

XCTMain([
     testCase(BluemixAppIDTests.allTests),
     // The following tests fail on linux due to the bug raised here:
     // https://bugs.swift.org/browse/SR-6968
     // Once this bug is fixed the following can be re-enabled
     // testCase(UserAttributesManagerTest.allTests),
     // testCase(UtilsTest.allTests),
     // testCase(WebAppPluginTest.allTests),
])
