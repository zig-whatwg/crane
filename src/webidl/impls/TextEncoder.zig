//! Implementation for TextEncoder interface
//!
//! WHATWG Encoding Standard § 5.2
//! https://encoding.spec.whatwg.org/#interface-textencoder
//!
//! TextEncoder encodes strings into UTF-8 byte sequences.
//!
//! ## Features
//!
//! - **UTF-8 Only**: Always encodes to UTF-8 (no label parameter)
//! - **No Streaming**: Stateless operation (no buffering needed)
//! - **Two Methods**: `encode()` allocates new buffer, `encodeInto()` uses existing buffer
//! - **Performance**: ASCII fast path for common cases

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const infra = @import("infra");

const TextEncoder = interfaces.TextEncoder;

pub const State = TextEncoder.State;

pub const ImplError = error{
    /// Out of memory
    OutOfMemory,
    /// Invalid state
    InvalidState,
};

/// Internal state for TextEncoder implementation
/// TextEncoder is stateless, so this just stores the allocator for encode()
pub const InternalState = struct {
    /// Memory allocator for encode() output
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
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
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// WHATWG Encoding Standard § 5.2.1
/// https://encoding.spec.whatwg.org/#dom-textencoder
///
/// Creates a new UTF-8 encoder (stateless).
///
/// The new TextEncoder() constructor steps are to do nothing.
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &TextEncoder.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create InternalState
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);

    internal.* = InternalState{
        .allocator = ctx.allocator,
    };

    state.own._internal = internal;

    // Set encoding to "utf-8" (always UTF-8 per spec)
    state.own.encoding = runtime.DOMString.initInterned("utf-8");

    return instance;
}

/// Getter for encoding
/// Returns the encoding name (always "utf-8" for TextEncoder)
/// Spec: https://encoding.spec.whatwg.org/#dom-textencodercommon-encoding
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.encoding;
}

/// encode() operation
/// WHATWG Encoding Standard § 5.2.2
/// https://encoding.spec.whatwg.org/#dom-textencoder-encode
///
/// Encodes the input string to UTF-8 and returns a newly allocated Uint8Array.
///
/// The encode(input) method steps are:
/// 1. Convert input to an I/O queue of scalar values
/// 2. Let output be the I/O queue of bytes
/// 3. Process with UTF-8 encoder
/// 4. Return Uint8Array
pub fn call_encode(instance: *runtime.Instance, input: webidl.Opt(runtime.USVString)) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return ImplError.InvalidState;
    const allocator = internal.allocator;

    // Get input value - default to empty string
    const input_slice: []const u8 = if (input.was_passed) input.value else "";

    // A USVString is valid UTF-8 already, so the UTF-8 encoder's output is the
    // input's own bytes (the ASCII fast path is the same case). Anything else
    // has its invalid sequences replaced with U+FFFD first.
    if (std.unicode.utf8ValidateSlice(input_slice)) {
        return newUint8Array(instance, input_slice);
    }
    const output = replaceInvalidUtf8(allocator, input_slice) catch return ImplError.OutOfMemory;
    defer allocator.free(output);
    return newUint8Array(instance, output);
}

/// encodeInto() operation
/// WHATWG Encoding Standard § 5.2.3
/// https://encoding.spec.whatwg.org/#dom-textencoder-encodeinto
///
/// Encodes the source string into the destination buffer (zero-copy, no allocation).
///
/// IMPORTANT: The `read` return value counts UTF-16 code units, NOT UTF-8 bytes.
/// This is because JavaScript strings are UTF-16 encoded internally.
/// For code points > U+FFFF (supplementary plane), read increments by 2 (surrogate pair).
///
/// The encodeInto(source, destination) method steps are:
/// 1. Let read be 0.
/// 2. Let written be 0.
/// 3. Let encoder be an instance of the UTF-8 encoder.
/// 4. Let unused be the I/O queue of scalar values « end-of-queue ».
/// 5. Convert source to an I/O queue of scalar values.
/// 6. While true:
///    a. Let item be the result of reading from source.
///    b. Let result be the result of running encoder's handler on unused and item.
///    c. If result is finished, then break.
///    d. Otherwise:
///       i.   If destination's byte length − written >= number of bytes in result:
///            1. If item is greater than U+FFFF, then increment read by 2.
///            2. Otherwise, increment read by 1.
///            3. Write the bytes in result into destination, with startingOffset set to written.
///            4. Increment written by the number of bytes in result.
///       ii.  Otherwise, break.
/// 7. Return «[ "read" → read, "written" → written ]».
pub fn call_encodeInto(instance: *runtime.Instance, source: runtime.USVString, destination: runtime.JSValue) anyerror!dictionaries.TextEncoderEncodeIntoResult {
    const engine = instance.ctx.getEngine() orelse return error.NotImplemented;
    const describe_view = engine.describeArrayBufferView orelse return error.NotSupported;
    const write_into_view = engine.writeIntoArrayBufferView orelse return error.NotSupported;

    // The binding hands `destination` over unconverted: WebIDL's conversion
    // to [AllowShared] Uint8Array is a TypeError for anything that is not a
    // Uint8Array - another typed array or a DataView included.
    const view = describe_view(destination) orelse return error.TypeError;
    if (view.view_type != .uint8_array) return error.TypeError;
    const capacity: u64 = view.byte_length;

    // Step 5: source as scalar values. A USVString is valid UTF-8, and the
    // UTF-8 encoder's result for each scalar value is its own bytes, so what
    // steps 6.4.1.3-4 write is a prefix of `text`.
    const allocator = instance.ctx.allocator;
    const replaced: ?[]const u8 = if (std.unicode.utf8ValidateSlice(source)) null else try replaceInvalidUtf8(allocator, source);
    defer if (replaced) |r| allocator.free(r);
    const text = replaced orelse source;

    // Steps 1-2: Let read and written be 0.
    var read: u64 = 0;
    var written: u64 = 0;

    // Step 6: While true
    var i: usize = 0;
    while (i < text.len) {
        // Steps 6.1-6.2: the next scalar value, and the encoder's result for it
        // (1-4 bytes; valid UTF-8, so its sequence length is known).
        const bytes_needed = std.unicode.utf8ByteSequenceLength(text[i]) catch unreachable;
        const code_point = std.unicode.utf8Decode(text[i .. i + bytes_needed]) catch unreachable;

        // Step 6.4.2: not enough room left - break.
        if (capacity - written < bytes_needed) break;

        // Step 6.4.1.1-2: a scalar value above U+FFFF is two UTF-16 code units.
        read += if (code_point > 0xFFFF) 2 else 1;

        // Step 6.4.1.4 (the bytes are written below, in one go).
        written += bytes_needed;
        i += bytes_needed;
    }

    // Step 6.4.1.3: write the bytes into destination, from startingOffset 0 -
    // all of them at once, since no script runs in between.
    if (written > 0) try write_into_view(destination, text[0..@intCast(written)], 0);

    // Step 7: Return result
    return .{
        .read = read,
        .written = written,
    };
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Replace invalid UTF-8 sequences with U+FFFD REPLACEMENT CHARACTER
fn replaceInvalidUtf8(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    const replacement = "\u{FFFD}"; // U+FFFD in UTF-8 (3 bytes: EF BF BD)

    var i: usize = 0;
    while (i < input.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            // Invalid start byte - replace with U+FFFD
            try output.appendSlice(replacement);
            i += 1;
            continue;
        };

        if (i + cp_len > input.len) {
            // Incomplete code point at end - replace with U+FFFD
            try output.appendSlice(replacement);
            break;
        }

        // Validate code point
        const cp = std.unicode.utf8Decode(input[i .. i + cp_len]) catch {
            // Invalid code point - replace with U+FFFD
            try output.appendSlice(replacement);
            i += cp_len;
            continue;
        };

        // Valid code point - encode back to UTF-8
        var buf: [4]u8 = undefined;
        const out_len = std.unicode.utf8Encode(cp, &buf) catch unreachable;
        try output.appendSlice(buf[0..out_len]);
        i += cp_len;
    }

    return output.toOwnedSlice();
}

/// A new Uint8Array over a copy of `bytes`, made in the current realm.
/// OWNED: the binding takes it.
fn newUint8Array(instance: *runtime.Instance, bytes: []const u8) !runtime.JSValue {
    const engine = instance.ctx.getEngine() orelse return error.NotImplemented;
    const create_uint8_array = engine.createUint8Array orelse return error.NotSupported;
    const engine_ctx = instance.ctx.getEngineContext() orelse return error.NotImplemented;
    return runtime.JSValue.fromHandle(try create_uint8_array(engine_ctx, bytes));
}
