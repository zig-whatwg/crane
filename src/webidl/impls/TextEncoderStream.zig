//! Implementation for TextEncoderStream interface
//!
//! Spec: https://encoding.spec.whatwg.org/#interface-textencoderstream
//!
//! TextEncoderStream takes a stream of strings and emits UTF-8 encoded bytes.
//! It's a transform stream that uses the TextEncoder algorithm.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const TextEncoderStream = interfaces.TextEncoderStream;

pub const State = TextEncoderStream.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
};

/// Internal state for TextEncoderStream
///
/// Spec: https://encoding.spec.whatwg.org/#textencoderstream
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The underlying transform stream
    transform: *runtime.Instance,

    /// Pending high surrogate from previous chunk (for surrogate pair handling)
    pending_high_surrogate: ?u16,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Transform stream has its own lifecycle
        _ = self;
        _ = allocator;
    }
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.pending_high_surrogate = null;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
///
/// Spec: § 8.2.1 "The TextEncoderStream() constructor steps are:"
/// 1. Set this's encoder to a new encoder for UTF-8
/// 2. Set this's transform to a new TransformStream
/// 3. Set up this's transform with transformAlgorithm and flushAlgorithm
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &TextEncoderStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Create the underlying transform stream
    // The transform algorithm encodes strings to UTF-8 bytes
    const empty_ptr: *const anyopaque = @ptrFromInt(1); // Non-null placeholder
    const transform = try interfaces.TransformStream.call_constructor(
        allocator,
        ctx,
        empty_ptr, // transformer placeholder
        .{}, // writableStrategy (default)
        .{}, // readableStrategy (default)
    );
    errdefer interfaces.TransformStream.deinit(transform);

    internal.transform = transform;

    return instance;
}

/// Getter for encoding
///
/// Spec: § 8.2.2 "The encoding getter steps are to return 'utf-8'"
/// TextEncoderStream always uses UTF-8 encoding.
pub fn get_encoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // Return static "utf-8" string (interned, no allocation needed)
    return runtime.DOMString.initInterned("utf-8");
}

/// Getter for readable
///
/// Spec: § 8.2.2 "The readable getter steps are to return this's transform.[[readable]]"
pub fn get_readable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const TransformStreamImpl = @import("TransformStream.zig");
    return TransformStreamImpl.get_readable(internal.transform) catch error.InvalidState;
}

/// Getter for writable
///
/// Spec: § 8.2.2 "The writable getter steps are to return this's transform.[[writable]]"
pub fn get_writable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const TransformStreamImpl = @import("TransformStream.zig");
    return TransformStreamImpl.get_writable(internal.transform) catch error.InvalidState;
}

// ============================================================================
// Internal Transform Algorithm
// ============================================================================

/// Encode a string chunk to UTF-8 bytes
///
/// This is the transform algorithm used by the underlying TransformStream.
/// It converts JavaScript strings (UTF-16) to UTF-8 encoded Uint8Array chunks.
pub fn encodeChunk(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    // Input is already UTF-8 in Zig strings
    // Just duplicate it for the output buffer
    return try allocator.dupe(u8, input);
}

/// Flush any pending state
///
/// This is the flush algorithm used by the underlying TransformStream.
/// It handles any pending high surrogate from surrogate pair splitting.
pub fn flush(internal: *InternalState) !?[]u8 {
    if (internal.pending_high_surrogate) |_| {
        // Pending high surrogate without low surrogate is an error
        // Per spec, we encode it as U+FFFD (replacement character)
        internal.pending_high_surrogate = null;
        const replacement = [_]u8{ 0xEF, 0xBF, 0xBD }; // U+FFFD in UTF-8
        return try internal.allocator.dupe(u8, &replacement);
    }
    return null;
}
