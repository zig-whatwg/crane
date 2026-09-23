//! URL § 1.3 "percent-encode after encoding".
//!
//! https://url.spec.whatwg.org/#string-percent-encode-after-encoding
//!
//! The half of URL's percent-encoding that needs an encoder, which is why it
//! lives here and not in the URL module: HTML form submission runs it with the
//! form's encoding (the application/x-www-form-urlencoded serializer, URL
//! § 5.2), and the URL parser's query state with the document's. The
//! percent-encode set belongs to the caller and arrives as a predicate over
//! each output byte's isomorphic code point.
//!
//! The encoder runs in "encode or fail" mode (Encoding § 6.4): an unmappable
//! code point ends one run, is written as "%26%23", its decimal value and
//! "%3B" (step 5.4), and the same encoder carries on. Keeping the one encoder
//! matters for ISO-2022-JP, whose state survives an error.

const std = @import("std");
const encoding_mod = @import("encoding.zig");
const streaming = @import("streaming.zig");

const Encoding = encoding_mod.Encoding;

/// Whether the isomorphic code point of an output byte is in the caller's
/// percent-encode set. Every byte >= 0x80 must be (step 5.3.3 asserts it).
pub const InSet = *const fn (byte: u8) bool;

/// Append the result of percent-encoding `input` after encoding it with
/// `encoding` to `output`.
///
/// `input` is UTF-8. It is converted to a scalar value string first, as the
/// algorithm's input is one: a lone surrogate (WTF-8) or an invalid sequence
/// becomes U+FFFD. `encoding` must already be an output encoding - not
/// replacement, UTF-16BE or UTF-16LE (URL § 5.2 step 1 gets one).
pub fn percentEncodeAfterEncoding(
    allocator: std.mem.Allocator,
    output: *std.ArrayListUnmanaged(u8),
    encoding: *const Encoding,
    input: []const u8,
    in_set: InSet,
    space_as_plus: bool,
) !void {
    // UTF-8 encodes every scalar value, so its encoder output is the scalar
    // value string's own UTF-8.
    if (encoding == &encoding_mod.UTF_8) {
        var it = ScalarValues{ .bytes = input };
        while (it.next()) |cp| {
            var buf: [4]u8 = undefined;
            const n = std.unicode.utf8Encode(cp, &buf) catch unreachable;
            for (buf[0..n]) |byte| try appendByte(allocator, output, byte, in_set, space_as_plus);
        }
        return;
    }

    // Step 1: Let encoder be the result of getting an encoder from encoding.
    var encoder = encoding.newEncoder() orelse return error.NoEncoder;

    // Steps 2-5: one code point at a time, so an error's extent is exactly
    // that code point. `is_last` stays false until the input is exhausted, so
    // the encoder keeps its state between calls.
    var it = ScalarValues{ .bytes = input };
    while (it.next()) |cp| {
        var units: [2]u16 = undefined;
        const unit_count: usize = if (cp >= 0x10000) blk: {
            const v = cp - 0x10000;
            units[0] = @intCast(0xD800 + (v >> 10));
            units[1] = @intCast(0xDC00 + (v & 0x3FF));
            break :blk 2;
        } else blk: {
            units[0] = @intCast(cp);
            break :blk 1;
        };
        var buf: [16]u8 = undefined;
        const result = encoder.encode(units[0..unit_count], &buf, false);
        // Step 5.3: the bytes this run produced.
        for (buf[0..result.bytes_written]) |byte| try appendByte(allocator, output, byte, in_set, space_as_plus);
        switch (result.status) {
            .input_empty => {},
            // Step 5.4: the error, as a percent-encoded numeric reference.
            .unmappable => try appendErrorReference(allocator, output, if (result.error_code_point != 0) result.error_code_point else cp),
            // Sixteen bytes hold any encoder's output for one code point.
            .output_full => return error.OutputFull,
        }
    }

    // End of queue: let a stateful encoder return to its initial state.
    var buf: [16]u8 = undefined;
    const tail = encoder.encode(&.{}, &buf, true);
    for (buf[0..tail.bytes_written]) |byte| try appendByte(allocator, output, byte, in_set, space_as_plus);
}

/// Step 5.3.1-5.3.5 for one byte.
fn appendByte(allocator: std.mem.Allocator, output: *std.ArrayListUnmanaged(u8), byte: u8, in_set: InSet, space_as_plus: bool) !void {
    // 5.3.1 spaceAsPlus: 0x20 becomes "+".
    if (space_as_plus and byte == 0x20) return output.append(allocator, '+');
    // 5.3.4 Not in the set: the isomorph itself.
    if (!in_set(byte)) return output.append(allocator, byte);
    // 5.3.5 Otherwise percent-encode it.
    const hex = "0123456789ABCDEF";
    try output.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0xF] });
}

/// Step 5.4: "%26%23", the shortest decimal digits of the code point, "%3B".
fn appendErrorReference(allocator: std.mem.Allocator, output: *std.ArrayListUnmanaged(u8), cp: u21) !void {
    var digits: [8]u8 = undefined;
    const text = std.fmt.bufPrint(&digits, "{d}", .{cp}) catch unreachable;
    try output.appendSlice(allocator, "%26%23");
    try output.appendSlice(allocator, text);
    try output.appendSlice(allocator, "%3B");
}

/// The scalar values of a UTF-8 (or WTF-8) byte string. Lone surrogates and
/// ill-formed sequences come out as U+FFFD - WebIDL's "convert to a scalar
/// value string", which the algorithm's input already is.
const ScalarValues = struct {
    bytes: []const u8,
    i: usize = 0,

    fn next(self: *ScalarValues) ?u21 {
        if (self.i >= self.bytes.len) return null;
        const lead = self.bytes[self.i];
        const len = std.unicode.utf8ByteSequenceLength(lead) catch {
            self.i += 1;
            return 0xFFFD;
        };
        if (self.i + len > self.bytes.len) {
            self.i += 1;
            return 0xFFFD;
        }
        const seq = self.bytes[self.i..][0..len];
        const cp = switch (len) {
            1 => @as(u21, lead),
            // utf8Decode rejects surrogates; the WTF-8 decoder accepts them,
            // and a surrogate on its own is exactly what becomes U+FFFD.
            3 => std.unicode.wtf8Decode(seq) catch {
                self.i += 1;
                return 0xFFFD;
            },
            else => std.unicode.utf8Decode(seq) catch {
                self.i += 1;
                return 0xFFFD;
            },
        };
        self.i += len;
        if (cp >= 0xD800 and cp <= 0xDFFF) return 0xFFFD;
        return cp;
    }
};
