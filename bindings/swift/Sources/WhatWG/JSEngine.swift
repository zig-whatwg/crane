import Foundation

/// JavaScript engine selection for the WHATWG Platform.
///
/// The platform supports multiple JavaScript engines. Choose the engine
/// based on your target platform and requirements.
///
/// ## Engine Comparison
///
/// | Engine | Platforms | Performance | Size |
/// |--------|-----------|-------------|------|
/// | JavaScriptCore | iOS, macOS | Excellent | Built-in |
/// | V8 | All | Excellent | ~10MB |
/// | QuickJS | All | Good | ~500KB |
///
public enum JSEngine: String, Sendable, CaseIterable {
    
    /// Apple's JavaScriptCore engine.
    ///
    /// This is the default choice for iOS and macOS as it's built into
    /// the operating system and requires no additional dependencies.
    ///
    /// - Note: Best choice for Apple platforms.
    case javaScriptCore = "jsc"
    
    /// Google's V8 engine.
    ///
    /// High-performance engine used by Chrome and Node.js.
    /// Requires linking the V8 library.
    ///
    /// - Note: Best for performance-critical applications.
    case v8 = "v8"
    
    /// Fabrice Bellard's QuickJS engine.
    ///
    /// Lightweight engine with small binary size.
    /// Good for embedded systems or when binary size matters.
    ///
    /// - Note: Best for size-constrained environments.
    case quickJS = "quickjs"
    
    /// Returns the recommended engine for the current platform.
    public static var recommended: JSEngine {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        return .javaScriptCore
        #else
        return .quickJS
        #endif
    }
    
    /// Human-readable name for the engine.
    public var displayName: String {
        switch self {
        case .javaScriptCore:
            return "JavaScriptCore"
        case .v8:
            return "V8"
        case .quickJS:
            return "QuickJS"
        }
    }
    
    /// Whether this engine is available on the current platform.
    public var isAvailable: Bool {
        switch self {
        case .javaScriptCore:
            #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
            return true
            #else
            return false
            #endif
        case .v8:
            // V8 availability would be checked at runtime
            return false // TODO: Check V8 availability
        case .quickJS:
            // QuickJS is always available if compiled in
            return true
        }
    }
}
