//! Implementation for TextDecoderStream interface
//!
//! Spec: https://encoding.spec.whatwg.org/#interface-textdecoderstream
//!
//! TextDecoderStream takes a stream of bytes and emits decoded strings.
//! It's a transform stream that uses the TextDecoder algorithm.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const TextDecoderStream = interfaces.TextDecoderStream;

pub const State = TextDecoderStream.State;

pub const ImplError = error{
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
};

/// Internal state for TextDecoderStream
///
/// Spec: https://encoding.spec.whatwg.org/#textdecoderstream
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The underlying transform stream
    transform: *runtime.Instance,

    /// The encoding label (normalized)
    encoding: []const u8,

    /// Whether to throw on decoding errors
    fatal: bool,

    /// Whether to ignore BOM
    ignore_bom: bool,

    /// Pending bytes from previous chunk (for multi-byte sequences)
    pending_bytes: infra.List(u8),

    /// Whether BOM has been seen
    bom_seen: bool,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.pending_bytes.deinit();
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
    internal.encoding = "utf-8";
    internal.fatal = false;
    internal.ignore_bom = false;
    internal.pending_bytes = infra.List(u8).init(allocator);
    internal.bom_seen = false;

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
/// Spec: § 8.1.1 "The TextDecoderStream(label, options) constructor steps are:"
/// 1. Let encoding be the result of getting an encoding from label
/// 2. If encoding is failure or replacement, throw RangeError
/// 3. Set this's encoding to encoding
/// 4. If options's fatal is true, set this's error mode to fatal
/// 5. Set this's ignore BOM to options's ignoreBOM
/// 6. Set this's transform to a new TransformStream
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, label: runtime.DOMString, options: dictionaries.TextDecoderOptions) !*runtime.Instance {
    const instance = try init(allocator, State, &TextDecoderStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Step 1-3: Get encoding from label (normalize to lowercase)
    // For now, we only support UTF-8
    const encoding = normalizeEncodingLabel(label) orelse return error.RangeError;
    internal.encoding = encoding;

    // Step 4: Set fatal mode
    internal.fatal = options.fatal orelse false;

    // Step 5: Set ignore BOM
    internal.ignore_bom = options.ignoreBOM orelse false;

    // Step 6: Create the underlying transform stream
    // Use empty transformer and default strategies
    var empty_transformer: u8 = 0; // Placeholder for null transformer
    const writable_strategy = dictionaries.QueuingStrategy{};
    const readable_strategy = dictionaries.QueuingStrategy{};
    const transform = try interfaces.TransformStream.call_constructor(
        allocator,
        ctx,
        &empty_transformer,
        writable_strategy,
        readable_strategy,
    );
    errdefer interfaces.TransformStream.deinit(transform);

    internal.transform = transform;

    return instance;
}

/// Normalize encoding label
///
/// Spec: https://encoding.spec.whatwg.org/#concept-encoding-get
fn normalizeEncodingLabel(label: runtime.DOMString) ?[]const u8 {
    // Get the raw string from DOMString union
    const label_str = label.asSlice();

    // Simple check for UTF-8 variants (case-insensitive)
    // In production would use full encoding label table
    if (label_str.len == 0) return null;

    // Check common UTF-8 labels
    if (std.ascii.eqlIgnoreCase(label_str, "utf-8") or
        std.ascii.eqlIgnoreCase(label_str, "utf8") or
        std.ascii.eqlIgnoreCase(label_str, "unicode-1-1-utf-8"))
    {
        return "utf-8";
    }

    // For now, only UTF-8 is fully supported
    // Return null for unsupported encodings
    return null;
}

/// Getter for encoding
///
/// Spec: § 8.1.2 "The encoding getter steps are to return this's encoding's name"
pub fn get_encoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    // Return as interned string since encoding names are fixed
    return runtime.DOMString.initInterned(internal.encoding);
}

/// Getter for fatal
///
/// Spec: § 8.1.2 "The fatal getter steps are to return true if this's error mode is fatal"
pub fn get_fatal(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.fatal;
}

/// Getter for ignoreBOM
///
/// Spec: § 8.1.2 "The ignoreBOM getter steps are to return this's ignore BOM"
pub fn get_ignoreBOM(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.ignore_bom;
}

/// Getter for readable
///
/// Spec: § 8.1.2 "The readable getter steps are to return this's transform.[[readable]]"
pub fn get_readable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const TransformStreamImpl = @import("TransformStream.zig");
    return TransformStreamImpl.get_readable(internal.transform) catch error.InvalidState;
}

/// Getter for writable
///
/// Spec: § 8.1.2 "The writable getter steps are to return this's transform.[[writable]]"
pub fn get_writable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const TransformStreamImpl = @import("TransformStream.zig");
    return TransformStreamImpl.get_writable(internal.transform) catch error.InvalidState;
}

// ============================================================================
// Internal Transform Algorithm
// ============================================================================

/// Decode a byte chunk to string
///
/// This is the transform algorithm used by the underlying TransformStream.
/// It converts bytes to UTF-8 decoded strings.
pub fn decodeChunk(internal: *InternalState, input: []const u8) ![]u8 {
    // Combine pending bytes with new input
    var combined = infra.List(u8).init(internal.allocator);
    defer combined.deinit();

    try combined.appendSlice(internal.pending_bytes.slice());
    try combined.appendSlice(input);

    // For UTF-8, we need to handle incomplete sequences at the end
    const bytes = combined.slice();
    var valid_end: usize = bytes.len;

    // Check for incomplete UTF-8 sequence at end
    if (bytes.len > 0) {
        var i = bytes.len - 1;
        while (i > 0 and (bytes[i] & 0xC0) == 0x80) : (i -= 1) {}

        const lead = bytes[i];
        const expected_len: usize = if ((lead & 0x80) == 0) 1 else if ((lead & 0xE0) == 0xC0) 2 else if ((lead & 0xF0) == 0xE0) 3 else if ((lead & 0xF8) == 0xF0) 4 else 1;

        const actual_len = bytes.len - i;
        if (actual_len < expected_len) {
            valid_end = i;
        }
    }

    // Store incomplete bytes for next chunk
    internal.pending_bytes.clear();
    if (valid_end < bytes.len) {
        try internal.pending_bytes.appendSlice(bytes[valid_end..]);
    }

    // Return valid UTF-8 portion
    if (valid_end > 0) {
        return try internal.allocator.dupe(u8, bytes[0..valid_end]);
    }
    return try internal.allocator.alloc(u8, 0);
}

/// Flush any pending state
///
/// This is the flush algorithm used by the underlying TransformStream.
pub fn flush(internal: *InternalState) !?[]u8 {
    if (internal.pending_bytes.len > 0) {
        if (internal.fatal) {
            // Fatal mode: incomplete sequence is an error
            return error.TypeError;
        }
        // Replacement mode: emit U+FFFD for incomplete sequence
        internal.pending_bytes.clear();
        const replacement = [_]u8{ 0xEF, 0xBF, 0xBD }; // U+FFFD in UTF-8
        return try internal.allocator.dupe(u8, &replacement);
    }
    return null;
}
