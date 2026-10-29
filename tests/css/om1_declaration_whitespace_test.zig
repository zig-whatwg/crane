//! CSSOM serialize a CSS declaration steps 3-6; liaison Q171.
//! Whitespace-only values are omitted from declarations, while CSS Variables
//! 1 section 4.1 still gives an empty custom property's getter one space.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Block = css.declarations.DeclarationBlock;

fn expectValue(block: *const Block, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try block.getPropertyValue(name, &out);
    try std.testing.expectEqualStrings(expected, out.items);
}

fn expectCssText(block: *const Block, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try block.serialize(&out);
    try std.testing.expectEqualStrings(expected, out.items);
}

test "CSSOM declaration step 4 omits empty and whitespace-only values without changing their getters" {
    var block = try Block.parse(.{ .allocator = a }, "--empty:; --spaces: \t\n\r\x0c ;");
    defer block.deinit();
    try expectValue(&block, "--empty", " ");
    try expectValue(&block, "--spaces", " ");
    try expectCssText(&block, "--empty: ; --spaces: ;");
}

test "CSSOM declaration step 4 preserves the important suffix after an omitted value" {
    var block = try Block.parse(.{ .allocator = a }, "--empty:!important; --spaces: \t\n\r\x0c !important;");
    defer block.deinit();
    try std.testing.expect(block.getPropertyPriority("--empty"));
    try std.testing.expect(block.getPropertyPriority("--spaces"));
    try expectValue(&block, "--empty", " ");
    try expectValue(&block, "--spaces", " ");
    // Step 3 contributes the separator space; step 5 contributes its own
    // space before !important, even when step 4 appends no value.
    try expectCssText(&block, "--empty:  !important; --spaces:  !important;");
}

test "CSSOM declaration step 4 preserves internal whitespace in nonempty custom values" {
    var block = try Block.parse(.{ .allocator = a }, "--value: a  \t b; color: red;");
    defer block.deinit();
    try expectValue(&block, "--value", "a  \t b");
    try expectCssText(&block, "--value: a  \t b; color: red;");
}
