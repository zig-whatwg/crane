//! Q112 final: Font Loading rejects function occurrences, even fixed or
//! cancelled ones. CSS style parsing still accepts them. Probe receipts:
//! tmp/analysis/integrator-probes-1023t/results/q112-{chrome,firefox,safari}.json.
//! Safari ships random(); Firefox/Safari supply the tree-counting majority.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const rejected = [_][]const u8{
    "random(fixed 0.5, 10px, 20px) serif",
    "calc(random(fixed 0.5, 10px, 20px)) serif",
    "calc((sibling-index() - sibling-index()) * 1px + 16px) serif",
    "16px/calc((sibling-count() - sibling-count()) * 1px + 20px) serif",
    "calc(random(1px, 2px)) serif",
    "calc(sibling-index() * 1px) serif",
    "calc(SIBLING-INDEX() * 1px) serif",
    "calc(sibling\\-index() * 1px) serif",
};

const Checks = if (@hasDecl(css, "font_request")) struct {
    fn rejection(allocator: std.mem.Allocator) !void {
        for (rejected) |text| {
            var result = try css.font_request.parseForFontLoading(.{ .allocator = allocator }, text);
            defer if (result) |*request| request.deinit();
            try testing.expect(result == null);
        }
    }

    fn families(allocator: std.mem.Allocator) !void {
        // The spelling alone is not a function token. These remain valid
        // elementless requests; no computed fallback hides a parse failure.
        for ([_][]const u8{
            "16px serif",
            "16px \"random(\" , serif",
            "16px random",
            "16px sibling-index",
        }) |text| {
            var result = (try css.font_request.parseForFontLoading(.{ .allocator = allocator }, text)) orelse return error.ExpectedAcceptedFont;
            defer result.deinit();
            try testing.expect(result == .resolved);
            try testing.expectEqual(@as(f32, 16), result.resolved.size_px);
        }
    }

    fn styleParsing(allocator: std.mem.Allocator) !void {
        for (rejected) |text| {
            var block = css.declarations.DeclarationBlock.init(allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = allocator }, "font", text, ""));
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(allocator);
            try block.getPropertyValue("font", &output);
            try testing.expect(output.items.len > 0);
        }
    }
} else struct {};

test "font loading rejects fixed random cancelled tree and decoded function occurrences" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.rejection, .{});
}

test "font loading accepts the ordinary control and function-like family names" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.families, .{});
}

test "elementless occurrence rejection does not change style font parsing" {
    if (comptime !@hasDecl(css, "font_request")) return error.FontRequestNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.styleParsing, .{});
}
