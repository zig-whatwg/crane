//! Values 5 §8.7.2 at the consuming grammar, with original input offsets.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn accepts(allocator: std.mem.Allocator, property: []const u8, text: []const u8, needle: ?[]const u8, kind: css.substitution.Taint) !bool {
    const start = if (needle) |n| std.mem.indexOf(u8, text, n).? else 0;
    const taint = [_]css.substitution.TaintRange{.{ .start = start, .end = start + if (needle) |n| n.len else 0, .kind = kind }};
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    return css.properties.parseDeclaration(.{ .allocator = allocator, .tainted_ranges = if (needle != null) &taint else &.{} }, css.properties.lookup(property).?, text, &assignments);
}

const Case = struct { property: []const u8 = "background-image", text: []const u8, tainted: []const u8, kind: css.substitution.Taint = .own, valid: bool = false };

fn check(allocator: std.mem.Allocator, case: Case) !void {
    // A rejected literal control must not masquerade as security enforcement.
    try testing.expect(try accepts(allocator, case.property, case.text, null, .none));
    try testing.expectEqual(case.valid, try accepts(allocator, case.property, case.text, case.tainted, case.kind));
}

test "attr taint: URL token, quoted URL and empty-result container spans" {
    for ([_]Case{
        .{ .text = "url(private.png)", .tainted = "url(private.png)" },
        .{ .text = "url(\"private.png\")", .tainted = "\"private.png\"" },
        .{ .text = "src(\"literal.png\" )", .tainted = "src(", .kind = .container },
        .{ .property = "cursor", .text = "url(\"private.png\"), auto", .tainted = "\"private.png\"" },
        .{ .property = "filter", .text = "url(\"private.svg#f\")", .tainted = "\"private.svg#f\"" },
    }) |case| try check(testing.allocator, case);
}

test "attr taint: image-set URL strings and non-URL type siblings" {
    for ([_]Case{
        .{ .text = "image-set(\"private.png\" 1x)", .tainted = "\"private.png\"" },
        .{ .text = "image-set(\"literal.png\" 1x type(\"image/png\"))", .tainted = "\"image/png\"", .valid = true },
        .{ .text = "image-set(\"literal.png\" 1x type(\"image/png\"))", .tainted = "image-set(", .kind = .container, .valid = true },
        .{ .text = "image-set(\"literal.png\" 1x type(\"image/png\"))", .tainted = "image-set(\"literal.png\" 1x type(\"image/png\"))" },
    }) |case| try check(testing.allocator, case);
}

test "attr taint: URL offsets survive preceding layers, content strings and raw functions" {
    for ([_]Case{
        .{ .text = "linear-gradient(red, blue), url(\"private.png\")", .tainted = "\"private.png\"" },
        .{ .text = "linear-gradient(red, blue), url(\"literal.png\")", .tainted = "red", .valid = true },
        .{ .text = "image(\"private.png\", red)", .tainted = "\"private.png\"" },
        .{ .text = "image(\"literal.png\", red)", .tainted = "red", .valid = true },
        .{ .property = "content", .text = "\"prefix\" url(\"private.png\")", .tainted = "\"private.png\"" },
        .{ .property = "content", .text = "\"prefix\" image(\"private.png\", red", .tainted = "\"private.png\"" },
        .{ .property = "content", .text = "\"prefix\" image(\"literal.png\", red", .tainted = "red", .valid = true },
    }) |case| try check(testing.allocator, case);
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    try check(allocator, .{ .property = "content", .text = "\"prefix\" image(\"private.png\", red", .tainted = "\"private.png\"" });
}

test "attr taint: rejecting a raw URL releases every partial allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}
