//! URLPattern parse step 1 and add-a-part step 11 use the generated spelling.
const std = @import("std");
const up = @import("urlpattern");
const A = std.testing.allocator;

test "URLPattern segment wildcard identity uses the generated escaped delimiter" {
    const cases = .{
        .{ "([^\\/]+?)", up.parser.pathname_options },
        .{ "([^\\.]+?)", up.parser.hostname_options },
        .{ "([^]+?)", up.parser.default_options },
        .{ "([^\\+]+?)", up.Options{ .delimiter_code_point = "+" } },
    };
    inline for (cases) |case| {
        var parts = try up.parsePatternString(A, case[0], case[1], up.identityEncoding);
        defer parts.deinit();
        try std.testing.expectEqual(up.PartType.segment_wildcard, parts.parts[0].type);
    }
}

test "URLPattern equivalent but differently spelled regexp remains a regexp" {
    const cases = .{
        .{ "([^/]+?)", up.parser.pathname_options },
        .{ "([^.]+?)", up.parser.hostname_options },
    };
    inline for (cases) |case| {
        var parts = try up.parsePatternString(A, case[0], case[1], up.identityEncoding);
        defer parts.deinit();
        try std.testing.expectEqual(up.PartType.regexp, parts.parts[0].type);
    }
}
