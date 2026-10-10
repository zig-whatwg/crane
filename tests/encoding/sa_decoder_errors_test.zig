//! Handler errors and restored bytes belong to the Encoding decoder contract.
const std = @import("std");
const encoding = @import("encoding");
const testing = std.testing;

fn decodeAll(allocator: std.mem.Allocator, enc: *const encoding.Encoding, bytes: []const u8, split: usize) ![]u8 {
    var decoder = enc.newDecoder();
    var units: [128]u16 = undefined;
    const a = decoder.decodeReplacement(bytes[0..split], &units, false);
    try testing.expectEqual(.input_empty, a.status);
    const b = decoder.decodeReplacement(bytes[split..], units[a.code_units_written..], true);
    try testing.expectEqual(.input_empty, b.status);
    return std.unicode.utf16LeToUtf8Alloc(allocator, units[0 .. a.code_units_written + b.code_units_written]);
}

test "streaming decoder handlers report malformed input instead of replacing it" {
    const cases = .{
        .{ &encoding.encoding.UTF_16LE, &[_]u8{ 0, 0xd8 } },
        .{ &encoding.encoding.UTF_16BE, &[_]u8{ 0xd8, 0 } },
        .{ &encoding.encoding.SHIFT_JIS, &[_]u8{0xff} },
        .{ &encoding.encoding.ISO_2022_JP, &[_]u8{0x0e} },
    };
    inline for (cases) |case| {
        var decoder = case[0].newDecoder();
        var out: [8]u16 = undefined;
        const result = decoder.decode(case[1], &out, true);
        try testing.expectEqual(.malformed, result.status);
        try testing.expectEqual(@as(usize, 0), result.code_units_written);
    }
}

test "replacement decoding restores valid bytes after malformed sequences at every split" {
    const cases = .{
        .{ encoding.UTF_8, &[_]u8{ 0xe2, 'A' }, "�A" },
        .{ &encoding.encoding.UTF_16LE, &[_]u8{ 0, 0xd8, 'A', 0 }, "�A" },
        .{ &encoding.encoding.UTF_16BE, &[_]u8{ 0xd8, 0, 0, 'A' }, "�A" },
        .{ &encoding.encoding.SHIFT_JIS, &[_]u8{ 0x81, 0x20 }, "� " },
        .{ &encoding.encoding.ISO_2022_JP, &[_]u8{ 0x1b, 'A', 'B' }, "�AB" },
        .{ &encoding.encoding.ISO_2022_JP, &[_]u8{ 0x1b, '(', 'A' }, "�(A" },
    };
    inline for (cases) |case| {
        for (0..case[1].len + 1) |split| {
            const actual = try decodeAll(testing.allocator, case[0], case[1], split);
            defer testing.allocator.free(actual);
            try testing.expectEqualStrings(case[2], actual);
        }
    }
}

test "ISO-2022-JP preserves output state after an error and handles EOF in lead-byte state" {
    const roman = [_]u8{ 0x1b, '(', 'J', 0x0e, 0x5c };
    for (0..roman.len + 1) |split| {
        const actual = try decodeAll(testing.allocator, &encoding.encoding.ISO_2022_JP, &roman, split);
        defer testing.allocator.free(actual);
        try testing.expectEqualStrings("�¥", actual);
    }
    const empty_jis = [_]u8{ 0x1b, '$', 'B' };
    const actual = try decodeAll(testing.allocator, &encoding.encoding.ISO_2022_JP, &empty_jis, 0);
    defer testing.allocator.free(actual);
    try testing.expectEqualStrings("", actual);
}

test "direct UTF-8 decoder paths also report malformed input" {
    inline for (.{ &encoding.encoding.SHIFT_JIS, &encoding.encoding.ISO_2022_JP }) |enc| {
        var decoder = enc.newDecoder();
        var out: [16]u8 = undefined;
        const result = decoder.decodeToUtf8(&.{0xff}, &out, true);
        try testing.expectEqual(.malformed, result.status);
    }
}

test "Shift_JIS handler includes U+0080 and reports its own errors" {
    var decoder = encoding.encoding.SHIFT_JIS.newDecoder();
    var out: [8]u16 = undefined;
    const valid = decoder.decode(&.{0x80}, &out, true);
    try testing.expectEqual(.input_empty, valid.status);
    try testing.expectEqualSlices(u16, &.{0x80}, out[0..valid.code_units_written]);
    const invalid = decoder.decode(&.{0xff}, &out, true);
    try testing.expectEqual(.malformed, invalid.status);
}

test "ISO-2022-JP direct UTF-8 path exposes malformed input to fatal callers" {
    var decoder = encoding.encoding.ISO_2022_JP.newDecoder();
    var out: [16]u8 = undefined;
    const result = decoder.decodeToUtf8(&.{0xff}, &out, true);
    try testing.expectEqual(.malformed, result.status);
}

test "ISO-2022-JP transitions retain the output flag and accept escape from lead-byte state" {
    const cases = .{
        .{ "\x1b(B\x1b(B", "�" },
        .{ "\x1b$B\x1b(BA", "�A" },
        .{ "\x1b$B\x3f\x65\x1b(BA", "水A" },
        .{ "\x1b$B\x3f", "�" },
        .{ "\x1b(", "�(" },
    };
    inline for (cases) |case| {
        for (0..case[0].len + 1) |split| {
            const actual = try decodeAll(testing.allocator, &encoding.encoding.ISO_2022_JP, case[0], split);
            defer testing.allocator.free(actual);
            try testing.expectEqualStrings(case[1], actual);
        }
    }
}

test "replacement decoders retain restored bytes across a full UTF-16 output buffer" {
    const cases = .{
        .{ &encoding.encoding.UTF_16LE, "A\x00\x00\xd8B\x00", "A�B" },
        .{ &encoding.encoding.UTF_16BE, "\x00A\xd8\x00\x00B", "A�B" },
        .{ &encoding.encoding.SHIFT_JIS, "A\x81 B", "A� B" },
        .{ &encoding.encoding.ISO_2022_JP, "A\x1b(J\\\x1b(A\\", "A¥�(A¥" },
    };
    inline for (cases) |case| {
        var decoder = case[0].newDecoder();
        var position: usize = 0;
        var units: [32]u16 = undefined;
        var written: usize = 0;
        for (0..32) |_| {
            const result = decoder.decodeReplacement(case[1][position..], units[written..][0..1], true);
            position += result.bytes_consumed;
            written += result.code_units_written;
            if (result.status == .input_empty) break;
            try testing.expectEqual(.output_full, result.status);
        } else return error.DecoderDidNotFinish;
        try testing.expectEqual(case[1].len, position);
        const actual = try std.unicode.utf16LeToUtf8Alloc(testing.allocator, units[0..written]);
        defer testing.allocator.free(actual);
        try testing.expectEqualStrings(case[2], actual);
    }
}

test "direct UTF-8 replacement retries an error when its replacement does not fit" {
    const cases = .{
        .{ &encoding.encoding.SHIFT_JIS, "A\xff\x90\x85", "A�水" },
        .{ &encoding.encoding.ISO_2022_JP, "A\xff\x1b$B\x3f\x65", "A�水" },
        .{ &encoding.encoding.ISO_2022_JP, "\x1b(J\\\x1b(A\\", "¥�(A¥" },
    };
    inline for (cases) |case| {
        var decoder = case[0].newDecoder();
        var position: usize = 0;
        var bytes: [64]u8 = undefined;
        var written: usize = 0;
        // A three-byte output slice forces rollback when ordinary output
        // leaves less than three bytes for U+FFFD or a JIS code point.
        for (0..32) |_| {
            const result = decoder.decodeToUtf8Replacement(case[1][position..], bytes[written..][0..3], true);
            position += result.bytes_consumed;
            written += result.bytes_written;
            if (result.status == .input_empty) break;
            try testing.expectEqual(.output_full, result.status);
        } else return error.DecoderDidNotFinish;
        try testing.expectEqual(case[1].len, position);
        try testing.expectEqualStrings(case[2], bytes[0..written]);
    }
}
