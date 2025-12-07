//! Implementation for TextDecoderStream interface
//!
//! WHATWG Encoding Standard § 5.3
//! https://encoding.spec.whatwg.org/#interface-textdecoderstream
//!
//! TextDecoderStream takes a stream of bytes and emits decoded strings.
//! It's a transform stream that uses the TextDecoder algorithm.
//!
//! ## Features
//!
//! - **39 Encodings**: Supports all WHATWG encodings (UTF-8, UTF-16, legacy single-byte, CJK, etc.)
//! - **BOM Handling**: Strips byte order marks by default (configurable)
//! - **Error Modes**: Fatal (throws) or replacement (U+FFFD)
//! - **Streaming**: Handles multi-byte sequences split across chunks

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const encoding_mod = @import("encoding");
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
/// WHATWG Encoding Standard § 5.3
/// https://encoding.spec.whatwg.org/#textdecoderstream
///
/// Associated state:
/// - encoding: An encoding
/// - decoder: A decoder instance
/// - I/O queue: An I/O queue of bytes
/// - ignore BOM: A boolean, initially false
/// - BOM seen: A boolean, initially false
/// - error mode: An error mode, initially "replacement"
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The underlying transform stream
    transform: *runtime.Instance,

    /// The encoding (pointer to static Encoding instance)
    enc: *const encoding_mod.Encoding,

    /// The decoder instance for this encoding
    decoder: encoding_mod.Decoder,

    /// Whether to throw on decoding errors (error mode is "fatal")
    fatal: bool,

    /// Whether to ignore BOM (keep it in output)
    ignore_bom: bool,

    /// Pending bytes from previous chunk (I/O queue of bytes)
    pending_bytes: infra.List(u8),

    /// Whether BOM has been seen (for BOM stripping in serialize)
    bom_seen: bool,

    /// Reusable UTF-16 buffer for decoding
    utf16_buffer: ?[]u16,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.pending_bytes.deinit();
        if (self.utf16_buffer) |buf| {
            self.allocator.free(buf);
        }
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
    internal.enc = encoding_mod.UTF_8; // Default, will be set in constructor
    internal.decoder = encoding_mod.UTF_8.newDecoder();
    internal.fatal = false;
    internal.ignore_bom = false;
    internal.pending_bytes = infra.List(u8).init(allocator);
    internal.bom_seen = false;
    internal.utf16_buffer = null;

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
/// WHATWG Encoding Standard § 5.3.1
/// https://encoding.spec.whatwg.org/#dom-textdecoderstream
///
/// The new TextDecoderStream(label, options) constructor steps are:
/// 1. Let encoding be the result of getting an encoding from label.
/// 2. If encoding is failure or replacement, then throw a RangeError.
/// 3. Set this's encoding to encoding.
/// 4. If options["fatal"] is true, then set this's error mode to "fatal".
/// 5. Set this's ignore BOM to options["ignoreBOM"].
/// 6. Set this's decoder to a new instance of this's encoding's decoder,
///    and set this's I/O queue to a new I/O queue.
/// 7. Let transformAlgorithm be an algorithm which takes a chunk argument
///    and runs the decode and enqueue a chunk algorithm with this and chunk.
/// 8. Let flushAlgorithm be an algorithm which takes no arguments and runs
///    the flush and enqueue algorithm with this.
/// 9. Let transformStream be a new TransformStream.
/// 10. Set up transformStream with transformAlgorithm set to transformAlgorithm
///     and flushAlgorithm set to flushAlgorithm.
/// 11. Set this's transform to transformStream.
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, label: webidl.Opt(runtime.DOMString), options: webidl.Opt(dictionaries.TextDecoderOptions)) !*runtime.Instance {
    const instance = try init(allocator, State, &TextDecoderStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Step 1: Get encoding from label
    const label_str = if (label.was_passed) label.value.asSlice() else "utf-8";
    const enc = encoding_mod.getEncoding(label_str) orelse {
        // Step 2: If encoding is failure, throw RangeError
        return error.RangeError;
    };

    // Step 2: If encoding is replacement, throw RangeError
    if (std.mem.eql(u8, enc.whatwg_name, "replacement")) {
        return error.RangeError;
    }

    // Step 3: Set this's encoding to encoding
    internal.enc = enc;

    // Get options value
    const opts = if (options.was_passed) options.value else dictionaries.TextDecoderOptions{};

    // Step 4: If options["fatal"] is true, set error mode to "fatal"
    internal.fatal = opts.fatal orelse false;

    // Step 5: Set this's ignore BOM to options["ignoreBOM"]
    internal.ignore_bom = opts.ignoreBOM orelse false;

    // Step 6: Set this's decoder to a new instance of encoding's decoder
    internal.decoder = enc.newDecoder();

    // Step 7-11: Create the underlying transform stream
    // The transform and flush algorithms are implemented in decodeChunk and flush
    //
    // Per spec, TextDecoderStream uses internal Zig-based transform/flush algorithms,
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

/// Getter for encoding
///
/// Spec: § 5.1.1 "The encoding getter steps are to return this's encoding's name,
/// ASCII lowercased."
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    // Return the WHATWG canonical name (already lowercase)
    return runtime.DOMString.initInterned(internal.enc.whatwg_name);
}

/// Getter for fatal
///
/// Spec: § 5.1.1 "The fatal getter steps are to return true if this's error mode
/// is "fatal"; otherwise false."
pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.fatal;
}

/// Getter for ignoreBOM
///
/// Spec: § 5.1.1 "The ignoreBOM getter steps are to return this's ignore BOM."
pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.ignore_bom;
}

/// Getter for readable
/// (use interface per Golden Rule #13)
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
// Internal Transform Algorithms
// ============================================================================

/// Decode and enqueue a chunk algorithm
///
/// WHATWG Encoding Standard § 5.3.2
/// https://encoding.spec.whatwg.org/#decode-and-enqueue-a-chunk
///
/// The decode and enqueue a chunk algorithm, given a TextDecoderStream object
/// decoder and a chunk, runs these steps:
/// 1. Let bufferSource be the result of converting chunk to an AllowSharedBufferSource.
/// 2. Push a copy of bufferSource to decoder's I/O queue.
/// 3. Let output be the I/O queue of scalar values « end-of-queue ».
/// 4. While true:
///    a. Let item be the result of reading from decoder's I/O queue.
///    b. If item is end-of-queue:
///       i.   Let outputChunk be the result of running serialize I/O queue
///            with decoder and output.
///       ii.  If outputChunk is not the empty string, then enqueue outputChunk
///            in decoder's transform.
///       iii. Return.
///    c. Let result be the result of processing an item with item, decoder's decoder,
///       decoder's I/O queue, output, and decoder's error mode.
///    d. If result is error, then throw a TypeError.
pub fn decodeChunk(internal: *InternalState, input: []const u8) ![]u8 {
    const allocator = internal.allocator;

    // Step 2: Push copy of input to I/O queue (combine with pending bytes)
    var combined = infra.List(u8).init(allocator);
    defer combined.deinit();

    try combined.appendSlice(internal.pending_bytes.slice());
    try combined.appendSlice(input);

    const bytes = combined.slice();

    // Handle empty input
    if (bytes.len == 0) {
        return try allocator.alloc(u8, 0);
    }

    // Allocate UTF-16 output buffer for decoder
    const max_utf16_len = internal.enc.maxUtf16Length(bytes.len);
    const utf16_buf = try getOrAllocUtf16Buffer(internal, max_utf16_len);

    // Step 3-4: Decode bytes through the encoding's decoder
    // The decoder handles the "process an item" algorithm internally
    const result = internal.decoder.decode(bytes, utf16_buf, false); // not last chunk

    // Step 4d: Check for errors in fatal mode
    if (internal.fatal and result.status == .malformed) {
        return error.TypeError;
    }

    // Store incomplete bytes for next chunk (bytes not consumed)
    internal.pending_bytes.clear();
    if (result.bytes_consumed < bytes.len) {
        try internal.pending_bytes.appendSlice(bytes[result.bytes_consumed..]);
    }

    // Step 4b.i: Run serialize I/O queue algorithm
    const utf16_output = utf16_buf[0..result.code_units_written];
    return try serializeIoQueue(internal, utf16_output);
}

/// Flush and enqueue algorithm
///
/// WHATWG Encoding Standard § 5.3.3
/// https://encoding.spec.whatwg.org/#flush-and-enqueue
///
/// The flush and enqueue algorithm, which handles the end of data from the input
/// ReadableStream object, given a TextDecoderStream object decoder, runs these steps:
/// 1. Let output be the I/O queue of scalar values « end-of-queue ».
/// 2. While true:
///    a. Let item be the result of reading from decoder's I/O queue.
///    b. Let result be the result of processing an item with item, decoder's decoder,
///       decoder's I/O queue, output, and decoder's error mode.
///    c. If result is finished:
///       i.   Let outputChunk be the result of running serialize I/O queue
///            with decoder and output.
///       ii.  If outputChunk is not the empty string, then enqueue outputChunk
///            in decoder's transform.
///       iii. Return.
///    d. Otherwise, if result is error, throw a TypeError.
pub fn flush(internal: *InternalState) !?[]u8 {
    const allocator = internal.allocator;

    // If no pending bytes, nothing to flush
    if (internal.pending_bytes.len == 0) {
        return null;
    }

    const bytes = internal.pending_bytes.slice();

    // Allocate UTF-16 buffer for final decode
    const max_utf16_len = internal.enc.maxUtf16Length(bytes.len);
    const utf16_buf = try getOrAllocUtf16Buffer(internal, max_utf16_len);

    // Process remaining bytes with is_last=true
    const result = internal.decoder.decode(bytes, utf16_buf, true);

    // Step 2d: Check for errors in fatal mode
    if (internal.fatal and result.status == .malformed) {
        return error.TypeError;
    }

    // Clear pending bytes
    internal.pending_bytes.clear();

    // Step 2c.i: Serialize the output
    const utf16_output = utf16_buf[0..result.code_units_written];

    // If malformed in replacement mode, the decoder should have emitted U+FFFD
    // We just need to serialize the output
    const output = try serializeIoQueue(internal, utf16_output);

    // Step 2c.ii: Only return non-empty output
    if (output.len == 0) {
        allocator.free(output);
        return null;
    }

    return output;
}

/// Serialize I/O queue algorithm
///
/// WHATWG Encoding Standard § 5.1.1
/// https://encoding.spec.whatwg.org/#serialize-i/o-queue
///
/// The serialize I/O queue algorithm, given a TextDecoderCommon decoder and
/// an I/O queue of scalar values ioQueue, runs these steps:
/// 1. Let output be the empty string.
/// 2. While true:
///    a. Let item be the result of reading from ioQueue.
///    b. If item is end-of-queue, then return output.
///    c. If decoder's encoding is UTF-8 or UTF-16BE/LE, and decoder's ignore BOM
///       and BOM seen are false:
///       i.  Set decoder's BOM seen to true.
///       ii. If item is U+FEFF BOM, then continue.
///    d. Append item to output.
fn serializeIoQueue(internal: *InternalState, utf16_output: []const u16) ![]u8 {
    const allocator = internal.allocator;

    // Fast path: empty output
    if (utf16_output.len == 0) {
        return try allocator.alloc(u8, 0);
    }

    // Check if we need BOM handling
    const needs_bom_check = !internal.ignore_bom and !internal.bom_seen and
        (std.mem.eql(u8, internal.enc.whatwg_name, "utf-8") or
            std.mem.eql(u8, internal.enc.whatwg_name, "utf-16be") or
            std.mem.eql(u8, internal.enc.whatwg_name, "utf-16le"));

    var start_idx: usize = 0;

    // Step 2c: BOM handling for UTF-8 and UTF-16BE/LE
    if (needs_bom_check and utf16_output.len > 0) {
        // Step 2c.i: Set BOM seen to true
        internal.bom_seen = true;

        // Step 2c.ii: If first item is U+FEFF (BOM), skip it
        if (utf16_output[0] == 0xFEFF) {
            start_idx = 1;
        }
    }

    // Convert UTF-16 to UTF-8
    const output_slice = utf16_output[start_idx..];

    // Calculate UTF-8 length
    var utf8_len: usize = 0;
    for (output_slice) |cu| {
        if (cu < 0x80) {
            utf8_len += 1;
        } else if (cu < 0x800) {
            utf8_len += 2;
        } else {
            utf8_len += 3;
        }
    }

    // Allocate and convert to UTF-8
    const utf8_output = try allocator.alloc(u8, utf8_len);
    errdefer allocator.free(utf8_output);

    var idx: usize = 0;
    var i: usize = 0;
    while (i < output_slice.len) {
        const cu = output_slice[i];

        // Handle surrogate pairs
        if (cu >= 0xD800 and cu <= 0xDBFF and i + 1 < output_slice.len) {
            const low = output_slice[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                // Decode surrogate pair to code point
                const cp: u21 = 0x10000 + (@as(u21, cu - 0xD800) << 10) + (low - 0xDC00);
                // Encode as 4-byte UTF-8
                utf8_output[idx] = @intCast(0xF0 | (cp >> 18));
                utf8_output[idx + 1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
                utf8_output[idx + 2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
                utf8_output[idx + 3] = @intCast(0x80 | (cp & 0x3F));
                idx += 4;
                i += 2;
                continue;
            }
        }

        // Single code unit
        if (cu < 0x80) {
            utf8_output[idx] = @intCast(cu);
            idx += 1;
        } else if (cu < 0x800) {
            utf8_output[idx] = @intCast(0xC0 | (cu >> 6));
            utf8_output[idx + 1] = @intCast(0x80 | (cu & 0x3F));
            idx += 2;
        } else {
            utf8_output[idx] = @intCast(0xE0 | (cu >> 12));
            utf8_output[idx + 1] = @intCast(0x80 | ((cu >> 6) & 0x3F));
            utf8_output[idx + 2] = @intCast(0x80 | (cu & 0x3F));
            idx += 3;
        }
        i += 1;
    }

    return utf8_output[0..idx];
}

/// Get or allocate UTF-16 buffer for decoding
fn getOrAllocUtf16Buffer(internal: *InternalState, min_len: usize) ![]u16 {
    if (internal.utf16_buffer) |buf| {
        if (buf.len >= min_len) {
            return buf;
        }
        // Buffer too small, free it
        internal.allocator.free(buf);
        internal.utf16_buffer = null;
    }

    // Allocate new buffer
    const new_buf = try internal.allocator.alloc(u16, min_len);
    internal.utf16_buffer = new_buf;
    return new_buf;
}
