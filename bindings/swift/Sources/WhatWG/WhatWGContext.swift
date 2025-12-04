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
        
        guard let platformHandle = platform.handle else {
            throw WhatWGError.notInitialized
        }
        
        guard let contextHandle = whatwg_context_create(platformHandle) else {
            throw WhatWGError.contextCreationFailed
        }
        
        self.handle = contextHandle
    }
    
    deinit {
        destroy()
    }
    
    // MARK: - Lifecycle
    
    /// Destroys the context and releases resources.
    ///
    /// After calling this method, the context can no longer be used.
    public func destroy() {
        guard !isDestroyed, let handle = handle else { return }
        
        whatwg_context_destroy(handle)
        self.handle = nil
        isDestroyed = true
    }
    
    // MARK: - JavaScript Execution
    
    /// Evaluates JavaScript code in this context.
    ///
    /// - Parameter script: The JavaScript code to execute.
    /// - Returns: The result of the evaluation as a string representation.
    /// - Throws: `WhatWGError` if evaluation fails.
    public func evaluate(_ script: String) throws -> String? {
        guard !isDestroyed, let handle = handle else {
            throw WhatWGError.notInitialized
        }
        
        return try script.withCString { cScript in
            var resultPtr: UnsafeMutablePointer<CChar>?
            var resultLen: Int = 0
            
            let status = whatwg_context_evaluate(
                handle,
                cScript,
                script.utf8.count,
                &resultPtr,
                &resultLen
            )
            
            guard status == 0 else {
                throw WhatWGError.operationFailed("Script evaluation failed with code \(status)")
            }
            
            guard let ptr = resultPtr, resultLen > 0 else {
                return nil
            }
            
            defer { whatwg_free(ptr) }
            return String(cString: ptr)
        }
    }
    
    // MARK: - Event Loop
    
    /// Runs the event loop until there are no more pending tasks.
    ///
    /// This is typically used for testing or command-line tools.
    public func runEventLoop() throws {
        guard !isDestroyed, let handle = handle else {
            throw WhatWGError.notInitialized
        }
        
        whatwg_context_run_event_loop(handle)
    }
    
    /// Performs a single iteration of the event loop.
    ///
    /// - Returns: `true` if there are more tasks pending.
    public func stepEventLoop() throws -> Bool {
        guard !isDestroyed, let handle = handle else {
            throw WhatWGError.notInitialized
        }
        
        return whatwg_context_step_event_loop(handle)
    }
}

// MARK: - WhatWGRealm Type Alias

/// A realm is a JavaScript execution environment.
///
/// In WHATWG terminology, a realm is associated with a global object
/// (like Window or WorkerGlobalScope). This type alias provides
/// semantic clarity when working with different execution contexts.
public typealias WhatWGRealm = WhatWGContext
