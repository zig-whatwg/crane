const std = @import("std");
const webidl = @import("webidl");

/// TextDecodeOptions dictionary
///
/// WHATWG Encoding Standard § 5.1.4
/// https://encoding.spec.whatwg.org/#dictdef-textdecodeoptions
///
/// Configuration options for TextDecoder.decode() method.
///
/// ## Fields
///
/// ### stream
/// Streaming mode control:
/// - `false` (default): Treat input as complete, flush decoder state
///   - Resets decoder before processing
///   - Processes all input
///   - Flushes any pending multi-byte sequences
/// - `true`: Treat input as fragment, preserve decoder state
///   - Accumulates partial multi-byte sequences
///   - State persists for next decode() call
///   - Use for processing fragmented input (network chunks, file chunks, etc.)
///
/// ## Examples
///
/// ### Non-Streaming (Default)
/// ```zig
/// var decoder = try TextDecoder.init(allocator, "utf-8", .{});
/// defer decoder.deinit();
///
/// const bytes = "Hello";
/// const text = try decoder.call_decode(bytes, .{}); // stream: false (default)
/// defer allocator.free(text);
/// // Decoder state reset before and flushed after
/// ```
///
/// ### Streaming Mode
/// ```zig
/// var decoder = try TextDecoder.init(allocator, "utf-8", .{});
/// defer decoder.deinit();
///
/// // Process chunks with stream: true
/// const chunk1 = try decoder.call_decode(bytes1, .{ .stream = true });
/// defer allocator.free(chunk1);
///
/// const chunk2 = try decoder.call_decode(bytes2, .{ .stream = true });
/// defer allocator.free(chunk2);
///
/// // Final flush with stream: false
/// const final = try decoder.call_decode(&[_]u8{}, .{ .stream = false });
/// defer allocator.free(final);
/// ```
///
/// ### Handling Multibyte Boundaries
/// ```zig
/// // UTF-8 "世" (3 bytes: E4 B8 96)
/// const part1 = [_]u8{ 0xE4, 0xB8 }; // Incomplete
/// const part2 = [_]u8{ 0x96 }; // Completion
///
/// var decoder = try TextDecoder.init(allocator, "utf-8", .{});
/// defer decoder.deinit();
///
/// // First chunk (incomplete character)
/// const text1 = try decoder.call_decode(&part1, .{ .stream = true });
/// defer allocator.free(text1);
/// // text1 is empty (waiting for more bytes)
///
/// // Second chunk (completes character)
/// const text2 = try decoder.call_decode(&part2, .{ .stream = false });
/// defer allocator.free(text2);
/// // text2 is "世" (complete character)
/// ```
///
/// ## WebIDL Spec
///
/// IDL:
/// ```
/// dictionary TextDecodeOptions {
///   boolean stream = false;
/// };
/// ```
///
/// ## See Also
///
/// - `TextDecoder.call_decode()` - Uses these options
/// - `TextDecoderOptions` - Options for constructor
pub const TextDecodeOptions = struct {
    /// If true, additional data is expected in subsequent calls.
    /// If false (default), end-of-queue will be pushed to the stream.
    stream: webidl.boolean = false,
};
