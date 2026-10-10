//! Encoding §§7.5–7.6 incremental codecs for the native transform algorithms.
const std = @import("std");
const encoding = @import("encoding.zig");
pub const Error = error{ OutOfMemory, InvalidData };

/// DOMString arrives as WTF-8, preserving isolated UTF-16 surrogates. Only
/// the pending leading surrogate survives a push (§7.6); returned bytes are
/// owned by the caller and can be enqueued after this codec is no longer used.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    leading_surrogate: ?u16 = null,
    finished: bool = false,

    pub fn push(self: *Encoder, input: []const u8, final: bool) Error![]u8 {
        if (self.finished) return error.InvalidData;
        errdefer self.finished = true;
        const view = std.unicode.Wtf8View.init(input) catch return error.InvalidData;
        var iter = view.iterator();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(self.allocator);
        while (iter.nextCodepoint()) |point| {
            // §7.6 convert code unit to scalar value, step 1. A non-trailing
            // item is restored and processed again after emitting U+FFFD.
            if (self.leading_surrogate) |leading| {
                self.leading_surrogate = null;
                if (point >= 0xdc00 and point <= 0xdfff) {
                    try appendScalar(self.allocator, &output, 0x10000 + (@as(u21, leading - 0xd800) << 10) + point - 0xdc00);
                    continue;
                }
                try appendScalar(self.allocator, &output, 0xfffd);
            }
            if (point >= 0xd800 and point <= 0xdbff) {
                self.leading_surrogate = @intCast(point);
            } else {
                try appendScalar(self.allocator, &output, if (point >= 0xdc00 and point <= 0xdfff) 0xfffd else point);
            }
        }
        // §7.6 encode and flush: an unmatched leading surrogate becomes U+FFFD.
        if (final) {
            if (self.leading_surrogate != null) try appendScalar(self.allocator, &output, 0xfffd);
            self.leading_surrogate = null;
            self.finished = true;
        }
        return output.toOwnedSlice(self.allocator);
    }
};

/// §7.5 keeps one decoder across writes, including empty writes. A close
/// sends end-of-queue even if the last write consumed every byte.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    encoding: *const encoding.Encoding,
    decoder: encoding.Decoder,
    fatal: bool = false,
    ignore_bom: bool = false,
    bom_seen: bool = false,
    finished: bool = false,

    pub fn init(allocator: std.mem.Allocator, enc: *const encoding.Encoding, fatal: bool, ignore_bom: bool) Decoder {
        return .{ .allocator = allocator, .encoding = enc, .decoder = enc.newDecoder(), .fatal = fatal, .ignore_bom = ignore_bom };
    }

    pub fn push(self: *Decoder, input: []const u8, final: bool) Error![]u8 {
        if (self.finished) return error.InvalidData;
        errdefer self.finished = true;
        // A Big5 pointer can emit two scalars. Four more units cover the
        // decoder's carried state/replayed bytes and a final replacement.
        const capacity = std.math.add(usize, std.math.mul(usize, input.len, 2) catch return error.OutOfMemory, 4) catch return error.OutOfMemory;
        const units = try self.allocator.alloc(u16, capacity);
        defer self.allocator.free(units);
        const result = if (self.fatal)
            self.decoder.decode(input, units, final)
        else
            self.decoder.decodeReplacement(input, units, final);
        if (result.status != .input_empty or result.bytes_consumed != input.len) return error.InvalidData;

        // TextDecoderCommon serialize I/O queue: ignore only the first scalar
        // BOM, only for the Unicode encodings, unless ignoreBOM is set.
        var start: usize = 0;
        if (!self.ignore_bom and !self.bom_seen and result.code_units_written != 0 and
            (self.encoding == &encoding.UTF_8 or self.encoding == &encoding.UTF_16BE or self.encoding == &encoding.UTF_16LE))
        {
            self.bom_seen = true;
            if (units[0] == 0xfeff) start = 1;
        }
        const output = std.unicode.utf16LeToUtf8Alloc(self.allocator, units[start..result.code_units_written]) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidData,
        };
        self.finished = final;
        return output;
    }
};

fn appendScalar(allocator: std.mem.Allocator, output: *std.ArrayList(u8), point: u21) error{OutOfMemory}!void {
    var bytes: [4]u8 = undefined;
    const length = std.unicode.utf8Encode(point, &bytes) catch unreachable;
    try output.appendSlice(allocator, bytes[0..length]);
}
