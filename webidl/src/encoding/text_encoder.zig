const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

// Import dictionary
const TextEncoderEncodeIntoResult = @import("text_encoder_encode_into_result.zig").TextEncoderEncodeIntoResult;

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
    allocator: std.mem.Allocator,

    /// Constructor - creates a new TextEncoder
    ///
    /// WHATWG Encoding Standard § 5.2.1
    /// https://encoding.spec.whatwg.org/#dom-textencoder
    ///
    /// The new TextEncoder() constructor steps are to do nothing.
    ///
    /// IDL:
    /// ```
    /// constructor();
    /// ```
    ///
    /// Note: The encoding is always "utf-8".
    pub fn init(allocator: std.mem.Allocator) TextEncoder {
        return .{
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
        _ = self;
        return "utf-8";
    }

    /// encode() - Encodes a string into UTF-8 bytes
    ///
    /// WHATWG Encoding Standard § 5.2.2
    /// https://encoding.spec.whatwg.org/#dom-textencoder-encode
    ///
    /// The encode(input) method steps are:
    /// 1. Convert input to an I/O queue of scalar values
    /// 2. Let output be the I/O queue of bytes
    /// 3. Process with UTF-8 encoder
    /// 4. Return Uint8Array
    ///
    /// IDL:
    /// ```
    /// [NewObject] Uint8Array encode(optional USVString input = "");
    /// ```
    ///
    /// Note: This implementation uses UTF-8 strings for I/O (Zig native).
    /// For JavaScript bindings, convert USVString (UTF-16) → UTF-8 before calling,
    /// and wrap returned []const u8 in Uint8Array after.
    ///
    /// The UTF-8 encoder cannot return error (assertion in spec).
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
    /// The encodeInto(source, destination) method steps are:
    /// 1. Convert source to scalar values
    /// 2. Encode with UTF-8 encoder into destination
    /// 3. Return read/written counts
    ///
    /// IDL:
    /// ```
    /// TextEncoderEncodeIntoResult encodeInto(USVString source, [AllowShared] Uint8Array destination);
    /// ```
    ///
    /// Note: This implementation uses UTF-8 strings for I/O.
    /// For JavaScript bindings, convert USVString (UTF-16) → UTF-8 before calling.
    ///
    /// Returns:
    /// - read: number of UTF-8 bytes (or UTF-16 code units) read from source
    /// - written: number of bytes written to destination
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

    // ============================================================================
    // Internal Helper Methods
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
});
