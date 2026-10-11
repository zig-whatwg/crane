//! Verify generated IDNA property lookups at boundaries, including defaults.
const std = @import("std");
const data = @import("url").idna.unicode_data_mod;

test "IDNA Unicode17 mapping covers new assigned characters and rejects reserved ones" {
    try std.testing.expectEqual(data.IdnaStatus.valid, data.lookupIdnaStatus(0x323b0).status);
    try std.testing.expectEqual(data.IdnaStatus.valid, data.lookupIdnaStatus(0x33479).status);
    try std.testing.expectEqual(data.IdnaStatus.disallowed, data.lookupIdnaStatus(0x3347a).status);
    try std.testing.expectEqual(data.IdnaStatus.disallowed, data.lookupIdnaStatus(0x10ffff).status);
    try std.testing.expectEqualStrings("ß", data.lookupIdnaStatus(0x1e9e).mapping.?);
}

test "IDNA general-category marks include spacing marks with zero combining class" {
    try std.testing.expect(data.isMark(0x903));
    try std.testing.expectEqual(@as(u8, 0), data.lookupCombiningClass(0x903));
    try std.testing.expect(data.isMark(0x20dd));
    try std.testing.expect(!data.isMark('a'));
    try std.testing.expect(data.isMark(0x300));
    try std.testing.expect(!data.isMark(0x2ff));
}

test "IDNA joining types distinguish joining and transparent letters" {
    try std.testing.expectEqual(data.JoiningType.U, data.lookupJoiningType('a'));
    try std.testing.expectEqual(data.JoiningType.R, data.lookupJoiningType(0x627));
    try std.testing.expectEqual(data.JoiningType.D, data.lookupJoiningType(0x628));
    try std.testing.expectEqual(data.JoiningType.T, data.lookupJoiningType(0x64e));
    try std.testing.expectEqual(data.JoiningType.U, data.lookupJoiningType(0x200c));
}

test "IDNA bidi defaults and canonical composition lookups preserve boundaries" {
    try std.testing.expectEqual(data.BidiClass.L, data.lookupBidiClass('a'));
    try std.testing.expectEqual(data.BidiClass.R, data.lookupBidiClass(0x5d0));
    try std.testing.expectEqual(data.BidiClass.AL, data.lookupBidiClass(0x627));
    try std.testing.expectEqual(data.BidiClass.NSM, data.lookupBidiClass(0x64e));
    try std.testing.expectEqual(@as(?u21, 0x9cb), data.lookupComposition(0x9c7, 0x9be));
    try std.testing.expectEqual(@as(?u21, null), data.lookupComposition(0x9c7, 0x9bf));
    try std.testing.expect(data.isCompositionExcluded(0x340));
    try std.testing.expect(!data.isCompositionExcluded(0xe0));
}
