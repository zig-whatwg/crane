//! SRI's structured-field projection validates once and keeps only tokens.
const std = @import("std");
const sf = @import("fetch").internal.structured_fields;

fn check() !void {
    if (comptime @hasDecl(sf, "parseTokenListDictionary")) {
        const a = std.testing.allocator;
        var parsed = try sf.parseTokenListDictionary(a, "a=(script;p=1 \"style\" 3 ?1 style;x=\"v\");p=1, b=script, c=(), a=(inline)");
        defer parsed.deinit(a);
        try std.testing.expectEqual(@as(usize, 3), parsed.members.items.len);
        try std.testing.expectEqualStrings("a", parsed.members.items[0].key);
        try std.testing.expectEqual(@as(usize, 1), parsed.members.items[0].tokens.?.len);
        try std.testing.expectEqualStrings("inline", parsed.members.items[0].tokens.?[0]);
        try std.testing.expect(parsed.members.items[1].tokens == null);
        try std.testing.expectEqual(@as(usize, 0), parsed.members.items[2].tokens.?.len);
        var mixed = try sf.parseTokenListDictionary(a, "a=(script;p=1 \"style\" 3 ?1 style;x=\"v\")");
        defer mixed.deinit(a);
        try std.testing.expectEqual(@as(usize, 2), mixed.members.items[0].tokens.?.len);
        try std.testing.expectEqualStrings("script", mixed.members.items[0].tokens.?[0]);
        try std.testing.expectEqualStrings("style", mixed.members.items[0].tokens.?[1]);
        for ([_][]const u8{ "a=(script", "a=(script,style)", "a=(script\tstyle)", "a=('script')", "a=(script), b=(broken", "a=(script),", "a=(script), b=\"\xc3\xa9\"" }) |header| {
            try std.testing.expectError(error.InvalidField, sf.parseTokenListDictionary(a, header));
        }
    } else return error.TestUnexpectedResult;
}

test "sri policy token-list projection preserves types order and whole-field failure" {
    try check();
}

fn allocationTrial(a: std.mem.Allocator) anyerror!void {
    if (comptime @hasDecl(sf, "parseTokenListDictionary")) {
        var parsed = try sf.parseTokenListDictionary(a, "a=(script \"discarded\" ?1), a=(inline), b=(last), b=scalar");
        defer parsed.deinit(a);
        try std.testing.expectEqual(@as(usize, 2), parsed.members.items.len);
        try std.testing.expect(parsed.members.items[1].tokens == null);
    } else return error.TestUnexpectedResult;
}

test "sri policy token-list projection releases partial arrays on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationTrial, .{});
}
