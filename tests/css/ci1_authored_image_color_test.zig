//! DRAFT / UNRUN. Q166 final image-grammar follow-up, after accepted f.
//! Images4 §§2, 2.5; Color4 §§15.1, 15.5; Syntax3 §5.5.10.
//! Exact C/F/S evidence: image-function-computed.html, all three 3/3.
//! This file does not assert rejection of existing image(URL/fallback) forms.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Longhand = css.properties.Longhand;

const Case = struct { input: []const u8, expected: []const u8 };
const properties = [_]Longhand{ .background_image, .list_style_image, .border_image_source, .mask_image, .mask_border_source, .content };

fn specified(allocator: Allocator, longhand: Longhand, case: Case) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, longhand.name(), case.input, ""));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(longhand.name(), &out);
    try testing.expectEqualStrings(case.expected, out.items);
}

test "authored image color specified serialization uses the shared color grammar" {
    for (properties) |longhand| for ([_]Case{
        .{ .input = "image(red)", .expected = "image(red)" },
        .{ .input = "image(transparent)", .expected = "image(transparent)" },
        .{ .input = "image(rgb(0 128 255))", .expected = "image(rgb(0, 128, 255))" },
        .{ .input = "image(currentcolor)", .expected = "image(currentcolor)" },
        .{ .input = "image(light-dark(black, white))", .expected = "image(light-dark(black, white))" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, specified, .{ longhand, case });
}

fn computed(allocator: Allocator, longhand: Longhand, case: Case) !void {
    const style = blk: {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:blue;color-scheme:light");
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, longhand.name(), case.input, ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    // The parsed declaration is already destroyed. No raw text pinning.
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(longhand, &out, allocator);
    try testing.expectEqualStrings(case.expected, out.items);
    try testing.expectEqual(@as(usize, 0), style.get(longhand).resourceUrls().len);
}

test "authored image red and transparent compute after declaration destruction" {
    for (properties) |longhand| for ([_]Case{
        .{ .input = "image(red)", .expected = "image(rgb(255, 0, 0))" },
        .{ .input = "image(transparent)", .expected = "image(rgba(0, 0, 0, 0))" },
        .{ .input = "image(rgba(0, 128, 255, 0.5))", .expected = "image(rgba(0, 128, 255, 0.5))" },
        .{ .input = "image(light-dark(black, white))", .expected = "image(rgb(0, 0, 0))" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{ longhand, case });
}

test "authored image EOF closes each open function and still computes its color" {
    for ([_]Longhand{ .background_image, .content }) |longhand| for ([_]Case{
        .{ .input = "image(transparent", .expected = "image(rgba(0, 0, 0, 0))" },
        .{ .input = "image(rgb(0 128 255", .expected = "image(rgb(0, 128, 255))" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, computed, .{ longhand, case });
}

fn retainedContentImage(allocator: Allocator) !void {
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "content", "'prefix' image(color(srgb 1 0 0)) / 'alt'", ""));
        const content = block.get(.content).?.value.value.content;
        const value = content.items[1].image orelse return error.ExpectedTypedAuthoredImage;
        value.retain();
        break :blk value;
    };
    defer value.release();
    // Item.image must use the backing allocator, never the freed Content arena.
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(.list_style_image, value, &out, allocator);
    try testing.expectEqualStrings("image(color(srgb 1 0 0))", out.items);
}

test "authored typed content image survives release of its original Content" {
    try testing.checkAllAllocationFailures(testing.allocator, retainedContentImage, .{});
}

fn dependency(allocator: Allocator, longhand: Longhand, input: []const u8, tree: bool, random: bool, metrics: bool) !void {
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, longhand.name(), input, ""));
        const value = block.get(longhand).?.value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(false));
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(true));
}

test "authored image forwards nested Color dependencies without inspecting Color tags" {
    for ([_]Longhand{ .background_image, .content }) |longhand| {
        try testing.checkAllAllocationFailures(testing.allocator, dependency, .{ longhand, "image(rgb(calc(sibling-index() * 10) 0 0))", true, false, false });
        try testing.checkAllAllocationFailures(testing.allocator, dependency, .{ longhand, "image(rgb(random(0, 255) 0 0))", false, true, false });
        try testing.checkAllAllocationFailures(testing.allocator, dependency, .{ longhand, "image(rgb(random(fixed 0.5, 0, 255) 0 0))", false, false, false });
        try testing.checkAllAllocationFailures(testing.allocator, dependency, .{ longhand, "image(rgb(calc(100 * sign(1cap - 10px)) 0 0))", false, false, true });
    }
}

const Resolver = struct {
    calls: usize = 0,
    oom: bool = false,
    fn resolve(raw: *const anyopaque, allocator: Allocator, text: []const u8) ?[]u8 {
        const self: *Resolver = @ptrCast(@alignCast(@constCast(raw)));
        self.calls += 1;
        return std.mem.concat(allocator, u8, &.{ "https://image.test/old/", text }) catch {
            self.oom = true;
            return null;
        };
    }
};

fn provenance(allocator: Allocator, longhand: Longhand) !void {
    var resolver: Resolver = .{};
    const style = blk: {
        const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://image.test/old/main.css", .referrer = "https://image.test/ref", .referrer_policy = "no-referrer", .origin_clean = false });
        defer source.unref();
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        const input = if (longhand == .content) "'prefix' image(transparent) url(asset.svg) / 'alt'" else "image(transparent), url(asset.svg)";
        const accepted = try block.setProperty(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, longhand.name(), input, "");
        if (resolver.oom) return error.OutOfMemory;
        try testing.expect(accepted);
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    };
    defer style.destroy();
    const calls = resolver.calls;
    const urls = style.get(longhand).resourceUrls();
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("https://image.test/old/asset.svg", urls[0].url);
    try testing.expectEqualStrings("no-referrer", urls[0].source.?.referrer_policy);
    try testing.expectEqualStrings("https://image.test/ref", urls[0].source.?.referrer.?);
    try testing.expect(!urls[0].source.?.origin_clean);
    var symbolic: std.ArrayList(u8) = .empty;
    defer symbolic.deinit(allocator);
    try css.properties.serializeValue(longhand, style.get(longhand), &symbolic, allocator);
    try testing.expectEqualStrings("url(\"asset.svg\")", symbolic.items[urls[0].range.start..urls[0].range.end]);
    var resolved: std.ArrayList(u8) = .empty;
    defer resolved.deinit(allocator);
    try style.serializeResolved(longhand, &resolved, allocator);
    const expected = if (longhand == .content) "\"prefix\" image(rgba(0, 0, 0, 0)) url(\"https://image.test/old/asset.svg\") / \"alt\"" else "image(rgba(0, 0, 0, 0)), url(\"https://image.test/old/asset.svg\")";
    try testing.expectEqualStrings(expected, resolved.items);
    try testing.expectEqual(calls, resolver.calls);
}

test "authored color computation preserves adjacent URL source and ranges after owners die" {
    for ([_]Longhand{ .background_image, .mask_image, .content }) |longhand|
        try testing.checkAllAllocationFailures(testing.allocator, provenance, .{longhand});
}
