//! Lane maj5 (this file also holds maj5's other pseudo-element and
//! pseudo-class parsing checks, below). CSS Overflow 5 §3.2 - `::scroll-button( '*' |
//! <scroll-button-direction> )`, one argument: `*`, a physical direction (up,
//! down, left, right), a flow-relative one (block-start, block-end,
//! inline-start, inline-end) or prev / next. Anything else is an invalid
//! selector (css/css-overflow/parsing/scroll-buttons-{valid,invalid}.html;
//! Chrome, the one browser that ships ::scroll-button(), rejects them).

const std = @import("std");
const selector = @import("selector");
const testing = std.testing;

fn parse(input: []const u8) !?selector.SelectorList {
    var tokenizer = selector.Tokenizer.init(testing.allocator, input);
    var parser = selector.Parser.init(testing.allocator, &tokenizer) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return null,
    };
    defer parser.deinit();
    return parser.parse() catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return null,
    };
}

fn expectValidity(expected: bool, inputs: []const []const u8) !void {
    var wrong: usize = 0;
    for (inputs) |input| {
        var list = try parse(input);
        const valid = list != null;
        if (list) |*l| l.deinit();
        if (valid != expected) {
            std.debug.print("expected {s}: \"{s}\"\n", .{ if (expected) "valid" else "invalid", input });
            wrong += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

test "::scroll-button() takes * or one scroll button direction" {
    try expectValidity(true, &.{
        "::scroll-button(up)",           "::scroll-button(down)",        "::scroll-button(left)",
        "::scroll-button(right)",        "::scroll-button(block-start)", "::scroll-button(block-end)",
        "::scroll-button(inline-start)", "::scroll-button(inline-end)",  "::scroll-button(*)",
        "::scroll-button( up)",          "::scroll-button(* )",          "::scroll-button(up):focus",
        "::scroll-button(UP)",           "::scroll-button(prev)",        "::scroll-button(next)",
    });
    try expectValidity(false, &.{
        "::scroll-button",        "::scroll-button)",      "::scroll-button(",
        "::scroll-button()",      "::scroll-button('up')", "::scroll-button(up, down)",
        "::scroll-button(north)", "::scroll-button(5051)", "::scroll-button(up down)",
        "::scroll-button(* up)",  "::scroll-button(**)",
    });
}

// ---------------------------------------------------------------------------
// More pseudo-element and pseudo-class parsing (lane maj5; Chrome, Firefox
// and Safari unless noted, wpt.fyi 2358bd4835).
// ---------------------------------------------------------------------------

fn expectText(input: []const u8, expected: []const u8) !void {
    const a = testing.allocator;
    var result = try selector.parseCssomOwned(a, try a.dupe(u8, input), .{});
    defer a.free(result.text);
    defer result.selectors.deinit();
    if (!std.mem.eql(u8, expected, result.text)) std.debug.print("\"{s}\" serialized as \"{s}\"\n", .{ input, result.text });
    try testing.expectEqualStrings(expected, result.text);
}

test "::column takes no user action pseudo-class (css-multicol/parsing/column-pseudo-invalid.html)" {
    try expectValidity(false, &.{ "::column:hover", "::column::before", "::column:focus" });
    try expectValidity(true, &.{"::column"});
}

test "::details-content is element-backed: tree-abiding pseudo-elements and non-structural pseudo-classes follow it" {
    try expectValidity(true, &.{ "::details-content", "::details-content::before", "::details-content::first-line", "::details-content:hover", "::details-content:lang(en)" });
    try expectValidity(false, &.{ "::details-content:nth-of-type(2)", "::details-content:has(a)", "::details-content::part(a)" });
}

test ":host()'s logical combinations take compound selectors (Chrome, Firefox: parse-not.html)" {
    try expectValidity(true, &.{ ":host(:not(.a))", ":not(:host(:not(.a)))", ":host(:is(.a, .b))" });
    try expectValidity(false, &.{ ":host(:not(.a .b))", ":host(:not(.a > .b))", "::slotted(:not(.a .b))" });
}

test ":state()'s argument and a -webkit- pseudo-element serialize canonically" {
    try expectText(":state( \\(escaped\\ state  )", ":state(\\(escaped\\ state)");
    try expectText("::-WeBkIt-sOmEtHiNg-NoNeXiSt123", "::-webkit-something-nonexist123");
    try expectText("::-webkit-\\ escaped", "::-webkit-\\ escaped");
}
