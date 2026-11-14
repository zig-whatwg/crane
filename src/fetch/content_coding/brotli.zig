//! The "br" content coding (RFC 7932), decoded as it arrives by the
//! platform's Brotli capability (kit/brotli: the pinned Google decoder, the
//! one Compression Streams uses).
//!
//! As Chromium's BrotliSourceStream: the decoder consumes everything it is
//! given; once its stream has finished, bytes after it are ignored
//! (DECODING_DONE: "Consume remaining bytes"), as Firefox drops what is left
//! of a segment; and a body that stops before the end is not an error (it
//! ignores its upstream's end; root.zig `Stage`).
const std = @import("std");
const Allocator = std.mem.Allocator;
const platform = @import("platform");
const root = @import("root.zig");
const Error = root.Error;
const Sink = root.Sink;

/// Output each call may make (Chromium's BrotliSourceStream writes into its
/// 32 KiB read buffer the same way).
const output_len = 32 * 1024;

pub const Decoder = struct {
    allocator: Allocator,
    codec: *platform.BrotliDecoder,
    /// Where each call's output goes, allocated once: a 32 KiB `undefined`
    /// stack array is filled by ReleaseSafe (the production build's mode)
    /// on every call.
    buffer: []u8,
    /// The stream has finished.
    ended: bool = false,

    pub fn init(allocator: Allocator) Error!Decoder {
        const buffer = try allocator.alloc(u8, output_len);
        errdefer allocator.free(buffer);
        const codec = platform.createBrotliDecoder(allocator) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.InvalidData, error.NotSupported => error.InvalidData,
        };
        return .{ .allocator = allocator, .codec = codec, .buffer = buffer };
    }

    pub fn deinit(self: *Decoder) void {
        platform.destroyBrotliDecoder(self.codec);
        self.allocator.free(self.buffer);
    }

    pub fn push(self: *Decoder, bytes: []const u8, sink: Sink) Error!void {
        if (self.ended) return;
        var remaining = bytes;
        while (true) {
            const buffer = self.buffer;
            const progress = platform.decompressBrotli(self.codec, .from(remaining), buffer) catch |err| return switch (err) {
                error.OutOfMemory => error.OutOfMemory,
                error.InvalidData, error.NotSupported => error.InvalidData,
            };
            remaining = remaining[progress.consumed..];
            if (progress.produced > 0) try sink.write(sink.context, buffer[0..progress.produced]);
            switch (progress.status) {
                .finished => {
                    self.ended = true;
                    return;
                },
                .need_input => {
                    if (remaining.len == 0) return;
                    // The decoder takes all the input it is given before it
                    // asks for more: one that did not cannot go on.
                    if (progress.consumed == 0 and progress.produced == 0) return error.InvalidData;
                },
                .need_output => {},
            }
        }
    }
};
