//! The Encoding encode-or-fail hook returns the handler's error scalar.
const std = @import("std");
const encoding = @import("encoding");
const enc = encoding.encoding;

test "encode or fail reports a supplementary scalar rather than its low surrogate" {
    const encodings = [_]*const encoding.Encoding{ &enc.GBK, &enc.BIG5, &enc.EUC_JP, &enc.EUC_KR, &enc.SHIFT_JIS, &enc.X_USER_DEFINED };
    for (encodings) |e| {
        var encoder = e.newEncoder().?;
        var output: [16]u8 = undefined;
        try std.testing.expectEqual(@as(?u21, 0x1f4a9), encoding.hooks.encodeOrFail(&encoder, &.{ 0xd83d, 0xdca9 }, &output));
    }
    var encoder = enc.GB18030.newEncoder().?;
    var output: [16]u8 = undefined;
    try std.testing.expectEqual(@as(?u21, 0xe5e5), encoding.hooks.encodeOrFail(&encoder, &.{0xe5e5}, &output));
    try std.testing.expectEqual(@as(?u21, null), encoding.hooks.encodeOrFail(&encoder, &.{'A'}, &output));
}
