//! Values 5 Appendix A: independently registered functions share one table.
const std = @import("std");
const sub = @import("css").substitution;
const testing = std.testing;

test "attr and if retain distinct name and ID lookups after integration" {
    try testing.expectEqual(sub.Id.attr, sub.functionId("attr").?);
    try testing.expectEqual(sub.Id.attr, sub.functionId("AtTr").?);
    try testing.expectEqual(sub.Id.@"if", sub.functionId("if").?);
    try testing.expectEqual(sub.Id.@"if", sub.functionId("IF").?);
    try testing.expectEqual(sub.Id.attr, sub.function(.attr).id);
    try testing.expectEqual(sub.Id.@"if", sub.function(.@"if").id);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const attr_nodes = sub.trim(try sub.parse(allocator, "attr(data-value px)"));
    try testing.expectEqual(@as(usize, 1), attr_nodes.len);
    try testing.expectEqual(sub.Id.attr, attr_nodes[0].function.?);
    _ = try sub.function(.attr).arguments(allocator, attr_nodes[0].children, .parse);
    const if_nodes = sub.trim(try sub.parse(allocator, "if(else: 7px)"));
    try testing.expectEqual(@as(usize, 1), if_nodes.len);
    try testing.expectEqual(sub.Id.@"if", if_nodes[0].function.?);
    _ = try sub.function(.@"if").arguments(allocator, if_nodes[0].children, .parse);
}
