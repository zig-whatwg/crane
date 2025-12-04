import XCTest
@testable import WhatWG

/// Tests for WhatWGPlatform initialization and configuration.
final class PlatformTests: XCTestCase {
    
    // MARK: - Initialization
    
    func testPlatformCreation() {
        let platform = WhatWGPlatform()
        XCTAssertNotNil(platform)
    }
    
    func testPlatformWithCustomEngine() {
        let platform = WhatWGPlatform()
        platform.engine = .quickJS
        XCTAssertEqual(platform.engine, .quickJS)
    }
    
    func testDefaultEngine() {
        let platform = WhatWGPlatform()
        // Default should be JSC on Apple platforms
        #if os(iOS) || os(macOS)
        XCTAssertEqual(platform.engine, .javaScriptCore)
        #endif
    }
    
    // MARK: - Version Info
    
    func testVersionString() {
        let version = WhatWGPlatform.version
        XCTAssertFalse(version.isEmpty, "Version string should not be empty")
    }
    
    func testABIVersion() {
        let version = WhatWGPlatform.abiVersion
        XCTAssertGreaterThan(version, 0, "ABI version should be positive")
    }
    
    // MARK: - Capability Configuration
    
    func testCapabilityEnumValues() {
        XCTAssertEqual(Capability.clipboard.rawValue, 0)
        XCTAssertEqual(Capability.timer.rawValue, 1)
        XCTAssertEqual(Capability.network.rawValue, 2)
        XCTAssertEqual(Capability.storage.rawValue, 3)
        XCTAssertEqual(Capability.layout.rawValue, 4)
        XCTAssertEqual(Capability.ui.rawValue, 5)
    }
    
    func testAllCapabilitiesCount() {
        XCTAssertEqual(Capability.allCases.count, 31)
    }
    
    func testCapabilityDisplayNames() {
        XCTAssertEqual(Capability.clipboard.displayName, "Clipboard")
        XCTAssertEqual(Capability.network.displayName, "Network")
        XCTAssertEqual(Capability.storage.displayName, "Storage")
        XCTAssertEqual(Capability.geolocation.displayName, "Geolocation")
    }
    
    // MARK: - Provider Configuration
    
    #if os(iOS) || os(macOS)
    func testSetClipboardProvider() {
        let platform = WhatWGPlatform()
        let provider = iOSClipboardProvider()
        platform.clipboardProvider = provider
        XCTAssertNotNil(platform.clipboardProvider)
    }
    
    func testSetTimerProvider() {
        let platform = WhatWGPlatform()
        let provider = iOSTimerProvider()
        platform.timerProvider = provider
        XCTAssertNotNil(platform.timerProvider)
    }
    
    func testSetNetworkProvider() {
        let platform = WhatWGPlatform()
        let provider = iOSNetworkProvider()
        platform.networkProvider = provider
        XCTAssertNotNil(platform.networkProvider)
    }
    
    func testSetStorageProvider() {
        let platform = WhatWGPlatform()
        let provider = iOSStorageProvider()
        platform.storageProvider = provider
        XCTAssertNotNil(platform.storageProvider)
    }
    
    func testSetMultipleProviders() {
        let platform = WhatWGPlatform()
        platform.clipboardProvider = iOSClipboardProvider()
        platform.timerProvider = iOSTimerProvider()
        platform.networkProvider = iOSNetworkProvider()
        platform.storageProvider = iOSStorageProvider()
        
        XCTAssertNotNil(platform.clipboardProvider)
        XCTAssertNotNil(platform.timerProvider)
        XCTAssertNotNil(platform.networkProvider)
        XCTAssertNotNil(platform.storageProvider)
    }
    #endif
    
    // MARK: - JS Engine Tests
    
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
    
    func testJSEngineAvailability() {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        XCTAssertTrue(JSEngine.javaScriptCore.isAvailable)
        #endif
        XCTAssertTrue(JSEngine.quickJS.isAvailable)
    }
    
    // MARK: - Error Tests
    
    func testErrorDescriptions() {
        XCTAssertNotNil(WhatWGError.initializationFailed.errorDescription)
        XCTAssertNotNil(WhatWGError.contextCreationFailed.errorDescription)
        XCTAssertNotNil(WhatWGError.notInitialized.errorDescription)
        XCTAssertNotNil(WhatWGError.capabilityNotAvailable(.clipboard).errorDescription)
        XCTAssertNotNil(WhatWGError.operationFailed("test").errorDescription)
    }
    
    func testErrorEquality() {
        XCTAssertEqual(
            WhatWGError.capabilityNotAvailable(.clipboard),
            WhatWGError.capabilityNotAvailable(.clipboard)
        )
        XCTAssertNotEqual(
            WhatWGError.capabilityNotAvailable(.clipboard),
            WhatWGError.capabilityNotAvailable(.network)
        )
    }
}
