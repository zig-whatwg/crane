//! Lane maj5: CSS grammar and serialization gaps that Chrome, Firefox and
//! Safari agree on (wpt.fyi 2358bd4835):
//! - CSS UI 4 §5.2: caret-color is `auto | <color> [auto | <color>]?` - a
//!   two-value form begins with a color, never with auto
//!   (css/css-ui/parsing/caret-color-invalid.html).
//! - CSSOM "serialize a CSS declaration block": when every longhand of `all`
//!   holds one CSS-wide keyword, the block serializes `all: <keyword>`
//!   (css/cssom/cssstyledeclaration-csstext-all-shorthand.html).
//! - Media Queries 4 §3 / CSS Syntax 3 §5.4.8: end of input closes an open
//!   block, whitespace inside it included; a <resolution> feature value may be
//!   a math function, which serializes simplified
//!   (css/mediaqueries/match-media-parsing.html).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;

fn accepts(name: []const u8, input: []const u8) !bool {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    return block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
}

test "caret-color: a two-value form begins with a color" {
    var wrong: usize = 0;
    for ([_][]const u8{ "auto auto", "auto red", "auto rgba(10, 20, 30, 0.4)", "auto transparent", "auto currentcolor", "auto auto auto", "red green blue", "red /", "auto !" }) |input| {
        if (try accepts("caret-color", input)) {
            std.debug.print("caret-color: \"{s}\" should be invalid\n", .{input});
            wrong += 1;
        }
    }
    for ([_][]const u8{ "auto", "red", "currentcolor", "red auto", "rgba(10, 20, 30, 0.4) auto", "red blue", "currentcolor auto" }) |input| {
        if (!try accepts("caret-color", input)) {
            std.debug.print("caret-color: \"{s}\" should be valid\n", .{input});
            wrong += 1;
        }
    }
    try testing.expectEqual(@as(usize, 0), wrong);
}

fn expectCssText(input: []const u8, expected: []const u8) !void {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    try block.setCssText(.{ .allocator = testing.allocator }, input);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    if (!std.mem.eql(u8, expected, out.items)) std.debug.print("cssText \"{s}\"\n  expected \"{s}\"\n  got      \"{s}\"\n", .{ input, expected, out.items });
    try testing.expectEqualStrings(expected, out.items);
}

test "cssText serializes the all shorthand when every longhand of it has one CSS-wide keyword" {
    try expectCssText("all: inherit", "all: inherit;");
    try expectCssText("width: 100px; all: inherit; height: inherit", "all: inherit;");
    try expectCssText("direction: ltr; all: inherit; unicode-bidi: plaintext", "direction: ltr; all: inherit; unicode-bidi: plaintext;");
    try expectCssText("width: 100px; --a: a; all: inherit; --b: b; height: inherit", "--a: a; all: inherit; --b: b;");
    try expectCssText("all: initial !important", "all: initial !important;");
    try expectCssText("width: 1px; color: red", "width: 1px; color: red;");
}

test "all is not written when one of its longhands has a value of its own" {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    try block.setCssText(.{ .allocator = testing.allocator }, "all: unset; width: 1px");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.serialize(&out);
    try testing.expect(std.mem.indexOf(u8, out.items, "all:") == null);
    try testing.expect(std.mem.indexOf(u8, out.items, "width: 1px;") != null);
}

fn expectMedia(input: []const u8, expected: []const u8) !void {
    var list = try css.media_queries.MediaQueryList.parse(testing.allocator, input);
    defer list.deinit();
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    defer aw.deinit();
    try list.serialize(&aw.writer);
    if (!std.mem.eql(u8, expected, aw.written())) std.debug.print("media \"{s}\"\n  expected \"{s}\"\n  got      \"{s}\"\n", .{ input, expected, aw.written() });
    try testing.expectEqualStrings(expected, aw.written());
}

test "end of input closes a media query's block, whitespace and all" {
    try expectMedia(" ( color   ", "(color)");
    try expectMedia("(color", "(color)");
    try expectMedia(" ( color  )  ", "(color)");
    try expectMedia("  color ), ( color", "not all, (color)");
}

test "a resolution feature value may be a math function, serialized simplified" {
    try expectMedia("(min-resolution: calc(1x))", "(min-resolution: calc(1dppx))");
    try expectMedia("(resolution: calc(2x))", "(resolution: calc(2dppx))");
    try expectMedia("(max-resolution: calc(7x))", "(max-resolution: calc(7dppx))");
    try expectMedia("(resolution: calc(1x + 2x))", "(resolution: calc(3dppx))");
    try expectMedia("(resolution: calc(5x - 2x))", "(resolution: calc(3dppx))");
    try expectMedia("(resolution: calc(1x * 3))", "(resolution: calc(3dppx))");
    try expectMedia("(resolution: calc(6x / 2))", "(resolution: calc(3dppx))");
    try expectMedia("(resolution: 2x)", "(resolution: 2x)");
    // And it evaluates: the environment's density is 1dppx.
    var list = try css.media_queries.MediaQueryList.parse(testing.allocator, "(resolution: calc(0.5x + 0.5x)), (min-resolution: calc(2x))");
    defer list.deinit();
    const values: css.media_queries.MediaValues = .{};
    try testing.expect(list.matches(&values));
    var high = try css.media_queries.MediaQueryList.parse(testing.allocator, "(min-resolution: calc(1x * 2))");
    defer high.deinit();
    try testing.expect(!high.matches(&values));
}
