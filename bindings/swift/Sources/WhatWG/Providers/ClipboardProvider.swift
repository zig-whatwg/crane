import Foundation

/// Protocol for providing clipboard functionality.
///
/// Implement this protocol to provide clipboard access to the WHATWG platform.
///
/// ## Example Implementation
///
/// ```swift
/// #if os(iOS)
/// import UIKit
///
/// class iOSClipboardProvider: ClipboardProvider {
///     func readText() async throws -> String? {
///         return UIPasteboard.general.string
///     }
///
///     func writeText(_ text: String) async throws {
///         UIPasteboard.general.string = text
///     }
/// }
/// #endif
/// ```
///
public protocol ClipboardProvider: AnyObject, Sendable {
    
    /// Reads text from the clipboard.
    ///
    /// - Returns: The clipboard text, or `nil` if empty.
    /// - Throws: If the operation fails or is denied.
    func readText() async throws -> String?
    
    /// Writes text to the clipboard.
    ///
    /// - Parameter text: The text to write.
    /// - Throws: If the operation fails or is denied.
    func writeText(_ text: String) async throws
    
    /// Reads arbitrary data from the clipboard.
    ///
    /// - Parameter type: The MIME type to read.
    /// - Returns: The clipboard data, or `nil` if not available.
    /// - Throws: If the operation fails or is denied.
    func read(type: String) async throws -> Data?
    
    /// Writes arbitrary data to the clipboard.
    ///
    /// - Parameters:
    ///   - data: The data to write.
    ///   - type: The MIME type of the data.
    /// - Throws: If the operation fails or is denied.
    func write(data: Data, type: String) async throws
    
    /// Checks if the clipboard can be read.
    ///
    /// - Returns: `true` if reading is permitted.
    func canRead() -> Bool
    
    /// Checks if the clipboard can be written.
    ///
    /// - Returns: `true` if writing is permitted.
    func canWrite() -> Bool
}

// MARK: - Default Implementations

public extension ClipboardProvider {
    
    func read(type: String) async throws -> Data? {
        // Default: only text is supported
        guard type == "text/plain" else { return nil }
        return try await readText()?.data(using: .utf8)
    }
    
    func write(data: Data, type: String) async throws {
        // Default: only text is supported
        guard type == "text/plain",
              let text = String(data: data, encoding: .utf8) else {
            throw WhatWGError.operationFailed("Unsupported clipboard type: \(type)")
        }
        try await writeText(text)
    }
    
    func canRead() -> Bool { true }
    func canWrite() -> Bool { true }
}
