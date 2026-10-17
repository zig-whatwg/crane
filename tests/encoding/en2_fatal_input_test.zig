//! Fatal decode drops restored input while preserving the handler's own state.
const std = @import("std");
const encoding = @import("encoding");
const testing = std.testing;
const enc = encoding.encoding;

test "fatal gb18030 discards restored bytes from either the current or previous chunk" {
    for ([_]usize{ 0, 3 }) |split| {
        for ([_]bool{ false, true }) |direct| {
            var decoder = enc.GB18030.newDecoder();
            const input = "\x81\x30\x81+";
            var units: [32]u16 = undefined;
            var bytes: [64]u8 = undefined;
            if (direct) {
                try testing.expectEqual(.input_empty, decoder.decodeToUtf8(input[0..split], &bytes, false).status);
                try testing.expectEqual(.malformed, decoder.decodeToUtf8(input[split..], &bytes, false).status);
                decoder.discardRestoredInputAfterError();
                const result = decoder.decodeToUtf8("@", &bytes, true);
                try testing.expectEqual(.input_empty, result.status);
                try testing.expectEqualStrings("@", bytes[0..result.bytes_written]);
            } else {
                try testing.expectEqual(.input_empty, decoder.decode(input[0..split], &units, false).status);
                try testing.expectEqual(.malformed, decoder.decode(input[split..], &units, false).status);
                decoder.discardRestoredInputAfterError();
                const result = decoder.decode("@", &units, true);
                try testing.expectEqual(.input_empty, result.status);
                try testing.expectEqualSlices(u16, &.{'@'}, units[0..result.code_units_written]);
            }
        }
    }
}

test "fatal UTF-8 discards the failed call's unconsumed suffix" {
    var decoder = enc.UTF_8.newDecoder();
    var units: [16]u16 = undefined;
    const result = decoder.decode("\xfd\xef", &units, false);
    try testing.expectEqual(.malformed, result.status);
    decoder.discardRestoredInputAfterError();
    const tail = decoder.decode(&.{}, &units, true);
    try testing.expectEqual(.input_empty, tail.status);
    try testing.expectEqual(@as(usize, 0), tail.code_units_written);
}

test "fatal ISO-2022-JP discards restored input but keeps Roman output state" {
    for ([_][]const u8{ "\x1b(J\xff", "\x1b(J\x1b(A" }) |input| {
        var decoder = enc.ISO_2022_JP.newDecoder();
        var units: [16]u16 = undefined;
        try testing.expectEqual(.malformed, decoder.decode(input, &units, false).status);
        decoder.discardRestoredInputAfterError();
        const result = decoder.decode("~", &units, true);
        try testing.expectEqual(.input_empty, result.status);
        try testing.expectEqualSlices(u16, &.{0x203e}, units[0..result.code_units_written]);
    }
}

test "fatal UTF-16 discards the byte restored after a lone leading surrogate" {
    const cases = .{
        .{ &enc.UTF_16LE, "\x00\xd8A\x00", "B\x00" },
        .{ &enc.UTF_16BE, "\xd8\x00\x00A", "\x00B" },
    };
    inline for (cases) |case| {
        var decoder = case[0].newDecoder();
        var units: [16]u16 = undefined;
        try testing.expectEqual(.malformed, decoder.decode(case[1], &units, false).status);
        decoder.discardRestoredInputAfterError();
        const empty = decoder.decode(&.{}, &units, false);
        try testing.expectEqual(.input_empty, empty.status);
        try testing.expectEqual(@as(usize, 0), empty.code_units_written);
        const result = decoder.decode(case[2], &units, true);
        try testing.expectEqual(.input_empty, result.status);
        try testing.expectEqualSlices(u16, &.{'B'}, units[0..result.code_units_written]);
    }
}
