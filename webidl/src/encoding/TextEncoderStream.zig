//! TextEncoderStream WebIDL Interface
//!
//! WHATWG Encoding Standard § 5.3
//! https://encoding.spec.whatwg.org/#interface-textencoderstream
//!
//! TextEncoderStream encodes a stream of strings into a stream of UTF-8 bytes.

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

// Import mixins
const TextEncoderCommon = @import("TextEncoderCommon.zig").TextEncoderCommon;
const GenericTransformStream = @import("../streams/GenericTransformStream.zig").GenericTransformStream;

// Import streams
const TransformStream = @import("transform_stream").TransformStream;
const TransformStreamDefaultController = @import("transform_stream_default_controller").TransformStreamDefaultController;

/// TextEncoderStream - encodes a stream of strings to a stream of UTF-8 bytes
///
/// WHATWG Encoding Standard § 5.3
/// https://encoding.spec.whatwg.org/#interface-textencoderstream
///
/// IDL:
/// ```
/// [Exposed=*]
/// interface TextEncoderStream {
///   constructor();
/// };
/// TextEncoderStream includes TextEncoderCommon;
/// TextEncoderStream includes GenericTransformStream;
/// ```
pub const TextEncoderStream = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// TextEncoderCommon mixin: encoding property
    encoding: []const u8,

    /// GenericTransformStream mixin: transform
    transform: *TransformStream,

    /// Associated leading surrogate (null or a leading surrogate, initially null)
    /// Spec: § 5.3 - used to handle unpaired surrogates across chunk boundaries
    leadingSurrogate: ?u16,

    /// Constructor - creates a new TextEncoderStream
    ///
    /// WHATWG Encoding Standard § 5.3 lines 1052-1064
    pub fn init(allocator: std.mem.Allocator) !TextEncoderStream {
        // Allocate stream on heap for context pointer
        const stream_ptr = try allocator.create(TextEncoderStream);
        errdefer allocator.destroy(stream_ptr);

        // Initialize with temporary values
        stream_ptr.* = .{
            .allocator = allocator,
            .encoding = "utf-8",
            .transform = undefined, // Will be set below
            .leadingSurrogate = null,
        };

        // Step 2-3: Create transform algorithms
        const Transformer = struct {
            pub fn transform(
                controller: *TransformStreamDefaultController,
                chunk: webidl.JSValue,
                ctx: *anyopaque,
            ) !void {
                const self: *TextEncoderStream = @ptrCast(@alignCast(ctx));
                try self.encodeAndEnqueue(controller, chunk);
            }

            pub fn flush(
                controller: *TransformStreamDefaultController,
                ctx: *anyopaque,
            ) !void {
                const self: *TextEncoderStream = @ptrCast(@alignCast(ctx));
                try self.flushAndEnqueue(controller);
            }
        };

        // Step 4-5: Create TransformStream
        const transform = try allocator.create(TransformStream);
        errdefer allocator.destroy(transform);

        transform.* = try TransformStream.initWithCallbacks(
            allocator,
            Transformer.transform,
            Transformer.flush,
            stream_ptr,
        );

        // Step 6: Set transform
        stream_ptr.transform = transform;

        return stream_ptr.*;
    }

    /// Cleanup resources
    pub fn deinit(self: *TextEncoderStream) void {
        self.transform.deinit();
        self.allocator.destroy(self.transform);
    }

    /// Get encoding (TextEncoderCommon mixin)
    pub fn get_encoding(self: *const TextEncoderStream) []const u8 {
        return self.encoding;
    }

    /// Get readable stream (GenericTransformStream mixin)
    pub fn get_readable(self: *const TextEncoderStream) *@import("readable_stream").ReadableStream {
        return self.transform.readableStream;
    }

    /// Get writable stream (GenericTransformStream mixin)
    pub fn get_writable(self: *const TextEncoderStream) *@import("writable_stream").WritableStream {
        return self.transform.writableStream;
    }

    // ============================================================================
    // Transform Algorithms
    // ============================================================================

    /// Encode and enqueue a chunk algorithm
    ///
    /// WHATWG Encoding Standard § 5.3 lines 1068-1097
    fn encodeAndEnqueue(
        self: *TextEncoderStream,
        controller: *TransformStreamDefaultController,
        chunk: webidl.JSValue,
    ) !void {
        // Step 1: Convert chunk to DOMString (extract string)
        const input_string = switch (chunk) {
            .string => |s| s,
            else => return, // Skip non-string chunks
        };

        // Step 2-3: Process code units and encode to UTF-8
        var output = std.ArrayList(u8).init(self.allocator);
        defer output.deinit();

        // Step 4: Process each code unit
        for (input_string) |code_unit| {
            // Step 4.3: Convert code unit to scalar value
            const scalar_value_opt = try self.convertCodeUnitToScalarValue(code_unit);

            // Step 4.4: If result is not continue, encode it
            if (scalar_value_opt) |scalar_value| {
                // Encode scalar value to UTF-8
                var utf8_buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(scalar_value, &utf8_buf) catch {
                    // Should never happen for valid scalar values
                    continue;
                };

                try output.appendSlice(utf8_buf[0..len]);
            }
        }

        // Step 4.2: If output is not empty, enqueue
        if (output.items.len > 0) {
            // Create Uint8Array JSValue
            const bytes = try self.allocator.dupe(u8, output.items);
            const output_js = webidl.JSValue{ .bytes = bytes };
            try controller.call_enqueue(output_js);
        }
    }

    /// Convert code unit to scalar value algorithm
    ///
    /// WHATWG Encoding Standard § 5.3 lines 1099-1117
    ///
    /// Returns: null for continue, u21 code point otherwise
    fn convertCodeUnitToScalarValue(
        self: *TextEncoderStream,
        item: u16,
    ) !?u21 {
        // Step 1: If encoder's leading surrogate is non-null
        if (self.leadingSurrogate) |leading| {
            // Step 1.2: Set encoder's leading surrogate to null
            self.leadingSurrogate = null;

            // Step 1.3: If item is a trailing surrogate
            if (item >= 0xDC00 and item <= 0xDFFF) {
                // Return scalar value from surrogates
                const code_point: u21 = 0x10000 + (((@as(u21, leading) - 0xD800) << 10) | (@as(u21, item) - 0xDC00));
                return code_point;
            }

            // Step 1.5: Return U+FFFD (unpaired leading surrogate)
            return 0xFFFD;
        }

        // Step 2: If item is a leading surrogate
        if (item >= 0xD800 and item < 0xDC00) {
            // Set encoder's leading surrogate to item
            self.leadingSurrogate = item;
            // Return continue (null)
            return null;
        }

        // Step 3: If item is a trailing surrogate
        if (item >= 0xDC00 and item <= 0xDFFF) {
            // Return U+FFFD (unpaired trailing surrogate)
            return 0xFFFD;
        }

        // Step 4: Return item (valid BMP code point)
        return @intCast(item);
    }

    /// Encode and flush algorithm
    ///
    /// WHATWG Encoding Standard § 5.3 lines 1120-1129
    fn flushAndEnqueue(
        self: *TextEncoderStream,
        controller: *TransformStreamDefaultController,
    ) !void {
        // Step 1: If encoder's leading surrogate is non-null
        if (self.leadingSurrogate != null) {
            // Clear the leading surrogate
            self.leadingSurrogate = null;

            // Step 1.1: Enqueue U+FFFD bytes (0xEF, 0xBF, 0xBD)
            const fffd_bytes = [_]u8{ 0xEF, 0xBF, 0xBD };
            const bytes = try self.allocator.dupe(u8, &fffd_bytes);
            const output_js = webidl.JSValue{ .bytes = bytes };

            // Step 1.2: Enqueue chunk
            try controller.call_enqueue(output_js);
        }
    }
}, .{
    .exposed = &.{.global},
});
