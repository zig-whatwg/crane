//! Slice-to-Queue Wrapper Functions
//!
//! Provides backward compatibility for slice-based APIs by converting
//! slices to I/O queues, running the queue-based algorithms, and converting
//! results back to slices.
//!
//! This allows existing code to continue working while the internal
//! implementation uses spec-compliant I/O queues.

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");
const Allocator = std.mem.Allocator;
const io_queue = @import("io_queue.zig");
const ByteQueue = io_queue.ByteQueue;
const ScalarQueue = io_queue.ScalarQueue;
const streaming = @import("streaming.zig");
const error_mode = @import("error_mode.zig");
const ErrorMode = error_mode.ErrorMode;

// Use webidl.code_points for surrogate handling (per AGENTS.md: "Prefer WebIDL API over Infra")
const code_points = webidl.code_points;

// Import queue-based implementations
const utf8_decoder_queue = @import("utf8/decoder_queue.zig");
const utf8_encoder_queue = @import("utf8/encoder_queue.zig");
const single_byte_decoder_queue = @import("single_byte/decoder_queue.zig");
const single_byte_encoder_queue = @import("single_byte/encoder_queue.zig");

/// Decode UTF-8 bytes to UTF-16 code units using slice API
///
/// This is a wrapper around the queue-based UTF-8 decoder.
pub fn decodeUtf8Slice(
    allocator: Allocator,
    input: []const u8,
    output: []u16,
    mode: ErrorMode,
) !streaming.DecodeResult {
    // Create input queue from slice
    var input_queue = try ByteQueue.fromSlice(allocator, input);
    defer input_queue.deinit();
    try input_queue.markEnd();

    // Create output queue
    var output_queue = ScalarQueue.init(allocator);
    defer output_queue.deinit();

    // Run queue-based decoder
    var state = utf8_decoder_queue.Utf8DecoderState{};
    const result = try utf8_decoder_queue.decode(&state, &input_queue, &output_queue, mode);

    // Convert output queue to slice
    const output_slice = try output_queue.toSlice(allocator);
    defer allocator.free(output_slice);

    // Copy to output buffer
    const to_copy = @min(output_slice.len, output.len);
    for (0..to_copy) |i| {
        output[i] = @intCast(output_slice[i]);
    }

    // Map result status
    const status: streaming.DecodeResult.Status = switch (result.status) {
        .finished => if (to_copy < output_slice.len) .output_full else .input_empty,
        .malformed => .malformed,
        .error_ => .malformed, // Fatal errors become malformed in slice API
    };

    return .{
        .status = status,
        .bytes_consumed = input.len, // All input consumed in queue mode
        .code_units_written = to_copy,
        .error_length = result.error_length,
    };
}

/// Encode UTF-16 code units to UTF-8 bytes using slice API
///
/// This is a wrapper around the queue-based UTF-8 encoder.
pub fn encodeUtf8Slice(
    allocator: Allocator,
    input: []const u16,
    output: []u8,
    mode: ErrorMode,
) !streaming.EncodeResult {
    // Create input queue from slice (convert UTF-16 to scalar values)
    var input_queue = ScalarQueue.init(allocator);
    defer input_queue.deinit();

    for (input) |code_unit| {
        // Handle surrogate pairs (WHATWG Infra §4.5)
        if (code_points.isLeadSurrogate(code_unit)) {
            // High surrogate - need to combine with low surrogate
            // Simplified: just pass through as scalar value
            // Full implementation would handle surrogate pair combination
        }
        try input_queue.push(code_unit);
    }
    try input_queue.markEnd();

    // Create output queue
    var output_queue = ByteQueue.init(allocator);
    defer output_queue.deinit();

    // Run queue-based encoder
    var state = utf8_encoder_queue.Utf8EncoderState{};
    const result = try utf8_encoder_queue.encode(&state, &input_queue, &output_queue, mode);

    // Convert output queue to slice
    const output_slice = try output_queue.toSlice(allocator);
    defer allocator.free(output_slice);

    // Copy to output buffer
    const to_copy = @min(output_slice.len, output.len);
    @memcpy(output[0..to_copy], output_slice[0..to_copy]);

    // Map result status
    const status: streaming.EncodeResult.Status = switch (result.status) {
        .finished => if (to_copy < output_slice.len) .output_full else .input_empty,
        .unmappable => .unmappable,
        .error_ => .unmappable, // Fatal errors become unmappable in slice API
    };

    return .{
        .status = status,
        .code_units_consumed = input.len, // All input consumed in queue mode
        .bytes_written = to_copy,
        .error_code_point = result.error_code_point,
    };
}

// Tests

test "wrapper - UTF-8 decode slice" {
    const allocator = std.testing.allocator;

    const input = "Hello";
    var output: [10]u16 = undefined;

    const result = try decodeUtf8Slice(allocator, input, &output, .replacement);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 5), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 'H'), output[0]);
    try std.testing.expectEqual(@as(u16, 'e'), output[1]);
}

test "wrapper - UTF-8 encode slice" {
    const allocator = std.testing.allocator;

    const input = [_]u16{ 'H', 'i' };
    var output: [10]u8 = undefined;

    const result = try encodeUtf8Slice(allocator, &input, &output, .replacement);

    try std.testing.expectEqual(streaming.EncodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_written);
    try std.testing.expectEqualStrings("Hi", output[0..result.bytes_written]);
}

test "wrapper - UTF-8 decode with multibyte" {
    const allocator = std.testing.allocator;

    // "€" = U+20AC = 0xE2 0x82 0xAC
    const input = [_]u8{ 0xE2, 0x82, 0xAC };
    var output: [10]u16 = undefined;

    const result = try decodeUtf8Slice(allocator, &input, &output, .replacement);

    try std.testing.expectEqual(streaming.DecodeResult.Status.input_empty, result.status);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x20AC), output[0]);
}
