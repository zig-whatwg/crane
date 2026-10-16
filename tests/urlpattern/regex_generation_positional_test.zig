//! URLPattern 2.2, "generate a regular expression and name list": positional
//! ECMAScript capture groups and a separate name list (urlpattern.md:3170ff;
//! Chromium's liburlpattern pattern.cc is positional too). Red on the
//! PCRE-named mock's generator, which emitted (?P<name>...) (Codex row 26,
//! preserved red in wpt-results/lanes/codex-urlpattern-72f5446996c0/).
const std = @import("std");
const up = @import("urlpattern");
const A = std.testing.allocator;

test "URLPattern generated regexp uses positional captures" {
    const cases = [_][2][]const u8{
        .{ "/:name", "^(?:\\/([^\\/]+?))$" },
        .{ "/:name?", "^(?:\\/([^\\/]+?))?$" },
        .{ ":name+", "^((?:[^\\/]+?)+)$" },
        .{ "/:name+", "^(?:\\/((?:[^\\/]+?)(?:\\/(?:[^\\/]+?))*))$" },
        .{ "/:name*", "^(?:\\/((?:[^\\/]+?)(?:\\/(?:[^\\/]+?))*))?$" },
        .{ "{pre:name(a|b)suf}+", "^(?:pre((?:a|b)(?:sufpre(?:a|b))*)suf)$" },
        .{ "*", "^(.*)$" },
    };
    for (cases) |case| {
        var parts = try up.parsePatternString(A, case[0], up.parser.pathname_options, up.identityEncoding);
        defer parts.deinit();
        var result = try up.generateRegexAndNameList(A, parts.parts, up.parser.pathname_options);
        defer result.deinit();
        try std.testing.expectEqualStrings(case[1], result.regex);
        try std.testing.expectEqual(@as(usize, 1), result.name_list.len);
        try std.testing.expectEqualStrings(if (std.mem.eql(u8, case[0], "*")) "0" else "name", result.name_list[0]);
    }
}
