import XCTest
@testable import WhatWG

final class WhatWGTests: XCTestCase {
    
    // MARK: - Platform Tests
    
    func testPlatformCreation() {
        let platform = WhatWGPlatform()
        XCTAssertNotNil(platform)
    }
    
    func testVersionString() {
        let version = WhatWGPlatform.version
        XCTAssertFalse(version.isEmpty)
    }
    
    func testABIVersion() {
        let version = WhatWGPlatform.abiVersion
        XCTAssertGreaterThan(version, 0)
    }
    
    // MARK: - Capability Tests
    
    func testCapabilityEnumValues() {
        XCTAssertEqual(Capability.clipboard.rawValue, 0)
        XCTAssertEqual(Capability.timer.rawValue, 1)
        XCTAssertEqual(Capability.network.rawValue, 2)
        XCTAssertEqual(Capability.storage.rawValue, 3)
    }
    
    func testAllCapabilities() {
        XCTAssertEqual(Capability.allCases.count, 31)
    }
    
    // MARK: - JSEngine Tests
    
    func testJSEngineRecommended() {
        let recommended = JSEngine.recommended
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        XCTAssertEqual(recommended, .javaScriptCore)
        #else
        XCTAssertEqual(recommended, .quickJS)
        #endif
    }
    
    func testJSEngineDisplayNames() {
        XCTAssertEqual(JSEngine.javaScriptCore.displayName, "JavaScriptCore")
        XCTAssertEqual(JSEngine.v8.displayName, "V8")
        XCTAssertEqual(JSEngine.quickJS.displayName, "QuickJS")
    }
    
    // MARK: - Error Tests
    
    func testErrorDescriptions() {
        XCTAssertNotNil(WhatWGError.initializationFailed.errorDescription)
        XCTAssertNotNil(WhatWGError.contextCreationFailed.errorDescription)
        XCTAssertNotNil(WhatWGError.notInitialized.errorDescription)
        XCTAssertNotNil(WhatWGError.capabilityNotAvailable(.clipboard).errorDescription)
        XCTAssertNotNil(WhatWGError.operationFailed("test").errorDescription)
    }
}
