#if os(iOS) || os(macOS)
import XCTest
@testable import WhatWG

/// Tests for NavigationState and related types.
@available(iOS 14.0, macOS 11.0, *)
final class NavigationStateTests: XCTestCase {
    
    // MARK: - NavigationState Tests
    
    func testEmptyState() {
        let state = NavigationState.empty
        
        XCTAssertNil(state.url)
        XCTAssertTrue(state.title.isEmpty)
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.loadingProgress, 0.0)
        XCTAssertFalse(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
        XCTAssertFalse(state.isSecure)
        XCTAssertNil(state.faviconURL)
    }
    
    func testStateWithURL() {
        let url = URL(string: "https://example.com")!
        let state = NavigationState(
            url: url,
            title: "Example",
            isLoading: false,
            loadingProgress: 1.0,
            canGoBack: true,
            canGoForward: false,
            isSecure: true,
            faviconURL: nil
        )
        
        XCTAssertEqual(state.url, url)
        XCTAssertEqual(state.title, "Example")
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.loadingProgress, 1.0)
        XCTAssertTrue(state.canGoBack)
        XCTAssertFalse(state.canGoForward)
        XCTAssertTrue(state.isSecure)
    }
    
    func testStateEquality() {
        let url = URL(string: "https://example.com")!
        let state1 = NavigationState(
            url: url,
            title: "Test",
            isLoading: false,
            loadingProgress: 1.0,
            canGoBack: false,
            canGoForward: false,
            isSecure: true,
            faviconURL: nil
        )
        let state2 = NavigationState(
            url: url,
            title: "Test",
            isLoading: false,
            loadingProgress: 1.0,
            canGoBack: false,
            canGoForward: false,
            isSecure: true,
            faviconURL: nil
        )
        
        XCTAssertEqual(state1, state2)
    }
    
    // MARK: - BrowserTab Tests
    
    func testBrowserTabCreation() {
        let tab = BrowserTab()
        
        XCTAssertNotNil(tab.id)
        XCTAssertFalse(tab.isActive)
        XCTAssertEqual(tab.state, .empty)
    }
    
    func testBrowserTabActive() {
        let tab = BrowserTab(isActive: true)
        XCTAssertTrue(tab.isActive)
    }
    
    func testBrowserTabUniqueness() {
        let tab1 = BrowserTab()
        let tab2 = BrowserTab()
        
        XCTAssertNotEqual(tab1.id, tab2.id)
    }
    
    // MARK: - HistoryEntry Tests
    
    func testHistoryEntryCreation() {
        let url = URL(string: "https://example.com")!
        let entry = HistoryEntry(url: url, title: "Example")
        
        XCTAssertEqual(entry.url, url)
        XCTAssertEqual(entry.title, "Example")
        XCTAssertNotNil(entry.visitedAt)
    }
    
    func testHistoryEntryWithDate() {
        let url = URL(string: "https://example.com")!
        let date = Date(timeIntervalSince1970: 1000)
        let entry = HistoryEntry(url: url, title: "Example", visitedAt: date)
        
        XCTAssertEqual(entry.visitedAt, date)
    }
    
    // MARK: - BrowserError Tests
    
    func testInvalidURLError() {
        let error = BrowserError.invalidURL("not a url")
        
        switch error {
        case .invalidURL(let url):
            XCTAssertEqual(url, "not a url")
        default:
            XCTFail("Wrong error type")
        }
    }
    
    func testNetworkError() {
        let error = BrowserError.networkError("Connection failed")
        
        switch error {
        case .networkError(let message):
            XCTAssertEqual(message, "Connection failed")
        default:
            XCTFail("Wrong error type")
        }
    }
    
    func testScriptError() {
        let error = BrowserError.scriptError(
            message: "Syntax error",
            line: 10,
            column: 5
        )
        
        switch error {
        case .scriptError(let message, let line, let column):
            XCTAssertEqual(message, "Syntax error")
            XCTAssertEqual(line, 10)
            XCTAssertEqual(column, 5)
        default:
            XCTFail("Wrong error type")
        }
    }
    
    func testTimeoutError() {
        let error = BrowserError.timeout
        
        switch error {
        case .timeout:
            break // Success
        default:
            XCTFail("Wrong error type")
        }
    }
    
    func testCancelledError() {
        let error = BrowserError.cancelled
        
        switch error {
        case .cancelled:
            break // Success
        default:
            XCTFail("Wrong error type")
        }
    }
    
    func testEngineNotAvailableError() {
        let error = BrowserError.engineNotAvailable
        
        switch error {
        case .engineNotAvailable:
            break // Success
        default:
            XCTFail("Wrong error type")
        }
    }
    
    // MARK: - NavigationEvent Tests
    
    func testNavigationEventStarted() {
        let url = URL(string: "https://example.com")!
        let event = NavigationEvent.started(url)
        
        if case .started(let eventUrl) = event {
            XCTAssertEqual(eventUrl, url)
        } else {
            XCTFail("Wrong event type")
        }
    }
    
    func testNavigationEventFinished() {
        let url = URL(string: "https://example.com")!
        let event = NavigationEvent.finished(url)
        
        if case .finished(let eventUrl) = event {
            XCTAssertEqual(eventUrl, url)
        } else {
            XCTFail("Wrong event type")
        }
    }
    
    func testNavigationEventFailed() {
        let error = BrowserError.timeout
        let event = NavigationEvent.failed(error)
        
        if case .failed(let eventError) = event {
            if case .timeout = eventError {
                // Success
            } else {
                XCTFail("Wrong error in event")
            }
        } else {
            XCTFail("Wrong event type")
        }
    }
    
    // MARK: - ConsoleMessage Tests
    
    func testConsoleMessageCreation() {
        let message = ConsoleMessage(
            level: .log,
            text: "Test message",
            source: "test.js",
            line: 42
        )
        
        XCTAssertEqual(message.level, .log)
        XCTAssertEqual(message.text, "Test message")
        XCTAssertEqual(message.source, "test.js")
        XCTAssertEqual(message.line, 42)
    }
    
    func testConsoleMessageLevels() {
        XCTAssertEqual(ConsoleMessage.Level.log.rawValue, "log")
        XCTAssertEqual(ConsoleMessage.Level.info.rawValue, "info")
        XCTAssertEqual(ConsoleMessage.Level.warn.rawValue, "warn")
        XCTAssertEqual(ConsoleMessage.Level.error.rawValue, "error")
        XCTAssertEqual(ConsoleMessage.Level.debug.rawValue, "debug")
    }
}
#endif
