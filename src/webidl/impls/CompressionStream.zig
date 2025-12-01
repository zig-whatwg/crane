//! Implementation for CompressionStream interface
//!
//! Spec: https://compression.spec.whatwg.org/#compressionstream
//!
//! CompressionStream compresses data using the specified format.
//! Supported formats: deflate, deflate-raw, gzip
//!
//! TODO: Implement actual compression when Zig std.compress matures or link zlib
//! - deflate: ZLIB format (RFC 1950) with 2-byte header and adler32 checksum
//! - deflate-raw: raw DEFLATE (RFC 1951) with no header/footer
//! - gzip: GZIP format (RFC 1952) with 10-byte header and crc32/size footer

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const CompressionStream = interfaces.CompressionStream;

pub const State = CompressionStream.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
    CompressionError,
    NotImplemented,
};

/// Compression format enumeration
pub const Format = enum {
    deflate, // zlib container (RFC 1950)
    deflate_raw, // raw deflate (RFC 1951)
    gzip, // gzip container (RFC 1952)
};

/// Internal state for CompressionStream
///
/// Spec: https://compression.spec.whatwg.org/#compressionstream
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The underlying transform stream
    transform: *runtime.Instance,

    /// The compression format
    format: Format,

    /// Accumulated input data - chunks are buffered until flush
    input_buffer: infra.List(u8),

    /// Whether compression has been finalized
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
/// Spec: § 3.1 "The CompressionStream(format) constructor steps are:"
/// 1. If format is unsupported, throw TypeError
/// 2. Set this's format to format
/// 3. Let transformAlgorithm be an algorithm which takes chunk and compresses it
/// 4. Let flushAlgorithm be an algorithm which finishes compression
/// 5. Set this's transform to a new TransformStream
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, format: enums.CompressionFormat) !*runtime.Instance {
    const instance = try init(allocator, State, &CompressionStream.vtable, ctx);
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
    var empty_transformer: u8 = 0;
    const writable_strategy = dictionaries.QueuingStrategy{};
    const readable_strategy = dictionaries.QueuingStrategy{};
    const transform = try interfaces.TransformStream.call_constructor(
        allocator,
        ctx,
        webidl.Opt(*const anyopaque).passed(&empty_transformer),
        webidl.Opt(dictionaries.QueuingStrategy).passed(writable_strategy),
        webidl.Opt(dictionaries.QueuingStrategy).passed(readable_strategy),
    );
    errdefer interfaces.TransformStream.deinit(transform);

    internal.transform = transform;

    return instance;
}

/// Getter for readable
///
/// Spec: "The readable getter steps are to return this's transform.[[readable]]"
pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const TransformStreamImpl = @import("TransformStream.zig");
    return TransformStreamImpl.get_readable(internal.transform) catch error.InvalidState;
}

/// Getter for writable
///
/// Spec: "The writable getter steps are to return this's transform.[[writable]]"
pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const TransformStreamImpl = @import("TransformStream.zig");
    return TransformStreamImpl.get_writable(internal.transform) catch error.InvalidState;
}

// ============================================================================
// Internal Transform Algorithm (Stubs)
// ============================================================================

/// Compress and enqueue a chunk algorithm
///
/// Spec: § 3.1 "compress and enqueue a chunk"
/// 1. If chunk is not a BufferSource type, throw TypeError
/// 2. Let buffer be the result of compressing chunk with cs's format and context
/// 3. If buffer is empty, return
/// 4. Split buffer into Uint8Arrays and enqueue each
///
/// TODO: Implement actual compression using zlib or mature Zig stdlib
pub fn compressChunk(internal: *InternalState, input: []const u8) ImplError![]u8 {
    if (internal.finalized) {
        return error.InvalidState;
    }

    // Buffer the input chunk for compression on flush
    try internal.input_buffer.appendSlice(input);

    // TODO: When compression is implemented, compress incrementally here
    // For now, return empty - actual compressed output comes from flush()
    return internal.allocator.alloc(u8, 0) catch return error.OutOfMemory;
}

/// Compress flush and enqueue algorithm
///
/// Spec: § 3.1 "compress flush and enqueue"
/// 1. Let buffer be the result of compressing empty input with finish flag
/// 2. If buffer is empty, return
/// 3. Split buffer into Uint8Arrays and enqueue each
///
/// TODO: Implement actual compression using zlib or mature Zig stdlib
pub fn flush(internal: *InternalState) ImplError!?[]u8 {
    if (internal.finalized) {
        return null;
    }

    internal.finalized = true;

    const input_data = internal.input_buffer.slice();
    if (input_data.len == 0) {
        return null;
    }

    // TODO: Implement actual compression
    // For now, return the data uncompressed as a placeholder
    // This allows the API to function for testing while compression is pending
    return internal.allocator.dupe(u8, input_data) catch return error.OutOfMemory;
}
