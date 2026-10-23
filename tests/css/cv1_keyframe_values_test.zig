const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Selectors = css.keyframe_values.Selectors;

test "keyframe selector identity preserves ordering duplicates and numeric precision" {
    var a = (try Selectors.parse(testing.allocator, "from, 0.5%, TO")).?;
    defer a.deinit();
    const out = try a.serialize(testing.allocator);
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("0%, 0.5%, 100%", out);
    var same = (try Selectors.parse(testing.allocator, "0%,.50%,100%")).?;
    defer same.deinit();
    try testing.expect(a.eql(same));
    var x = (try Selectors.parse(testing.allocator, "1.234567891%, 0%, 0%")).?;
    defer x.deinit();
    var y = (try Selectors.parse(testing.allocator, "1.234567892%, 0%, 0%")).?;
    defer y.deinit();
    try testing.expect(!x.eql(y));
    var reversed = (try Selectors.parse(testing.allocator, "100%,.5%,0%")).?;
    defer reversed.deinit();
    try testing.expect(!a.eql(reversed));
}

test "keyframe grammar accepts named ranges and rejects calculations atomically" {
    var valid = (try Selectors.parse(testing.allocator, "entry -20%, exit 120%, COVER 50%")).?;
    defer valid.deinit();
    const out = try valid.serialize(testing.allocator);
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("entry -20%, exit 120%, cover 50%", out);
    for ([_][]const u8{ "", "-1%", "101%", "0", "foo", "entry", "entry from", "from,", ",to", "from to", "calc(10%)", "entry calc(10%)" }) |bad| {
        const parsed = try Selectors.parse(testing.allocator, bad);
        defer if (parsed) |value| {
            var owned = value;
            owned.deinit();
        };
        try testing.expect(parsed == null);
    }
}

test "keyframe declaration context filters importance and animation controls" {
    var block = try css.declarations.DeclarationBlock.parseInContext(.{ .allocator = testing.allocator }, "left:1px;top:2px!important;animation-duration:1s;--value:yes;animation-timing-function:linear", .keyframe);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("top", &out);
    try testing.expectEqualStrings("", out.items);
    try block.getPropertyValue("animation-duration", &out);
    try testing.expectEqualStrings("", out.items);
    try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "left", "3px", "important"));
    try block.getPropertyValue("left", &out);
    try testing.expectEqualStrings("1px", out.items);
    try block.setCssText(.{ .allocator = testing.allocator }, "right:4px;left:5px!important;animation-delay:1s");
    out.clearRetainingCapacity();
    try block.serialize(&out);
    try testing.expectEqualStrings("right: 4px;", out.items);
}

test "keyframe selector and name parsing release partially constructed lists" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    var list = (try Selectors.parse(allocator, "from, entry -20%, 1.234567891%, to")).?;
    defer list.deinit();
    const text = try list.serialize(allocator);
    defer allocator.free(text);
    var stream = css.properties.Stream.init("\"initial\"");
    const name = (try css.keyframe_values.consumeName(allocator, &stream)).?;
    defer allocator.free(name);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.keyframe_values.serializeName(name, &out, allocator);
    try testing.expectEqualStrings("\"initial\"", out.items);
}
