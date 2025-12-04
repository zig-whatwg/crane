#if os(iOS)
import UIKit
import UniformTypeIdentifiers

/// iOS implementation of ClipboardProvider using UIPasteboard.
///
/// This provider uses UIPasteboard.general for clipboard access.
/// Note: iOS restricts clipboard access when the app is not in the foreground.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.clipboardProvider = iOSClipboardProvider()
/// ```
///
@available(iOS 14.0, *)
public final class iOSClipboardProvider: ClipboardProvider, @unchecked Sendable {
    
    private let pasteboard: UIPasteboard
    
    /// Creates a new iOS clipboard provider.
    ///
    /// - Parameter pasteboard: The pasteboard to use. Defaults to `UIPasteboard.general`.
    public init(pasteboard: UIPasteboard = .general) {
        self.pasteboard = pasteboard
    }
    
    // MARK: - ClipboardProvider
    
    public func readText() async throws -> String? {
        return await MainActor.run {
            pasteboard.string
        }
    }
    
    public func writeText(_ text: String) async throws {
        await MainActor.run {
            pasteboard.string = text
        }
    }
    
    public func read(type: String) async throws -> Data? {
        return await MainActor.run {
            switch type {
            case "text/plain":
                return pasteboard.string?.data(using: .utf8)
            case "text/html":
                if let htmlData = pasteboard.data(forPasteboardType: UTType.html.identifier) {
                    return htmlData
                }
                return nil
            case "image/png":
                if let image = pasteboard.image {
                    return image.pngData()
                }
                return nil
            case "image/jpeg":
                if let image = pasteboard.image {
                    return image.jpegData(compressionQuality: 0.9)
                }
                return nil
            default:
                // Try to match by UTI
                if let utType = UTType(mimeType: type) {
                    return pasteboard.data(forPasteboardType: utType.identifier)
                }
                return nil
            }
        }
    }
    
    public func write(data: Data, type: String) async throws {
        await MainActor.run {
            switch type {
            case "text/plain":
                if let text = String(data: data, encoding: .utf8) {
                    pasteboard.string = text
                }
            case "text/html":
                pasteboard.setData(data, forPasteboardType: UTType.html.identifier)
            case "image/png":
                if let image = UIImage(data: data) {
                    pasteboard.image = image
                }
            case "image/jpeg":
                if let image = UIImage(data: data) {
                    pasteboard.image = image
                }
            default:
                // Try to match by UTI
                if let utType = UTType(mimeType: type) {
                    pasteboard.setData(data, forPasteboardType: utType.identifier)
                }
            }
        }
    }
    
    public func canRead() -> Bool {
        // iOS always allows reading when app is in foreground
        return true
    }
    
    public func canWrite() -> Bool {
        // iOS always allows writing when app is in foreground
        return true
    }
}
#endif
