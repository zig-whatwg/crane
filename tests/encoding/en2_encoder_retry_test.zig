//! A slice encoder checkpoints this call's cursor and its carried surrogate.
const std = @import("std");
const encoding = @import("encoding");
const testing = std.testing;
const enc = encoding.encoding;
const Case = struct { encoding: *const encoding.Encoding, high: u16 = 0xd800, low: u16 = 0xdc00, encoded: ?[]const u8 = null };
const cases = [_]Case{
    .{ .encoding = &enc.GB18030, .encoded = "\x90\x30\x81\x30" },
    .{ .encoding = &enc.BIG5, .high = 0xd864, .low = 0xdd0d, .encoded = "\xfe\xfd" },
    .{ .encoding = &enc.EUC_JP },
    .{ .encoding = &enc.EUC_KR },
    .{ .encoding = &enc.SHIFT_JIS },
    .{ .encoding = &enc.X_USER_DEFINED },
    .{ .encoding = &enc.GBK },
    .{ .encoding = &enc.ISO_2022_JP },
};

test "legacy encoders retry a supplementary scalar whose high came in a previous call" {
    for (cases) |case| {
        for (0..4) |capacity| {
            var encoder = case.encoding.newEncoder().?;
            var output: [16]u8 = undefined;
            const first = encoder.encode(&.{case.high}, &output, false);
            try testing.expectEqual(.input_empty, first.status);
            try testing.expectEqual(@as(usize, 1), first.code_units_consumed);
            try testing.expectEqual(@as(usize, 0), first.bytes_written);
            const result = encoder.encode(&.{case.low}, output[0..capacity], false);
            if (case.encoded) |expected| {
                if (capacity < expected.len) {
                    try testing.expectEqual(.output_full, result.status);
                    try testing.expectEqual(@as(usize, 0), result.code_units_consumed);
                    try testing.expectEqual(@as(usize, 0), result.bytes_written);
                    const retry = encoder.encode(&.{case.low}, &output, true);
                    try testing.expectEqual(.input_empty, retry.status);
                    try testing.expectEqual(@as(usize, 1), retry.code_units_consumed);
                    try testing.expectEqualStrings(expected, output[0..retry.bytes_written]);
                } else {
                    try testing.expectEqual(.input_empty, result.status);
                    try testing.expectEqualStrings(expected, output[0..result.bytes_written]);
                }
            } else {
                // These encoders cannot represent supplementary scalars, so
                // the handler reports unmappable before testing output space.
                try testing.expectEqual(.unmappable, result.status);
                try testing.expectEqual(@as(u21, 0x10000), result.error_code_point);
                try testing.expectEqual(@as(usize, 0), result.code_units_consumed);
            }
            const after = encoder.encode(&.{'A'}, &output, true);
            try testing.expectEqual(.input_empty, after.status);
            try testing.expectEqualStrings("A", output[0..after.bytes_written]);
        }
    }
}

test "legacy encoders leave the non-low unit unread after a pending surrogate error" {
    for (cases) |case| {
        for (0..4) |capacity| {
            var encoder = case.encoding.newEncoder().?;
            var output: [16]u8 = undefined;
            _ = encoder.encode(&.{case.high}, &output, false);
            const result = encoder.encode(&.{'A'}, output[0..capacity], false);
            try testing.expectEqual(@as(usize, 0), result.code_units_consumed);
            try testing.expectEqual(@as(usize, 0), result.bytes_written);
            const is_gb18030 = case.encoding == &enc.GB18030;
            try testing.expectEqual(@as(@TypeOf(result.status), if (is_gb18030) .output_full else .unmappable), result.status);
            if (!is_gb18030) try testing.expectEqual(@as(u21, 0xfffd), result.error_code_point);
            const retry = encoder.encode(&.{'A'}, &output, true);
            try testing.expectEqual(.input_empty, retry.status);
            try testing.expectEqual(@as(usize, 1), retry.code_units_consumed);
            try testing.expectEqualStrings(if (is_gb18030) "\x84\x31\xa4\x37A" else "A", output[0..retry.bytes_written]);
        }
    }
}

test "legacy encoders preserve a valid prefix before a surrogate retry" {
    for (cases) |case| {
        var encoder = case.encoding.newEncoder().?;
        var output: [16]u8 = undefined;
        const input = [_]u16{ 'A', case.high, 'B' };
        const result = encoder.encode(&input, output[0..1], false);
        try testing.expectEqual(@as(usize, 2), result.code_units_consumed);
        try testing.expectEqualStrings("A", output[0..result.bytes_written]);
        const retry = encoder.encode(input[result.code_units_consumed..], output[1..], true);
        try testing.expectEqual(.input_empty, retry.status);
        try testing.expectEqualStrings(if (case.encoding == &enc.GB18030) "A\x84\x31\xa4\x37B" else "AB", output[0 .. 1 + retry.bytes_written]);
    }
}

test "legacy encoder consumes a final lone surrogate error only once" {
    for (cases) |case| {
        var encoder = case.encoding.newEncoder().?;
        var output: [16]u8 = undefined;
        _ = encoder.encode(&.{case.high}, &output, false);
        const last = encoder.encode(&.{}, &output, true);
        try testing.expectEqual(@as(@TypeOf(last.status), if (case.encoding == &enc.GB18030) .input_empty else .unmappable), last.status);
        const again = encoder.encode(&.{}, &output, true);
        try testing.expectEqual(.input_empty, again.status);
        try testing.expectEqual(@as(usize, 0), again.bytes_written);
    }
}

test "ISO-2022-JP final surrogate error emits its ASCII designation once" {
    for (0..4) |capacity| {
        var encoder = enc.ISO_2022_JP.newEncoder().?;
        var output: [16]u8 = undefined;
        const first = encoder.encode(&.{ 0x6c34, 0xd800 }, &output, false);
        try testing.expectEqual(.input_empty, first.status);
        try testing.expectEqualStrings("\x1b$B\x3f\x65", output[0..first.bytes_written]);
        var last = encoder.encode(&.{}, output[0..capacity], true);
        if (capacity < 3) {
            try testing.expectEqual(.output_full, last.status);
            try testing.expectEqual(@as(usize, 0), last.bytes_written);
            last = encoder.encode(&.{}, &output, true);
        }
        try testing.expectEqual(.unmappable, last.status);
        try testing.expectEqual(@as(u21, 0xfffd), last.error_code_point);
        try testing.expectEqualStrings("\x1b(B", output[0..last.bytes_written]);
        const again = encoder.encode(&.{}, &output, true);
        try testing.expectEqual(.input_empty, again.status);
        try testing.expectEqual(@as(usize, 0), again.bytes_written);
    }
}

test "ISO-2022-JP Roman mode finishes after reporting a lone surrogate once" {
    var encoder = enc.ISO_2022_JP.newEncoder().?;
    var output: [16]u8 = undefined;
    const first = encoder.encode(&.{ 0xa5, 0xd800 }, &output, false);
    try testing.expectEqual(.input_empty, first.status);
    try testing.expectEqualStrings("\x1b(J\\", output[0..first.bytes_written]);
    const last = encoder.encode(&.{}, &output, true);
    try testing.expectEqual(.unmappable, last.status);
    try testing.expectEqual(@as(usize, 0), last.bytes_written);
    const small = encoder.encode(&.{}, output[0..2], true);
    try testing.expectEqual(.output_full, small.status);
    try testing.expectEqual(@as(usize, 0), small.bytes_written);
    const again = encoder.encode(&.{}, &output, true);
    try testing.expectEqual(.input_empty, again.status);
    try testing.expectEqualStrings("\x1b(B", output[0..again.bytes_written]);
}
