//! Canonical URLPattern strings must parse back to the same pattern.
const std = @import("std");
const up = @import("urlpattern");

fn encode(allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error![]u8 {
    return up.canonicalizePathname(allocator, value) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => unreachable, // These inputs are all valid pathname fragments.
    };
}

test "generate a pattern string preserves grouping and boundaries" {
    const cases = [_][2][]const u8{
        .{ "/{foo}?", "/{foo}?" },
        .{ "/{foo}+", "/{foo}+" },
        .{ "{:foo}{(.*)}", "{:foo}(.*)" },
        .{ "{:foo}{(.*)bar}", ":foo{*bar}" },
        .{ "{:foo}{bar(.*)}", ":foo{bar*}" },
        .{ "{:foo\\.bar}", "{:foo.bar}" },
        .{ ":foo\\bar", "{:foo}bar" },
        .{ ":foo{}(.*)", "{:foo}(.*)" },
        .{ "*\\/*", "*/{*}" },
        .{ "/:foo\\bar", "{/:foo}bar" },
        .{ "(foo)(.*)", "(foo)(.*)" },
        .{ "(foo)?(.*)", "(foo)?*" },
        .{ "/a\\+b\\?c", "/a\\+b%3Fc" },
    };
    for (cases) |case| {
        var original = try up.parsePatternString(std.testing.allocator, case[0], up.parser.pathname_options, encode);
        defer original.deinit();
        const serialized = try up.pattern_string.generate(std.testing.allocator, original.parts, up.parser.pathname_options);
        defer std.testing.allocator.free(serialized);
        try std.testing.expectEqualStrings(case[1], serialized);
        var repeated = try up.parsePatternString(std.testing.allocator, serialized, up.parser.pathname_options, encode);
        defer repeated.deinit();
        var before = try up.generateRegexAndNameList(std.testing.allocator, original.parts, up.parser.pathname_options);
        defer before.deinit();
        var after = try up.generateRegexAndNameList(std.testing.allocator, repeated.parts, up.parser.pathname_options);
        defer after.deinit();
        try std.testing.expectEqualStrings(before.regex, after.regex);
    }
}
