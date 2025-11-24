//! Abstract JavaScript Engine Interface
//!
//! This module defines the interface that all JavaScript engine implementations
//! must satisfy. It provides engine-agnostic operations for WebIDL bindings.
//!
//! ## Design Goals
//!
//! 1. **Engine Independence**: WebIDL impl files should not import engine-specific code
//! 2. **Runtime Dispatch**: Engine operations dispatched through vtable at runtime
//! 3. **Zero Cost When Unused**: No overhead when engine operations aren't called
//! 4. **Type Safety**: Zig's type system ensures correct usage
//!
//! ## Supported Engines
//!
//! - V8 (implemented in src/runtime/engines/v8/)
//! - JSC (future)
//! - SpiderMonkey (future)
//!
//! ## Usage
//!
//! ```zig
//! const runtime = @import("runtime");
//!
//! pub fn call_values(instance: *runtime.Instance, options: Options) !*const anyopaque {
//!     const ctx = instance.ctx;
//!
//!     // Create Zig-side iterator (engine-agnostic)
//!     const zig_iterator = try createAsyncIterator(ctx, instance, options);
//!
//!     // Wrap for JS engine (engine-specific, but abstracted)
//!     const engine = ctx.getEngine() orelse return error.NoEngine;
//!     return try engine.wrapAsyncIterator(ctx, zig_iterator);
//! }
//! ```

const std = @import("std");

/// Error set for engine operations
pub const EngineError = error{
    /// No engine is configured in the context
    NoEngine,
    /// Engine operation failed
    OperationFailed,
    /// Memory allocation failed
    OutOfMemory,
    /// Type conversion failed
    TypeError,
    /// Promise creation/resolution failed
    PromiseError,
    /// Async iterator wrapping failed
    AsyncIteratorError,
    /// Interface registration failed
    RegistrationFailed,
};

/// Abstract interface for JavaScript engine operations
///
/// All engine implementations (V8, JSC, etc.) must provide these operations.
/// The interface uses function pointers for runtime dispatch, allowing
/// engine selection without recompilation of WebIDL code.
pub const EngineInterface = struct {
    /// Wrap a Zig async iterator for the JS engine
    ///
    /// Takes a Zig async iterator (e.g., ReadableStreamAsyncIterator) and
    /// returns an engine-specific async iterator object that JavaScript
    /// can use with `for await...of` loops.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context (V8 Isolate, JSC VM, etc.)
    ///   - zig_iterator: Pointer to Zig async iterator
    ///
    /// Returns:
    ///   - Opaque pointer to engine's async iterator object
    wrapAsyncIterator: *const fn (
        engine_ctx: *anyopaque,
        zig_iterator: *anyopaque,
    ) EngineError!*anyopaque,

    /// Create a Promise that can be resolved/rejected from Zig
    ///
    /// Returns a handle that can be used with resolvePromise/rejectPromise.
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - allocator: Allocator for any needed storage
    ///
    /// Returns:
    ///   - Opaque pointer to promise handle
    createPromise: *const fn (
        engine_ctx: *anyopaque,
        allocator: std.mem.Allocator,
    ) EngineError!*anyopaque,

    /// Resolve a Promise with a value
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - promise_handle: Handle from createPromise
    ///   - value: Opaque pointer to value (engine will convert)
    resolvePromise: *const fn (
        engine_ctx: *anyopaque,
        promise_handle: *anyopaque,
        value: ?*const anyopaque,
    ) EngineError!void,

    /// Reject a Promise with an error
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - promise_handle: Handle from createPromise
    ///   - err: Error to reject with
    rejectPromise: *const fn (
        engine_ctx: *anyopaque,
        promise_handle: *anyopaque,
        err: anyerror,
    ) EngineError!void,

    /// Get the Promise object to return to JavaScript
    ///
    /// Arguments:
    ///   - promise_handle: Handle from createPromise
    ///
    /// Returns:
    ///   - Opaque pointer to the JS Promise object
    getPromiseObject: *const fn (
        promise_handle: *anyopaque,
    ) *anyopaque,

    /// Create an event loop for async operations
    ///
    /// Arguments:
    ///   - engine_ctx: Engine-specific context
    ///   - allocator: Allocator for event loop storage
    ///
    /// Returns:
    ///   - Opaque pointer to event loop
    createEventLoop: ?*const fn (
        engine_ctx: *anyopaque,
        allocator: std.mem.Allocator,
    ) EngineError!*anyopaque,

    /// Destroy an event loop
    ///
    /// Arguments:
    ///   - event_loop: Event loop from createEventLoop
    ///   - allocator: Same allocator used to create it
    destroyEventLoop: ?*const fn (
        event_loop: *anyopaque,
        allocator: std.mem.Allocator,
    ) void,

    /// Engine name for debugging/logging
    name: []const u8,

    /// Engine version string
    version: []const u8,
};

/// Stub engine interface for testing without a JS engine
///
/// All operations return errors, useful for testing Zig-only code paths.
pub const stub_engine: EngineInterface = .{
    .wrapAsyncIterator = stubWrapAsyncIterator,
    .createPromise = stubCreatePromise,
    .resolvePromise = stubResolvePromise,
    .rejectPromise = stubRejectPromise,
    .getPromiseObject = stubGetPromiseObject,
    .createEventLoop = null,
    .destroyEventLoop = null,
    .name = "stub",
    .version = "0.0.0",
};

fn stubWrapAsyncIterator(_: *anyopaque, _: *anyopaque) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubCreatePromise(_: *anyopaque, _: std.mem.Allocator) EngineError!*anyopaque {
    return EngineError.NoEngine;
}

fn stubResolvePromise(_: *anyopaque, _: *anyopaque, _: ?*const anyopaque) EngineError!void {
    return EngineError.NoEngine;
}

fn stubRejectPromise(_: *anyopaque, _: *anyopaque, _: anyerror) EngineError!void {
    return EngineError.NoEngine;
}

fn stubGetPromiseObject(_: *anyopaque) *anyopaque {
    // This should never be called if createPromise returns error
    unreachable;
}

// ============================================================================
// Tests
// ============================================================================

test "EngineInterface - stub returns errors" {
    const testing = std.testing;

    // All stub operations should return NoEngine error
    try testing.expectError(EngineError.NoEngine, stub_engine.wrapAsyncIterator(undefined, undefined));
    try testing.expectError(EngineError.NoEngine, stub_engine.createPromise(undefined, testing.allocator));
}

test "EngineInterface - struct size" {
    const testing = std.testing;

    // Interface should be reasonably small (just function pointers + strings)
    try testing.expect(@sizeOf(EngineInterface) < 128);
}
