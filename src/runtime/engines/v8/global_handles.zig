//! V8 Global Handle Management
//!
//! This module provides type-safe wrappers for V8 Global handles, which persist
//! beyond HandleScope lifetimes. This is essential for storing JavaScript callbacks
//! (like stream start/write/close/abort callbacks) that need to survive after the
//! JavaScript constructor returns.
//!
//! ## Problem This Solves
//!
//! V8 uses two types of handles:
//! - **Local<T>**: Stack-bound, invalid after HandleScope ends
//! - **Global<T>**: Heap-allocated, persists until explicitly disposed
//!
//! When JavaScript code like `new WritableStream({ start: function() {...} })` is executed:
//! 1. V8 creates a HandleScope for the constructor call
//! 2. The `start` function is extracted as a Local<Value>
//! 3. When the constructor returns, the HandleScope is destroyed
//! 4. The Local<Value> pointer becomes INVALID (dangling pointer!)
//!
//! Using GlobalHandle converts the Local to a Global before the HandleScope ends,
//! preserving the callback for later invocation.
//!
//! ## Usage
//!
//! ```zig
//! // When extracting callback from dictionary (during constructor)
//! const callback_local = extractCallbackFromDict(...);
//! const callback_global = GlobalHandle.create(isolate, callback_local) orelse {
//!     // Handle null case
//! };
//! controller.start_callback = callback_global;
//!
//! // Later, when invoking the callback
//! if (controller.start_callback) |handle| {
//!     const local = handle.get(isolate) orelse return error.HandleInvalid;
//!     // Use local within current HandleScope
//! }
//!
//! // During cleanup
//! if (controller.start_callback) |handle| {
//!     handle.dispose();
//!     controller.start_callback = null;
//! }
//! ```

const ffi = @import("ffi.zig");

/// A type-safe wrapper for V8 Global<Value> handles.
///
/// GlobalHandle represents a persistent reference to a V8 value that survives
/// HandleScope destruction. It must be explicitly disposed to avoid memory leaks.
pub const GlobalHandle = struct {
    /// The underlying V8 Global<Value>* pointer
    ptr: *ffi.Value,

    /// Create a GlobalHandle from a Local value pointer.
    ///
    /// This converts a stack-bound Local<Value> to a heap-allocated Global<Value>
    /// that persists independently of any HandleScope.
    ///
    /// Parameters:
    ///   isolate: The current V8 isolate
    ///   local: A Local<Value> pointer (from dictionary extraction, callback arg, etc.)
    ///
    /// Returns:
    ///   A GlobalHandle if successful, or null if the local value is empty/invalid
    pub fn create(isolate: *ffi.Isolate, local: *anyopaque) ?GlobalHandle {
        const global_ptr = ffi.v8_Value_ToGlobal(isolate, local);
        if (global_ptr) |ptr| {
            return GlobalHandle{ .ptr = ptr };
        }
        return null;
    }

    /// Create a GlobalHandle from a V8 Value pointer.
    ///
    /// Convenience overload that accepts *ffi.Value directly.
    pub fn createFromValue(isolate: *ffi.Isolate, value: *ffi.Value) ?GlobalHandle {
        return create(isolate, @ptrCast(value));
    }

    /// Dispose the GlobalHandle and release the V8 reference.
    ///
    /// After calling this, the GlobalHandle should not be used. The underlying
    /// V8 value may be garbage collected if no other references exist.
    ///
    /// This is idempotent - calling dispose multiple times is safe.
    pub fn dispose(self: GlobalHandle) void {
        ffi.v8_Global_Dispose(self.ptr);
    }

    /// Get a Local<Value> pointer from this Global handle.
    ///
    /// The returned pointer is only valid within the current HandleScope.
    /// Do not store the returned pointer - store the GlobalHandle instead.
    ///
    /// Parameters:
    ///   isolate: The current V8 isolate
    ///
    /// Returns:
    ///   A local value pointer for use in V8 API calls, or null if the global is empty
    pub fn get(self: GlobalHandle, isolate: *ffi.Isolate) ?*ffi.Value {
        const local_ptr = ffi.v8_Global_Get(isolate, self.ptr);
        if (local_ptr) |ptr| {
            return @ptrCast(@alignCast(ptr));
        }
        return null;
    }

    /// Get this handle as an anyopaque pointer for FFI calls.
    ///
    /// Some V8 FFI functions expect *anyopaque for the value parameter.
    pub fn asAnyopaque(self: GlobalHandle, isolate: *ffi.Isolate) ?*anyopaque {
        return ffi.v8_Global_Get(isolate, self.ptr);
    }

    /// Get this handle as a Function pointer if it contains a function.
    ///
    /// Returns null if the Global doesn't contain a function value.
    pub fn asFunction(self: GlobalHandle) ?*ffi.Function {
        return ffi.v8_Global_ToFunction(self.ptr);
    }

    /// Check if this GlobalHandle is empty.
    pub fn isEmpty(self: GlobalHandle) bool {
        return ffi.v8_Global_IsEmpty(self.ptr);
    }

    /// Get the raw pointer (for storage in fields that expect *ffi.Value)
    pub fn rawPtr(self: GlobalHandle) *ffi.Value {
        return self.ptr;
    }
};

/// Optional GlobalHandle - commonly used for optional callbacks
pub const OptionalGlobalHandle = ?GlobalHandle;

/// Helper to dispose an optional GlobalHandle
pub fn disposeOptional(handle: *OptionalGlobalHandle) void {
    if (handle.*) |h| {
        h.dispose();
        handle.* = null;
    }
}

/// Helper to create a GlobalHandle from an optional local pointer
pub fn createOptional(isolate: *ffi.Isolate, local: ?*anyopaque) OptionalGlobalHandle {
    if (local) |l| {
        return GlobalHandle.create(isolate, l);
    }
    return null;
}
