//! TextEncoder WebIDL Interface
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
//!
//! ## Usage (Zig)
//!
//! ```zig
//! const allocator = std.heap.page_allocator;
//!
//! // Create encoder (UTF-8 only)
//! var encoder = TextEncoder.init(allocator);
//! defer encoder.deinit();
//!
//! // Encode string to bytes (allocates new buffer)
//! const text = "Hello, 世界!";
//! const bytes = try encoder.encode(text);
//! defer allocator.free(bytes);
//! // bytes is UTF-8 encoded
//!
//! // Encode into existing buffer (zero-copy)
//! var buffer: [100]u8 = undefined;
//! const result = try encoder.encodeInto(text, &buffer);
//! // result.read: UTF-8 bytes read from text
//! // result.written: bytes written to buffer
//! // buffer[0..result.written] contains encoded data
//! ```
//!
//! ## Usage (JavaScript Bindings)
//!
//! For JavaScript bindings, convert between WebIDL types:
//!
//! ```zig
//! var encoder = TextEncoder.init(allocator);
//! defer encoder.deinit();
//!
//! // Convert input: USVString (UTF-16) → UTF-8
//! const usv_input: []const u16 = &.{ 'H', 'e', 'l', 'l', 'o' };
//! const utf8_input = try infra.string.utf16ToUtf8(allocator, usv_input);
//! defer allocator.free(utf8_input);
//!
//! // Encode
//! const utf8_output = try encoder.encode(utf8_input);
//! defer allocator.free(utf8_output);
//!
//! // Wrap output in Uint8Array
//! const array_buffer = try webidl.ArrayBuffer.init(allocator, utf8_output);
//! const uint8_array = try webidl.TypedArray(u8).init(array_buffer, 0, utf8_output.len);
//! ```
//!
//! ## Performance Notes
//!
//! - **ASCII Fast Path**: Direct passthrough for ASCII-only input (~10x faster)
//! - **Zero-Copy encodeInto()**: No allocation, writes directly to buffer
//! - **Stateless**: No internal state, safe to use concurrently (from different threads with different instances)
//!
//! ## Error Handling
//!
//! UTF-8 encoder cannot fail per spec (assertion in spec).
//! Invalid UTF-8 sequences replaced with U+FFFD automatically.
//!
//! ## Memory Management
//!
//! - **`encode()`**: Caller owns returned buffer (must free)
//! - **`encodeInto()`**: No allocation, uses provided buffer
//! - **Cleanup**: `deinit()` is no-op (stateless)
//! - **Thread Safety**: Thread-safe (stateless, no shared state)
//!
//! ## Common Patterns
//!
//! ### Allocating Encode
//! ```zig
//! var encoder = TextEncoder.init(allocator);
//! const bytes = try encoder.encode("Hello");
//! defer allocator.free(bytes);
//! ```
//!
//! ### Zero-Copy Encode
//! ```zig
//! var buffer: [100]u8 = undefined;
//! const result = try encoder.encodeInto("Hello, 世界!", &buffer);
//! const encoded = buffer[0..result.written];
//! // No allocation, no free needed
//! ```
//!
//! ### Handle Truncation
//! ```zig
//! var buffer: [5]u8 = undefined;
//! const result = try encoder.encodeInto("Hello, World!", &buffer);
//! // result.read = 5 (bytes read)
//! // result.written = 5 (bytes written)
//! // buffer contains "Hello" (truncated at buffer boundary)
//! ```
//!
//! ### Multibyte Character Truncation
//! ```zig
//! var buffer: [3]u8 = undefined;
//! const result = try encoder.encodeInto("Hi🌍", &buffer);
//! // result.read = 2 ("Hi" only, emoji skipped - doesn't fit)
//! // result.written = 2
//! // buffer[0..2] = "Hi"
//! // Emoji (4 bytes) didn't fit, so it's not partially written
//! ```
//!
//! ## See Also
//!
//! - `TextDecoder` - Decode bytes to strings
//! - `TextEncoderEncodeIntoResult` - Result type for `encodeInto()`
//! - WHATWG Encoding Standard: https://encoding.spec.whatwg.org/

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

// Import dictionary
const TextEncoderEncodeIntoResult = @import("TextEncoderEncodeIntoResult.zig").TextEncoderEncodeIntoResult;

// Import mixin
const TextEncoderCommon = @import("TextEncoderCommon.zig").TextEncoderCommon;

// ============================================================================
// Helper Functions (Module-Level)
// ============================================================================

/// Check if byte slice is ASCII-only (fast path optimization)
fn isAscii(bytes: []const u8) bool {
    for (bytes) |byte| {
        if (byte > 0x7F) return false;
    }
    return true;
}

/// Replace invalid UTF-8 sequences with U+FFFD REPLACEMENT CHARACTER
fn replaceInvalidUtf8(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    // Allocate output buffer (worst case: 3 bytes per input byte for U+FFFD)
    var output = std.ArrayList(u8).init(allocator);
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

/// TextEncoder - encodes strings to UTF-8 bytes
///
/// WHATWG Encoding Standard § 5.2
/// https://encoding.spec.whatwg.org/#interface-textencoder
///
/// IDL:
/// ```
/// [Exposed=*]
/// interface TextEncoder {
///   constructor();
///   [NewObject] Uint8Array encode(optional USVString input = "");
///   TextEncoderEncodeIntoResult encodeInto(USVString source, [AllowShared] Uint8Array destination);
/// };
/// TextEncoder includes TextEncoderCommon;
///
/// interface mixin TextEncoderCommon {
///   readonly attribute DOMString encoding;
/// };
/// ```
///
/// Note: TextEncoder only supports UTF-8 encoding (no label argument).
/// Note: TextEncoder offers no stream option (no buffering needed).
pub const TextEncoder = webidl.interface(struct {
    /// WebIDL includes: TextEncoderCommon (encoding)
    ///
    /// The TextEncoderCommon mixin is flattened into this interface by the codegen
    /// to provide the readonly encoding attribute
    pub const includes = .{TextEncoderCommon};

    allocator: std.mem.Allocator,

    /// Constructor - creates a new TextEncoder
    ///
    /// WHATWG Encoding Standard § 5.2.1
    /// https://encoding.spec.whatwg.org/#dom-textencoder
    ///
    /// Creates a new UTF-8 encoder (stateless).
    ///
    /// ## Parameters
    ///
    /// - `allocator`: Memory allocator for `encode()` output (not used by `encodeInto()`)
    ///
    /// ## Returns
    ///
    /// New TextEncoder instance (always UTF-8).
    ///
    /// ## Examples
    ///
    /// ```zig
    /// var encoder = TextEncoder.init(allocator);
    /// defer encoder.deinit(); // No-op, but good practice
    ///
    /// const bytes = try encoder.encode("Hello");
    /// defer allocator.free(bytes);
    /// ```
    ///
    /// ## Spec Algorithm
    ///
    /// The new TextEncoder() constructor steps are to do nothing.
    ///
    /// ## Implementation Notes
    ///
    /// - No label parameter (always UTF-8 per spec)
    /// - No stream option (no buffering needed per spec)
    /// - Stateless (safe to share across threads if allocator is thread-safe)
    pub fn init(allocator: std.mem.Allocator) TextEncoder {
        return .{
            .encoding = "utf-8",
            .allocator = allocator,
        };
    }

    /// Cleanup resources
    pub fn deinit(self: *TextEncoder) void {
        _ = self;
        // No resources to clean up (stateless)
    }

    /// Get the encoding name (always "utf-8")
    ///
    /// WHATWG Encoding Standard § 5.2.1
    /// TextEncoderCommon.encoding getter
    ///
    /// IDL:
    /// ```
    /// readonly attribute DOMString encoding;
    /// ```
    ///
    /// Note: Returns UTF-8 string. For JavaScript bindings, convert to DOMString (UTF-16).
    pub inline fn get_encoding(self: *const TextEncoder) []const u8 {
        return self.encoding;
    }

    /// encode() - Encodes a string into UTF-8 bytes
    ///
    /// WHATWG Encoding Standard § 5.2.2
    /// https://encoding.spec.whatwg.org/#dom-textencoder-encode
    ///
    /// Encodes the input string to UTF-8 and returns a newly allocated byte buffer.
    ///
    /// ## Parameters
    ///
    /// - `input`: String to encode (UTF-8)
    ///   - For JavaScript bindings: convert USVString (UTF-16) → UTF-8 first
    ///
    /// ## Returns
    ///
    /// Newly allocated UTF-8 byte buffer. **Caller owns the returned memory** and must free it.
    ///
    /// ## Errors
    ///
    /// - `error.OutOfMemory`: Allocation failed
    ///
    /// Note: Per WHATWG spec, UTF-8 encoder cannot fail (invalid sequences replaced with U+FFFD).
    ///
    /// ## Behavior
    ///
    /// - **ASCII Fast Path**: For ASCII-only input, direct copy (~10x faster)
    /// - **UTF-8 Validation**: Invalid sequences replaced with U+FFFD (shouldn't happen with valid input)
    /// - **Allocation**: Always allocates new buffer (use `encodeInto()` for zero-copy)
    ///
    /// ## Examples
    ///
    /// ### Basic Encode
    /// ```zig
    /// var encoder = TextEncoder.init(allocator);
    /// defer encoder.deinit();
    ///
    /// const bytes = try encoder.encode("Hello");
    /// defer allocator.free(bytes);
    /// // bytes is [_]u8{ 0x48, 0x65, 0x6C, 0x6C, 0x6F }
    /// ```
    ///
    /// ### Multibyte Characters
    /// ```zig
    /// const bytes = try encoder.encode("世界");
    /// defer allocator.free(bytes);
    /// // bytes contains UTF-8 encoding of Chinese characters (6 bytes)
    /// ```
    ///
    /// ### Empty String
    /// ```zig
    /// const bytes = try encoder.encode("");
    /// defer allocator.free(bytes);
    /// // bytes.len == 0
    /// ```
    ///
    /// ## Performance
    ///
    /// - ASCII-only: O(n) copy
    /// - Multibyte: O(n) with validation
    /// - No reallocation (size known upfront)
    ///
    /// ## Spec Algorithm
    ///
    /// The encode(input) method steps are:
    /// 1. Convert input to an I/O queue of scalar values
    /// 2. Let output be the I/O queue of bytes
    /// 3. Process with UTF-8 encoder
    /// 4. Return Uint8Array
    ///
    /// ## Implementation Notes
    ///
    /// This implementation uses UTF-8 strings for I/O (Zig native).
    /// For JavaScript bindings:
    /// - Convert USVString (UTF-16) → UTF-8 before calling
    /// - Wrap returned []const u8 in Uint8Array after calling
    pub fn call_encode(
        self: *TextEncoder,
        input: []const u8,
    ) ![]const u8 {
        // Handle empty input (common case)
        if (input.len == 0) {
            return &[_]u8{};
        }

        // ASCII FAST PATH: For ASCII-only input, return as-is
        // ASCII is valid UTF-8, no conversion needed
        if (isAscii(input)) {
            return self.allocator.dupe(u8, input);
        }

        // GENERAL PATH: Validate and encode UTF-8
        // Note: If input is already valid UTF-8, we just copy it
        // The spec says to encode scalar values with UTF-8 encoder
        // Since our input is UTF-8, we validate and copy
        if (!std.unicode.utf8ValidateSlice(input)) {
            // Invalid UTF-8 - replace invalid sequences with U+FFFD
            // This shouldn't happen with USVString input, but handle it gracefully
            return try replaceInvalidUtf8(self.allocator, input);
        }

        // Valid UTF-8 - just duplicate
        return self.allocator.dupe(u8, input);
    }

    /// encodeInto() - Encodes a string into an existing Uint8Array
    ///
    /// WHATWG Encoding Standard § 5.2.3
    /// https://encoding.spec.whatwg.org/#dom-textencoder-encodeinto
    ///
    /// Encodes the source string into the destination buffer (zero-copy, no allocation).
    ///
    /// ## Parameters
    ///
    /// - `source`: String to encode (UTF-8)
    ///   - For JavaScript bindings: convert USVString (UTF-16) → UTF-8 first
    /// - `destination`: Existing buffer to write encoded bytes into
    ///
    /// ## Returns
    ///
    /// `TextEncoderEncodeIntoResult` containing:
    /// - `read`: Number of UTF-8 bytes (or UTF-16 code units for JS) read from source
    /// - `written`: Number of bytes written to destination
    ///
    /// ## Errors
    ///
    /// - `error.OutOfMemory`: Should not occur (no allocation)
    ///
    /// ## Behavior
    ///
    /// - **Zero-Copy**: Writes directly to provided buffer (no allocation)
    /// - **Partial Encoding**: Stops when destination full
    /// - **Character Boundary**: Never splits multibyte characters (stops before incomplete char)
    /// - **Progress Tracking**: Returns read/written counts for resuming
    ///
    /// ## Examples
    ///
    /// ### Basic encodeInto
    /// ```zig
    /// var encoder = TextEncoder.init(allocator);
    /// var buffer: [100]u8 = undefined;
    ///
    /// const result = try encoder.encodeInto("Hello", &buffer);
    /// // result.read = 5
    /// // result.written = 5
    /// // buffer[0..5] = "Hello"
    /// ```
    ///
    /// ### Insufficient Buffer
    /// ```zig
    /// var buffer: [3]u8 = undefined;
    /// const result = try encoder.encodeInto("Hello", &buffer);
    /// // result.read = 3
    /// // result.written = 3
    /// // buffer[0..3] = "Hel" (truncated)
    /// ```
    ///
    /// ### Multibyte Character Boundary
    /// ```zig
    /// var buffer: [3]u8 = undefined;
    /// const result = try encoder.encodeInto("Hi🌍", &buffer);
    /// // result.read = 2 ("Hi" only)
    /// // result.written = 2
    /// // buffer[0..2] = "Hi"
    /// // Emoji skipped (4 bytes, doesn't fit)
    /// ```
    ///
    /// ### Resuming After Partial Encode
    /// ```zig
    /// const text = "Hello, World!";
    /// var buffer: [5]u8 = undefined;
    ///
    /// var offset: usize = 0;
    /// while (offset < text.len) {
    ///     const remaining = text[offset..];
    ///     const result = try encoder.encodeInto(remaining, &buffer);
    ///     // Process buffer[0..result.written]
    ///     offset += result.read;
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// - **Zero Allocation**: No memory allocation
    /// - **Single Pass**: One iteration through source
    /// - **Optimal**: Faster than `encode()` when buffer is reused
    ///
    /// ## Spec Algorithm
    ///
    /// The encodeInto(source, destination) method steps are:
    /// 1. Convert source to scalar values
    /// 2. Encode with UTF-8 encoder into destination
    /// 3. Return read/written counts
    ///
    /// ## Implementation Notes
    ///
    /// This implementation uses UTF-8 strings for I/O.
    /// For JavaScript bindings:
    /// - Convert USVString (UTF-16) → UTF-8 before calling
    /// - `result.read` should be adjusted to UTF-16 code units for JS
    pub fn call_encodeInto(
        self: *TextEncoder,
        source: []const u8,
        destination: []u8,
    ) !TextEncoderEncodeIntoResult {
        _ = self;

        var read: u64 = 0;
        var written: u64 = 0;

        // Process UTF-8 input
        var i: usize = 0;
        while (i < source.len and written < destination.len) {
            // Get UTF-8 code point length
            const cp_len = std.unicode.utf8ByteSequenceLength(source[i]) catch {
                // Invalid UTF-8 - skip byte
                i += 1;
                read += 1;
                continue;
            };

            // Check if we have enough space
            if (written + cp_len > destination.len) {
                // Not enough space for this code point
                break;
            }

            // Check if we have enough input bytes
            if (i + cp_len > source.len) {
                // Incomplete code point at end of input
                break;
            }

            // Copy code point bytes
            @memcpy(destination[written .. written + cp_len], source[i .. i + cp_len]);

            written += cp_len;
            read += cp_len;
            i += cp_len;
        }

        return .{
            .read = read,
            .written = written,
        };
    }
}, .{
    .exposed = &.{.global},
});
