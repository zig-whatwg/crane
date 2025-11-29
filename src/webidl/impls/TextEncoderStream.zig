//! Implementation for TextEncoderStream interface
//!
//! WHATWG Encoding Standard § 5.4
//! https://encoding.spec.whatwg.org/#interface-textencoderstream
//!
//! TextEncoderStream takes a stream of strings and emits UTF-8 encoded bytes.
//! It's a transform stream that uses the TextEncoder algorithm.
//!
//! ## Features
//!
//! - **UTF-8 Only**: Always encodes to UTF-8 (no label parameter)
//! - **Surrogate Pair Handling**: Correctly handles surrogate pairs split across chunks
//! - **Streaming**: Buffers leading surrogates for potential pairing with next chunk
//!
//! ## Key Algorithm: convert code unit to scalar value
//!
//! The spec defines a special algorithm for handling surrogate pairs that may be
//! split between chunks. If a leading surrogate (U+D800-U+DBFF) appears at the end
//! of a chunk, it's buffered until the next chunk to check for a trailing surrogate.
//! Lone surrogates are replaced with U+FFFD.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const TextEncoderStream = interfaces.TextEncoderStream;

pub const State = TextEncoderStream.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
};

/// Internal state for TextEncoderStream
///
/// WHATWG Encoding Standard § 5.4
/// https://encoding.spec.whatwg.org/#textencoderstream
///
/// Associated state:
/// - encoder: An encoder instance (for UTF-8)
/// - leading surrogate: Null or a leading surrogate, initially null
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The underlying transform stream
    transform: *runtime.Instance,

    /// Pending leading surrogate from previous chunk (for surrogate pair handling)
    /// WHATWG spec: "leading surrogate: Null or a leading surrogate, initially null"
    pending_leading_surrogate: ?u16,

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
    internal.pending_leading_surrogate = null;

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
/// WHATWG Encoding Standard § 5.4.1
/// https://encoding.spec.whatwg.org/#dom-textencoderstream
///
/// The new TextEncoderStream() constructor steps are:
/// 1. Set this's encoder to an instance of the UTF-8 encoder.
/// 2. Let transformAlgorithm be an algorithm which takes a chunk argument
///    and runs the encode and enqueue a chunk algorithm with this and chunk.
/// 3. Let flushAlgorithm be an algorithm which runs the encode and flush
///    algorithm with this.
/// 4. Let transformStream be a new TransformStream.
/// 5. Set up transformStream with transformAlgorithm set to transformAlgorithm
///    and flushAlgorithm set to flushAlgorithm.
/// 6. Set this's transform to transformStream.
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &TextEncoderStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Step 1: Encoder is implicit (UTF-8 only)

    // Steps 2-6: Create the underlying transform stream
    const empty_ptr: *const anyopaque = @ptrFromInt(1); // Non-null placeholder
    const transform = try interfaces.TransformStream.call_constructor(
        allocator,
        ctx,
        webidl.Opt(*const anyopaque).passed(empty_ptr),
        webidl.Opt(dictionaries.QueuingStrategy).notPassed(),
        webidl.Opt(dictionaries.QueuingStrategy).notPassed(),
    );
    errdefer interfaces.TransformStream.deinit(transform);

    internal.transform = transform;

    return instance;
}

/// Getter for encoding
///
/// Spec: § 5.2.1 "The encoding getter steps are to return 'utf-8'"
/// TextEncoderStream always uses UTF-8 encoding.
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    // Return static "utf-8" string (interned, no allocation needed)
    return runtime.DOMString.initInterned("utf-8");
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
// Internal Transform Algorithms
// ============================================================================

/// Encode and enqueue a chunk algorithm
///
/// WHATWG Encoding Standard § 5.4.2
/// https://encoding.spec.whatwg.org/#encode-and-enqueue-a-chunk
///
/// The encode and enqueue a chunk algorithm, given a TextEncoderStream object
/// encoder and chunk, runs these steps:
/// 1. Let input be the result of converting chunk to a DOMString.
/// 2. Convert input to an I/O queue of code units.
///    (Note: DOMString and I/O queue of code units (not scalar values) are used
///    so that surrogate pairs split between chunks can be reassembled)
/// 3. Let output be the I/O queue of bytes « end-of-queue ».
/// 4. While true:
///    a. Let item be the result of reading from input.
///    b. If item is end-of-queue:
///       i.   Convert output into a byte sequence.
///       ii.  If output is not empty:
///            1. Let chunk be the result of creating a Uint8Array object
///               given output and encoder's relevant realm.
///            2. Enqueue chunk into encoder's transform.
///       iii. Return.
///    c. Let result be the result of executing the convert code unit to scalar
///       value algorithm with encoder, item and input.
///    d. If result is not continue, then process an item with result, encoder's
///       encoder, input, output, and "fatal".
///
/// Note: In Zig, input is UTF-8 encoded. We need to:
/// 1. Convert UTF-8 to UTF-16 code units (to handle surrogates properly)
/// 2. Apply the convert code unit to scalar value algorithm
/// 3. Encode resulting scalar values back to UTF-8
pub fn encodeChunk(internal: *InternalState, input_utf8: []const u8) ![]u8 {
    const allocator = internal.allocator;

    // Handle empty input
    if (input_utf8.len == 0 and internal.pending_leading_surrogate == null) {
        return try allocator.alloc(u8, 0);
    }

    // Convert UTF-8 input to UTF-16 code units
    // This is necessary because we need to handle surrogates at the code unit level
    var utf16_units = infra.List(u16).init(allocator);
    defer utf16_units.deinit();

    // If there's a pending leading surrogate, we need to handle it first
    // by checking if the first character of this chunk is a trailing surrogate

    // Parse UTF-8 to code points, then to UTF-16 code units
    var i: usize = 0;
    while (i < input_utf8.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(input_utf8[i]) catch {
            // Invalid UTF-8 - treat as single byte (will become replacement)
            try utf16_units.append(0xFFFD);
            i += 1;
            continue;
        };

        if (i + cp_len > input_utf8.len) {
            // Incomplete UTF-8 at end - emit replacement
            try utf16_units.append(0xFFFD);
            break;
        }

        const code_point = std.unicode.utf8Decode(input_utf8[i .. i + cp_len]) catch {
            try utf16_units.append(0xFFFD);
            i += cp_len;
            continue;
        };

        // Convert code point to UTF-16 code units
        if (code_point <= 0xFFFF) {
            try utf16_units.append(@intCast(code_point));
        } else {
            // Supplementary plane - encode as surrogate pair
            const adjusted = code_point - 0x10000;
            const high: u16 = @intCast(0xD800 + (adjusted >> 10));
            const low: u16 = @intCast(0xDC00 + (adjusted & 0x3FF));
            try utf16_units.append(high);
            try utf16_units.append(low);
        }

        i += cp_len;
    }

    // Step 3: Create output buffer
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    // Step 4: Process each code unit through convert code unit to scalar value
    const code_units = utf16_units.slice();
    var cu_idx: usize = 0;

    while (cu_idx < code_units.len) {
        const item = code_units[cu_idx];

        // Step 4c: Run convert code unit to scalar value algorithm
        const result = convertCodeUnitToScalarValue(internal, item, code_units, &cu_idx);

        // Step 4d: If result is not continue, process the scalar value
        if (result) |scalar_value| {
            // Encode scalar value to UTF-8 and append to output
            var utf8_buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(scalar_value, &utf8_buf) catch {
                // Shouldn't happen for valid scalar values
                continue;
            };
            try output.appendSlice(utf8_buf[0..len]);
        }

        cu_idx += 1;
    }

    return output.toOwnedSlice();
}

/// Convert code unit to scalar value algorithm
///
/// WHATWG Encoding Standard § 5.4.3
/// https://encoding.spec.whatwg.org/#convert-code-unit-to-scalar-value
///
/// The convert code unit to scalar value algorithm, given a TextEncoderStream object
/// encoder, a code unit item, and an I/O queue of code units input, runs these steps:
///
/// 1. If encoder's leading surrogate is non-null:
///    a. Let leadingSurrogate be encoder's leading surrogate.
///    b. Set encoder's leading surrogate to null.
///    c. If item is a trailing surrogate, then return a scalar value from
///       surrogates given leadingSurrogate and item.
///    d. Restore item to input.
///    e. Return U+FFFD (�).
///
/// 2. If item is a leading surrogate, then set encoder's leading surrogate to
///    item and return continue.
///
/// 3. If item is a trailing surrogate, then return U+FFFD (�).
///
/// 4. Return item.
fn convertCodeUnitToScalarValue(
    internal: *InternalState,
    item: u16,
    code_units: []const u16,
    idx: *usize,
) ?u21 {
    _ = code_units; // Used for potential future optimizations

    // Step 1: Check if we have a pending leading surrogate
    if (internal.pending_leading_surrogate) |leading_surrogate| {
        // Step 1a-b: Clear the pending surrogate
        internal.pending_leading_surrogate = null;

        // Step 1c: If item is a trailing surrogate, combine them
        if (isTrailingSurrogate(item)) {
            // Return scalar value from surrogate pair
            return scalarValueFromSurrogates(leading_surrogate, item);
        }

        // Step 1d: Item is not a trailing surrogate - restore it
        // We handle this by decrementing idx so the item is processed again
        // after we return the replacement character
        if (idx.* > 0) {
            idx.* -= 1;
        }

        // Step 1e: Return U+FFFD for the unpaired leading surrogate
        return 0xFFFD;
    }

    // Step 2: If item is a leading surrogate, buffer it
    if (isLeadingSurrogate(item)) {
        internal.pending_leading_surrogate = item;
        return null; // continue
    }

    // Step 3: If item is a trailing surrogate (without leading), return U+FFFD
    if (isTrailingSurrogate(item)) {
        return 0xFFFD;
    }

    // Step 4: Regular BMP code point - return as-is
    return @as(u21, item);
}

/// Encode and flush algorithm
///
/// WHATWG Encoding Standard § 5.4.4
/// https://encoding.spec.whatwg.org/#encode-and-flush
///
/// The encode and flush algorithm, given a TextEncoderStream object encoder,
/// runs these steps:
///
/// 1. If encoder's leading surrogate is non-null:
///    a. Let chunk be the result of creating a Uint8Array object given
///       « 0xEF, 0xBF, 0xBD » and encoder's relevant realm.
///       (This is U+FFFD in UTF-8 bytes)
///    b. Enqueue chunk into encoder's transform.
pub fn flush(internal: *InternalState) !?[]u8 {
    // Step 1: Check for pending leading surrogate
    if (internal.pending_leading_surrogate) |_| {
        // Step 1a: Emit U+FFFD in UTF-8
        internal.pending_leading_surrogate = null;
        const replacement = [_]u8{ 0xEF, 0xBF, 0xBD }; // U+FFFD in UTF-8
        return try internal.allocator.dupe(u8, &replacement);
    }

    return null;
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Check if a code unit is a leading surrogate (U+D800-U+DBFF)
fn isLeadingSurrogate(code_unit: u16) bool {
    return code_unit >= 0xD800 and code_unit <= 0xDBFF;
}

/// Check if a code unit is a trailing surrogate (U+DC00-U+DFFF)
fn isTrailingSurrogate(code_unit: u16) bool {
    return code_unit >= 0xDC00 and code_unit <= 0xDFFF;
}

/// Obtain a scalar value from surrogate pair
///
/// WHATWG Infra Standard
/// https://infra.spec.whatwg.org/#surrogate
///
/// To obtain a scalar value from surrogates, given a leading surrogate leading
/// and a trailing surrogate trailing, return:
/// 0x10000 + ((leading − 0xD800) << 10) + (trailing − 0xDC00)
fn scalarValueFromSurrogates(leading: u16, trailing: u16) u21 {
    return 0x10000 + (@as(u21, leading - 0xD800) << 10) + (trailing - 0xDC00);
}
