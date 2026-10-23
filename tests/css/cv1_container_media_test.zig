//! Q97: Media Queries5 §1.3 plus Conditional5 §7, no element scope.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "elementless media features resolve all container units through small viewport fallback" {
    inline for (.{
        "(width: 100cqw)",  "(height: 100cqh)",   "(width: 100cqi)",
        "(height: 100cqb)", "(height: 100cqmin)", "(width: 100cqmax)",
    }) |query| {
        var parsed = try css.media_queries.MediaQueryList.parse(testing.allocator, query);
        defer parsed.deinit();
        try testing.expect(parsed.matches(&.{ .width = 800, .height = 600 }));
    }
}

test "container media lengths preserve comparisons and unknown unit rejection" {
    inline for (.{
        .{ "(width > 50cqw)", true },            .{ "(width < 50cqw)", false },
        .{ "(width: 90cqw)", false },            .{ "(height: 90cqh)", false },
        .{ "(width: 100CQW)", true },            .{ "(width: 100cqunknown)", false },
        .{ "not (width: 100cqunknown)", false }, .{ "(height > -100cqh)", true },
    }) |case| {
        var parsed = try css.media_queries.MediaQueryList.parse(testing.allocator, case[0]);
        defer parsed.deinit();
        try testing.expectEqual(case[1], parsed.matches(&.{ .width = 800, .height = 600 }));
    }
}
