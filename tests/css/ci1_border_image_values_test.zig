//! UNRUN adapted draft, Q170 preparation; Q173/Q175/Q174 PART2 dispositions.
//! Golden rule2: main/tmp/analysis/integrator-probes-1024c/ (Q174).
//! Target: actual accepted post-f parent, not the unbuilt provisional inspection tree.
//! CSS Backgrounds3 §§3.4,5.1–5.7; CSSOM §§6.6.1,6.7.2,9; Values4 §§9.1,10.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const family = [_][]const u8{ "border-image-source", "border-image-slice", "border-image-width", "border-image-outset", "border-image-repeat" };
const initial = [_][]const u8{ "none", "100%", "1", "0", "stretch" };

fn property(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.BorderImageFamilyNotImplemented;
}
fn requireFamily() !void {
    for (family) |name| _ = try property(name);
    _ = try property("border-image");
}
fn freeAssignments(allocator: Allocator, assignments: *std.ArrayList(css.properties.Assignment)) void {
    for (assignments.items) |a| a.value.release();
    assignments.deinit(allocator);
}
fn expectText(block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(block.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}
fn expectParse(name: []const u8, input: []const u8, expected: ?[]const u8) !void {
    const p = try property(name);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer freeAssignments(testing.allocator, &assignments);
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments));
    if (expected) |text| {
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try css.properties.serializeAssigned(p.longhand, assignments.items[0].value, &out, testing.allocator);
        try testing.expectEqualStrings(text, out.items);
    } else try testing.expectEqual(@as(usize, 0), assignments.items.len);
}
fn expectComputed(style: *const css.computed_style.ComputedStyle, name: []const u8, expected: []const u8, allocator: Allocator) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved((try property(name)).longhand, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "ci1 border image longhands accept typed components and compress one to four sides" {
    const Case = struct { name: []const u8, input: []const u8, expected: []const u8 };
    for ([_]Case{
        .{ .name = "border-image-slice", .input = "1 1 1 1", .expected = "1" },
        .{ .name = "border-image-slice", .input = "1 2% 1 2%", .expected = "1 2%" },
        .{ .name = "border-image-slice", .input = "1 2% 3 2%", .expected = "1 2% 3" },
        .{ .name = "border-image-slice", .input = "fill 1 2% 3 4%", .expected = "1 2% 3 4% fill" },
        .{ .name = "border-image-slice", .input = "125%", .expected = "125%" },
        .{ .name = "border-image-width", .input = "1 auto 10px 20%", .expected = "1 auto 10px 20%" },
        .{ .name = "border-image-width", .input = "auto auto auto auto", .expected = "auto" },
        .{ .name = "border-image-width", .input = "0 0px 0 0px", .expected = "0 0px" },
        .{ .name = "border-image-outset", .input = "1px 2 1px 2", .expected = "1px 2" },
        .{ .name = "border-image-outset", .input = "1px 2 3px 4", .expected = "1px 2 3px 4" },
        .{ .name = "border-image-repeat", .input = "space space", .expected = "space" },
        .{ .name = "border-image-repeat", .input = "round stretch", .expected = "round stretch" },
    }) |c| try expectParse(c.name, c.input, c.expected);
}

test "ci1 border image invalid grammar rolls back owned parser output" {
    for ([_][]const u8{ "fill", "1% fill 2%", "fill 1 fill", "1 2 3 4 5", "-1", "-1%", "1px", "calc(1 + 2%)" }) |s| try expectParse("border-image-slice", s, null);
    for ([_][]const u8{ "none", "-1", "-1px", "-1%", "1 2 3 4 5", "calc(1 + 2px)" }) |s| try expectParse("border-image-width", s, null);
    for ([_][]const u8{ "auto", "1%", "-1", "-1px", "1 2 3 4 5", "calc(1% + 2px)" }) |s| try expectParse("border-image-outset", s, null);
    for ([_][]const u8{ "auto", "repeat-x", "no-repeat", "stretch repeat round" }) |s| try expectParse("border-image-repeat", s, null);
    const p = try property("border-image");
    for ([_][]const u8{ "auto", "fill", "none, url(a)", "url(a) url(b)", "/ 2", "1 /", "1 / /", "1 / / auto", "1 / / 1%", "1 / 2 / 3 / 4", "url(a) 1 / calc(2px) / 3 junk" }) |s| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer freeAssignments(testing.allocator, &assignments);
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, s, &assignments));
        try testing.expectEqual(@as(usize, 0), assignments.items.len);
    }
}

test "ci1 border image expansion retains number percentage length and auto distinctions" {
    const p = try property("border-image-width");
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer freeAssignments(testing.allocator, &assignments);
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = testing.allocator, .quirks = true }, p, "2 2px 3% auto", &assignments));
    const sides = assignments.items[0].value.value.image_quad.sides;
    try testing.expectEqual(@as(f64, 2), sides[0].number);
    try testing.expectEqual(@as(f64, 2), sides[1].length.value);
    try testing.expectEqual(css.style_values.LengthUnit.px, sides[1].length.unit);
    try testing.expectEqual(css.style_values.LengthUnit.percent, sides[2].length.unit);
    try testing.expect(sides[3].isKeyword(.auto));
}

fn shorthandCase(allocator: Allocator) !void {
    try requireFamily();
    const Case = struct { input: []const u8, values: [5][]const u8 };
    for ([_]Case{
        .{ .input = "none", .values = initial },
        .{ .input = "repeat round", .values = .{ "none", "100%", "1", "0", "repeat round" } },
        .{ .input = "fill 1 2% 3 4% / 5% / 6", .values = .{ "none", "1 2% 3 4% fill", "5%", "6", "stretch" } },
        .{ .input = "round url(https://example.test/frame.svg) 20 / / 2px", .values = .{ "url(\"https://example.test/frame.svg\")", "20", "1", "2px", "round" } },
        .{ .input = "20 / 2 auto / 3 url(https://example.test/frame.svg) repeat space", .values = .{ "url(\"https://example.test/frame.svg\")", "20", "2 auto", "3", "repeat space" } },
    }) |c| {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border-image", c.input, "important"));
        try testing.expectEqual(@as(usize, 5), block.length());
        for (family, c.values) |name, value| {
            // Confirm recognition, not just an unparsed declaration with matching text.
            try testing.expect(block.get((try property(name)).longhand) != null);
            try expectText(&block, name, value);
            try testing.expect(block.getPropertyPriority(name));
        }
        // Invalid setter preserves all previously accepted components and priority.
        try testing.expect(!try block.setProperty(.{ .allocator = allocator }, "border-image", "url(a) 20 / calc(2px) / 3 junk", ""));
        for (family, c.values) |name, value| try expectText(&block, name, value);
    }
}

test "ci1 border image shorthand slash grammar unordered groups and omitted defaults all OOM" {
    try shorthandCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, shorthandCase, .{});
}

fn mathCase(allocator: Allocator) !void {
    try requireFamily();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:40px;border-style:none;border-image-slice:calc(20 - 30) calc(20% - 30%) 125% fill;border-image-width:calc(20% + 10px) calc(-.5em + 10px) auto 2;border-image-outset:0 calc(.5em + 10px) 3 calc(-.5em + 10px);border-image-repeat:round space");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try expectComputed(style, "border-image-slice", "0 0% 125% fill", allocator);
    try expectComputed(style, "border-image-width", "calc(20% + 10px) 0px auto 2", allocator);
    try expectComputed(style, "border-image-outset", "0 30px 3 0px", allocator);
    try expectComputed(style, "border-image-repeat", "round space", allocator);
    // Compute must not mutate the specified expression shared by declarations.
    try expectText(&block, "border-image-width", "calc(20% + 10px) calc(-0.5em + 10px) auto 2");
}

test "ci1 border image pure math computes and clamps only top level with all OOM" {
    try mathCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, mathCase, .{});
}

fn retainedCase(allocator: Allocator) !void {
    try requireFamily();
    // The child escapes declaration, ResourceSource, and parent lifetimes.
    const child = blk: {
        const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://old.test/css/style.css", .referrer_policy = "no-referrer" });
        defer source.unref();
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator, .resource_source = source }, "border-image", "url(https://assets.test/frame.svg) 20 fill / calc(1em + 2px) / 2 round space", ""));
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer parent.destroy();
        var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "font-size:80px;border-image:inherit");
        defer inherited.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author } }});
    };
    defer child.destroy();
    try expectComputed(child, "border-image-width", "18px", allocator);
    try expectComputed(child, "border-image-slice", "20 fill", allocator);
    try expectComputed(child, "border-image-outset", "2", allocator);
    try expectComputed(child, "border-image-repeat", "round space", allocator);
    const urls = child.get((try property(family[0])).longhand).resourceUrls();
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("https://assets.test/frame.svg", urls[0].url);
    try testing.expectEqualStrings("https://old.test/css/style.css", urls[0].source.?.base_url);
    try testing.expectEqualStrings("no-referrer", urls[0].source.?.referrer_policy);
    const ordinary = try css.cascade.cascade(.{ .allocator = allocator, .parent = child }, &.{});
    defer ordinary.destroy();
    for (family, initial) |name, value| try expectComputed(ordinary, name, value, allocator);
}

test "ci1 border image inherited typed owners survive release of declaration source and parent all OOM" {
    try retainedCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, retainedCase, .{});
}

fn resetCase(allocator: Allocator) !void {
    try requireFamily();
    const seed = "border-image:url(https://example.test/frame) 20 fill / 2px / 3 round space;";
    for ([_][]const u8{ "border-top", "border-right", "border-bottom", "border-left", "border-width", "border-style", "border-color", "border-block", "border-inline" }) |side| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, seed);
        defer block.deinit();
        const input = if (std.mem.eql(u8, side, "border-width")) "2px" else if (std.mem.eql(u8, side, "border-style")) "solid" else if (std.mem.eql(u8, side, "border-color")) "red" else "2px solid red";
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, side, input, ""));
        try expectText(&block, "border-image-slice", "20 fill");
        try expectText(&block, "border-image-width", "2px");
        try expectText(&block, "border-image-outset", "3");
        try expectText(&block, "border-image-repeat", "round space");
    }
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, seed);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border", "2px solid", ""));
    for (family, initial) |name, value| try expectText(&block, name, value);
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border-image-slice", "100% 100% 100% 100%", ""));
    try expectText(&block, "border", "2px solid");
    for ([_][]const u8{ "initial", "inherit", "unset", "revert", "revert-layer" }) |wide| {
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border", wide, ""));
        for (family) |name| try expectText(&block, name, wide);
    }
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border", "2px solid", ""));
    // A reset-only noninitial component makes border impossible to serialize.
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border-image-width", "3", ""));
    try expectText(&block, "border", "");
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    _ = try block.removeProperty("border", &removed);
    for (family) |name| try testing.expect(block.get((try property(name)).longhand) == null);
}

test "ci1 border resets every border image component side shorthands preserve them all OOM" {
    try resetCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, resetCase, .{});
}

test "ci1 border image shorthand serializer round trip preserves five typed longhands" {
    try requireFamily();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "border-image:url(https://example.test/frame) 20 fill / 2 auto / 3 round space");
    defer block.deinit();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try block.getPropertyValue("border-image", &text);
    try testing.expectEqualStrings("url(\"https://example.test/frame\") 20 fill / 2 auto / 3 round space", text.items);
    var again = css.declarations.DeclarationBlock.init(testing.allocator);
    defer again.deinit();
    try testing.expect(try again.setProperty(.{ .allocator = testing.allocator }, "border-image", text.items, ""));
    for (family) |name| {
        const l = (try property(name)).longhand;
        try testing.expect(block.get(l).?.value.value.eql(again.get(l).?.value.value));
    }
    try testing.expect(try again.setProperty(.{ .allocator = testing.allocator }, "border-image-width", "4", "important"));
    try expectText(&again, "border-image", "");
}

// UNRUN. Exact Q174 canonical cases and OOM coverage are supplied in the new
// ci1_border_image_serialization_ruled_test.zig supplement.

fn invalidOwnedCase(allocator: Allocator) !void {
    const p = try property("border-image");
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer freeAssignments(allocator, &assignments);
    try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator }, p, "url(https://example.test/a) 20 / calc(1em + 2px) / 3 junk", &assignments));
    try testing.expectEqual(@as(usize, 0), assignments.items.len);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-image: url(https://example.test/a) 20 / calc(1em + 2px) / 3 junk; border-image-repeat:round");
    defer block.deinit();
    try testing.expectEqual(@as(usize, 1), block.length());
    try testing.expect(block.get((try property("border-image-source")).longhand) == null);
    try expectText(&block, "border-image-repeat", "round");
}
test "ci1 border image rejection after image and math acquisition frees every OOM prefix" {
    try invalidOwnedCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, invalidOwnedCase, .{});
}

test "ci1 border image supplied viewport fallback uses existing context without a query container" {
    try requireFamily();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "border-image-slice:calc(10 + sign(2cqw - 10px) * 5) calc(20% + sign(2cqw - 10px) * 5%);border-image-width:calc(max(-2px, -1px) + 3px)");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .viewport_width = 400, .viewport_height = 300 }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    // Conditional5 §7 fallback: 2cqw=8px; do not emulate the WPT's 100px container.
    try expectComputed(style, "border-image-slice", "5 15%", testing.allocator);
    // Only the outer result clamps: max(-2px,-1px)+3px = 2px, not 3px.
    try expectComputed(style, "border-image-width", "2px", testing.allocator);
}

fn provenanceCase(allocator: Allocator) !void {
    try requireFamily();
    const first_source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://first.test/a.css", .referrer_policy = "no-referrer" });
    defer first_source.unref();
    const second_source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://second.test/b.css", .referrer_policy = "origin" });
    defer second_source.unref();
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const text = "url(https://assets.test/frame.svg) 20 / 2 / 3 round";
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .resource_source = first_source }, "border-image", text, ""));
    const old = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer old.destroy();
    try testing.expect(try block.setProperty(.{ .allocator = allocator, .resource_source = second_source }, "border-image", text, ""));
    const fresh = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer fresh.destroy();
    const l = (try property("border-image-source")).longhand;
    // Value.eql compares text; provenance is separate, as pinned by
    // cv1_resource_values_test and ci1_cursor_test (Q237).
    try testing.expect(old.get(l).eql(fresh.get(l)));
    try testing.expect(!old.get(l).resourcesEql(fresh.get(l)));
    try testing.expectEqualStrings("no-referrer", old.get(l).resourceUrls()[0].source.?.referrer_policy);
    try testing.expectEqualStrings("origin", fresh.get(l).resourceUrls()[0].source.?.referrer_policy);
    try testing.expectEqualStrings("https://second.test/b.css", fresh.get(l).resourceUrls()[0].source.?.base_url);
}
test "ci1 border image identical URL text replaces provenance without aliasing old computed owner all OOM" {
    try provenanceCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, provenanceCase, .{});
}
