//! The raw UTF-8 fallback preserves scalar, EOF and output-capacity boundaries.
const std = @import("std");
const encoding = @import("encoding");
const testing = std.testing;
const enc = encoding.encoding;
const Case = struct { encoding: *const encoding.Encoding, input: []const u8, expected: []const u8 };
const scalar_cases = [_]Case{
    .{ .encoding = &enc.UTF_8, .input = "A💩水B", .expected = "A💩水B" },
    .{ .encoding = &enc.UTF_16LE, .input = "A\x00\x3d\xd8\xa9\xdc\x34\x6cB\x00", .expected = "A💩水B" },
    .{ .encoding = &enc.UTF_16BE, .input = "\x00A\xd8\x3d\xdc\xa9\x6c\x34\x00B", .expected = "A💩水B" },
    .{ .encoding = &enc.X_USER_DEFINED, .input = "A\x80\xffB", .expected = "A\u{f780}\u{f7ff}B" },
};

test "UTF-8 fallback encodes supplementary scalars and every input split" {
    for (scalar_cases) |case| {
        for (0..case.input.len + 1) |split| {
            var decoder = case.encoding.newDecoder();
            var output: [128]u8 = undefined;
            const a = decoder.decodeToUtf8(case.input[0..split], &output, false);
            try testing.expectEqual(.input_empty, a.status);
            const b = decoder.decodeToUtf8(case.input[split..], output[a.bytes_written..], true);
            try testing.expectEqual(.input_empty, b.status);
            try testing.expectEqual(case.input.len, a.bytes_consumed + b.bytes_consumed);
            try testing.expectEqualStrings(case.expected, output[0 .. a.bytes_written + b.bytes_written]);
        }
    }
}

test "UTF-8 fallback preserves a scalar at the 256 UTF-16 unit boundary" {
    for (scalar_cases) |case| {
        const ascii: []const u8 = if (case.encoding == &enc.UTF_16LE) "a\x00" else if (case.encoding == &enc.UTF_16BE) "\x00a" else "a";
        const prefix = try testing.allocator.alloc(u8, 255 * ascii.len);
        defer testing.allocator.free(prefix);
        for (0..255) |i| @memcpy(prefix[i * ascii.len ..][0..ascii.len], ascii);
        // Drop the scalar case's initial A: the supplementary scalar follows
        // exactly 255 ordinary UTF-16 units in the intermediate buffer.
        const input = try std.mem.concat(testing.allocator, u8, &.{ prefix, case.input[ascii.len..] });
        defer testing.allocator.free(input);
        const expected = try std.mem.concat(testing.allocator, u8, &.{ "a" ** 255, case.expected[1..] });
        defer testing.allocator.free(expected);
        const output = try testing.allocator.alloc(u8, 2048);
        defer testing.allocator.free(output);
        var decoder = case.encoding.newDecoder();
        const result = decoder.decodeToUtf8(input, output, true);
        try testing.expectEqual(.input_empty, result.status);
        try testing.expectEqual(input.len, result.bytes_consumed);
        try testing.expectEqualStrings(expected, output[0..result.bytes_written]);
    }
}

test "UTF-8 fallback flushes an incomplete sequence on empty final input" {
    const cases = .{ .{ &enc.UTF_8, "\xe2\x82" }, .{ &enc.UTF_16LE, "A" }, .{ &enc.UTF_16BE, "A" } };
    inline for (cases) |case| {
        var decoder = case[0].newDecoder();
        var output: [32]u8 = undefined;
        try testing.expectEqual(.input_empty, decoder.decodeToUtf8(case[1], &output, false).status);
        const result = decoder.decodeToUtf8(&.{}, &output, true);
        try testing.expectEqual(.malformed, result.status);
        try testing.expectEqual(@as(usize, 0), result.bytes_consumed);
        try testing.expectEqual(@as(u8, 0), result.error_length);
        try testing.expectEqual(.input_empty, decoder.decodeToUtf8(&.{}, &output, true).status);

        decoder = case[0].newDecoder();
        _ = decoder.decodeToUtf8Replacement(case[1], &output, false);
        const replacement = decoder.decodeToUtf8Replacement(&.{}, &output, true);
        try testing.expectEqual(.input_empty, replacement.status);
        try testing.expectEqualStrings("�", output[0..replacement.bytes_written]);
    }
}

test "UTF-8 fallback output-full retries match one large decode" {
    for (scalar_cases) |case| {
        for (0..12) |capacity| {
            var decoder = case.encoding.newDecoder();
            var output: [128]u8 = undefined;
            const a = decoder.decodeToUtf8(case.input, output[0..capacity], true);
            try testing.expect(a.status != .malformed);
            if (capacity < 3) {
                try testing.expectEqual(.output_full, a.status);
                try testing.expectEqual(@as(usize, 0), a.bytes_consumed);
                try testing.expectEqual(@as(usize, 0), a.bytes_written);
            }
            const b = decoder.decodeToUtf8(case.input[a.bytes_consumed..], output[a.bytes_written..], true);
            try testing.expectEqual(.input_empty, b.status);
            try testing.expectEqual(case.input.len, a.bytes_consumed + b.bytes_consumed);
            try testing.expectEqualStrings(case.expected, output[0 .. a.bytes_written + b.bytes_written]);
        }
        var decoder = case.encoding.newDecoder();
        var output: [128]u8 = undefined;
        var read: usize = 0;
        var written: usize = 0;
        for (0..32) |_| {
            const r = decoder.decodeToUtf8(case.input[read..], output[written..][0..6], true);
            read += r.bytes_consumed;
            written += r.bytes_written;
            if (r.status == .input_empty) break;
            try testing.expectEqual(.output_full, r.status);
        } else return error.DecoderDidNotFinish;
        try testing.expectEqual(case.input.len, read);
        try testing.expectEqualStrings(case.expected, output[0..written]);
    }
}

test "UTF-8 decoder drains a supplementary scalar deferred by a one-unit output" {
    for ([_][]const u8{ "", "B" }) |next| {
        var decoder = enc.UTF_8.newDecoder();
        var units: [260]u16 = undefined;
        const input = "a" ** 255 ++ "💩";
        const first = decoder.decode(input, units[0..256], false);
        try testing.expectEqual(.output_full, first.status);
        try testing.expectEqual(input.len, first.bytes_consumed);
        try testing.expectEqual(@as(usize, 255), first.code_units_written);
        try testing.expectEqualSlices(u16, &([_]u16{'a'} ** 255), units[0..first.code_units_written]);
        const small = decoder.decode(next, units[0..1], true);
        try testing.expectEqual(.output_full, small.status);
        try testing.expectEqual(@as(usize, 0), small.bytes_consumed);
        const last = decoder.decode(next, &units, true);
        try testing.expectEqual(.input_empty, last.status);
        try testing.expectEqualSlices(u16, if (next.len == 0) &.{ 0xd83d, 0xdca9 } else &.{ 0xd83d, 0xdca9, 'B' }, units[0..last.code_units_written]);
    }
}

test "UTF-8 replacement decoder drains deferred output before more input" {
    const input = "A💩B\xffC";
    var decoder = enc.UTF_8.newDecoder();
    var units: [32]u16 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    for (0..16) |_| {
        const result = decoder.decodeReplacement(input[read..], units[written..][0..2], true);
        read += result.bytes_consumed;
        written += result.code_units_written;
        if (result.status == .input_empty) break;
        try testing.expectEqual(.output_full, result.status);
    } else return error.DecoderDidNotFinish;
    try testing.expectEqual(input.len, read);
    try testing.expectEqualSlices(u16, &.{ 'A', 0xd83d, 0xdca9, 'B', 0xfffd, 'C' }, units[0..written]);
}
