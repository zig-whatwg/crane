const std = @import("std");
const parser = @import("html").parser;

fn expectHtmlChildren(source: []const u8) !void {
    const allocator = std.testing.allocator;
    const context = try parser.TreeNode.initElement(allocator, "html", .html);
    defer context.deinit();

    var fragment = try parser.parseFragment(allocator, context, source, .{});
    defer fragment.deinit();

    try std.testing.expectEqual(@as(usize, 3), fragment.children.len);
    try std.testing.expectEqualStrings("head", fragment.children[0].local_name.?);
    try std.testing.expectEqualStrings("body", fragment.children[1].local_name.?);
    try std.testing.expectEqual(parser.TreeNode.NodeType.comment, fragment.children[2].node_type);
    try std.testing.expectEqualStrings(" tail ", fragment.children[2].text_content.toSlice());
}

test "CE2 html fragment preserves explicit head body and trailing comment" {
    try expectHtmlChildren("<head></head><body></body><!-- tail -->");
}

test "CE2 html fragment inserts an omitted head before body" {
    try expectHtmlChildren("<body></body><!-- tail -->");
}

test "CE2 html fragment ignores the closing html token after body" {
    try expectHtmlChildren("<head></head><body></body></html><!-- tail -->");
}
