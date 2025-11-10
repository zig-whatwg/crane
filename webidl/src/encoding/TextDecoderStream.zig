//! TextDecoderStream WebIDL Interface
//!
//! WHATWG Encoding Standard § 6.3
//! https://encoding.spec.whatwg.org/#interface-textdecoderstream
//!
//! TextDecoderStream decodes a stream of bytes into a stream of strings using character encodings.

const std = @import("std");
const webidl = @import("webidl");

// Import mixins
const TextDecoderCommon = @import("TextDecoderCommon.zig").TextDecoderCommon;
const GenericTransformStream = @import("../streams/GenericTransformStream.zig").GenericTransformStream;

// Import dictionaries
const TextDecoderOptions = @import("TextDecoderOptions.zig").TextDecoderOptions;

// Import streams
const streams = @import("streams");
const TransformStream = streams.TransformStream;
const ReadableStream = streams.ReadableStream;
const WritableStream = streams.WritableStream;

// Import encoding infrastructure
const encoding_mod = @import("encoding");
const Encoding = encoding_mod.Encoding;
const Decoder = encoding_mod.Decoder;

/// TextDecoderStream - decodes a stream of bytes to a stream of strings
///
/// WHATWG Encoding Standard § 6.3
/// https://encoding.spec.whatwg.org/#interface-textdecoderstream
///
/// IDL:
/// ```
/// [Exposed=*]
/// interface TextDecoderStream {
///   constructor(optional DOMString label = "utf-8", optional TextDecoderOptions options = {});
/// };
/// TextDecoderStream includes TextDecoderCommon;
/// TextDecoderStream includes GenericTransformStream;
/// ```
pub const TextDecoderStream = webidl.interface(struct {
    /// WebIDL includes: TextDecoderCommon and GenericTransformStream
    ///
    /// The mixins are flattened into this interface by the codegen:
    /// - TextDecoderCommon provides: encoding, fatal, ignoreBOM
    /// - GenericTransformStream provides: transform, get_readable(), get_writable()
    pub const includes = .{
        TextDecoderCommon,
        GenericTransformStream,
    };

    allocator: std.mem.Allocator,

    /// The encoding used by this stream decoder
    enc: *const Encoding,

    /// Internal decoder instance
    decoder: *Decoder,

    /// Constructor - creates a new TextDecoderStream
    ///
    /// WHATWG Encoding Standard § 6.3.1
    /// https://encoding.spec.whatwg.org/#dom-textdecoderstream
    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        options: TextDecoderOptions,
    ) !TextDecoderStream {
        // Get encoding from label
        const enc = encoding_mod.getEncoding(label) orelse {
            return error.InvalidEncoding;
        };

        // Reject replacement encoding
        if (std.mem.eql(u8, enc.whatwg_name, "replacement")) {
            return error.ReplacementEncoding;
        }

        // Create transform stream
        const transform = try allocator.create(TransformStream);
        errdefer allocator.destroy(transform);

        transform.* = try TransformStream.init(allocator, .{
            .transform = transformAlgorithm,
            .flush = flushAlgorithm,
        });

        // Create decoder instance
        const decoder = try allocator.create(Decoder);
        errdefer allocator.destroy(decoder);
        decoder.* = enc.newDecoder();

        return .{
            .encoding = enc.whatwg_name,
            .fatal = options.fatal,
            .ignoreBOM = options.ignoreBOM,
            .transform = transform,
            .allocator = allocator,
            .enc = enc,
            .decoder = decoder,
        };
    }

    /// Cleanup resources
    pub fn deinit(self: *TextDecoderStream) void {
        self.allocator.destroy(self.decoder);
        self.transform.deinit();
        self.allocator.destroy(self.transform);
    }

    // ============================================================================
    // Transform Algorithms
    // ============================================================================

    /// Transform algorithm - decode chunk and enqueue
    ///
    /// WHATWG Encoding Standard § 6.3.2
    /// "decode and enqueue a chunk"
    fn transformAlgorithm(chunk: []const u8, controller: *TransformStream.Controller) !void {
        // TODO: Implement decode and enqueue algorithm
        // This requires:
        // 1. Run decoder on chunk (streaming mode)
        // 2. Enqueue decoded string to readable side
        // 3. Handle fatal errors
        _ = chunk;
        _ = controller;
    }

    /// Flush algorithm - flush decoder
    ///
    /// WHATWG Encoding Standard § 6.3.2
    /// "flush and enqueue"
    fn flushAlgorithm(controller: *TransformStream.Controller) !void {
        // TODO: Implement flush and enqueue algorithm
        // This requires:
        // 1. Flush decoder (finalize any pending bytes)
        // 2. Enqueue final decoded string (if any)
        // 3. Handle fatal errors
        _ = controller;
    }
}, .{
    .exposed = &.{.all},
});
