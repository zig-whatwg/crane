//! Q115: Color4 §15.5 currentcolor inherits symbolically; CSSOM resolves
//! against the receiver. Q116 supplies the owner query used by the fast path.
//! WPT border-image-source-computed.sub.html:23–26 and Q56 browser probes.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Longhand = css.properties.Longhand;
const Value = css.style_values.Value;

const Resolver = struct {
    calls: usize = 0,
    oom: bool = false,
    fn resolve(raw: *const anyopaque, allocator: Allocator, text: []const u8) ?[]u8 {
        const self: *Resolver = @ptrCast(@alignCast(@constCast(raw)));
        self.calls += 1;
        return std.mem.concat(allocator, u8, &.{ "https://gradient.test/old/", text }) catch {
            self.oom = true;
            return null;
        };
    }
};
const Case = struct { longhand: Longhand, input: []const u8, expected: []const u8, child_color: []const u8 = "blue" };

fn inheritance(allocator: Allocator, case: Case) !void {
    var resolver: Resolver = .{};
    var original: ?Value = null;
    defer if (original) |value| value.release();
    const child = blk: {
        const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://gradient.test/old/main.css" });
        defer source.unref();
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:red;font-size:40px");
        defer block.deinit();
        const accepted = try block.setProperty(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, case.longhand.name(), case.input, "");
        if (resolver.oom) return error.OutOfMemory;
        try testing.expect(accepted);
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        original = parent.get(case.longhand);
        original.?.retain();
        var inherit = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color-scheme:dark;font-size:10px");
        defer inherit.deinit();
        try testing.expect(try inherit.setProperty(.{ .allocator = allocator }, "color", case.child_color, ""));
        try testing.expect(try inherit.setProperty(.{ .allocator = allocator }, case.longhand.name(), "inherit", ""));
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherit, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    // Only the retained computed value and child survive; neither declaration,
    // the parent, nor the ResourceSource's external owner remains.
    const calls = resolver.calls;
    var symbolic: std.ArrayList(u8) = .empty;
    defer symbolic.deinit(allocator);
    try css.properties.serializeValue(case.longhand, original.?, &symbolic, allocator);
    try testing.expect(std.mem.indexOf(u8, symbolic.items, "currentcolor") != null);
    var resolved: std.ArrayList(u8) = .empty;
    defer resolved.deinit(allocator);
    try child.serializeResolved(case.longhand, &resolved, allocator);
    try testing.expectEqualStrings(case.expected, resolved.items);
    try testing.expectEqual(calls, resolver.calls);
    try testing.expect(original.?.eql(child.get(case.longhand)));
    var unchanged: std.ArrayList(u8) = .empty;
    defer unchanged.deinit(allocator);
    try css.properties.serializeValue(case.longhand, original.?, &unchanged, allocator);
    try testing.expectEqualStrings(symbolic.items, unchanged.items);
}

test "gradient currentcolor resolves only for the receiver after source and parent destruction" {
    for ([_]Longhand{ .background_image, .border_image_source, .list_style_image, .mask_border_source }) |longhand|
        try testing.checkAllAllocationFailures(testing.allocator, inheritance, .{Case{
            .longhand = longhand,
            .input = "linear-gradient(currentcolor 1em, black)",
            .expected = "linear-gradient(rgb(0, 0, 255) 40px, rgb(0, 0, 0))",
        }});
}

test "resolved gradient wrappers preserve adjacent URL ranges and inherited scalar metadata" {
    for ([_]Case{
        .{ .longhand = .background_image, .input = "linear-gradient(in srgb, currentcolor, black)", .expected = "linear-gradient(color(srgb 1 0 0), rgb(0, 0, 0))", .child_color = "color(srgb 1 0 0)" },
        .{ .longhand = .background_image, .input = "linear-gradient(light-dark(currentcolor, red), black)", .expected = "linear-gradient(rgb(0, 0, 255), rgb(0, 0, 0))" },
        .{ .longhand = .background_image, .input = "linear-gradient(currentcolor, black), url(asset.svg)", .expected = "linear-gradient(rgb(0, 0, 255), rgb(0, 0, 0)), url(\"https://gradient.test/old/asset.svg\")" },
        .{ .longhand = .mask_image, .input = "url(asset.svg), linear-gradient(currentcolor, black)", .expected = "url(\"https://gradient.test/old/asset.svg\"), linear-gradient(rgb(0, 0, 255), rgb(0, 0, 0))" },
        .{ .longhand = .background_image, .input = "image-set(linear-gradient(currentcolor, black) 2x, url(asset.svg))", .expected = "image-set(linear-gradient(rgb(0, 0, 255), rgb(0, 0, 0)) 2dppx, url(\"https://gradient.test/old/asset.svg\") 1dppx)" },
        .{ .longhand = .content, .input = "'prefix' linear-gradient(currentcolor, black) url(asset.svg) / 'alt'", .expected = "\"prefix\" linear-gradient(rgb(0, 0, 255), rgb(0, 0, 0)) url(\"https://gradient.test/old/asset.svg\") / \"alt\"" },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, inheritance, .{case});
}

fn noAllocation(case: Case) !void {
    const allocator = testing.allocator;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, case.longhand.name(), case.input, ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const Style = @TypeOf(style.*);
    if (comptime !@hasDecl(Style, "resolvedImageValue")) return error.ResolvedImageValueNotImplemented;
    var fail = testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const resolved = try style.resolvedImageValue(case.longhand, fail.allocator());
    defer resolved.release();
    try testing.expect(resolved.eql(style.get(case.longhand)));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, 4096);
    // With output capacity available, the existing serialization route must
    // not allocate any intermediate graph or scratch text for absolute colors.
    try style.serializeResolved(case.longhand, &out, fail.allocator());
    try testing.expectEqualStrings(case.expected, out.items);
}

test "absolute and selected-away currentcolor graphs keep the no-allocation CSSOM route" {
    for ([_]Case{
        .{ .longhand = .background_image, .input = "linear-gradient(red, black)", .expected = "linear-gradient(rgb(255, 0, 0), rgb(0, 0, 0))" },
        .{ .longhand = .background_image, .input = "linear-gradient(color(srgb 1 0 0), black)", .expected = "linear-gradient(color(srgb 1 0 0), rgb(0, 0, 0))" },
        .{ .longhand = .background_image, .input = "linear-gradient(light-dark(red, currentcolor), black)", .expected = "linear-gradient(rgb(255, 0, 0), rgb(0, 0, 0))" },
        .{ .longhand = .mask_image, .input = "url(asset.svg), linear-gradient(red, black)", .expected = "url(\"asset.svg\"), linear-gradient(rgb(255, 0, 0), rgb(0, 0, 0))" },
        .{ .longhand = .content, .input = "'prefix' linear-gradient(color(srgb 1 0 0), black)", .expected = "\"prefix\" linear-gradient(color(srgb 1 0 0), rgb(0, 0, 0))" },
    }) |case| try noAllocation(case);
}

fn currentCopy(allocator: Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "color:blue;background-image:linear-gradient(rgb(from currentcolor r g b), black)");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const Style = @TypeOf(style.*);
    if (comptime !@hasDecl(Style, "resolvedImageValue")) return error.ResolvedImageValueNotImplemented;
    var fail = testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try testing.expectError(error.OutOfMemory, style.resolvedImageValue(.background_image, fail.allocator()));
    const resolved = try style.resolvedImageValue(.background_image, allocator);
    defer resolved.release();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(.background_image, resolved, &out, allocator);
    try testing.expectEqualStrings("linear-gradient(color(srgb 0 0 1), rgb(0, 0, 0))", out.items);
}

test "nested currentcolor takes the owned-copy route with complete allocation cleanup" {
    try testing.checkAllAllocationFailures(testing.allocator, currentCopy, .{});
}

fn colorQuery(allocator: Allocator, input: []const u8, specified: bool, computed: bool) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "color", input, ""));
    const value = (block.get(.color) orelse return error.ExpectedColor).value.value.color;
    try testing.expectEqual(specified, value.containsCurrentColor());
    const resolved = try value.resolveComputed(allocator, .{ .scheme = .light });
    defer resolved.release();
    block.clear();
    try testing.expectEqual(computed, resolved.containsCurrentColor());
}

test "the owner currentcolor query distinguishes nested origins and selected-away branches" {
    const Color = css.style_values.Color;
    if (comptime !@hasDecl(Color, "containsCurrentColor")) return error.ColorCurrentColorQueryNotAvailable;
    for ([_][]const u8{ "red", "color(srgb 1 0 0)", "oklch(0.5 0.1 120)" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, colorQuery, .{ input, false, false });
    for ([_][]const u8{ "currentcolor", "rgb(from currentcolor r g b)", "color-mix(in srgb, red, currentcolor)", "contrast-color(currentcolor)", "alpha(from currentcolor / 0.5)", "light-dark(currentcolor, red)" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, colorQuery, .{ input, true, true });
    try testing.checkAllAllocationFailures(testing.allocator, colorQuery, .{ "light-dark(red, currentcolor)", true, false });
}
