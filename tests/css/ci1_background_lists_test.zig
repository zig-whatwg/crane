//! Q119 FINAL: per-case browser mechanisms for resolved background lists.
//! Receipts: tmp/analysis/integrator-probes-1023u/results/q119-*-*.json.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Case = struct { declaration: []const u8, specified: []const u8, computed: []const u8, longhands: []const struct { name: []const u8, value: []const u8 } };
const cases = [_]Case{
    // q119-P1-{chrome,firefox,safari}.json; Q119 selects each form separately.
    .{
        .declaration = "background-image:url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\"), url(\"https://example.test/c.png\");background-position-x:10px, 20px;background-position-y:30px",
        .specified = "",
        .computed = "url(\"https://example.test/a.png\") repeat scroll 10px 30px / auto padding-box border-box, url(\"https://example.test/b.png\") repeat scroll 20px 30px / auto padding-box border-box, rgba(0, 0, 0, 0) url(\"https://example.test/c.png\") repeat scroll 10px 30px / auto padding-box border-box",
        .longhands = &.{
            .{ .name = "background-color", .value = "rgba(0, 0, 0, 0)" },
            .{ .name = "background-image", .value = "url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\"), url(\"https://example.test/c.png\")" },
            .{ .name = "background-position-x", .value = "10px, 20px" },
            .{ .name = "background-position-y", .value = "30px" },
            .{ .name = "background-size", .value = "auto, auto, auto" },
            .{ .name = "background-repeat", .value = "repeat" },
            .{ .name = "background-attachment", .value = "scroll" },
            .{ .name = "background-origin", .value = "padding-box" },
            .{ .name = "background-clip", .value = "border-box" },
        },
    },
    // q119-P2-{chrome,firefox,safari}.json; Q119 selects each form separately.
    .{
        .declaration = "background-image:url(\"https://example.test/a.png\");background-size:10px, 20px",
        .specified = "",
        .computed = "rgba(0, 0, 0, 0) url(\"https://example.test/a.png\") repeat scroll 0% 0% / 10px auto padding-box border-box",
        .longhands = &.{
            .{ .name = "background-color", .value = "rgba(0, 0, 0, 0)" },
            .{ .name = "background-image", .value = "url(\"https://example.test/a.png\")" },
            .{ .name = "background-position-x", .value = "0%" },
            .{ .name = "background-position-y", .value = "0%" },
            .{ .name = "background-size", .value = "10px auto, 20px auto" },
            .{ .name = "background-repeat", .value = "repeat" },
            .{ .name = "background-attachment", .value = "scroll" },
            .{ .name = "background-origin", .value = "padding-box" },
            .{ .name = "background-clip", .value = "border-box" },
        },
    },
    // q119-P3-{chrome,firefox,safari}.json; Q119 selects each form separately.
    .{
        .declaration = "background-image:url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\");background-repeat:no-repeat, repeat-x, repeat-y",
        .specified = "",
        .computed = "url(\"https://example.test/a.png\") no-repeat scroll 0% 0% / auto padding-box border-box, rgba(0, 0, 0, 0) url(\"https://example.test/b.png\") repeat-x scroll 0% 0% / auto padding-box border-box",
        .longhands = &.{
            .{ .name = "background-color", .value = "rgba(0, 0, 0, 0)" },
            .{ .name = "background-image", .value = "url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\")" },
            .{ .name = "background-position-x", .value = "0%" },
            .{ .name = "background-position-y", .value = "0%" },
            .{ .name = "background-size", .value = "auto, auto" },
            .{ .name = "background-repeat", .value = "no-repeat, repeat-x, repeat-y" },
            .{ .name = "background-attachment", .value = "scroll" },
            .{ .name = "background-origin", .value = "padding-box" },
            .{ .name = "background-clip", .value = "border-box" },
        },
    },
    // q119-P4-{chrome,firefox,safari}.json; Q119 selects each form separately.
    .{
        .declaration = "background-image:url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\");background-attachment:fixed;background-origin:content-box, padding-box, border-box",
        .specified = "",
        .computed = "url(\"https://example.test/a.png\") repeat fixed 0% 0% / auto content-box border-box, rgba(0, 0, 0, 0) url(\"https://example.test/b.png\") repeat fixed 0% 0% / auto padding-box border-box",
        .longhands = &.{
            .{ .name = "background-color", .value = "rgba(0, 0, 0, 0)" },
            .{ .name = "background-image", .value = "url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\")" },
            .{ .name = "background-position-x", .value = "0%" },
            .{ .name = "background-position-y", .value = "0%" },
            .{ .name = "background-size", .value = "auto, auto" },
            .{ .name = "background-repeat", .value = "repeat" },
            .{ .name = "background-attachment", .value = "fixed" },
            .{ .name = "background-origin", .value = "content-box, padding-box, border-box" },
            .{ .name = "background-clip", .value = "border-box" },
        },
    },
    // q119-P5-{chrome,firefox,safari}.json; Q119 selects each form separately.
    .{
        .declaration = "background-image:url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\");background-clip:border-box",
        .specified = "",
        .computed = "url(\"https://example.test/a.png\") repeat scroll 0% 0% / auto padding-box border-box, rgba(0, 0, 0, 0) url(\"https://example.test/b.png\") repeat scroll 0% 0% / auto padding-box border-box",
        .longhands = &.{
            .{ .name = "background-color", .value = "rgba(0, 0, 0, 0)" },
            .{ .name = "background-image", .value = "url(\"https://example.test/a.png\"), url(\"https://example.test/b.png\")" },
            .{ .name = "background-position-x", .value = "0%" },
            .{ .name = "background-position-y", .value = "0%" },
            .{ .name = "background-size", .value = "auto, auto" },
            .{ .name = "background-repeat", .value = "repeat" },
            .{ .name = "background-attachment", .value = "scroll" },
            .{ .name = "background-origin", .value = "padding-box" },
            .{ .name = "background-clip", .value = "border-box" },
        },
    },
    // q119-C6-{chrome,firefox,safari}.json; Q119 selects each form separately.
    .{
        .declaration = "background-image:none, none;background-size:cover",
        .specified = "",
        .computed = "none repeat scroll 0% 0% / cover padding-box border-box, rgba(0, 0, 0, 0) none repeat scroll 0% 0% / cover padding-box border-box",
        .longhands = &.{
            .{ .name = "background-color", .value = "rgba(0, 0, 0, 0)" },
            .{ .name = "background-image", .value = "none, none" },
            .{ .name = "background-position-x", .value = "0%" },
            .{ .name = "background-position-y", .value = "0%" },
            .{ .name = "background-size", .value = "cover, cover" },
            .{ .name = "background-repeat", .value = "repeat" },
            .{ .name = "background-attachment", .value = "scroll" },
            .{ .name = "background-origin", .value = "padding-box" },
            .{ .name = "background-clip", .value = "border-box" },
        },
    },
    // q119-C7-{chrome,firefox,safari}.json; Q119 selects each form separately.
    .{
        .declaration = "background-position-x:10px, 20px;background-position-y:30px",
        .specified = "",
        .computed = "rgba(0, 0, 0, 0) none repeat scroll 10px 30px / auto padding-box border-box",
        .longhands = &.{
            .{ .name = "background-color", .value = "rgba(0, 0, 0, 0)" },
            .{ .name = "background-image", .value = "none" },
            .{ .name = "background-position-x", .value = "10px, 20px" },
            .{ .name = "background-position-y", .value = "30px" },
            .{ .name = "background-size", .value = "auto" },
            .{ .name = "background-repeat", .value = "repeat" },
            .{ .name = "background-attachment", .value = "scroll" },
            .{ .name = "background-origin", .value = "padding-box" },
            .{ .name = "background-clip", .value = "border-box" },
        },
    },
};

fn check(allocator: std.mem.Allocator, case: Case) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.declaration);
    var owned = true;
    defer if (owned) block.deinit();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue("background", &text);
    try testing.expectEqualStrings(case.specified, text.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.deinit();
    owned = false;
    for (case.longhands) |expected| {
        text.clearRetainingCapacity();
        const longhand = css.properties.lookup(expected.name).?.longhand;
        try style.serializeResolved(longhand, &text, allocator);
        try testing.expectEqualStrings(expected.value, text.items);
    }
    const longhands = css.properties.Shorthand.background.longhands();
    var assigned: [css.properties.max_assignments]css.properties.Assigned = undefined;
    for (longhands, 0..) |longhand, index| assigned[index] = .{ .value = style.get(longhand) };
    text.clearRetainingCapacity();
    try testing.expect(try css.properties.serializeShorthand(.background, assigned[0..longhands.len], .computed, &text, allocator));
    try testing.expectEqualStrings(case.computed, text.items);
}

test "background Q119 P1: resolved shorthand and every longhand" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[0]});
}

test "background Q119 P2: resolved shorthand and every longhand" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[1]});
}

test "background Q119 P3: resolved shorthand and every longhand" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[2]});
}

test "background Q119 P4: resolved shorthand and every longhand" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[3]});
}

test "background Q119 P5: resolved shorthand and every longhand" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[4]});
}

test "background Q119 C6: resolved shorthand and every longhand" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[5]});
}

test "background Q119 C7: resolved shorthand and every longhand" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[6]});
}

fn immutableSizeRead(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:20px;background-image:none,none,none;background-size:1em");
    var owned = true;
    defer if (owned) block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.deinit();
    owned = false;
    const held = style.get(.background_size);
    held.retain();
    defer held.release();
    try testing.expectEqual(@as(usize, 1), css.image_layers.count(held));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, 256);
    var fail = testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try style.serializeResolved(.background_size, &out, fail.allocator());
    try testing.expectEqualStrings("20px auto, 20px auto, 20px auto", out.items);
    try testing.expect(!fail.has_induced_failure);
    try testing.expectEqual(@as(usize, 1), css.image_layers.count(style.get(.background_size)));
    try testing.expect(held.eql(style.get(.background_size)));
}

test "background Q120 size read repeats borrowed values without allocation or mutation" {
    try testing.checkAllAllocationFailures(testing.allocator, immutableSizeRead, .{});
}
