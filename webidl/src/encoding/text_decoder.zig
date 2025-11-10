const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

// Import dictionaries
const TextDecoderOptions = @import("text_decoder_options.zig").TextDecoderOptions;
const TextDecodeOptions = @import("text_decode_options.zig").TextDecodeOptions;

// Import encoding infrastructure
const encoding_mod = @import("encoding");
const Encoding = encoding_mod.Encoding;
const Decoder = encoding_mod.Decoder;

/// TextDecoder errors map to WebIDL simple exceptions per WHATWG Encoding Standard
///
/// Error Mapping (for JavaScript bindings):
/// - error.InvalidEncoding → RangeError (invalid encoding label)
/// - error.ReplacementEncoding → RangeError (replacement encoding not allowed)
/// - error.DecodingError → TypeError (fatal mode encountered invalid sequence)
pub const TextDecoderError = error{
    /// Invalid encoding label → WebIDL RangeError
    InvalidEncoding,
    /// Replacement encoding not supported → WebIDL RangeError
    ReplacementEncoding,
    /// Fatal decoding error → WebIDL TypeError
    DecodingError,
    /// Out of memory
    OutOfMemory,
};

/// TextDecoder - decodes bytes to strings using various character encodings
///
/// WHATWG Encoding Standard § 5
/// https://encoding.spec.whatwg.org/#interface-textdecoder
///
/// IDL:
/// ```
/// [Exposed=*]
/// interface TextDecoder {
///   constructor(optional DOMString label = "utf-8", optional TextDecoderOptions options = {});
///   USVString decode(optional AllowSharedBufferSource input, optional TextDecodeOptions options = {});
/// };
/// TextDecoder includes TextDecoderCommon;
///
/// interface mixin TextDecoderCommon {
///   readonly attribute DOMString encoding;
///   readonly attribute boolean fatal;
///   readonly attribute boolean ignoreBOM;
/// };
/// ```
pub const TextDecoder = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// The encoding used by this decoder
    enc: *const Encoding,

    /// The encoding name (WHATWG canonical name) as UTF-8
    encoding_name: []const u8,

    /// do not flush flag (true when stream mode is active)
    do_not_flush: bool,

    /// Error mode: if true, throw on invalid sequences; if false, use U+FFFD
    fatal: webidl.boolean,

    /// If true, ignore BOM; if false, strip BOM from output
    ignore_bom: webidl.boolean,

    /// Whether BOM has been seen in the stream
    bom_seen: bool,

    /// Reusable buffer for UTF-16 output (performance optimization)
    reusable_utf16_buf: ?[]u16,

    /// Reusable buffer for UTF-8 intermediate results (performance optimization)
    reusable_utf8_buf: ?[]u8,

    /// Constructor - creates a new TextDecoder
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
    ///
    /// Note: This implementation uses UTF-8 strings for Zig ergonomics.
    /// For JavaScript bindings, convert DOMString → UTF-8 before calling this.
    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        options: TextDecoderOptions,
    ) TextDecoderError!TextDecoder {
        // Step 1: Get encoding from label (§4.2 get an encoding)
        // https://encoding.spec.whatwg.org/#concept-encoding-get
        const enc = encoding_mod.getEncoding(label) orelse {
            // Step 2: If encoding is failure, throw RangeError
            return error.InvalidEncoding;
        };

        // Step 2: If encoding is replacement, throw RangeError
        if (std.mem.eql(u8, enc.whatwg_name, "replacement")) {
            return error.ReplacementEncoding;
        }

        // Store encoding name (no allocation - just reference the static string)
        const encoding_name = enc.whatwg_name;

        // Step 3-5: Set properties
        return .{
            .allocator = allocator,
            .enc = enc,
            .encoding_name = encoding_name,
            .do_not_flush = false,
            .fatal = options.fatal,
            .ignore_bom = options.ignoreBOM,
            .bom_seen = false,
            .reusable_utf16_buf = null,
            .reusable_utf8_buf = null,
        };
    }

    /// Cleanup resources
    pub fn deinit(self: *TextDecoder) void {
        // Free reusable buffers
        if (self.reusable_utf16_buf) |buf| {
            self.allocator.free(buf);
        }
        if (self.reusable_utf8_buf) |buf| {
            self.allocator.free(buf);
        }
    }

    /// Get the encoding name (WHATWG canonical name)
    ///
    /// WHATWG Encoding Standard § 5.1.1
    /// TextDecoderCommon.encoding getter
    ///
    /// IDL:
    /// ```
    /// readonly attribute DOMString encoding;
    /// ```
    ///
    /// Note: Returns UTF-8 string. For JavaScript bindings, convert to DOMString (UTF-16).
    pub inline fn get_encoding(self: *const TextDecoder) []const u8 {
        return self.encoding_name;
    }

    /// Get the fatal flag
    ///
    /// WHATWG Encoding Standard § 5.1.1
    /// TextDecoderCommon.fatal getter
    ///
    /// IDL:
    /// ```
    /// readonly attribute boolean fatal;
    /// ```
    pub inline fn get_fatal(self: *const TextDecoder) webidl.boolean {
        return self.fatal;
    }

    /// Get the ignoreBOM flag
    ///
    /// WHATWG Encoding Standard § 5.1.1
    /// TextDecoderCommon.ignoreBOM getter
    ///
    /// IDL:
    /// ```
    /// readonly attribute boolean ignoreBOM;
    /// ```
    pub inline fn get_ignoreBOM(self: *const TextDecoder) webidl.boolean {
        return self.ignore_bom;
    }

    /// decode() - Decodes bytes to a string
    ///
    /// WHATWG Encoding Standard § 5.1.4
    /// https://encoding.spec.whatwg.org/#dom-textdecoder-decode
    ///
    /// The decode(input, options) method steps are:
    /// 1. If this's do not flush is false, reset decoder state
    /// 2. Set this's do not flush to options["stream"]
    /// 3. If input is given, push a copy to I/O queue
    /// 4. Let output be the I/O queue of scalar values
    /// 5. Process the queue with encoding's decoder
    /// 6. Return serialized output
    ///
    /// IDL:
    /// ```
    /// USVString decode(optional AllowSharedBufferSource input, optional TextDecodeOptions options = {});
    /// ```
    ///
    /// Note: This implementation uses UTF-8 strings for I/O.
    /// For JavaScript bindings, convert AllowSharedBufferSource → []const u8 before calling,
    /// and convert returned []const u8 → USVString (UTF-16) after.
    ///
    /// Errors:
    /// - error.DecodingError → WebIDL TypeError (fatal mode error)
    pub fn call_decode(
        self: *TextDecoder,
        input: []const u8,
        options: TextDecodeOptions,
    ) TextDecoderError![]const u8 {
        // Step 1: If do not flush is false, reset decoder state
        if (!self.do_not_flush) {
            self.bom_seen = false;
            // Note: Decoder is recreated for each call, so no explicit reset needed
        }

        // Step 2: Set do not flush to options["stream"]
        self.do_not_flush = options.stream;

        // Handle empty input (common case for final flush)
        if (input.len == 0) {
            // Return empty string (no work to do)
            return &[_]u8{};
        }

        // Step 3-6: Process input bytes
        var bytes = input;

        // ASCII FAST PATH: For ASCII-only input, return as-is (ASCII is valid UTF-8)
        if (isAscii(bytes)) {
            // Allocate and copy (caller owns the result)
            return self.allocator.dupe(u8, bytes);
        }

        // Step 4: Handle BOM (if not ignoreBOM and not seen yet)
        if (!self.ignore_bom and !self.bom_seen) {
            bytes = self.stripBOM(bytes);
        }

        // UTF-8 FAST PATH: For UTF-8 encoding, validate and return
        if (std.mem.eql(u8, self.enc.whatwg_name, "utf-8")) {
            return try self.decodeUtf8(bytes);
        }

        // GENERAL PATH: Use encoding infrastructure to decode
        // Step 5: Create decoder instance and decode
        var decoder = self.enc.newDecoder();

        // Allocate UTF-16 output buffer
        const max_utf16_len = self.enc.maxUtf16Length(bytes.len);
        const utf16_buf = try self.getOrAllocUtf16Buffer(max_utf16_len);

        // Decode bytes → UTF-16
        const result = decoder.decode(bytes, utf16_buf, !self.do_not_flush);

        // Handle decoding errors in fatal mode
        if (self.fatal and result.had_errors) {
            return error.DecodingError;
        }

        // Convert UTF-16 → UTF-8 for output
        const utf16_output = utf16_buf[0..result.output_written];
        const utf8_output = try infra.string.utf16ToUtf8(self.allocator, utf16_output);

        return utf8_output;
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

    /// Strip BOM from input bytes (if present)
    ///
    /// WHATWG Encoding Standard § 5.1.4
    /// BOM handling per encoding type
    fn stripBOM(self: *TextDecoder, bytes: []const u8) []const u8 {
        // UTF-8 BOM: EF BB BF
        if (std.mem.eql(u8, self.enc.whatwg_name, "utf-8")) {
            if (bytes.len >= 3 and
                bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF)
            {
                self.bom_seen = true;
                return bytes[3..];
            }
        }
        // UTF-16BE BOM: FE FF
        else if (std.mem.eql(u8, self.enc.whatwg_name, "UTF-16BE")) {
            if (bytes.len >= 2 and bytes[0] == 0xFE and bytes[1] == 0xFF) {
                self.bom_seen = true;
                return bytes[2..];
            }
        }
        // UTF-16LE BOM: FF FE
        else if (std.mem.eql(u8, self.enc.whatwg_name, "UTF-16LE")) {
            if (bytes.len >= 2 and bytes[0] == 0xFF and bytes[1] == 0xFE) {
                self.bom_seen = true;
                return bytes[2..];
            }
        }

        return bytes;
    }

    /// Decode UTF-8 bytes (fast path for UTF-8 encoding)
    fn decodeUtf8(self: *TextDecoder, bytes: []const u8) TextDecoderError![]const u8 {
        // Validate UTF-8 in fatal mode
        if (self.fatal) {
            if (!std.unicode.utf8ValidateSlice(bytes)) {
                return error.DecodingError;
            }
        }

        // Allocate and copy (caller owns the result)
        // In non-fatal mode, invalid sequences are preserved as-is
        // (encoding infrastructure handles replacement with U+FFFD)
        return self.allocator.dupe(u8, bytes);
    }

    /// Get or allocate UTF-16 buffer (reuse optimization)
    fn getOrAllocUtf16Buffer(self: *TextDecoder, min_size: usize) TextDecoderError![]u16 {
        if (self.reusable_utf16_buf) |buf| {
            if (buf.len >= min_size) {
                return buf; // Reuse existing buffer
            }
            // Need larger buffer - grow it
            self.reusable_utf16_buf = try self.allocator.realloc(buf, min_size);
            return self.reusable_utf16_buf.?;
        }

        // First allocation
        self.reusable_utf16_buf = try self.allocator.alloc(u16, min_size);
        return self.reusable_utf16_buf.?;
    }
});
