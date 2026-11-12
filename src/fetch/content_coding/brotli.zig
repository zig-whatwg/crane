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

pub const Decoder = struct {
    codec: *platform.BrotliDecoder,
    /// The stream has finished.
    ended: bool = false,

    pub fn init(allocator: Allocator) Error!Decoder {
        const codec = platform.createBrotliDecoder(allocator) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.InvalidData, error.NotSupported => error.InvalidData,
        };
        return .{ .codec = codec };
    }

    pub fn deinit(self: *Decoder) void {
        platform.destroyBrotliDecoder(self.codec);
    }

    pub fn push(self: *Decoder, bytes: []const u8, sink: Sink) Error!void {
        if (self.ended) return;
        var remaining = bytes;
        while (true) {
            var buffer: [32 * 1024]u8 = undefined;
            const progress = platform.decompressBrotli(self.codec, .from(remaining), &buffer) catch |err| return switch (err) {
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
