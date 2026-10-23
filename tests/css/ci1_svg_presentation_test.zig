//! SVG2 §6.6 and browser-ruling Q6: presentation attributes contribute only valid values.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "SVG presentation mappings preserve namespace case and element exceptions" {
    if (comptime @hasDecl(css, "svg_presentation")) return Checks.mapping();
    return error.PresentationAttributesNotImplemented;
}

test "invalid SVG presentation attributes append no declaration" {
    if (comptime @hasDecl(css, "svg_presentation")) return Checks.invalid();
    return error.PresentationAttributesNotImplemented;
}

test "SVG presentation shorthand ownership rolls back on allocation failure" {
    if (comptime @hasDecl(css, "svg_presentation")) return testing.checkAllAllocationFailures(testing.allocator, Checks.allocationFailures, .{});
    return error.PresentationAttributesNotImplemented;
}

const Checks = struct {
    fn mapping() !void {
        const p = css.svg_presentation;
        const ns = p.svg_namespace;
        try testing.expect(p.lookup(ns, "rect", "fill") != null);
        try testing.expect(p.lookup(ns, "g", "cursor") != null);
        try testing.expect(p.lookup(ns, "rect", "width") != null);
        try testing.expect(p.lookup(ns, "text", "width") == null);
        try testing.expect(p.lookup(ns, "rect", "Fill") == null);
        try testing.expect(p.lookup("http://www.w3.org/1999/xhtml", "rect", "fill") == null);
        for ([_][]const u8{ "animate", "animateMotion", "animateTransform", "set", "discard" }) |element| try testing.expect(p.lookup(ns, element, "fill") == null);
        try testing.expect(p.lookup(ns, "g", "marker") == null);
        try testing.expect(p.lookup(ns, "g", "marker-start") != null);
        try testing.expect(p.lookup(ns, "g", "mask") != null);
        try testing.expect(p.lookup(ns, "g", "margin-left") == null);
        try testing.expect(p.lookup(ns, "radialGradient", "r") == null);
        try testing.expect(p.lookup(ns, "text", "x") == null);
        try testing.expect(p.lookup(ns, "tspan", "x") == null);
        try testing.expect(p.lookup(ns, "pattern", "transform") == null);
        try testing.expect(p.lookup(ns, "linearGradient", "transform") == null);
        try testing.expect(p.lookup(ns, "radialGradient", "transform") == null);
    }

    fn invalid() !void {
        const p = css.svg_presentation;
        var out: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (out.items) |assignment| assignment.value.release();
            out.deinit(testing.allocator);
        }
        const opts: css.properties.ParseOptions = .{ .allocator = testing.allocator };
        // All three: tmp/analysis/integrator-probes-1022d/results/svgattr-*.json.
        try testing.expect(!try p.parse(opts, p.svg_namespace, "rect", "fill", "bogus", &out));
        try testing.expect(!try p.parse(opts, p.svg_namespace, "svg", "overflow", "bogus", &out));
        try testing.expect(!try p.parse(opts, p.svg_namespace, "rect", "fill", "red !important", &out));
        try testing.expect(!try p.parse(opts, p.svg_namespace, "rect", "stroke-width", "5foo", &out));
        try testing.expectEqual(@as(usize, 0), out.items.len);
        try testing.expect(try p.parse(opts, p.svg_namespace, "rect", "fill", "inherit", &out));
        try testing.expectEqual(css.style_values.CssWide.inherit, out.items[0].value.css_wide);
        // Q17: stroke-width's own <number> grammar accepts this in (b1).
        // The general SVG unitless-length flag is exercised separately in (b2).
        try testing.expect(try p.parse(opts, p.svg_namespace, "rect", "stroke-width", "5", &out));
        try testing.expectEqual(@as(f64, 5), out.items[1].value.value.number);
    }

    fn allocationFailures(allocator: std.mem.Allocator) !void {
        const p = css.svg_presentation;
        var out: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (out.items) |assignment| assignment.value.release();
            out.deinit(allocator);
        }
        // Overflow is a presentation shorthand already supported by BASE.
        try testing.expect(try p.parse(.{ .allocator = allocator }, p.svg_namespace, "svg", "overflow", "hidden", &out));
        const before = out.items.len;
        try testing.expect(!try p.parse(.{ .allocator = allocator }, p.svg_namespace, "rect", "fill", "url(a) none extra", &out));
        try testing.expectEqual(before, out.items.len);
    }
};
