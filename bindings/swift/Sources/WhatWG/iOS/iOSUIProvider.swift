#if os(iOS)
import UIKit

/// iOS implementation of UIProvider using UIAlertController and UIKit APIs.
///
/// This provider uses UIAlertController for alert, confirm, and prompt dialogs.
/// UI operations are performed on the main thread.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.uiProvider = iOSUIProvider()
/// ```
///
@available(iOS 14.0, *)
@MainActor
public final class iOSUIProvider: UIProvider, @unchecked Sendable {
    
    private var windows: [String: iOSWindowHandle] = [:]
    
    /// Creates a new iOS UI provider.
    public init() {}
    
    // MARK: - UIProvider
    
    public func alert(message: String) async {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: nil,
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                continuation.resume()
            })
            
            presentAlert(alert)
        }
    }
    
    public func confirm(message: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: nil,
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                continuation.resume(returning: true)
            })
            
            presentAlert(alert)
        }
    }
    
    public func prompt(message: String, defaultValue: String?) async -> String? {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: nil,
                message: message,
                preferredStyle: .alert
            )
            
            alert.addTextField { textField in
                textField.text = defaultValue
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: nil)
            })
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                let text = alert.textFields?.first?.text
                continuation.resume(returning: text)
            })
            
            presentAlert(alert)
        }
    }
    
    public func open(url: URL?, target: String?, features: String?) async -> WindowHandle? {
        guard let url = url else { return nil }
        
        // For iOS, we can only open URLs in Safari
        guard await UIApplication.shared.canOpenURL(url) else {
            return nil
        }
        
        await UIApplication.shared.open(url)
        
        // Return a handle that doesn't do much on iOS
        let handle = iOSWindowHandle(identifier: url.absoluteString)
        let identifier = target ?? url.absoluteString
        windows[identifier] = handle
        
        return handle
    }
    
    public func print() async {
        // iOS printing requires a UIPrintInteractionController
        // This is a simplified implementation
        guard UIPrintInteractionController.isPrintingAvailable else {
            return
        }
        
        let printController = UIPrintInteractionController.shared
        printController.present(animated: true)
    }
    
    public func scrollTo(x: Double, y: Double) {
        // This would need a reference to the scroll view being controlled
        // For now, this is a no-op as the actual implementation depends on
        // how the browser engine renders content
    }
    
    public func scrollBy(x: Double, y: Double) {
        // Same as scrollTo - needs actual scroll view reference
    }
    
    // MARK: - Private
    
    private func presentAlert(_ alert: UIAlertController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }
        
        // Find the topmost presented view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        topVC.present(alert, animated: true)
    }
}

// MARK: - iOSWindowHandle

@available(iOS 14.0, *)
final class iOSWindowHandle: WindowHandle, @unchecked Sendable {
    
    private let identifier: String
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    public func close() {
        // iOS doesn't allow closing Safari tabs programmatically
    }
    
    public func focus() {
        // iOS doesn't support programmatic window focus
    }
    
    public func blur() {
        // iOS doesn't support programmatic window blur
    }
    
    public func postMessage(_ message: Any, targetOrigin: String) {
        // Cross-window messaging isn't supported for external URLs on iOS
    }
}
#endif

#if os(macOS)
import AppKit

/// macOS implementation of UIProvider using NSAlert and AppKit APIs.
///
/// This provider uses NSAlert for dialogs and NSWorkspace for window operations.
///
@available(macOS 11.0, *)
@MainActor
public final class macOSUIProvider: UIProvider, @unchecked Sendable {
    
    /// Creates a new macOS UI provider.
    public init() {}
    
    // MARK: - UIProvider
    
    public func alert(message: String) async {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    public func confirm(message: String) async -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    public func prompt(message: String, defaultValue: String?) async -> String? {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = defaultValue ?? ""
        alert.accessoryView = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return textField.stringValue
        }
        return nil
    }
    
    public func open(url: URL?, target: String?, features: String?) async -> WindowHandle? {
        guard let url = url else { return nil }
        NSWorkspace.shared.open(url)
        return macOSWindowHandle(identifier: url.absoluteString)
    }
    
    public func print() async {
        // macOS printing would need document context
    }
    
    public func scrollTo(x: Double, y: Double) {
        // Needs scroll view reference
    }
    
    public func scrollBy(x: Double, y: Double) {
        // Needs scroll view reference
    }
}

@available(macOS 11.0, *)
final class macOSWindowHandle: WindowHandle, @unchecked Sendable {
    
    private let identifier: String
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    public func close() {}
    public func focus() {}
    public func blur() {}
    public func postMessage(_ message: Any, targetOrigin: String) {}
}
#endif
