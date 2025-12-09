//! Implementation for TextDecoder interface
//!
//! WHATWG Encoding Standard § 5.1
//! https://encoding.spec.whatwg.org/#interface-textdecoder
//!
//! TextDecoder decodes byte streams into strings using various character encodings.
//!
//! ## Features
//!
//! - **39 Encodings**: Supports UTF-8, UTF-16LE/BE, and all legacy encodings
//! - **BOM Handling**: Strips byte order marks by default (configurable via ignoreBOM)
//! - **Error Modes**: Fatal (throws) or replacement (U+FFFD)
//! - **Streaming**: Process fragmented input with stream option
//! - **Performance**: ASCII and UTF-8 fast paths for common cases
//!
//! ## Spec Compliance Notes
//!
//! The decode() method follows the spec exactly:
//! 1. Reset state when not in streaming mode (do not flush = false)
//! 2. Process bytes through encoding's decoder
//! 3. Run "serialize I/O queue" algorithm which handles BOM stripping
//!
//! BOM handling is done in the serialize step, not during decoding:
//! - For UTF-8 and UTF-16BE/LE encodings
//! - If ignore BOM is false and BOM seen is false
//! - First U+FEFF in decoded output is stripped (not passed through)

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const infra = @import("infra");
const encoding_mod = @import("encoding");

const TextDecoder = interfaces.TextDecoder;
const Encoding = encoding_mod.Encoding;
const Decoder = encoding_mod.Decoder;

pub const State = TextDecoder.State;

pub const ImplError = error{
    /// Invalid encoding label → WebIDL RangeError
    InvalidEncoding,
    /// Replacement encoding not supported → WebIDL RangeError
    ReplacementEncoding,
    /// Fatal decoding error → WebIDL TypeError
    DecodingError,
    /// Out of memory
    OutOfMemory,
    /// Invalid state
    InvalidState,
    /// Type error for invalid input
    TypeError,
    /// Invalid UTF-8 (from infra string conversion)
    InvalidUtf8,
    /// Invalid UTF-16 (from infra string conversion)
    InvalidUtf16,
    /// Invalid code point (from infra string conversion)
    InvalidCodePoint,
};

/// Internal state for TextDecoder implementation
///
/// WHATWG Encoding Standard § 5.1.1 TextDecoderCommon
/// Associated state:
/// - encoding: An encoding
/// - decoder: A decoder instance
/// - I/O queue: An I/O queue of bytes
/// - ignore BOM: A boolean, initially false
/// - BOM seen: A boolean, initially false
/// - error mode: An error mode, initially "replacement"
pub const InternalState = struct {
    /// The encoding used by this decoder
    enc: *const Encoding,

    /// do not flush flag (true when stream mode is active)
    /// Spec: "A TextDecoder object has an associated do not flush, which is a boolean, initially false."
    do_not_flush: bool,

    /// Whether BOM has been seen in the stream (for serialize I/O queue algorithm)
    /// Spec: "BOM seen: A boolean, initially false"
    bom_seen: bool,

    /// Decoder instance for streaming operations
    /// Spec: "decoder: A decoder instance"
    decoder: ?Decoder,

    /// I/O queue of bytes - pending bytes from incomplete multi-byte sequences
    /// Spec: "I/O queue: An I/O queue of bytes"
    pending_bytes: [4]u8,
    pending_len: u8,

    /// Reusable buffer for UTF-16 output (performance optimization)
    reusable_utf16_buffer: ?[]u16,

    /// Memory allocator for internal buffers
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        if (self.reusable_utf16_buffer) |buf| {
            self.allocator.free(buf);
        }
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
///
/// WHATWG Encoding Standard § 5.1.3
/// https://encoding.spec.whatwg.org/#dom-textdecoder
///
/// The new TextDecoder(label, options) constructor steps are:
/// 1. Let encoding be the result of getting an encoding from label.
/// 2. If encoding is failure or replacement, then throw a RangeError.
/// 3. Set this's encoding to encoding.
/// 4. If options["fatal"] is true, then set this's error mode to "fatal".
/// 5. Set this's ignore BOM to options["ignoreBOM"].
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, label: webidl.Opt(runtime.DOMString), options: webidl.Opt(dictionaries.TextDecoderOptions)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &TextDecoder.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Get label as UTF-8 slice
    const label_str = if (label.was_passed) label.value.asSlice() else "utf-8";

    // Step 1: Get encoding from label (§4.2 get an encoding)
    const enc = encoding_mod.getEncoding(label_str) orelse {
        // Step 2: If encoding is failure, throw RangeError
        return ImplError.InvalidEncoding;
    };

    // Step 2: If encoding is replacement, throw RangeError
    if (std.mem.eql(u8, enc.whatwg_name, "replacement")) {
        return ImplError.ReplacementEncoding;
    }

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .enc = enc,
        .do_not_flush = false,
        .bom_seen = false,
        .decoder = null,
        .pending_bytes = undefined,
        .pending_len = 0,
        .reusable_utf16_buffer = null,
        .allocator = allocator,
    };

    state.own._internal = internal;

    // Step 3: Set this's encoding to encoding
    state.own.encoding = runtime.DOMString.initInterned(enc.whatwg_name);

    // Get options value
    const opts = if (options.was_passed) options.value else dictionaries.TextDecoderOptions{};

    // Step 4: If options["fatal"] is true, set error mode to "fatal"
    state.own.fatal = opts.fatal orelse false;

    // Step 5: Set this's ignore BOM to options["ignoreBOM"]
    state.own.ignoreBOM = opts.ignoreBOM orelse false;

    return instance;
}

/// Getter for encoding
/// Spec: "The encoding getter steps are to return this's encoding's name, ASCII lowercased."
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.encoding;
}

/// Getter for fatal
/// Spec: "The fatal getter steps are to return true if this's error mode is "fatal"; otherwise false."
pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.fatal;
}

/// Getter for ignoreBOM
/// Spec: "The ignoreBOM getter steps are to return this's ignore BOM."
pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    return state.own.ignoreBOM;
}

/// decode() operation
///
/// WHATWG Encoding Standard § 5.1.4
/// https://encoding.spec.whatwg.org/#dom-textdecoder-decode
///
/// The decode(input, options) method steps are:
/// 1. If this's do not flush is false, then set this's decoder to a new instance of
///    this's encoding's decoder, this's I/O queue to the I/O queue of bytes
///    « end-of-queue », and this's BOM seen to false.
/// 2. Set this's do not flush to options["stream"].
/// 3. If input is given, then push a copy of input to this's I/O queue.
/// 4. Let output be the I/O queue of scalar values « end-of-queue ».
/// 5. While true:
///    a. Let item be the result of reading from this's I/O queue.
///    b. If item is end-of-queue and this's do not flush is true, then return
///       the result of running serialize I/O queue with this and output.
///    c. Otherwise:
///       i.   Let result be the result of processing an item with item, this's
///            decoder, this's I/O queue, output, and this's error mode.
///       ii.  If result is finished, then return the result of running
///            serialize I/O queue with this and output.
///       iii. Otherwise, if result is error, throw a TypeError.
pub fn call_decode(instance: *runtime.Instance, input: webidl.Opt(typedefs.AllowSharedBufferSource), options: webidl.Opt(dictionaries.TextDecodeOptions)) anyerror!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return ImplError.InvalidState;

    // Get streaming option
    const opts = if (options.was_passed) options.value else dictionaries.TextDecodeOptions{};
    const stream = opts.stream orelse false;

    // Step 1: If do not flush is false, reset decoder state
    if (!internal.do_not_flush) {
        internal.bom_seen = false;
        internal.decoder = internal.enc.newDecoder();
        internal.pending_len = 0;
    }

    // Step 2: Set do not flush to options["stream"]
    internal.do_not_flush = stream;

    // Step 3: Get bytes from input and add to I/O queue
    // If input was not passed, use empty byte slice
    const input_bytes: []const u8 = if (input.was_passed) extractBytesFromBufferSource(input.value) else &[_]u8{};

    // IMPORTANT: Free the AllowSharedBufferSource after we're done with the bytes
    // The V8 conversion allocates an ArrayBuffer struct and data that must be freed
    defer if (input.was_passed) freeBufferSource(instance.ctx.allocator, input.value);

    // Combine pending bytes (I/O queue) with new input
    var bytes: []const u8 = input_bytes;
    var combined_buffer: ?[]u8 = null;
    defer if (combined_buffer) |buf| internal.allocator.free(buf);

    if (internal.pending_len > 0) {
        combined_buffer = try internal.allocator.alloc(u8, internal.pending_len + input_bytes.len);
        @memcpy(combined_buffer.?[0..internal.pending_len], internal.pending_bytes[0..internal.pending_len]);
        @memcpy(combined_buffer.?[internal.pending_len..], input_bytes);
        bytes = combined_buffer.?;
        internal.pending_len = 0;
    }

    // Handle empty input (common case for final flush)
    if (bytes.len == 0) {
        if (stream) {
            // Step 5a-b: End-of-queue with do not flush = true
            return "";
        }
        // Final decode with no input - serialize empty output
        return "";
    }

    // Step 4-5: Process bytes through decoder and serialize
    const is_last = !stream;
    // IMPORTANT: Use instance.ctx.allocator for returned strings, not internal.allocator
    // The V8 binding layer expects to free returned strings with instance.ctx.allocator
    return try processAndSerialize(internal, instance.ctx.allocator, bytes, state.own.fatal, state.own.ignoreBOM, is_last);
}

/// Extract bytes from AllowSharedBufferSource
fn extractBytesFromBufferSource(source: typedefs.AllowSharedBufferSource) []const u8 {
    // AllowSharedBufferSource is a tagged union - use its asBytes method
    return source.asBytes() catch return &[_]u8{};
}

/// Free an AllowSharedBufferSource that was allocated during V8 conversion
///
/// For most V8 conversions, we now use a non-owning byte_slice variant that
/// doesn't require any cleanup. This function handles cleanup for cases where
/// actual allocation occurred.
fn freeBufferSource(allocator: std.mem.Allocator, source: typedefs.AllowSharedBufferSource) void {
    switch (source) {
        .array_buffer => |buf| {
            // Free the data array (unless it's empty - indicated by ptr being null or len being 0)
            if (buf.data.len > 0) {
                allocator.free(buf.data);
            }
            // Free the ArrayBuffer struct itself
            allocator.destroy(buf);
        },
        .shared_array_buffer => |buf| {
            // SharedArrayBuffer uses its own deinit which handles aligned deallocation
            var mutable_buf = buf;
            mutable_buf.deinit();
            // Note: The SharedArrayBuffer struct itself may need freeing if it was heap-allocated
            // For now, we assume it manages its own memory via its stored allocator
        },
        .array_buffer_view => {
            // ArrayBufferView references an existing buffer, doesn't own the memory
            // Nothing to free here
        },
        .byte_slice => {
            // Non-owning view into V8 buffer - nothing to free
            // The V8 GC manages the underlying buffer lifetime
        },
    }
}

/// Process bytes through decoder and run serialize I/O queue algorithm
///
/// @param output_allocator: Allocator for the returned string (must be instance.ctx.allocator)
fn processAndSerialize(
    internal: *InternalState,
    output_allocator: std.mem.Allocator,
    bytes: []const u8,
    fatal: bool,
    ignore_bom: bool,
    is_last: bool,
) ImplError!runtime.USVString {
    // ASCII FAST PATH: For ASCII-only input with UTF-8 encoding
    if (std.mem.eql(u8, internal.enc.whatwg_name, "utf-8") and infra.string.isAscii(bytes)) {
        // ASCII can't contain BOM, so just return as-is
        return output_allocator.dupe(u8, bytes) catch return ImplError.OutOfMemory;
    }

    // Get or create decoder
    if (internal.decoder == null) {
        internal.decoder = internal.enc.newDecoder();
    }

    // OPTIMIZATION: Use direct UTF-8 decode path when available
    // This eliminates the intermediate UTF-16 buffer and conversion step
    if (internal.enc.supportsDirectUtf8Decode()) {
        return try processAndSerializeDirectUtf8(internal, output_allocator, bytes, fatal, ignore_bom, is_last);
    }

    // FALLBACK: Use UTF-16 intermediate path for encodings without direct UTF-8 support
    return try processAndSerializeViaUtf16(internal, output_allocator, bytes, fatal, ignore_bom, is_last);
}

/// Direct UTF-8 decode path - decodes directly to UTF-8 without UTF-16 intermediate
///
/// This provides significant performance improvement for legacy encodings by:
/// 1. Eliminating UTF-16 buffer allocation
/// 2. Eliminating UTF-16 to UTF-8 conversion pass
fn processAndSerializeDirectUtf8(
    internal: *InternalState,
    output_allocator: std.mem.Allocator,
    bytes: []const u8,
    fatal: bool,
    ignore_bom: bool,
    is_last: bool,
) ImplError!runtime.USVString {
    // Handle empty input
    if (bytes.len == 0) {
        return output_allocator.alloc(u8, 0) catch return ImplError.OutOfMemory;
    }

    // Allocate UTF-8 output buffer based on encoding's max expansion
    const max_utf8_len = internal.enc.maxUtf8LengthForInput(bytes.len);
    const utf8_buf = output_allocator.alloc(u8, max_utf8_len) catch return ImplError.OutOfMemory;
    // NOTE: No errdefer here! serializeUtf8Output takes ownership of utf8_buf
    // and is responsible for freeing it in ALL paths (success and error).
    // Using errdefer here would cause double-free when serializeUtf8Output
    // frees the buffer on error and then errdefer fires.

    var input_pos: usize = 0;
    var output_pos: usize = 0;

    while (input_pos < bytes.len) {
        const remaining_input = bytes[input_pos..];
        const remaining_output = utf8_buf[output_pos..];

        const result = internal.decoder.?.decodeToUtf8(remaining_input, remaining_output, is_last and input_pos + remaining_input.len == bytes.len);

        // Bounds check: ensure bytes_written doesn't exceed remaining output buffer
        // This prevents buffer overflow if decoder returns incorrect value
        const safe_bytes_written = @min(result.bytes_written, remaining_output.len);
        output_pos += safe_bytes_written;
        input_pos += result.bytes_consumed;

        if (result.status == .malformed) {
            if (fatal) {
                output_allocator.free(utf8_buf);
                return ImplError.DecodingError;
            }
            // Replacement mode: emit U+FFFD (0xEF 0xBF 0xBD in UTF-8)
            if (output_pos + 3 <= utf8_buf.len) {
                utf8_buf[output_pos] = 0xEF;
                utf8_buf[output_pos + 1] = 0xBF;
                utf8_buf[output_pos + 2] = 0xBD;
                output_pos += 3;
            }
            // Skip the malformed byte(s)
            const skip = if (result.error_length > 0) result.error_length else 1;
            input_pos += skip;
            // Reset decoder state after error
            internal.decoder = internal.enc.newDecoder();
        } else if (result.status == .input_empty) {
            break;
        } else if (result.status == .output_full) {
            break;
        }
    }

    // Handle incomplete sequences in streaming mode
    if (!is_last and input_pos < bytes.len) {
        const remaining = bytes.len - input_pos;
        if (remaining <= 4) {
            @memcpy(internal.pending_bytes[0..remaining], bytes[input_pos..]);
            internal.pending_len = @intCast(remaining);
        }
    }

    // Handle BOM stripping for UTF-8 and UTF-16 encodings
    // serializeUtf8Output takes ownership of utf8_buf - DO NOT free it here
    const utf8_output = utf8_buf[0..output_pos];
    return serializeUtf8Output(internal, output_allocator, utf8_buf, utf8_output, ignore_bom);
}

/// Fallback path using UTF-16 intermediate buffer
fn processAndSerializeViaUtf16(
    internal: *InternalState,
    output_allocator: std.mem.Allocator,
    bytes: []const u8,
    fatal: bool,
    ignore_bom: bool,
    is_last: bool,
) ImplError!runtime.USVString {
    // Allocate UTF-16 output buffer
    const max_utf16_len = internal.enc.maxUtf16Length(bytes.len);
    const utf16_buf = try getOrAllocUtf16Buffer(internal, max_utf16_len);

    // Step 5c.i: Process bytes through decoder (process an item algorithm)
    // Loop to handle malformed bytes in replacement mode
    var input_pos: usize = 0;
    var output_pos: usize = 0;

    while (input_pos < bytes.len) {
        const remaining_input = bytes[input_pos..];
        const remaining_output = utf16_buf[output_pos..];

        const result = internal.decoder.?.decode(remaining_input, remaining_output, is_last and input_pos + remaining_input.len == bytes.len);

        // Add decoded output
        output_pos += result.code_units_written;
        input_pos += result.bytes_consumed;

        if (result.status == .malformed) {
            // Step 5c.iii: Handle decoding errors based on error mode
            if (fatal) {
                return ImplError.DecodingError;
            }
            // Replacement mode: emit U+FFFD and skip the bad byte(s)
            if (output_pos < utf16_buf.len) {
                utf16_buf[output_pos] = 0xFFFD;
                output_pos += 1;
            }
            // Skip the malformed byte(s)
            const skip = if (result.error_length > 0) result.error_length else 1;
            input_pos += skip;
            // Reset decoder state after error
            internal.decoder = internal.enc.newDecoder();
        } else if (result.status == .input_empty) {
            // All input consumed
            break;
        } else if (result.status == .output_full) {
            // Output buffer full - shouldn't happen with our sizing
            break;
        }
    }

    // Handle incomplete sequences in streaming mode
    if (!is_last and input_pos < bytes.len) {
        const remaining = bytes.len - input_pos;
        if (remaining <= 4) {
            @memcpy(internal.pending_bytes[0..remaining], bytes[input_pos..]);
            internal.pending_len = @intCast(remaining);
        }
    }

    // Step 5b/5c.ii: Run serialize I/O queue algorithm
    const utf16_output = utf16_buf[0..output_pos];
    return try serializeIoQueue(internal, output_allocator, utf16_output, ignore_bom);
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
fn serializeIoQueue(
    internal: *InternalState,
    output_allocator: std.mem.Allocator,
    utf16_output: []const u16,
    ignore_bom: bool,
) ImplError![]u8 {
    // Fast path: empty output
    if (utf16_output.len == 0) {
        return output_allocator.alloc(u8, 0) catch return ImplError.OutOfMemory;
    }

    // Step 2c: Check if we need BOM handling
    // Only for UTF-8 and UTF-16BE/LE encodings
    const needs_bom_check = !ignore_bom and !internal.bom_seen and
        (std.mem.eql(u8, internal.enc.whatwg_name, "utf-8") or
            std.mem.eql(u8, internal.enc.whatwg_name, "utf-16be") or
            std.mem.eql(u8, internal.enc.whatwg_name, "utf-16le"));

    var start_idx: usize = 0;

    if (needs_bom_check and utf16_output.len > 0) {
        // Step 2c.i: Set BOM seen to true (for first scalar value)
        internal.bom_seen = true;

        // Step 2c.ii: If first item is U+FEFF (BOM), skip it
        if (utf16_output[0] == 0xFEFF) {
            start_idx = 1;
        }
    }

    // Step 1 & 2d: Build output string
    const output_slice = utf16_output[start_idx..];

    // Convert UTF-16 to UTF-8
    return utf16ToUtf8(output_allocator, output_slice) catch return ImplError.OutOfMemory;
}

/// Serialize UTF-8 output with BOM handling
///
/// Similar to serializeIoQueue but for direct UTF-8 output.
/// Handles BOM stripping for UTF-8 and UTF-16 encodings.
///
/// OWNERSHIP: This function takes ownership of full_buffer and is responsible for freeing it.
/// The caller's errdefer should NOT free full_buffer after calling this function.
fn serializeUtf8Output(
    internal: *InternalState,
    output_allocator: std.mem.Allocator,
    full_buffer: []u8,
    utf8_output: []const u8,
    ignore_bom: bool,
) ImplError![]u8 {
    // Fast path: empty output
    if (utf8_output.len == 0) {
        output_allocator.free(full_buffer);
        // Return empty slice - don't allocate, just return a zero-length slice
        // This avoids potential OOM on a zero-length allocation
        return &[_]u8{};
    }

    // Check if we need BOM handling (only for UTF-8 and UTF-16BE/LE)
    const needs_bom_check = !ignore_bom and !internal.bom_seen and
        (std.mem.eql(u8, internal.enc.whatwg_name, "utf-8") or
            std.mem.eql(u8, internal.enc.whatwg_name, "utf-16be") or
            std.mem.eql(u8, internal.enc.whatwg_name, "utf-16le"));

    var start_idx: usize = 0;

    if (needs_bom_check and utf8_output.len >= 3) {
        // Set BOM seen to true
        internal.bom_seen = true;

        // Check for UTF-8 BOM (EF BB BF = U+FEFF)
        if (utf8_output[0] == 0xEF and utf8_output[1] == 0xBB and utf8_output[2] == 0xBF) {
            start_idx = 3;
        }
    }

    // Return the appropriate slice
    if (start_idx == 0) {
        // No BOM to strip - shrink buffer to exact size and return
        if (utf8_output.len < full_buffer.len) {
            // Reallocate to exact size - free original first to avoid double-free on OOM
            const result = output_allocator.dupe(u8, utf8_output) catch {
                output_allocator.free(full_buffer);
                return ImplError.OutOfMemory;
            };
            output_allocator.free(full_buffer);
            return result;
        }
        // Buffer is exactly the right size - return it directly (transfer ownership)
        return @constCast(utf8_output);
    } else {
        // BOM stripped - allocate new buffer with remaining content
        const output_slice = utf8_output[start_idx..];
        const result = output_allocator.dupe(u8, output_slice) catch {
            output_allocator.free(full_buffer);
            return ImplError.OutOfMemory;
        };
        output_allocator.free(full_buffer);
        return result;
    }
}

/// Convert UTF-16 code units to UTF-8 bytes
fn utf16ToUtf8(allocator: std.mem.Allocator, utf16: []const u16) ![]u8 {
    if (utf16.len == 0) {
        return allocator.alloc(u8, 0);
    }

    // Calculate UTF-8 length (including surrogate pairs)
    var utf8_len: usize = 0;
    var i: usize = 0;
    while (i < utf16.len) {
        const cu = utf16[i];

        // Check for surrogate pair
        if (cu >= 0xD800 and cu <= 0xDBFF and i + 1 < utf16.len) {
            const low = utf16[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                // Surrogate pair -> 4-byte UTF-8
                utf8_len += 4;
                i += 2;
                continue;
            }
        }

        // Single code unit
        if (cu < 0x80) {
            utf8_len += 1;
        } else if (cu < 0x800) {
            utf8_len += 2;
        } else {
            utf8_len += 3;
        }
        i += 1;
    }

    // Allocate and convert
    const output = try allocator.alloc(u8, utf8_len);
    errdefer allocator.free(output);

    var idx: usize = 0;
    i = 0;
    while (i < utf16.len) {
        const cu = utf16[i];

        // Handle surrogate pairs
        if (cu >= 0xD800 and cu <= 0xDBFF and i + 1 < utf16.len) {
            const low = utf16[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                // Decode surrogate pair to code point
                const cp: u21 = 0x10000 + (@as(u21, cu - 0xD800) << 10) + (low - 0xDC00);
                // Encode as 4-byte UTF-8
                output[idx] = @intCast(0xF0 | (cp >> 18));
                output[idx + 1] = @intCast(0x80 | ((cp >> 12) & 0x3F));
                output[idx + 2] = @intCast(0x80 | ((cp >> 6) & 0x3F));
                output[idx + 3] = @intCast(0x80 | (cp & 0x3F));
                idx += 4;
                i += 2;
                continue;
            }
        }

        // Single code unit
        if (cu < 0x80) {
            output[idx] = @intCast(cu);
            idx += 1;
        } else if (cu < 0x800) {
            output[idx] = @intCast(0xC0 | (cu >> 6));
            output[idx + 1] = @intCast(0x80 | (cu & 0x3F));
            idx += 2;
        } else {
            output[idx] = @intCast(0xE0 | (cu >> 12));
            output[idx + 1] = @intCast(0x80 | ((cu >> 6) & 0x3F));
            output[idx + 2] = @intCast(0x80 | (cu & 0x3F));
            idx += 3;
        }
        i += 1;
    }

    return output[0..idx];
}

/// Get or allocate UTF-16 buffer for decoding
fn getOrAllocUtf16Buffer(internal: *InternalState, min_len: usize) ![]u16 {
    if (internal.reusable_utf16_buffer) |buf| {
        if (buf.len >= min_len) {
            return buf;
        }
        internal.allocator.free(buf);
        internal.reusable_utf16_buffer = null;
    }

    const new_buf = try internal.allocator.alloc(u16, min_len);
    internal.reusable_utf16_buffer = new_buf;
    return new_buf;
}
