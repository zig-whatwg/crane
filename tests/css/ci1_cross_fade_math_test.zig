//! Q143: a specified legacy cross-fade may own an unresolved progress value;
//! computed consumers read one normalized numeric contract after computation.
//! Q148 FINAL: shipping Chrome/Safari specified strings and WebKit computed form.
//! Evidence: tmp/analysis/integrator-probes-1024b/results/q148-{chrome,firefox,safari}.json.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const available = @hasDecl(css.image_values.CrossFade, "normalizedWeight");

const Checks = if (available) struct {
    fn input(allocator: Allocator, expression: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "-webkit-cross-fade(none, none, {s})", .{expression});
    }
    fn parsed(allocator: Allocator, expression: []const u8) !css.style_values.Value {
        const text = try input(allocator, expression);
        defer allocator.free(text);
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "list-style-image", text, ""));
        const value = block.get(.list_style_image).?.value.value;
        value.retain();
        return value;
    }
    const ProbeCase = struct { expression: []const u8, specified: []const u8, computed: []const u8 };
    const Resolver = struct {
        prefix: []const u8 = "http://127.0.0.1:18982/",
        calls: usize = 0,
        oom: bool = false,
        fn resolve(raw: *const anyopaque, allocator: Allocator, url: []const u8) ?[]u8 {
            const self: *Resolver = @ptrCast(@alignCast(@constCast(raw)));
            self.calls += 1;
            return std.mem.concat(allocator, u8, &.{ self.prefix, url }) catch {
                self.oom = true;
                return null;
            };
        }
    };
    fn probeSpelling(allocator: Allocator, case: ProbeCase) !void {
        const text = try std.fmt.allocPrint(allocator, "-webkit-cross-fade(url(a.png), url(b.png), {s})", .{case.expression});
        defer allocator.free(text);
        const specified = try std.fmt.allocPrint(allocator, "-webkit-cross-fade(url(\"a.png\"), url(\"b.png\"), {s})", .{case.specified});
        defer allocator.free(specified);
        const computed_text = try std.fmt.allocPrint(allocator, "-webkit-cross-fade(url(\"http://127.0.0.1:18982/a.png\"), url(\"http://127.0.0.1:18982/b.png\"), {s})", .{case.computed});
        defer allocator.free(computed_text);
        var resolver: Resolver = .{};
        var calls_after_parse: usize = 0;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        const style = blk: {
            const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "http://127.0.0.1:18982/index.html", .referrer_policy = "no-referrer" });
            defer source.unref();
            var block = css.declarations.DeclarationBlock.init(allocator);
            defer block.deinit();
            const accepted = try block.setProperty(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, "background-image", text, "");
            if (resolver.oom) return error.OutOfMemory;
            try testing.expect(accepted);
            try block.getPropertyValue("background-image", &out);
            try testing.expectEqualStrings(specified, out.items);
            calls_after_parse = resolver.calls;
            try testing.expect(calls_after_parse > 0);
            resolver.prefix = "https://changed.test/";
            break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        };
        defer style.destroy();
        // CSSOM serialize-a-URL: resolved URLs stay frozen after their declaration dies.
        out.clearRetainingCapacity();
        try style.serializeResolved(.background_image, &out, allocator);
        try testing.expectEqualStrings(computed_text, out.items);
        try testing.expectEqual(calls_after_parse, resolver.calls);
        const urls = style.get(.background_image).resourceUrls();
        try testing.expectEqual(@as(usize, 2), urls.len);
        for (urls) |url| {
            try testing.expectEqualStrings("http://127.0.0.1:18982/index.html", url.source.?.base_url);
            try testing.expectEqualStrings("no-referrer", url.source.?.referrer_policy);
        }
    }
    fn pending(allocator: Allocator) !void {
        const value = try parsed(allocator, "calc(0.25 + 0.25)");
        defer value.release();
        const cross = css.image_values.view(value).?.cross_fade;
        try testing.expectEqual(@as(?f64, null), cross.normalizedWeight());
        try testing.expect(cross.weight_value != null);
        const clone = try css.image_values.Image.create(allocator, value.image.data);
        defer clone.unref();
        try testing.expect(value.image.eql(clone));
        try testing.expectEqual(@as(?f64, null), clone.data.cross_fade.normalizedWeight());
        const literal = try parsed(allocator, "50%");
        defer literal.release();
        try testing.expectEqual(@as(?f64, 0.5), css.image_values.view(literal).?.cross_fade.normalizedWeight());
    }
    fn computed(allocator: Allocator, expression: []const u8, expected: f64) !void {
        const text = try input(allocator, expression);
        defer allocator.free(text);
        const style = blk: {
            var block = css.declarations.DeclarationBlock.init(allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = allocator }, "list-style-image", text, ""));
            break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        };
        defer style.destroy();
        const cross = css.image_values.view(style.get(.list_style_image)).?.cross_fade;
        try testing.expect(cross.weight_value == null);
        try testing.expectEqual(@as(?f64, expected), cross.normalizedWeight());
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try style.serializeResolved(.list_style_image, &out, allocator);
        const number = try std.fmt.allocPrint(allocator, "{d}", .{expected});
        defer allocator.free(number);
        const expected_text = try input(allocator, number);
        defer allocator.free(expected_text);
        try testing.expectEqualStrings(expected_text, out.items);
    }
    fn dependencies(allocator: Allocator, expression: []const u8, tree: bool, random: bool, metrics: bool) !void {
        const original = try parsed(allocator, expression);
        const image = css.image_values.Image.create(allocator, original.image.data) catch |err| {
            original.release();
            return err;
        };
        original.release();
        const clone: css.style_values.Value = .{ .image = image };
        defer clone.release();
        try testing.expectEqual(tree, clone.needsTreeCounts());
        try testing.expectEqual(random, clone.needsRandomBase());
        try testing.expectEqual(metrics, clone.needsUnavailableMetrics(false));
        try testing.expectEqual(metrics, clone.needsUnavailableMetrics(true));
    }
    const Counts = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque) css.math_values.TreeCounts {
            const self: *Counts = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return .{ .index = 3, .count = 7 };
        }
    };
    fn inherited(allocator: Allocator, allowed: bool) !void {
        var counts: Counts = .{};
        const child = blk: {
            var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;list-style-image:-webkit-cross-fade(none,none,calc(10% * sibling-index() + 1% * sign(1em - 10px)))");
            defer user.deinit();
            try testing.expect(user.get(.list_style_image) != null);
            var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "list-style-image:revert");
            defer author.deinit();
            const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &counts, .get = Counts.get } }, &.{
                .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
                .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
            });
            defer parent.destroy();
            var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:5px;list-style-image:inherit");
            defer block.deinit();
            break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &block, .source = .{ .origin = .author, .tree_count_allowed = !allowed } }});
        };
        defer child.destroy();
        try testing.expectApproxEqAbs(@as(f64, if (allowed) 0.31 else 0.01), css.image_values.view(child.get(.list_style_image)).?.cross_fade.normalizedWeight().?, 1e-10);
        try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
        try testing.expect(!child.get(.list_style_image).needsTreeCounts());
    }
    fn randomFallback(allocator: Allocator, fixed: bool) !void {
        const style = blk: {
            var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (fixed)
                "list-style-image:none;list-style-image:-webkit-cross-fade(none,none,random(fixed 0.5, 10%, 20%))"
            else
                "list-style-image:none;list-style-image:-webkit-cross-fade(none,none,random(10%, 20%))");
            defer block.deinit();
            try testing.expect(block.get(.list_style_image).?.value.value == .image);
            break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        };
        defer style.destroy();
        if (fixed) try testing.expectEqual(@as(?f64, 0.15), css.image_values.view(style.get(.list_style_image)).?.cross_fade.normalizedWeight()) else try testing.expect(style.get(.list_style_image).isKeyword(.none));
    }
    fn invalid(allocator: Allocator, expression: []const u8) !void {
        const text = try input(allocator, expression);
        defer allocator.free(text);
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(!try block.setProperty(.{ .allocator = allocator }, "list-style-image", text, ""));
    }
} else struct {};

test "legacy cross-fade pending progress has one nullable accessor and an owned clone" {
    if (comptime !available) return error.CrossFadeMathNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.pending, .{});
}
test "legacy cross-fade math computes and clamps normalized numbers" {
    if (comptime !available) return error.CrossFadeMathNotImplemented;
    for ([_]struct { input: []const u8, expected: f64 }{
        .{ .input = "calc(50%)", .expected = 0.5 },
        .{ .input = "calc(0.25 + 0.25)", .expected = 0.5 },
        .{ .input = "calc(-10%)", .expected = 0 },
        .{ .input = "calc(300%)", .expected = 1 },
        .{ .input = "calc(-2)", .expected = 0 },
        .{ .input = "calc(2)", .expected = 1 },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, Checks.computed, .{ case.input, case.expected });
}
test "legacy cross-fade progress retains tree random and metric dependencies after source death" {
    if (comptime !available) return error.CrossFadeMathNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "calc(sibling-index() * 10%)", true, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "random(0%, 100%)", false, true, false });
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "random(fixed 0.5, 0%, 100%)", false, false, false });
    try testing.checkAllAllocationFailures(testing.allocator, Checks.dependencies, .{ "calc(sign(1cap - 1px) * 10%)", false, false, true });
}
test "legacy cross-fade progress uses winning Source and remains computed after parent death" {
    if (comptime !available) return error.CrossFadeMathNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.inherited, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, Checks.inherited, .{true});
}
test "legacy cross-fade unavailable random falls back and fixed random computes" {
    if (comptime !available) return error.CrossFadeMathNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.randomFallback, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, Checks.randomFallback, .{true});
}
test "legacy cross-fade progress rejects non-number-percentage math" {
    if (comptime !available) return error.CrossFadeMathNotImplemented;
    for ([_][]const u8{ "calc(1px)", "calc(1deg)", "calc(1 + 10%)" }) |expression|
        try testing.checkAllAllocationFailures(testing.allocator, Checks.invalid, .{expression});
}

test "legacy cross-fade matches Q148 specified and computed URL probe strings" {
    if (comptime !available) return error.CrossFadeMathNotImplemented;
    for ([_]Checks.ProbeCase{
        .{ .expression = "calc(0.25 + 0.25)", .specified = "calc(0.5)", .computed = "0.5" },
        .{ .expression = "calc(50%)", .specified = "calc(50%)", .computed = "0.5" },
        .{ .expression = "calc(-10%)", .specified = "calc(-10%)", .computed = "0" },
        .{ .expression = "calc(300%)", .specified = "calc(300%)", .computed = "1" },
        .{ .expression = "50%", .specified = "0.5", .computed = "0.5" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, Checks.probeSpelling, .{case});
}
