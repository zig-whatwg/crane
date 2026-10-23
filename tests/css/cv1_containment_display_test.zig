//! CSS Contain 2 §3.1: principal-box requirements for size containment.
const std = @import("std");
const Display = @import("css").style_values.Display;

test "size containment applies only to eligible principal boxes" {
    if (comptime @hasDecl(Display, "canSizeContain")) return Checks.display();
    return error.MissingContainmentApplicability;
}

const Checks = struct {
    fn display() !void {
        const Case = struct { display: Display, replaced: bool = false, expected: bool };
        for ([_]Case{
            .{ .display = .none, .expected = false },
            .{ .display = .contents, .expected = false },
            .{ .display = .block_flow, .expected = true },
            .{ .display = .inline_flow, .expected = false },
            .{ .display = .inline_flow, .replaced = true, .expected = true },
            .{ .display = .{ .outer = .run_in }, .expected = false },
            .{ .display = .{ .outer = .run_in, .inner = .flow_root }, .expected = true },
            .{ .display = .{ .inner = .flow_root }, .expected = true },
            .{ .display = .{ .inner = .flex }, .expected = true },
            .{ .display = .{ .inner = .grid }, .expected = true },
            .{ .display = .{ .inner = .table }, .expected = false },
            .{ .display = .{ .outer = .block, .inner = .table }, .expected = false },
            .{ .display = .{ .inner = .ruby }, .expected = false },
            .{ .display = .{ .box = .internal, .internal = .table_caption }, .expected = true },
        }) |case| try std.testing.expectEqual(case.expected, case.display.canSizeContain(case.replaced));
        inline for (std.meta.tags(Display.Internal)) |kind| {
            const d: Display = .{ .box = .internal, .internal = kind };
            try std.testing.expectEqual(kind == .table_caption, d.canSizeContain(false));
        }
    }
};
