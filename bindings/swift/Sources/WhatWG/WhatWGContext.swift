import Foundation
import CWhatWG

/// An execution context (realm/window) for running JavaScript.
///
/// A context represents an isolated JavaScript environment with its own
/// global object and execution state. Multiple contexts can exist within
/// a single platform instance.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// let context = try platform.createContext()
///
/// // Execute JavaScript
/// let result = try context.evaluate("1 + 1")
///
/// // Clean up
/// context.destroy()
/// ```
///
/// - Note: Context execution is currently not implemented. The C library
///   needs to be rebuilt with context support.
///
public final class WhatWGContext {
    
    // MARK: - Properties
    
    /// The platform this context belongs to.
    public private(set) weak var platform: WhatWGPlatform?
    
    /// The underlying C context handle.
    internal var handle: OpaquePointer?
    
    /// Whether the context has been destroyed.
    public private(set) var isDestroyed: Bool = false
    
    // MARK: - Initialization
    
    /// Creates a new context within the given platform.
    ///
    /// - Parameter platform: The platform to create the context in.
    /// - Throws: `WhatWGError` if context creation fails.
    internal init(platform: WhatWGPlatform) throws {
        self.platform = platform
        
        guard platform.handle != nil else {
            throw WhatWGError.notInitialized
        }
        
        // Context creation is not yet implemented in the C library.
        // For now, we create a context without a C handle.
        // This allows the Swift API to be tested while the C implementation
        // is being developed.
        self.handle = nil
    }
    
    deinit {
        destroy()
    }
    
    // MARK: - Lifecycle
    
    /// Destroys the context and releases resources.
    ///
    /// After calling this method, the context can no longer be used.
    public func destroy() {
        guard !isDestroyed else { return }
        
        // Context destruction will be implemented when C library support is added.
        self.handle = nil
        isDestroyed = true
    }
    
    // MARK: - JavaScript Execution
    
    /// Evaluates JavaScript code in this context.
    ///
    /// - Parameter script: The JavaScript code to execute.
    /// - Returns: The result of the evaluation as a string representation.
    /// - Throws: `WhatWGError` if evaluation fails.
    ///
    /// - Note: JavaScript evaluation is not yet implemented in the C library.
    public func evaluate(_ script: String) throws -> String? {
        guard !isDestroyed else {
            throw WhatWGError.notInitialized
        }
        
        // JavaScript evaluation is not yet implemented in the C library.
        throw WhatWGError.operationFailed("JavaScript evaluation not yet implemented")
    }
    
    // MARK: - Event Loop
    
    /// Runs the event loop until there are no more pending tasks.
    ///
    /// This is typically used for testing or command-line tools.
    ///
    /// - Note: Event loop is not yet implemented in the C library.
    public func runEventLoop() throws {
        guard !isDestroyed else {
            throw WhatWGError.notInitialized
        }
        
        // Event loop is not yet implemented in the C library.
        // This is a no-op for now.
    }
    
    /// Performs a single iteration of the event loop.
    ///
    /// - Returns: `true` if there are more tasks pending.
    ///
    /// - Note: Event loop is not yet implemented in the C library.
    public func stepEventLoop() throws -> Bool {
        guard !isDestroyed else {
            throw WhatWGError.notInitialized
        }
        
        // Event loop is not yet implemented in the C library.
        return false
    }
}

// MARK: - WhatWGRealm Type Alias

/// A realm is a JavaScript execution environment.
///
/// In WHATWG terminology, a realm is associated with a global object
/// (like Window or WorkerGlobalScope). This type alias provides
/// semantic clarity when working with different execution contexts.
public typealias WhatWGRealm = WhatWGContext
