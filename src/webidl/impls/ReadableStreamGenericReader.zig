//! Implementation for ReadableStreamGenericReader mixin
//!
//! Spec: https://streams.spec.whatwg.org/#readablestreamgenericreader
//!
//! This mixin provides shared functionality for all reader types:
//! - ReadableStreamDefaultReader
//! - ReadableStreamBYOBReader
//!
//! The actual implementation is in the concrete reader classes.
//! This mixin provides the interface contract that both readers implement.

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ReadableStreamGenericReader = interfaces.ReadableStreamGenericReader;

pub const State = ReadableStreamGenericReader.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
};

/// Internal state for mixin
///
/// Note: Mixins don't typically have their own instances.
/// The state is managed by the concrete reader implementations.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
};

/// Initialize instance
///
/// Note: This mixin is not typically instantiated directly.
/// Use ReadableStreamDefaultReader or ReadableStreamBYOBReader instead.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    runtime.Instance.deinit(instance);
}

/// Getter for closed
///
/// Spec: § 4.4.2 "The closed getter steps are:"
/// Returns a promise that fulfills when the stream closes or rejects if it errors.
///
/// Note: This delegates to the concrete reader implementation.
/// Both DefaultReader and BYOBReader implement this via their internal closedPromise.
pub fn get_closed(instance: *runtime.Instance) ImplError!*const anyopaque {
    // Determine which reader type this is and delegate
    // Try DefaultReader first
    if (instance.vtable == &interfaces.ReadableStreamDefaultReader.vtable) {
        const DefaultReaderImpl = @import("ReadableStreamDefaultReader.zig");
        return DefaultReaderImpl.get_closed(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try BYOBReader
    if (instance.vtable == &interfaces.ReadableStreamBYOBReader.vtable) {
        const BYOBReaderImpl = @import("ReadableStreamBYOBReader.zig");
        return BYOBReaderImpl.get_closed(instance) catch |err| {
            return switch (err) {
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    return error.TypeError;
}

/// Operation: cancel
///
/// Spec: § 4.4.3 "The cancel(reason) method steps are:"
/// Cancels the stream with the given reason.
///
/// Note: This delegates to the concrete reader implementation.
pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(*const anyopaque)) ImplError!*const anyopaque {
    // Determine which reader type this is and delegate
    // Try DefaultReader first
    if (instance.vtable == &interfaces.ReadableStreamDefaultReader.vtable) {
        const DefaultReaderImpl = @import("ReadableStreamDefaultReader.zig");
        return DefaultReaderImpl.call_cancel(instance, reason) catch |err| {
            return switch (err) {
                error.TypeError => error.TypeError,
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    // Try BYOBReader
    if (instance.vtable == &interfaces.ReadableStreamBYOBReader.vtable) {
        const BYOBReaderImpl = @import("ReadableStreamBYOBReader.zig");
        return BYOBReaderImpl.call_cancel(instance, reason) catch |err| {
            return switch (err) {
                error.TypeError => error.TypeError,
                error.InvalidState => error.InvalidState,
                else => error.InvalidState,
            };
        };
    }

    return error.TypeError;
}
