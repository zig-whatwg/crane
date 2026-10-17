//! Legacy handlers expose errors and preserve restored input at every split.
const std = @import("std");
const encoding = @import("encoding");
const testing = std.testing;
const enc = encoding.encoding;

const Case = struct { encoding: *const encoding.Encoding, input: []const u8, expected: []const u8 };
const cases = [_]Case{
    .{ .encoding = &enc.BIG5, .input = "\x81@", .expected = "�@" },
    .{ .encoding = &enc.BIG5, .input = "\x87\x87@", .expected = "�@" },
    .{ .encoding = &enc.BIG5, .input = "\x80<", .expected = "�<" },
    .{ .encoding = &enc.EUC_KR, .input = "\x81<", .expected = "�<" },
    .{ .encoding = &enc.EUC_KR, .input = "\xfeA", .expected = "�A" },
    .{ .encoding = &enc.EUC_JP, .input = "\xa1<", .expected = "�<" },
    .{ .encoding = &enc.EUC_JP, .input = "\x8f\xa1<", .expected = "�<" },
    .{ .encoding = &enc.GB18030, .input = "\x81(", .expected = "�(" },
    .{ .encoding = &enc.GB18030, .input = "\x84\x31\xa5\x30", .expected = "�" },
    .{ .encoding = &enc.GB18030, .input = "\x81\x30+", .expected = "�0+" },
    .{ .encoding = &enc.GB18030, .input = "\x81\x30\x80", .expected = "�0€" },
    .{ .encoding = &enc.GB18030, .input = "\x81\x30\xff", .expected = "�0�" },
    .{ .encoding = &enc.GB18030, .input = "\x81\x30\x81+", .expected = "�0�+" },
    .{ .encoding = &enc.GBK, .input = "\x81\x30\x81+", .expected = "�0�+" },
};

fn expectUnits(expected: []const u8, actual: []const u16) !void {
    const units = try std.unicode.utf8ToUtf16LeAlloc(testing.allocator, expected);
    defer testing.allocator.free(units);
    for (units) |*unit| unit.* = std.mem.littleToNative(u16, unit.*);
    try testing.expectEqualSlices(u16, units, actual);
}

fn expectReplacement(case: Case, split: usize) !void {
    var decoder = case.encoding.newDecoder();
    var units: [128]u16 = undefined;
    const first = decoder.decodeReplacement(case.input[0..split], &units, false);
    try testing.expectEqual(.input_empty, first.status);
    try testing.expectEqual(split, first.bytes_consumed);
    const last = decoder.decodeReplacement(case.input[split..], units[first.code_units_written..], true);
    try testing.expectEqual(.input_empty, last.status);
    try testing.expectEqual(case.input.len - split, last.bytes_consumed);
    try expectUnits(case.expected, units[0 .. first.code_units_written + last.code_units_written]);

    decoder = case.encoding.newDecoder();
    var bytes: [128]u8 = undefined;
    const a = decoder.decodeToUtf8Replacement(case.input[0..split], &bytes, false);
    try testing.expectEqual(.input_empty, a.status);
    try testing.expectEqual(split, a.bytes_consumed);
    const b = decoder.decodeToUtf8Replacement(case.input[split..], bytes[a.bytes_written..], true);
    try testing.expectEqual(.input_empty, b.status);
    try testing.expectEqual(case.input.len - split, b.bytes_consumed);
    try testing.expectEqualStrings(case.expected, bytes[0 .. a.bytes_written + b.bytes_written]);
}

test "legacy malformed sequences preserve ASCII and restored bytes at every split" {
    for (cases) |case| for (0..case.input.len + 1) |split| try expectReplacement(case, split);
}

test "legacy handlers report fatal errors on both output paths" {
    for (cases) |case| {
        var decoder = case.encoding.newDecoder();
        var units: [128]u16 = undefined;
        try testing.expectEqual(.malformed, decoder.decode(case.input, &units, true).status);
        decoder = case.encoding.newDecoder();
        var bytes: [128]u8 = undefined;
        try testing.expectEqual(.malformed, decoder.decodeToUtf8(case.input, &bytes, true).status);
    }
}

test "legacy final empty call reports one unfinished-sequence error" {
    const encodings = [_]*const encoding.Encoding{ &enc.BIG5, &enc.EUC_KR, &enc.EUC_JP, &enc.GB18030, &enc.GBK };
    for (encodings) |e| {
        var decoder = e.newDecoder();
        var units: [8]u16 = undefined;
        const first = decoder.decode(&.{0xa1}, &units, false);
        try testing.expectEqual(.input_empty, first.status);
        try testing.expectEqual(@as(usize, 0), first.code_units_written);
        const last = decoder.decode(&.{}, &units, true);
        try testing.expectEqual(.malformed, last.status);
        try testing.expectEqual(@as(usize, 0), last.bytes_consumed);
        try testing.expectEqual(@as(u8, 0), last.error_length);
        try testing.expectEqual(.input_empty, decoder.decode(&.{}, &units, true).status);
    }
}

test "replacement retries preserve decoder state with small output buffers" {
    for (cases) |case| {
        var decoder = case.encoding.newDecoder();
        var bytes: [128]u8 = undefined;
        var read: usize = 0;
        var written: usize = 0;
        for (0..32) |_| {
            const r = decoder.decodeToUtf8Replacement(case.input[read..], bytes[written..][0..3], true);
            read += r.bytes_consumed;
            written += r.bytes_written;
            if (r.status == .input_empty) break;
            try testing.expectEqual(.output_full, r.status);
        } else return error.DecoderDidNotFinish;
        try testing.expectEqual(case.input.len, read);
        try testing.expectEqualStrings(case.expected, bytes[0..written]);
    }
}

test "EUC-JP halfwidth prefix with a non-halfwidth trail reports malformed" {
    var decoder = enc.EUC_JP.newDecoder();
    var units: [8]u16 = undefined;
    try testing.expectEqual(.malformed, decoder.decode(&.{ 0x8e, 0xe0 }, &units, true).status);
}

test "legacy output-full retry retains complete multi-code-point and supplementary output" {
    const valid = [_]Case{
        .{ .encoding = &enc.BIG5, .input = "A\x88\x62B\xfe\xfdC", .expected = "AÊ̄B\u{2910d}C" },
        .{ .encoding = &enc.EUC_JP, .input = "A\xb0\xb0B", .expected = "A旭B" },
        .{ .encoding = &enc.EUC_KR, .input = "A\x81\x41B", .expected = "A갂B" },
        .{ .encoding = &enc.GB18030, .input = "A\x90\x30\x81\x30B", .expected = "A\u{10000}B" },
        .{ .encoding = &enc.GBK, .input = "A\x90\x30\x81\x30B", .expected = "A\u{10000}B" },
    };
    for (valid) |case| {
        for (0..case.input.len + 1) |split| try expectReplacement(case, split);
        for (0..9) |capacity| {
            var decoder = case.encoding.newDecoder();
            var units: [128]u16 = undefined;
            const a = decoder.decodeReplacement(case.input, units[0..capacity], true);
            try testing.expect(a.status != .malformed);
            const b = decoder.decodeReplacement(case.input[a.bytes_consumed..], units[a.code_units_written..], true);
            try testing.expectEqual(.input_empty, b.status);
            try testing.expectEqual(case.input.len, a.bytes_consumed + b.bytes_consumed);
            try expectUnits(case.expected, units[0 .. a.code_units_written + b.code_units_written]);

            decoder = case.encoding.newDecoder();
            var bytes: [128]u8 = undefined;
            const x = decoder.decodeToUtf8Replacement(case.input, bytes[0..capacity], true);
            try testing.expect(x.status != .malformed);
            const y = decoder.decodeToUtf8Replacement(case.input[x.bytes_consumed..], bytes[x.bytes_written..], true);
            try testing.expectEqual(.input_empty, y.status);
            try testing.expectEqual(case.input.len, x.bytes_consumed + y.bytes_consumed);
            try testing.expectEqualStrings(case.expected, bytes[0 .. x.bytes_written + y.bytes_written]);
        }
    }
}

// Checkpoint rollback is shared by replacement mode and both output encodings.
// Exercise it after valid output as well as at the first malformed item.
test "malformed output-full retry loses neither valid prefixes nor restored input" {
    for (cases) |case| {
        const input = try std.mem.concat(testing.allocator, u8, &.{ "ab", case.input, "cd" });
        defer testing.allocator.free(input);
        const expected = try std.mem.concat(testing.allocator, u8, &.{ "ab", case.expected, "cd" });
        defer testing.allocator.free(expected);
        for (0..12) |capacity| {
            var decoder = case.encoding.newDecoder();
            var units: [128]u16 = undefined;
            const a = decoder.decodeReplacement(input, units[0..capacity], true);
            const b = decoder.decodeReplacement(input[a.bytes_consumed..], units[a.code_units_written..], true);
            try testing.expectEqual(.input_empty, b.status);
            try testing.expectEqual(input.len, a.bytes_consumed + b.bytes_consumed);
            try expectUnits(expected, units[0 .. a.code_units_written + b.code_units_written]);

            decoder = case.encoding.newDecoder();
            var bytes: [128]u8 = undefined;
            const x = decoder.decodeToUtf8Replacement(input, bytes[0..capacity], true);
            const y = decoder.decodeToUtf8Replacement(input[x.bytes_consumed..], bytes[x.bytes_written..], true);
            try testing.expectEqual(.input_empty, y.status);
            try testing.expectEqual(input.len, x.bytes_consumed + y.bytes_consumed);
            try testing.expectEqualStrings(expected, bytes[0 .. x.bytes_written + y.bytes_written]);
        }
    }
}
