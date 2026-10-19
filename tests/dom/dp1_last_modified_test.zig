//! Pure HTML lastModified formatting; platform conversion is tested separately.
const std = @import("std");
const dom = @import("dom");

test "dp1 lastModified formatter pads each calendar field and retains long years" {
    if (comptime !@hasDecl(dom, "document_last_modified")) {
        try std.testing.expect(false);
    } else {
        const allocator = std.testing.allocator;
        const cases = .{
            .{ dom.document_last_modified.LocalDateTime{ .year = 7, .month = 2, .day = 3, .hour = 4, .minute = 5, .second = 6 }, "02/03/0007 04:05:06" },
            .{ dom.document_last_modified.LocalDateTime{ .year = 1969, .month = 12, .day = 31, .hour = 23, .minute = 59, .second = 59 }, "12/31/1969 23:59:59" },
            .{ dom.document_last_modified.LocalDateTime{ .year = 2024, .month = 2, .day = 29, .hour = 0, .minute = 0, .second = 0 }, "02/29/2024 00:00:00" },
            .{ dom.document_last_modified.LocalDateTime{ .year = 10000, .month = 10, .day = 20, .hour = 12, .minute = 34, .second = 56 }, "10/20/10000 12:34:56" },
        };
        inline for (cases) |case| {
            const actual = try dom.document_last_modified.format(allocator, case[0]);
            defer allocator.free(actual);
            try std.testing.expectEqualStrings(case[1], actual);
        }
    }
}
