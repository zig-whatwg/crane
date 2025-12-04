import Foundation

/// Errors that can occur during browser operations.
public enum BrowserError: Error, LocalizedError {
    
    /// The URL is invalid or malformed.
    case invalidURL(String)
    
    /// Navigation failed.
    case navigationFailed(String)
    
    /// JavaScript execution failed.
    case scriptError(String)
    
    /// The browser engine is not initialized.
    case notInitialized
    
    /// The requested page was not found (404).
    case pageNotFound
    
    /// The network request failed.
    case networkError(Error)
    
    /// SSL/TLS certificate error.
    case certificateError(String)
    
    /// The page was blocked by content security policy.
    case blockedByCSP
    
    /// The page was blocked by safe browsing.
    case blockedBySafeBrowsing
    
    /// The operation timed out.
    case timeout
    
    /// An unknown error occurred.
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .navigationFailed(let reason):
            return "Navigation failed: \(reason)"
        case .scriptError(let message):
            return "JavaScript error: \(message)"
        case .notInitialized:
            return "Browser not initialized"
        case .pageNotFound:
            return "Page not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .certificateError(let message):
            return "Certificate error: \(message)"
        case .blockedByCSP:
            return "Blocked by Content Security Policy"
        case .blockedBySafeBrowsing:
            return "Blocked by Safe Browsing"
        case .timeout:
            return "Request timed out"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
