import Foundation
import CWhatWG

// MARK: - C Interop Helpers

/// Internal helpers for C interop.
///
/// These functions bridge Swift providers to C VTable callbacks.
/// The pattern is:
/// 1. Store Swift provider reference in user_context
/// 2. C callback retrieves provider from user_context
/// 3. C callback invokes Swift method
/// 4. Result is converted back to C types
///

// MARK: - String Conversion

extension String {
    /// Creates a string from a C buffer with length.
    init?(cBuffer: UnsafePointer<CChar>?, length: Int) {
        guard let buffer = cBuffer, length > 0 else { return nil }
        let data = Data(bytes: buffer, count: length)
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        self = string
    }
    
    /// Calls a closure with the string as a C buffer.
    func withCBuffer<T>(_ body: (UnsafePointer<CChar>, Int) throws -> T) rethrows -> T {
        try withCString { ptr in
            try body(ptr, utf8.count)
        }
    }
}

// MARK: - Provider Context

/// Container for Swift providers passed to C callbacks.
internal class ProviderContext {
    weak var platform: WhatWGPlatform?
    
    init(platform: WhatWGPlatform) {
        self.platform = platform
    }
}

// MARK: - VTable Builders

/// Creates a clipboard VTable that bridges to a Swift provider.
internal func makeClipboardVTable(context: UnsafeMutableRawPointer) -> whatwg_clipboard_vtable_t {
    var vtable = whatwg_clipboard_vtable_t()
    
    // read_text callback
    vtable.read_text = { userContext, buffer, bufferLen in
        guard let ctx = userContext?.assumingMemoryBound(to: ProviderContext.self).pointee,
              let provider = ctx.platform?.clipboardProvider else {
            return -1
        }
        
        // This would need async bridging in real implementation
        // For now, return not available
        return Int32(WHATWG_CLIPBOARD_NOT_AVAILABLE.rawValue)
    }
    
    // write_text callback
    vtable.write_text = { userContext, text, textLen in
        guard let ctx = userContext?.assumingMemoryBound(to: ProviderContext.self).pointee,
              let provider = ctx.platform?.clipboardProvider else {
            return whatwg_clipboard_result_t(WHATWG_CLIPBOARD_NOT_AVAILABLE.rawValue)
        }
        
        return whatwg_clipboard_result_t(WHATWG_CLIPBOARD_NOT_AVAILABLE.rawValue)
    }
    
    return vtable
}

/// Creates a timer VTable that bridges to a Swift provider.
internal func makeTimerVTable(context: UnsafeMutableRawPointer) -> whatwg_timer_vtable_t {
    var vtable = whatwg_timer_vtable_t()
    
    vtable.set_timeout = { userContext, callback, delayMs, userData in
        guard let ctx = userContext?.assumingMemoryBound(to: ProviderContext.self).pointee,
              let provider = ctx.platform?.timerProvider else {
            return 0
        }
        
        // Timer implementation would go here
        return 0
    }
    
    vtable.set_interval = { userContext, callback, intervalMs, userData in
        guard let ctx = userContext?.assumingMemoryBound(to: ProviderContext.self).pointee,
              let provider = ctx.platform?.timerProvider else {
            return 0
        }
        
        return 0
    }
    
    vtable.clear_timeout = { userContext, timerId in
        guard let ctx = userContext?.assumingMemoryBound(to: ProviderContext.self).pointee,
              let provider = ctx.platform?.timerProvider else {
            return
        }
        
        // Clear timer implementation
    }
    
    vtable.clear_interval = { userContext, timerId in
        guard let ctx = userContext?.assumingMemoryBound(to: ProviderContext.self).pointee,
              let provider = ctx.platform?.timerProvider else {
            return
        }
        
        // Clear interval implementation
    }
    
    return vtable
}

// MARK: - Additional VTable builders would follow the same pattern
// storage, network, filesystem, geolocation, etc.
