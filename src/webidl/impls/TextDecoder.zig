//! Implementation for TextDecoder interface
//!
//! WHATWG Encoding Standard § 5.1
//! https://encoding.spec.whatwg.org/#interface-textdecoder
//!
//! TextDecoder decodes byte streams into strings using various character encodings.
//!
//! ## Features
//!
//! - **88 Encoding Labels**: Supports UTF-8, UTF-16LE/BE, and all legacy encodings
//! - **BOM Handling**: Strips byte order marks by default (configurable)
//! - **Error Modes**: Fatal (throws) or replacement (U+FFFD)
//! - **Streaming**: Process fragmented input with stream option
//! - **Performance**: ASCII and UTF-8 fast paths for common cases

const std = @import("std");
const runtime = @import("runtime");
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
/// Stores decoder configuration and streaming state
pub const InternalState = struct {
    /// The encoding used by this decoder
    enc: *const Encoding,

    /// do not flush flag (true when stream mode is active)
    do_not_flush: bool,

    /// Whether BOM has been seen in the stream (for ignoreBOM handling)
    bom_seen: bool,

    /// Decoder state for streaming operations
    decoder: ?Decoder,

    /// Pending bytes from incomplete multi-byte sequences (for streaming)
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
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// WHATWG Encoding Standard § 5.1.3
/// https://encoding.spec.whatwg.org/#dom-textdecoder
///
/// Creates a decoder for the specified encoding label with optional configuration.
///
/// The new TextDecoder(label, options) constructor steps are:
/// 1. Let encoding be the result of getting an encoding from label.
/// 2. If encoding is failure or replacement, then throw a RangeError.
/// 3. Set this's encoding to encoding.
/// 4. If options["fatal"] is true, then set this's error mode to "fatal".
/// 5. Set this's ignore BOM to options["ignoreBOM"].
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    label: runtime.DOMString,
    options: dictionaries.TextDecoderOptions,
) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &TextDecoder.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Get label as UTF-8 slice
    const label_str = label.asSlice();

    // Step 1: Get encoding from label (§4.2 get an encoding)
    // https://encoding.spec.whatwg.org/#concept-encoding-get
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

    // Step 3: Set this's encoding to encoding (store WHATWG canonical name)
    // The encoding name is a static string from the encoding module, so we can use interned
    state.own.encoding = runtime.DOMString.initInterned(enc.whatwg_name);

    // Step 4: If options["fatal"] is true, set error mode to "fatal"
    state.own.fatal = options.fatal orelse false;

    // Step 5: Set this's ignore BOM to options["ignoreBOM"]
    state.own.ignoreBOM = options.ignoreBOM orelse false;

    return instance;
}

/// Getter for encoding
/// Returns the encoding name (lowercase ASCII, e.g., "utf-8", "windows-1252")
/// Spec: https://encoding.spec.whatwg.org/#dom-textdecodercommon-encoding
pub fn get_encoding(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const state = instance.getState(State);
    return state.own.encoding;
}

/// Getter for fatal
/// Returns true if decoder throws on errors, false if it uses replacement character
/// Spec: https://encoding.spec.whatwg.org/#dom-textdecodercommon-fatal
pub fn get_fatal(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    return state.own.fatal;
}

/// Getter for ignoreBOM
/// Returns true if BOM is kept in output, false if BOM is stripped
/// Spec: https://encoding.spec.whatwg.org/#dom-textdecodercommon-ignorebom
pub fn get_ignoreBOM(instance: *runtime.Instance) ImplError!bool {
    const state = instance.getState(State);
    return state.own.ignoreBOM;
}

/// decode() operation
/// WHATWG Encoding Standard § 5.1.4
/// https://encoding.spec.whatwg.org/#dom-textdecoder-decode
///
/// Decodes a byte sequence using the configured encoding and returns a USVString.
///
/// The decode(input, options) method steps are:
/// 1. If this's do not flush is false, then set this's decoder to a new decoder
///    for this's encoding's decoder, this's error mode, and this's I/O queue.
/// 2. Set this's do not flush to options["stream"].
/// 3. Let chunk be the result of reading all bytes from input.
/// 4. Let output be the I/O queue of scalar values << output >>.
/// 5. Let result be the result of pushing chunk to this's decoder.
/// 6. If result is error, throw a TypeError.
/// 7. Return output serialized.
pub fn call_decode(
    instance: *runtime.Instance,
    input: typedefs.AllowSharedBufferSource,
    options: dictionaries.TextDecodeOptions,
) ImplError!runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return ImplError.InvalidState;

    // Get streaming option
    const stream = options.stream orelse false;

    // Step 1: If do not flush is false, reset decoder state
    if (!internal.do_not_flush) {
        internal.bom_seen = false;
        internal.decoder = null;
        internal.pending_len = 0;
    }

    // Step 2: Set do not flush to options["stream"]
    internal.do_not_flush = stream;

    // Get bytes from input
    // AllowSharedBufferSource is an opaque pointer that V8 bindings will have populated
    // For now, we interpret it as a pointer to a byte slice descriptor
    // In practice, the V8 binding layer will extract the actual bytes before calling this
    const bytes = extractBytesFromBufferSource(input);

    // Handle empty input (common case for final flush)
    if (bytes.len == 0 and internal.pending_len == 0) {
        // Return empty string
        return "";
    }

    // Process bytes through decoder
    return try decodeBytes(internal, bytes, state.own.fatal, state.own.ignoreBOM, !stream);
}

/// Extract bytes from AllowSharedBufferSource
/// In the actual V8 binding, this would extract bytes from ArrayBuffer/TypedArray
/// For now, we handle it as an opaque pointer that could be:
/// - A direct pointer to bytes with length encoded
/// - A slice descriptor struct
fn extractBytesFromBufferSource(source: typedefs.AllowSharedBufferSource) []const u8 {
    // AllowSharedBufferSource is *const anyopaque
    // The V8 binding layer should have converted the JS typed array to a byte slice
    // and passed it as a pointer to a ByteSlice struct or similar
    //
    // For safety, check for null-like patterns
    // Note: In Zig 0.15+, we can't directly compare pointers to address 0
    // Instead, we check by converting to an integer
    const source_addr = @intFromPtr(source);
    if (source_addr == 0) {
        return "";
    }

    // In a real implementation, the V8 bindings would pass a struct like:
    // struct { ptr: [*]const u8, len: usize }
    // For now, we'll need to handle this based on how the V8 layer passes data
    //
    // Temporary implementation: treat as empty until V8 binding is implemented
    // TODO: Properly extract bytes when V8 TypedArray binding is complete
    //
    // When V8 bindings are implemented, this function should:
    // 1. Check if source is an ArrayBuffer, SharedArrayBuffer, or TypedArray view
    // 2. Extract the underlying byte data and length
    // 3. Return the byte slice
    //
    // The source pointer could be interpreted as:
    // - A V8 persistent handle to a TypedArray
    // - A struct containing { data: [*]const u8, len: usize }
    // - A runtime.Uint8Array or similar wrapper type
    //
    // For now, we attempt to interpret it as a simple pointer to a length-prefixed buffer
    // This is a placeholder that will need to be updated based on actual V8 integration
    const ByteSliceHeader = extern struct {
        len: usize,
        // data follows immediately after
    };

    // Try to interpret as a byte slice header
    // This is unsafe and assumes a specific memory layout from the V8 bindings
    const header: *const ByteSliceHeader = @ptrCast(@alignCast(source));
    if (header.len == 0) {
        return "";
    }

    // Get pointer to data (immediately after header)
    const data_ptr: [*]const u8 = @ptrCast(@as([*]const u8, @ptrCast(source)) + @sizeOf(ByteSliceHeader));
    return data_ptr[0..header.len];
}

/// Decode bytes using the internal decoder state
fn decodeBytes(
    internal: *InternalState,
    input_bytes: []const u8,
    fatal: bool,
    ignoreBOM: bool,
    is_last: bool,
) ImplError!runtime.USVString {
    const allocator = internal.allocator;

    // Combine pending bytes with new input
    var bytes: []const u8 = input_bytes;
    var combined_buffer: ?[]u8 = null;
    defer if (combined_buffer) |buf| allocator.free(buf);

    if (internal.pending_len > 0) {
        combined_buffer = try allocator.alloc(u8, internal.pending_len + input_bytes.len);
        @memcpy(combined_buffer.?[0..internal.pending_len], internal.pending_bytes[0..internal.pending_len]);
        @memcpy(combined_buffer.?[internal.pending_len..], input_bytes);
        bytes = combined_buffer.?;
        internal.pending_len = 0;
    }

    // Handle empty input after combining
    if (bytes.len == 0) {
        return "";
    }

    // Step 4: Handle BOM (if not ignoreBOM and not seen yet)
    if (!ignoreBOM and !internal.bom_seen) {
        bytes = stripBOM(internal, bytes);
    }

    // ASCII FAST PATH: For ASCII-only input with UTF-8 encoding, return as-is
    if (std.mem.eql(u8, internal.enc.whatwg_name, "utf-8") and isAscii(bytes)) {
        // Allocate and copy (caller owns the result)
        const result = try allocator.dupe(u8, bytes);
        return result;
    }

    // UTF-8 FAST PATH: For UTF-8 encoding, validate and return
    if (std.mem.eql(u8, internal.enc.whatwg_name, "utf-8")) {
        return try decodeUtf8(allocator, bytes, fatal, is_last, internal);
    }

    // GENERAL PATH: Use encoding infrastructure to decode
    // Create or reuse decoder
    if (internal.decoder == null) {
        internal.decoder = internal.enc.newDecoder();
    }

    // Allocate UTF-16 output buffer
    const max_utf16_len = internal.enc.maxUtf16Length(bytes.len);
    const utf16_buf = try getOrAllocUtf16Buffer(internal, max_utf16_len);

    // Decode bytes → UTF-16
    const result = internal.decoder.?.decode(bytes, utf16_buf, is_last);

    // Handle decoding errors in fatal mode
    if (fatal and result.status == .malformed) {
        return ImplError.DecodingError;
    }

    // Handle incomplete sequences in streaming mode
    if (!is_last and result.status == .input_empty and result.bytes_consumed < bytes.len) {
        // Save remaining bytes for next call
        const remaining = bytes.len - result.bytes_consumed;
        if (remaining <= 4) {
            @memcpy(internal.pending_bytes[0..remaining], bytes[result.bytes_consumed..]);
            internal.pending_len = @intCast(remaining);
        }
    }

    // Convert UTF-16 → UTF-8 for output
    const utf16_output = utf16_buf[0..result.code_units_written];
    const utf8_output = try infra.string.utf16ToUtf8(allocator, utf16_output);

    return utf8_output;
}

/// Check if byte slice is ASCII-only (fast path optimization)
fn isAscii(bytes: []const u8) bool {
    // Use SIMD-optimized version from infra
    return infra.string.isAscii(bytes);
}

/// Strip BOM (Byte Order Mark) from input bytes
/// WHATWG Encoding Standard § 5.1.4 step 4
fn stripBOM(internal: *InternalState, bytes: []const u8) []const u8 {
    // UTF-8 BOM: EF BB BF (3 bytes)
    if (std.mem.eql(u8, internal.enc.whatwg_name, "utf-8")) {
        if (bytes.len >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF) {
            internal.bom_seen = true;
            return bytes[3..];
        }
    }
    // UTF-16LE BOM: FF FE (2 bytes)
    else if (std.mem.eql(u8, internal.enc.whatwg_name, "utf-16le")) {
        if (bytes.len >= 2 and bytes[0] == 0xFF and bytes[1] == 0xFE) {
            internal.bom_seen = true;
            return bytes[2..];
        }
    }
    // UTF-16BE BOM: FE FF (2 bytes)
    else if (std.mem.eql(u8, internal.enc.whatwg_name, "utf-16be")) {
        if (bytes.len >= 2 and bytes[0] == 0xFE and bytes[1] == 0xFF) {
            internal.bom_seen = true;
            return bytes[2..];
        }
    }

    // No BOM found or encoding doesn't use BOM
    return bytes;
}

/// Decode UTF-8 bytes with validation
/// WHATWG Encoding Standard § 5.1.4 step 5 (UTF-8 fast path)
fn decodeUtf8(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    fatal: bool,
    is_last: bool,
    internal: *InternalState,
) ImplError![]const u8 {
    // Validate UTF-8 encoding
    if (std.unicode.utf8ValidateSlice(bytes)) {
        // Valid UTF-8 - return a copy
        return allocator.dupe(u8, bytes) catch return ImplError.OutOfMemory;
    }

    // Find where validation fails for streaming support
    if (!is_last) {
        // In streaming mode, check if failure is due to incomplete sequence at end
        var i: usize = 0;
        while (i < bytes.len) {
            const len = std.unicode.utf8ByteSequenceLength(bytes[i]) catch {
                // Invalid start byte
                break;
            };

            if (i + len > bytes.len) {
                // Incomplete sequence at end - save for next call
                const remaining = bytes.len - i;
                if (remaining <= 4) {
                    @memcpy(internal.pending_bytes[0..remaining], bytes[i..]);
                    internal.pending_len = @intCast(remaining);
                    // Return valid portion
                    if (i > 0) {
                        return allocator.dupe(u8, bytes[0..i]) catch return ImplError.OutOfMemory;
                    }
                    return "";
                }
                break;
            }

            // Validate the sequence
            _ = std.unicode.utf8Decode(bytes[i .. i + len]) catch {
                break;
            };

            i += len;
        }
    }

    // Invalid UTF-8
    if (fatal) {
        return ImplError.DecodingError;
    }

    // Non-fatal mode: Replace invalid sequences with U+FFFD (replacement character)
    // U+FFFD in UTF-8 is: EF BF BD
    const replacement = "\u{FFFD}";

    // Allocate output buffer using infra.List (worst case: every byte is invalid = 3x size)
    var output = infra.List(u8).init(allocator);
    errdefer output.deinit();

    var i: usize = 0;
    while (i < bytes.len) {
        // Try to decode one codepoint
        const cp_len = std.unicode.utf8ByteSequenceLength(bytes[i]) catch {
            // Invalid start byte - replace with U+FFFD
            output.appendSlice(replacement) catch return ImplError.OutOfMemory;
            i += 1;
            continue;
        };

        // Check if we have enough bytes
        if (i + cp_len > bytes.len) {
            if (!is_last) {
                // Save incomplete sequence for next call
                const remaining = bytes.len - i;
                if (remaining <= 4) {
                    @memcpy(internal.pending_bytes[0..remaining], bytes[i..]);
                    internal.pending_len = @intCast(remaining);
                    break;
                }
            }
            // In final mode or too many pending bytes - replace with U+FFFD
            output.appendSlice(replacement) catch return ImplError.OutOfMemory;
            i += 1;
            continue;
        }

        // Validate the sequence
        _ = std.unicode.utf8Decode(bytes[i .. i + cp_len]) catch {
            // Invalid sequence - replace with U+FFFD
            output.appendSlice(replacement) catch return ImplError.OutOfMemory;
            i += 1;
            continue;
        };

        // Valid codepoint - copy the bytes
        output.appendSlice(bytes[i .. i + cp_len]) catch return ImplError.OutOfMemory;
        i += cp_len;
    }

    return output.toOwnedSlice() catch return ImplError.OutOfMemory;
}

/// Get or allocate UTF-16 buffer for decoding
fn getOrAllocUtf16Buffer(internal: *InternalState, min_len: usize) ![]u16 {
    if (internal.reusable_utf16_buffer) |buf| {
        if (buf.len >= min_len) {
            return buf;
        }
        // Buffer too small, free it
        internal.allocator.free(buf);
        internal.reusable_utf16_buffer = null;
    }

    // Allocate new buffer
    const new_buf = try internal.allocator.alloc(u16, min_len);
    internal.reusable_utf16_buffer = new_buf;
    return new_buf;
}
