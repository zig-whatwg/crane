//! Implementation for DecompressionStream interface
//!
//! Spec: https://compression.spec.whatwg.org/#decompressionstream
//!
//! DecompressionStream decompresses data using the specified format.
//! Supported formats: deflate, deflate-raw, gzip
//!
//! Implementation Status:
//! - Structure: COMPLETE (per spec)
//! - Decompression: STUB (uses pass-through until streaming decompression API available)
//!
//! The Zig 0.15 std.compress.flate API requires a reader-based streaming interface
//! which doesn't directly fit the chunk-by-chunk transform stream model.
//! A full implementation would buffer input and use flate.Decompress.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const DecompressionStream = interfaces.DecompressionStream;

pub const State = DecompressionStream.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
    DecompressionError,
};

/// Decompression format enumeration
pub const Format = enum {
    deflate,
    deflate_raw,
    gzip,
};

/// Internal state for DecompressionStream
///
/// Spec: https://compression.spec.whatwg.org/#decompressionstream
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The underlying transform stream
    transform: *runtime.Instance,

    /// The decompression format
    format: Format,

    /// Accumulated input data
    input_buffer: infra.List(u8),

    /// Whether decompression has been finalized
    finalized: bool,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.input_buffer.deinit();
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
    internal.format = .deflate;
    internal.input_buffer = infra.List(u8).init(allocator);
    internal.finalized = false;

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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: § 4.1 "The DecompressionStream(format) constructor steps are:"
/// 1. If format is unsupported, throw TypeError
/// 2. Set this's format to format
/// 3. Let transformAlgorithm be an algorithm which takes chunk and decompresses it
/// 4. Let flushAlgorithm be an algorithm which finishes decompression
/// 5. Set this's transform to a new TransformStream
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, format: enums.CompressionFormat) !*runtime.Instance {
    const instance = try init(allocator, State, &DecompressionStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Step 1-2: Set format
    internal.format = switch (format) {
        ._deflate_ => .deflate,
        ._deflate_raw_ => .deflate_raw,
        ._gzip_ => .gzip,
    };

    // Step 3-5: Create transform stream
    //
    // Per spec, DecompressionStream uses internal Zig-based transform/flush algorithms,
    // not a JavaScript transformer object. We pass notPassed() to indicate no
    // JavaScript transformer is needed.
    //
    // IMPORTANT: Do NOT pass a Zig stack pointer as the transformer - that would
    // cause TransformStream to try to use it as a V8 Object handle, resulting in
    // misaligned pointer segfaults. See whatwg-lbw51 for details.
    const v8 = @import("v8");
    const transform = try interfaces.TransformStream.call_constructor(
        allocator,
        ctx,
        webidl.Opt(v8.JSValue).notPassed(),
        webidl.Opt(dictionaries.QueuingStrategy).notPassed(),
        webidl.Opt(dictionaries.QueuingStrategy).notPassed(),
    );
    errdefer interfaces.TransformStream.deinit(transform);

    internal.transform = transform;

    return instance;
}

/// Getter for readable (use interface per Golden Rule #13)
///
/// Spec: "The readable getter steps are to return this's transform.[[readable]]"
pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return interfaces.TransformStream.get_readable(internal.transform) catch error.InvalidState;
}

/// Getter for writable (use interface per Golden Rule #13)
///
/// Spec: "The writable getter steps are to return this's transform.[[writable]]"
pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return interfaces.TransformStream.get_writable(internal.transform) catch error.InvalidState;
}

// ============================================================================
// Internal Transform Algorithm
// ============================================================================

/// Decompress a chunk of data
///
/// This is the transform algorithm used by the underlying TransformStream.
///
/// STUB: Currently passes data through unchanged. Full implementation would use
/// std.compress.flate.Decompress with reader-based API.
pub fn decompressChunk(internal: *InternalState, input: []const u8) ![]u8 {
    if (internal.finalized) {
        return error.InvalidState;
    }

    // STUB: Pass through unchanged
    // Full implementation would decompress using flate
    return try internal.allocator.dupe(u8, input);
}

/// Finish decompression
///
/// This is the flush algorithm used by the underlying TransformStream.
///
/// STUB: Returns null (no pending data). Full implementation would finalize
/// the decompression stream and return any remaining decompressed data.
pub fn flush(internal: *InternalState) !?[]u8 {
    if (internal.finalized) {
        return null;
    }

    internal.finalized = true;

    // STUB: No pending data
    return null;
}
