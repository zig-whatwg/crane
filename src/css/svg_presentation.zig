//! SVG2 §6.6: presentation attributes, with §4.2 value parsing.
//! Values are NOT declarations. Invalid syntax contributes no cascade hint.
const std = @import("std");
const properties = @import("properties.zig");
const Allocator = std.mem.Allocator;

pub const svg_namespace = "http://www.w3.org/2000/svg";

const universal = std.StaticStringMap(void).initComptime(.{
    .{ "alignment-baseline", {} }, .{ "baseline-shift", {} },      .{ "clip-path", {} },                   .{ "clip-rule", {} },
    .{ "color", {} },              .{ "color-interpolation", {} }, .{ "color-interpolation-filters", {} }, .{ "cursor", {} },
    .{ "direction", {} },          .{ "display", {} },             .{ "dominant-baseline", {} },           .{ "fill-opacity", {} },
    .{ "fill-rule", {} },          .{ "filter", {} },              .{ "flood-color", {} },                 .{ "flood-opacity", {} },
    .{ "font-family", {} },        .{ "font-size", {} },           .{ "font-size-adjust", {} },            .{ "font-stretch", {} },
    .{ "font-style", {} },         .{ "font-variant", {} },        .{ "font-weight", {} },                 .{ "glyph-orientation-vertical", {} },
    .{ "image-rendering", {} },    .{ "letter-spacing", {} },      .{ "lighting-color", {} },              .{ "marker-end", {} },
    .{ "marker-mid", {} },         .{ "marker-start", {} },        .{ "mask", {} },                        .{ "mask-type", {} },
    .{ "opacity", {} },            .{ "overflow", {} },            .{ "paint-order", {} },                 .{ "pointer-events", {} },
    .{ "shape-rendering", {} },    .{ "stop-color", {} },          .{ "stop-opacity", {} },                .{ "stroke", {} },
    .{ "stroke-dasharray", {} },   .{ "stroke-dashoffset", {} },   .{ "stroke-linecap", {} },              .{ "stroke-linejoin", {} },
    .{ "stroke-miterlimit", {} },  .{ "stroke-opacity", {} },      .{ "stroke-width", {} },                .{ "text-anchor", {} },
    .{ "text-decoration", {} },    .{ "text-overflow", {} },       .{ "text-rendering", {} },              .{ "transform-origin", {} },
    .{ "unicode-bidi", {} },       .{ "vector-effect", {} },       .{ "visibility", {} },                  .{ "white-space", {} },
    .{ "word-spacing", {} },       .{ "writing-mode", {} },
});

fn oneOf(name: []const u8, choices: []const []const u8) bool {
    for (choices) |choice| if (std.mem.eql(u8, name, choice)) return true;
    return false;
}

/// The CSS property of a SUPPORTED presentation attribute. Attribute and
/// element names remain case-sensitive, unlike CSS property names.
pub fn lookup(namespace: []const u8, element: []const u8, attribute: []const u8) ?properties.Property {
    if (!std.mem.eql(u8, namespace, svg_namespace)) return null;
    if (universal.has(attribute)) return properties.lookup(attribute);
    if (std.mem.eql(u8, attribute, "fill")) {
        if (oneOf(element, &.{ "animate", "animateMotion", "animateTransform", "set", "discard" })) return null;
        return properties.lookup("fill");
    }
    if (std.mem.eql(u8, attribute, "transform")) {
        if (oneOf(element, &.{ "pattern", "linearGradient", "radialGradient" })) return null;
        return properties.lookup("transform");
    }
    if (std.mem.eql(u8, attribute, "patternTransform")) return if (std.mem.eql(u8, element, "pattern")) properties.lookup("transform") else null;
    if (std.mem.eql(u8, attribute, "gradientTransform")) return if (oneOf(element, &.{ "linearGradient", "radialGradient" })) properties.lookup("transform") else null;
    const permitted = if (oneOf(attribute, &.{ "cx", "cy" }))
        oneOf(element, &.{ "circle", "ellipse" })
    else if (oneOf(attribute, &.{ "height", "width", "x", "y" }))
        oneOf(element, &.{ "foreignObject", "image", "rect", "svg", "symbol", "use" })
    else if (std.mem.eql(u8, attribute, "r"))
        std.mem.eql(u8, element, "circle")
    else if (oneOf(attribute, &.{ "rx", "ry" }))
        oneOf(element, &.{ "ellipse", "rect" })
    else if (std.mem.eql(u8, attribute, "d"))
        std.mem.eql(u8, element, "path")
    else
        false;
    return if (permitted) properties.lookup(attribute) else null;
}

/// Append owned assignments only for a valid supported attribute. SVG2 §6.6
/// parses a property VALUE, so !important is never stripped. Invalid values
/// are ignored, rather than set to initial: all three browsers agree in
/// tmp/analysis/integrator-probes-1022d/results/svgattr-*.json (Q6), overriding
/// SVG2 §4.2's older initial-value prose under the browser-majority rule.
pub fn parse(options: properties.ParseOptions, namespace: []const u8, element: []const u8, attribute: []const u8, text: []const u8, out: *std.ArrayList(properties.Assignment)) Allocator.Error!bool {
    const property = lookup(namespace, element, attribute) orelse return false;
    var context = options;
    context.svg_presentation = true;
    return properties.parseDeclaration(context, property, text, out);
}
