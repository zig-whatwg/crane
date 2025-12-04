import Foundation

/// Protocol for providing UI functionality (alert, confirm, prompt).
///
/// Implement this protocol to provide modal dialog support.
///
public protocol UIProvider: AnyObject, Sendable {
    
    /// Shows an alert dialog.
    ///
    /// - Parameter message: The message to display.
    func alert(message: String) async
    
    /// Shows a confirmation dialog.
    ///
    /// - Parameter message: The message to display.
    /// - Returns: `true` if confirmed, `false` if cancelled.
    func confirm(message: String) async -> Bool
    
    /// Shows a prompt dialog.
    ///
    /// - Parameters:
    ///   - message: The message to display.
    ///   - defaultValue: The default input value.
    /// - Returns: The entered value, or `nil` if cancelled.
    func prompt(message: String, defaultValue: String?) async -> String?
    
    /// Opens a URL.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - target: The target window name.
    ///   - features: Window features.
    /// - Returns: A window handle, or `nil` if blocked.
    func open(url: URL?, target: String?, features: String?) async -> WindowHandle?
    
    /// Prints the current page.
    func print() async
    
    /// Scrolls the window.
    ///
    /// - Parameters:
    ///   - x: X offset.
    ///   - y: Y offset.
    func scrollTo(x: Double, y: Double)
    
    /// Scrolls the window by an offset.
    ///
    /// - Parameters:
    ///   - x: X delta.
    ///   - y: Y delta.
    func scrollBy(x: Double, y: Double)
}

/// A handle to a window.
public protocol WindowHandle: AnyObject, Sendable {
    /// Closes the window.
    func close()
    
    /// Focuses the window.
    func focus()
    
    /// Blurs the window.
    func blur()
    
    /// Posts a message to the window.
    func postMessage(_ message: Any, targetOrigin: String)
}
