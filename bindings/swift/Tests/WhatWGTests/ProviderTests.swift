#if os(iOS) || os(macOS)
import XCTest
@testable import WhatWG

/// Tests for capability provider implementations.
@available(iOS 14.0, macOS 11.0, *)
final class ProviderTests: XCTestCase {
    
    // MARK: - Clipboard Provider Tests
    
    func testClipboardProviderCreation() {
        let provider = iOSClipboardProvider()
        XCTAssertNotNil(provider)
    }
    
    func testClipboardWriteAndRead() async throws {
        let provider = iOSClipboardProvider()
        
        let testText = "Test clipboard content \(UUID().uuidString)"
        try await provider.writeText(testText)
        
        let readText = try await provider.readText()
        XCTAssertEqual(readText, testText)
    }
    
    func testClipboardReadEmpty() async throws {
        let provider = iOSClipboardProvider()
        // Clear clipboard first
        try await provider.writeText("")
        
        let text = try await provider.readText()
        // Empty string or nil are both acceptable
        XCTAssertTrue(text == nil || text?.isEmpty == true)
    }
    
    // MARK: - Timer Provider Tests
    
    func testTimerProviderCreation() {
        let provider = iOSTimerProvider()
        XCTAssertNotNil(provider)
    }
    
    func testSetTimeout() async throws {
        let provider = iOSTimerProvider()
        let expectation = XCTestExpectation(description: "Timeout fired")
        
        _ = provider.setTimeout(delay: 100) {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testClearTimeout() async throws {
        let provider = iOSTimerProvider()
        var fired = false
        
        let id = provider.setTimeout(delay: 100) {
            fired = true
        }
        
        provider.clearTimeout(id: id)
        
        // Wait longer than the timeout
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(fired, "Timeout should have been cancelled")
    }
    
    func testSetInterval() async throws {
        let provider = iOSTimerProvider()
        var fireCount = 0
        
        let id = provider.setInterval(delay: 50) {
            fireCount += 1
        }
        
        // Wait for multiple fires
        try await Task.sleep(nanoseconds: 200_000_000)
        
        provider.clearInterval(id: id)
        
        XCTAssertGreaterThan(fireCount, 1, "Interval should fire multiple times")
    }
    
    func testClearInterval() async throws {
        let provider = iOSTimerProvider()
        var fireCount = 0
        
        let id = provider.setInterval(delay: 50) {
            fireCount += 1
        }
        
        // Let it fire once
        try await Task.sleep(nanoseconds: 75_000_000)
        provider.clearInterval(id: id)
        
        let countAfterClear = fireCount
        
        // Wait and verify no more fires
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(fireCount, countAfterClear, "No more fires after clear")
    }
    
    // MARK: - Network Provider Tests
    
    func testNetworkProviderCreation() {
        let provider = iOSNetworkProvider()
        XCTAssertNotNil(provider)
    }
    
    func testNetworkFetch() async throws {
        let provider = iOSNetworkProvider()
        
        // Use a reliable test endpoint
        let request = NetworkRequest(
            url: URL(string: "https://httpbin.org/get")!,
            method: "GET",
            headers: [:]
        )
        
        let response = try await provider.fetch(request)
        XCTAssertEqual(response.status, 200)
    }
    
    func testNetworkFetchWithHeaders() async throws {
        let provider = iOSNetworkProvider()
        
        let request = NetworkRequest(
            url: URL(string: "https://httpbin.org/headers")!,
            method: "GET",
            headers: ["X-Custom-Header": "test-value"]
        )
        
        let response = try await provider.fetch(request)
        XCTAssertEqual(response.status, 200)
    }
    
    func testNetworkPostRequest() async throws {
        let provider = iOSNetworkProvider()
        
        let body = "test=data".data(using: .utf8)!
        let request = NetworkRequest(
            url: URL(string: "https://httpbin.org/post")!,
            method: "POST",
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: body
        )
        
        let response = try await provider.fetch(request)
        XCTAssertEqual(response.status, 200)
    }
    
    func testNetworkConnectivityCheck() async {
        let provider = iOSNetworkProvider()
        let isConnected = await provider.isConnected()
        // Just verify it returns a value without crashing
        _ = isConnected
    }
    
    // MARK: - Storage Provider Tests
    
    func testStorageProviderCreation() {
        let provider = iOSStorageProvider()
        XCTAssertNotNil(provider)
    }
    
    func testStorageSetAndGet() async throws {
        let provider = iOSStorageProvider()
        let key = "test_key_\(UUID().uuidString)"
        let value = "test_value_\(UUID().uuidString)"
        
        try await provider.setItem(key: key, value: value)
        let retrieved = try await provider.getItem(key: key)
        
        XCTAssertEqual(retrieved, value)
        
        // Cleanup
        try await provider.removeItem(key: key)
    }
    
    func testStorageGetNonExistent() async throws {
        let provider = iOSStorageProvider()
        let key = "non_existent_key_\(UUID().uuidString)"
        
        let value = try await provider.getItem(key: key)
        XCTAssertNil(value)
    }
    
    func testStorageRemoveItem() async throws {
        let provider = iOSStorageProvider()
        let key = "test_remove_\(UUID().uuidString)"
        
        try await provider.setItem(key: key, value: "value")
        try await provider.removeItem(key: key)
        
        let value = try await provider.getItem(key: key)
        XCTAssertNil(value)
    }
    
    func testStorageClear() async throws {
        let provider = iOSStorageProvider()
        let prefix = "clear_test_\(UUID().uuidString)_"
        
        // Set multiple items
        try await provider.setItem(key: "\(prefix)1", value: "v1")
        try await provider.setItem(key: "\(prefix)2", value: "v2")
        
        try await provider.clear()
        
        // Note: clear() clears ALL storage, not just our test items
        // Verify at least one is gone
        let v1 = try await provider.getItem(key: "\(prefix)1")
        XCTAssertNil(v1)
    }
    
    // MARK: - Geolocation Provider Tests
    
    func testGeolocationProviderCreation() {
        let provider = iOSGeolocationProvider()
        XCTAssertNotNil(provider)
    }
    
    // Note: Actual geolocation tests require permissions and device/simulator
    // location services, so we just test creation and error handling
    
    // MARK: - Notification Provider Tests
    
    func testNotificationProviderCreation() {
        let provider = iOSNotificationProvider()
        XCTAssertNotNil(provider)
    }
    
    // Note: Notification tests require permissions
    
    // MARK: - UI Provider Tests
    
    func testUIProviderCreation() {
        let provider = iOSUIProvider()
        XCTAssertNotNil(provider)
    }
    
    // Note: UI tests would require UI hosting
    
    // MARK: - File System Provider Tests
    
    func testFileSystemProviderCreation() {
        let provider = iOSFileSystemProvider()
        XCTAssertNotNil(provider)
    }
    
    func testFileSystemWriteAndRead() async throws {
        let provider = iOSFileSystemProvider()
        let filename = "test_\(UUID().uuidString).txt"
        let content = "Test file content"
        
        // Write file
        try await provider.writeFile(
            path: filename,
            data: content.data(using: .utf8)!
        )
        
        // Read file
        let data = try await provider.readFile(path: filename)
        let readContent = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(readContent, content)
        
        // Cleanup
        try await provider.deleteFile(path: filename)
    }
    
    func testFileSystemDeleteFile() async throws {
        let provider = iOSFileSystemProvider()
        let filename = "test_delete_\(UUID().uuidString).txt"
        
        // Create file
        try await provider.writeFile(
            path: filename,
            data: "test".data(using: .utf8)!
        )
        
        // Delete file
        try await provider.deleteFile(path: filename)
        
        // Verify deleted - reading should throw
        do {
            _ = try await provider.readFile(path: filename)
            XCTFail("Should have thrown error for deleted file")
        } catch {
            // Expected
        }
    }
    
    func testFileSystemFileExists() async throws {
        let provider = iOSFileSystemProvider()
        let filename = "test_exists_\(UUID().uuidString).txt"
        
        // Should not exist initially
        var exists = try await provider.fileExists(path: filename)
        XCTAssertFalse(exists)
        
        // Create file
        try await provider.writeFile(
            path: filename,
            data: "test".data(using: .utf8)!
        )
        
        // Should exist now
        exists = try await provider.fileExists(path: filename)
        XCTAssertTrue(exists)
        
        // Cleanup
        try await provider.deleteFile(path: filename)
    }
}
#endif
