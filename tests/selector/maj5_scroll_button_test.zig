//! Lane maj5: CSS Overflow 5 §3.2 - `::scroll-button( '*' |
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
