//! Lane maj1: CSS Color 4 Appendix B, the <quirky-color>. In quirks mode a
//! hex color may drop its "#" in color, background-color and the
//! border-*-color properties, as an ident (3 or 6 hex digits), a
//! <number-token> or a <dimension-token> with the integer flag: "Serialize
//! the integer's value" (and append the unit's), prepend "0"s to 6
//! characters. All three browsers (wpt.fyi 2358bd4835,
//! quirks/hashless-hex-color/quirks.html: Chrome, Firefox and Safari pass
//! every case below).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;

fn specified(quirks: bool, name: []const u8, input: []const u8, out: *std.ArrayList(u8)) !void {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator, .quirks = quirks }, name, input, "");
    out.clearRetainingCapacity();
    try block.getPropertyValue(name, out);
}

fn expectColor(input: []const u8, expected: []const u8) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try specified(true, "background-color", input, &text);
    if (!std.mem.eql(u8, expected, text.items)) std.debug.print("quirky \"{s}\"\n", .{input});
    try testing.expectEqualStrings(expected, text.items);
    // Never in no-quirks mode.
    try specified(false, "background-color", input, &text);
    try testing.expectEqualStrings("", text.items);
}

fn expectInvalid(input: []const u8) !void {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try specified(true, "background-color", input, &text);
    if (text.items.len != 0) std.debug.print("quirky \"{s}\" should be invalid\n", .{input});
    try testing.expectEqualStrings("", text.items);
}

test "a number token with the integer flag is a quirky hex color" {
    try expectColor("123", "rgb(0, 1, 35)");
    try expectColor("003", "rgb(0, 0, 3)");
    try expectColor("000000", "rgb(0, 0, 0)");
    try expectColor("112233", "rgb(17, 34, 51)");
    try expectColor("1", "rgb(0, 0, 1)");
    try expectColor("12345", "rgb(1, 35, 69)");
    try expectColor("+123456", "rgb(18, 52, 86)");
    try expectInvalid("1234567");
    try expectInvalid("-1");
    try expectInvalid("1.1");
    try expectInvalid("1.0");
    try expectInvalid("+1.1");
}

test "a dimension token with the integer flag is a quirky hex color, its unit appended" {
    try expectColor("1ab", "rgb(0, 1, 171)");
    try expectColor("1AB", "rgb(0, 1, 171)");
    try expectColor("1a", "rgb(0, 0, 26)");
    try expectColor("1abcd", "rgb(1, 171, 205)");
    try expectColor("+12345a", "rgb(18, 52, 90)");
    // The unit's escape is decoded: "12" with the unit "3".
    try expectColor("12\\33 ", "rgb(0, 1, 35)");
    try expectInvalid("1abcdef");
    try expectInvalid("-1a");
    try expectInvalid("1.1a");
    try expectInvalid("1g");
}

test "the quirk is the named properties' only" {
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try specified(true, "border-top-color", "123", &text);
    try testing.expectEqualStrings("rgb(0, 1, 35)", text.items);
    try specified(true, "color", "1ab", &text);
    try testing.expectEqualStrings("rgb(0, 1, 171)", text.items);
    try specified(true, "outline-color", "123", &text);
    try testing.expectEqualStrings("", text.items);
}
