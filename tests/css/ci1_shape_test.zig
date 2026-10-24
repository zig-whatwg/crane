//! CSS Shapes §3: structured functions compute components without layout.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectText(input: []const u8, expected: ?[]const u8, computed: bool) !void {
    const p = css.properties.lookup("clip-path") orelse return error.ClipPathNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color:lime;font-size:20px");
    defer block.deinit();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    const valid = try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments);
    try testing.expectEqual(expected != null, valid);
    if (expected) |text| {
        const value = assignments.items[0].value.value;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        if (computed) {
            try block.entries.ensureUnusedCapacity(testing.allocator, 1);
            value.retain();
            block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = p.longhand, .value = .{ .value = value }, .important = false } });
            const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
            defer style.destroy();
            try style.serializeResolved(p.longhand, &out, testing.allocator);
        } else try css.properties.serializeValue(p.longhand, value, &out, testing.allocator);
        try testing.expectEqualStrings(text, out.items);
    }
}

test "clip-path validates typed shapes and canonical geometry boxes" {
    try expectText("none", "none", false);
    try expectText("url(#clip)", "url(\"#clip\")", false);
    try expectText("border-box circle(7% at top right)", "circle(7% at right top)", false);
    try expectText("circle(closest-side)", "circle()", false);
    try expectText("ellipse(closest-side closest-side at center)", "ellipse(at center center)", false);
    try expectText("inset(1px 2px 1px 2px round 3px / 3px)", "inset(1px 2px round 3px)", false);
    try expectText("xywh(0 1% 2px 3em round 0)", "xywh(0px 1% 2px 3em)", false);
    try expectText("rect(auto auto auto auto)", "rect(auto auto auto auto)", false);
    try expectText("polygon(nonzero round 1px, 1% 2%)", "polygon(round 1px, 1% 2%)", false);
    try expectText("polygon(evenodd, 1px 2px, 3em 4%)", "polygon(evenodd, 1px 2px, 3em 4%)", false);
    for ([_][]const u8{ "auto", "none circle()", "circle() circle()", "url(a) border-box", "circle(-1px)", "circle(at)", "circle(at top 1px)", "ellipse(closest-side)", "ellipse(farthest-side at 100% 0%)", "ellipse(1px -2px)", "inset()", "inset(0 round -1px)", "inset(0 round / 1px)", "xywh(0 0 -1px 2px)", "rect(0 0 0)", "polygon(round -1px, 1px 2px)", "polygon(round 1%, 1px 2px)", "polygon(round 1px nonzero, 1px 2px)", "polygon(1px)" }) |bad| try expectText(bad, null, false);
}

test "clip-path computes lengths positions and equivalent inset without geometry" {
    try expectText("circle(1em at right 10px bottom 20%)", "circle(20px at calc(100% - 10px) 80%)", true);
    // Q8: unanimous current browsers keep default position serialization.
    try expectText("ellipse(at 50% 50%)", "ellipse(at 50% 50%)", true);
    try expectText("polygon(round 1em, 1px 2px, 3em 4em)", "polygon(round 20px, 1px 2px, 60px 80px)", true);
    try expectText("xywh(0 1% 2px 0.5em)", "inset(1% calc(100% - 2px) calc(99% - 10px) 0px)", true);
    try expectText("rect(auto auto auto auto)", "inset(0%)", true);
    try expectText("rect(0 1% 2px 0.5em)", "inset(0px 99% calc(100% - 2px) 10px)", true);
}

test "CSS path parses every SVG command and rejects any incomplete path" {
    try expectText("path(nonzero, 'M20,20h60 v60 h-60z')", "path(\"M 20 20 h 60 v 60 h -60 Z\")", false);
    try expectText("path('m1 2 3 4L5-6H7V8C1 2 3 4 5 6S1 2 3 4Q1 2 3 4T5 6A1 2 30 01 7 8z')", "path(\"m 1 2 l 3 4 L 5 -6 H 7 V 8 C 1 2 3 4 5 6 S 1 2 3 4 Q 1 2 3 4 T 5 6 A 1 2 30 0 1 7 8 Z\")", false);
    try expectText("path('M1e1.5')", "path(\"M 10 0.5\")", false);
    for ([_][]const u8{ "path('')", "path(' ')", "path('L1 2')", "path('M1')", "path('M1 2 L3')", "path('M1 2 A1 2 0 2 0 3 4')", "path('M1 2 Z3 4')", "path('M1 2 Q1 2 3')", "path('M1 2 junk')" }) |bad| try expectText(bad, null, false);
}

test "shape commands preserve relative coordinates control origins and ordered arc options" {
    try expectText("shape(nonzero from bottom right, curve to top left with 1em 2em from origin / 3px 4px from end, close)", "shape(from right bottom, curve to left top with 1em 2em / 3px 4px from end, close)", false);
    try expectText("shape(evenodd from center, move by 1px 2%, hline to x-start, vline by -3em, smooth by 0 0 with 1px 2px from start)", "shape(evenodd from center center, move by 1px 2%, hline to x-start, vline by -3em, smooth by 0px 0px with 1px 2px)", false);
    try expectText("shape(from 0 0, arc to 10px 20px of 10px 10px rotate 0deg small ccw)", "shape(from 0px 0px, arc to 10px 20px of 10px 10px)", false);
    try expectText("shape(from 0 0, arc by 10% 20% large rotate .5turn of -1em -2em cw)", "shape(from 0px 0px, arc by 10% 20% of -1em -2em cw large rotate 0.5turn)", false);
    try expectText("shape(from 1em 2em, curve by 3em 4em with 5em 6em from end, hline to center, arc to left top of 1em rotate .5turn)", "shape(from 20px 40px, curve by 60px 80px with 100px 120px from end, hline to 50%, arc to 0% 0% of 20px rotate 180deg)", true);
    for ([_][]const u8{
        "shape(from 0 0)",                                  "shape(from 0 0,)",                                          "shape(from 0 0, close,)",
        "shape(from 0 0, hline to top)",                    "shape(from 0 0, vline to x-end)",                           "shape(from 0 0, hline by left)",
        "shape(from 0 0, line by center)",                  "shape(from 0 0, curve to 1px 2px)",                         "shape(from 0 0, curve by 1px 2px with left top)",
        "shape(from 0 0, curve to 1px 2px with 1px 2px /)", "shape(from 0 0, smooth by 1px 2px with 1px 2px / 3px 4px)", "shape(from 0 0, arc to 1px 2px)",
        "shape(from 0 0, arc to 1px 2px of 1px cw ccw)",    "shape(from 0 0, arc to 1px 2px of 1px small large)",        "shape(from 0 0, arc to 1px 2px of 1px rotate 0)",
    }) |bad| try expectText(bad, null, false);
}

fn shapeAllocationCase(allocator: std.mem.Allocator, input: []const u8) !void {
    const property = css.properties.lookup("clip-path") orelse return error.ClipPathNotImplemented;
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, input, &assignments));
    try block.entries.ensureUnusedCapacity(allocator, 1);
    assignments.items[0].value.retain();
    block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = property.longhand, .value = assignments.items[0].value, .important = false } });
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try style.serializeResolved(property.longhand, &text, allocator);
}

test "shape allocation failure unwinds parsed computed and serialization ownership" {
    for ([_][]const u8{
        "inset(1em 2em 3em round 1em 2em / 3em)",
        "ellipse(1em 2em at right 1em bottom 2em)",
        "polygon(evenodd round 1em, 1em 2em, 3em 4em)",
        "path('M1 2 L3 4 z')",
        "shape(from 1em 2em, curve to left top with 1em 2em / 3em 4em from end, arc by 1em 2em of 3em 4em, close)",
    }) |input| try testing.checkAllAllocationFailures(testing.allocator, shapeAllocationCase, .{input});
}
