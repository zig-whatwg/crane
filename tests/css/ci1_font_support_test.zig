//! Conditional5 §§2–2.1.1: a support condition takes exactly one identifier.
//! The loader's format()/tech() descriptor grammar is a separate contract.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn condition(text: []const u8) bool {
    return css.supports.supportsCondition(testing.allocator, text, null);
}

test "font support conditions accept known identifiers with CSS escaping and case folding" {
    for ([_][]const u8{
        "font-tech(features-opentype)",
        "font-tech(color-COLRv0)",
        "FONT-TECH( COLOR-colrv0 )",
        "font-tech(color-\\43 OLRv0)",
        "font-format(opentype)",
        "font-format(truetype)",
        "font-format(woff)",
        "FONT-FORMAT( OpenType )",
        "font-format(wo\\66 f)",
        "font-format(/**/woff/**/)",
    }) |text| try testing.expect(condition(text));
}

test "font support conditions reject strings lists unknown values and trailing components" {
    for ([_][]const u8{
        "font-tech()",                                "font-format()",
        "font-tech('features-opentype')",             "font-format(\"opentype\")",
        "font-tech(features-opentype color-COLRv0)",  "font-format(opentype truetype)",
        "font-tech(features-opentype, color-COLRv0)", "font-format(opentype, truetype)",
        "font-tech(features-opentype !important)",    "font-format(opentype !important)",
        "font-tech(feature-opentype)",                "font-tech(colors-COLRv0)",
        "font-tech(unknown)",                         "font-format(unknown)",
        "font-format(var(--format))",                 "font-tech(var(--tech))",
    }) |text| try testing.expect(!condition(text));
}

test "font support conditions compose with not and or without changing unknown functions" {
    try testing.expect(condition("font-format(woff) and font-tech(features-opentype)"));
    try testing.expect(condition("font-format(unknown) or font-tech(features-opentype)"));
    try testing.expect(!condition("not font-tech(features-opentype)"));
    try testing.expect(condition("not font-format(unknown)"));
    try testing.expect(!condition("unknown-font-tech(color-COLRv1)"));
    try testing.expect(condition("not unknown-font-tech(color-COLRv1)"));
}

test "font support follows the routed color SVG graphite incremental and collection majorities" {
    // Integrator's 2026-10-22 cv-* probes: SVG tech F/S; graphite false C/S;
    // incremental false all three; collection format false F/S.
    try testing.expect(condition("font-tech(color-svg)"));
    try testing.expect(!condition("font-tech(features-graphite)"));
    try testing.expect(!condition("font-tech(incremental)"));
    try testing.expect(!condition("font-format(collection)"));
}

test "font support matrix follows each browser majority" {
    // Integrator probes 1023m, CSS.supports and @supports agree per keyword.
    try testing.expectEqual(true, condition("font-tech(features-opentype)"));
    try testing.expectEqual(true, condition("font-tech(features-aat)"));
    try testing.expectEqual(false, condition("font-tech(features-graphite)"));
    try testing.expectEqual(true, condition("font-tech(color-COLRv0)"));
    try testing.expectEqual(true, condition("font-tech(color-COLRv1)"));
    try testing.expectEqual(true, condition("font-tech(color-svg)"));
    try testing.expectEqual(true, condition("font-tech(color-sbix)"));
    try testing.expectEqual(false, condition("font-tech(color-CBDT)"));
    try testing.expectEqual(true, condition("font-tech(variations)"));
    try testing.expectEqual(true, condition("font-tech(palettes)"));
    try testing.expectEqual(false, condition("font-tech(incremental)"));
    try testing.expectEqual(false, condition("font-tech(incremental-patch)"));
    try testing.expectEqual(false, condition("font-tech(incremental-range)"));
    try testing.expectEqual(false, condition("font-tech(incremental-auto)"));
    try testing.expectEqual(true, condition("font-format(opentype)"));
    try testing.expectEqual(true, condition("font-format(truetype)"));
    try testing.expectEqual(true, condition("font-format(woff)"));
    try testing.expectEqual(true, condition("font-format(woff2)"));
    try testing.expectEqual(false, condition("font-format(collection)"));
    try testing.expectEqual(false, condition("font-format(embedded-opentype)"));
    try testing.expectEqual(false, condition("font-format(svg)"));
    try testing.expectEqual(true, condition("font-tech(color-colrv1)"));
    try testing.expectEqual(true, condition("font-format(WOFF2)"));
    try testing.expectEqual(true, condition("FONT-TECH( FEATURES-AAT )"));
    try testing.expectEqual(false, condition("font-format(\"woff2\")"));
    try testing.expectEqual(false, condition("font-tech(features-aat, variations)"));
    try testing.expectEqual(false, condition("font-tech(features-aat variations)"));
    try testing.expectEqual(false, condition("font-tech()"));
    try testing.expectEqual(false, condition("font-format()"));
    try testing.expectEqual(false, condition("font-tech(unknown)"));
    try testing.expectEqual(false, condition("font-format(unknown)"));
}
