//! ElementStyle keeps one presentational hint (element_style.Hint): a
//! background hint, an HTML font element's hint, or an SVG element's
//! presentation-attribute hint. One slot serves the three because the sets
//! of element types that carry them are disjoint (lane quick1 b4):
//! - background: HTML body, table, thead, tbody, tfoot, tr, td, th
//!   (HTML 15.3.4, 15.3.9);
//! - font: the HTML font element (HTML 15.3.4) - an HTML font inside SVG's
//!   foreignObject is still an HTML element, with no SVG hint;
//! - SVG: elements in the SVG namespace (SVG 2 §6.6).
//! A slot asked to hold a second kind panics (ElementStyle.setHint).
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const css = dom.style.css;

const html = "http://www.w3.org/1999/xhtml";
const svg = "http://www.w3.org/2000/svg";

test "the three sets of element types that carry a hint are disjoint" {
    // The background set's own test is in src/dom/style/element_style.zig
    // (its predicate is resource_loading's). An HTML element - the font
    // element, the eight background tags - has no SVG presentation
    // attribute, whatever its name; an SVG element of any name may.
    for ([_][]const u8{ "font", "body", "table", "thead", "tbody", "tfoot", "tr", "td", "th" }) |name| {
        try testing.expect(css.svg_presentation.lookup(html, name, "fill") == null);
        try testing.expect(css.svg_presentation.lookup(html, name, "color") == null);
    }
    try testing.expect(css.svg_presentation.lookup(svg, "rect", "fill") != null);
    try testing.expect(css.svg_presentation.lookup(svg, "font", "color") != null);
}

test "the slot keeps one hint; dropping another kind leaves it" {
    const state = try dom.style.ElementStyle.create(testing.allocator);
    defer state.destroy();
    _ = (try dom.style.font_hints.fontHint(state, .{ .color = "red" })) orelse return error.TestExpectedHint;
    try testing.expect(state.fontHint() != null);
    try testing.expect(state.backgroundHint() == null);
    state.dropBackgroundHint();
    try testing.expect(state.fontHint() != null);
    // A changed input rebuilds the hint in the same slot.
    _ = (try dom.style.font_hints.fontHint(state, .{ .color = "blue" })) orelse return error.TestExpectedHint;
    try testing.expectEqualStrings("blue", state.fontHint().?.color.?);
    // No input: the font hint goes.
    try testing.expect((try dom.style.font_hints.fontHint(state, .{})) == null);
    try testing.expect(state.hint == null);
}
