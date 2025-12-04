#if os(iOS) || os(macOS)
import XCTest
@testable import WhatWG

/// Tests for WhatWGBrowser SwiftUI component.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
final class BrowserTests: XCTestCase {
    
    // MARK: - Initialization
    
    func testBrowserCreation() {
        let browser = WhatWGBrowser()
        XCTAssertNotNil(browser)
    }
    
    func testBrowserWithCustomPlatform() {
        let platform = WhatWGPlatform()
        let browser = WhatWGBrowser(platform: platform)
        XCTAssertNotNil(browser)
    }
    
    func testInitialState() {
        let browser = WhatWGBrowser()
        
        XCTAssertTrue(browser.urlString.isEmpty)
        XCTAssertTrue(browser.title.isEmpty)
        XCTAssertFalse(browser.isLoading)
        XCTAssertEqual(browser.loadingProgress, 0.0)
        XCTAssertFalse(browser.canGoBack)
        XCTAssertFalse(browser.canGoForward)
        XCTAssertFalse(browser.isSecure)
        XCTAssertNil(browser.lastError)
    }
    
    // MARK: - Tab Management
    
    func testInitialTab() {
        let browser = WhatWGBrowser()
        XCTAssertEqual(browser.tabs.count, 1)
        XCTAssertEqual(browser.activeTabIndex, 0)
    }
    
    func testNewTab() {
        let browser = WhatWGBrowser()
        let tabId = browser.newTab()
        
        XCTAssertEqual(browser.tabs.count, 2)
        XCTAssertEqual(browser.activeTabIndex, 1)
        XCTAssertNotNil(browser.tabs.first(where: { $0.id == tabId }))
    }
    
    func testNewTabInactive() {
        let browser = WhatWGBrowser()
        _ = browser.newTab(makeActive: false)
        
        XCTAssertEqual(browser.tabs.count, 2)
        XCTAssertEqual(browser.activeTabIndex, 0, "Active tab should remain unchanged")
    }
    
    func testCloseTab() {
        let browser = WhatWGBrowser()
        let tab1 = browser.tabs[0].id
        let tab2 = browser.newTab()
        
        browser.closeTab(tab2)
        
        XCTAssertEqual(browser.tabs.count, 1)
        XCTAssertEqual(browser.tabs[0].id, tab1)
    }
    
    func testCloseLastTab() {
        let browser = WhatWGBrowser()
        let originalId = browser.tabs[0].id
        browser.closeTab(originalId)
        
        // Should create a new tab when closing the last one
        XCTAssertEqual(browser.tabs.count, 1)
        XCTAssertNotEqual(browser.tabs[0].id, originalId)
    }
    
    func testSwitchToTab() {
        let browser = WhatWGBrowser()
        let tab1 = browser.tabs[0].id
        _ = browser.newTab()
        
        XCTAssertEqual(browser.activeTabIndex, 1)
        
        browser.switchToTab(tab1)
        XCTAssertEqual(browser.activeTabIndex, 0)
    }
    
    // MARK: - Navigation
    
    func testLoadURLWithString() async {
        let browser = WhatWGBrowser()
        browser.urlString = "https://example.com"
        browser.loadURL()
        
        XCTAssertTrue(browser.isLoading)
        XCTAssertEqual(browser.urlString, "https://example.com")
    }
    
    func testLoadURLAddsScheme() {
        let browser = WhatWGBrowser()
        browser.urlString = "example.com"
        browser.loadURL()
        
        XCTAssertEqual(browser.urlString, "https://example.com")
    }
    
    func testLoadURLWithURL() async {
        let browser = WhatWGBrowser()
        let url = URL(string: "https://example.com/path")!
        browser.loadURL(url)
        
        XCTAssertTrue(browser.isLoading)
        XCTAssertEqual(browser.urlString, "https://example.com/path")
    }
    
    func testInvalidURL() {
        let browser = WhatWGBrowser()
        browser.urlString = "not a valid url :::"
        browser.loadURL()
        
        XCTAssertNotNil(browser.lastError)
        if case .invalidURL(let url) = browser.lastError {
            XCTAssertEqual(url, "https://not a valid url :::")
        } else {
            XCTFail("Expected invalidURL error")
        }
    }
    
    func testEmptyURLDoesNothing() {
        let browser = WhatWGBrowser()
        browser.urlString = ""
        browser.loadURL()
        
        XCTAssertFalse(browser.isLoading)
        XCTAssertNil(browser.lastError)
    }
    
    func testSecureURL() async throws {
        let browser = WhatWGBrowser()
        let url = URL(string: "https://example.com")!
        browser.loadURL(url)
        
        // Wait for loading to complete
        try await Task.sleep(nanoseconds: 600_000_000)
        
        XCTAssertTrue(browser.isSecure)
    }
    
    func testInsecureURL() async throws {
        let browser = WhatWGBrowser()
        let url = URL(string: "http://example.com")!
        browser.loadURL(url)
        
        // Wait for loading to complete
        try await Task.sleep(nanoseconds: 600_000_000)
        
        XCTAssertFalse(browser.isSecure)
    }
    
    // MARK: - Navigation History
    
    func testGoBack() {
        let browser = WhatWGBrowser()
        
        // Can't go back initially
        XCTAssertFalse(browser.canGoBack)
        browser.goBack() // Should not crash
    }
    
    func testGoForward() {
        let browser = WhatWGBrowser()
        
        // Can't go forward initially
        XCTAssertFalse(browser.canGoForward)
        browser.goForward() // Should not crash
    }
    
    func testReload() async throws {
        let browser = WhatWGBrowser()
        let url = URL(string: "https://example.com")!
        browser.loadURL(url)
        
        // Wait for initial load
        try await Task.sleep(nanoseconds: 600_000_000)
        
        browser.reload()
        XCTAssertTrue(browser.isLoading)
    }
    
    func testStopLoading() {
        let browser = WhatWGBrowser()
        browser.urlString = "https://example.com"
        browser.loadURL()
        
        XCTAssertTrue(browser.isLoading)
        browser.stopLoading()
        XCTAssertFalse(browser.isLoading)
    }
    
    // MARK: - History
    
    func testHistoryAfterNavigation() async throws {
        let browser = WhatWGBrowser()
        let url = URL(string: "https://example.com")!
        browser.loadURL(url)
        
        // Wait for loading to complete
        try await Task.sleep(nanoseconds: 600_000_000)
        
        XCTAssertGreaterThan(browser.history.count, 0)
        XCTAssertEqual(browser.history.last?.url, url)
    }
    
    // MARK: - Navigation Events
    
    func testNavigationEventCallback() async throws {
        let browser = WhatWGBrowser()
        var receivedEvents: [NavigationEvent] = []
        
        browser.onNavigationEvent = { event in
            receivedEvents.append(event)
        }
        
        let url = URL(string: "https://example.com")!
        browser.loadURL(url)
        
        // Wait for loading to complete
        try await Task.sleep(nanoseconds: 600_000_000)
        
        XCTAssertTrue(receivedEvents.contains { event in
            if case .started = event { return true }
            return false
        })
        
        XCTAssertTrue(receivedEvents.contains { event in
            if case .finished = event { return true }
            return false
        })
    }
    
    // MARK: - JavaScript Execution
    
    func testEvaluateJavaScript() async throws {
        let browser = WhatWGBrowser()
        let result = try await browser.evaluateJavaScript("1 + 1")
        // Current implementation returns nil
        XCTAssertNil(result)
    }
    
    // MARK: - Navigation State
    
    func testNavigationState() {
        let browser = WhatWGBrowser()
        
        XCTAssertEqual(browser.navigationState, .empty)
        XCTAssertNil(browser.navigationState.url)
    }
    
    func testNavigationStateAfterLoad() async throws {
        let browser = WhatWGBrowser()
        let url = URL(string: "https://example.com")!
        browser.loadURL(url)
        
        // Wait for loading to complete
        try await Task.sleep(nanoseconds: 600_000_000)
        
        XCTAssertNotNil(browser.navigationState.url)
        XCTAssertEqual(browser.navigationState.url, url)
        XCTAssertFalse(browser.navigationState.isLoading)
    }
}
#endif
