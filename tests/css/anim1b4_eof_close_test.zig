//! Lane anim1 batch 4: a declaration value cut off at EOF is valid CSS.
//! CSS Syntax 3 "consume a function" and "consume a simple block": EOF is a
//! parse error and the function or block is returned as it is - closed. So
//! `inset(10px` is `inset(10px)` (Chrome, Firefox and Safari accept it; WPT
//! css/css-masking/animations/clip-path-interpolation-xywh-rect.html writes
//! its expectations that way), and a nested cut-off function closes too.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Block = css.declarations.DeclarationBlock;

fn expectValue(allocator: Allocator, name: []const u8, text: []const u8, expected: []const u8) !void {
    var block = Block.init(allocator);
    defer block.deinit();
    testing.expect(try block.setProperty(.{ .allocator = allocator }, name, text, "")) catch |err| {
        std.debug.print("rejected: {s}: {s}\n", .{ name, text });
        return err;
    };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn cases(allocator: Allocator) !void {
    try expectValue(allocator, "clip-path", "inset(10px", "inset(10px)");
    try expectValue(allocator, "clip-path", "circle(calc(10px + 5px", "circle(calc(15px))");
    // Specified calc() simplifies once closed (Values 4 10.10).
    try expectValue(allocator, "width", "calc(1px + min(2px, 3px", "calc(3px)");
    try expectValue(allocator, "clip-path", "inset(-30px calc(-100% + 90px) calc(-20% + 20px) calc(-20% + 20px)", "inset(-30px calc(-100% + 90px) calc(-20% + 20px) calc(-20% + 20px))");
}

/// A declaration LIST is different: a function consumes `;` and the rest as
/// ordinary tokens until `)` or EOF (CSS Syntax 3 5.4.8), so the cut text is
/// never closed into a value of its own - width is invalid here.
fn listCase(allocator: Allocator) !void {
    var block = try Block.parse(.{ .allocator = allocator }, "width: calc(1px; color: red");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("width", &out);
    try testing.expectEqualStrings("", out.items);
}

test "anim1b4: a function cut off inside a declaration list is not closed into a value" {
    try listCase(testing.allocator);
}

// Spec check (CSS Syntax 3 5.4.8): the calc() swallows `; color: red`, so
// color is not applied either. Recorded to learn the splitter's behavior.
test "anim1b4: probe - a function swallows the rest of a declaration list" {
    const allocator = testing.allocator;
    var block = try Block.parse(.{ .allocator = allocator }, "width: calc(1px; color: red");
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("color", &out);
    try testing.expectEqualStrings("", out.items);
}

test "anim1b4: a declaration value's functions close at EOF" {
    try cases(testing.allocator);
}

test "anim1b4: closing at EOF under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, cases, .{});
}
