//! HTML get-noopener steps 1–2 and submission's no-referrer policy.
const std = @import("std");
const forms = @import("html").forms;

test "form target policy tokenizes ASCII whitespace and ignores token case" {
    const cases = [_]struct { rel: []const u8, target: []const u8, noopener: bool, noreferrer: bool }{
        .{ .rel = "", .target = "_blank", .noopener = true, .noreferrer = false },
        .{ .rel = "", .target = "_BlAnK", .noopener = true, .noreferrer = false },
        .{ .rel = "", .target = "named", .noopener = false, .noreferrer = false },
        .{ .rel = "", .target = "_self", .noopener = false, .noreferrer = false },
        .{ .rel = "OPENER", .target = "_blank", .noopener = false, .noreferrer = false },
        .{ .rel = "noopener", .target = "named", .noopener = true, .noreferrer = false },
        .{ .rel = "noreferrer", .target = "named", .noopener = true, .noreferrer = true },
        .{ .rel = "opener\tNOOPENER\nexternal", .target = "_blank", .noopener = true, .noreferrer = false },
        .{ .rel = "opener\r\x0cNoReFeRrEr ", .target = "_blank", .noopener = true, .noreferrer = true },
        .{ .rel = "xnoopener noreferrerx", .target = "named", .noopener = false, .noreferrer = false },
        .{ .rel = "noopener\xc2\xa0opener", .target = "named", .noopener = false, .noreferrer = false },
    };
    for (cases) |case| {
        // Heap-backed input also pins that the result borrows no token storage.
        const rel = try std.testing.allocator.dupe(u8, case.rel);
        const policy = forms.targetPolicy(rel, case.target);
        std.testing.allocator.free(rel);
        try std.testing.expectEqual(case.noopener, policy.noopener);
        try std.testing.expectEqual(case.noreferrer, policy.noreferrer);
    }
}
