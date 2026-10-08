//! The textarea start-tag algorithm survives suspended input without peeking.
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inbody

const std = @import("std");
const parser = @import("html").parser;
const TreeNode = parser.TreeNode;
const InputStreamManager = parser.document_write.InputStreamManager;

fn findElement(node: *TreeNode, name: []const u8) ?*TreeNode {
    if (node.hasTagName(name)) return node;
    var child = node.first_child;
    while (child) |value| : (child = value.next_sibling) {
        if (findElement(value, name)) |found| return found;
    }
    return null;
}

fn expectAllSplits(content: []const u8, expected: []const u8) !void {
    const allocator = std.testing.allocator;
    const input = try std.mem.concat(allocator, u8, &.{
        "<textarea>", content, "</textarea><p>after</p>",
    });
    defer allocator.free(input);
    for (0..input.len + 1) |split| {
        var stream = try InputStreamManager.init(allocator, "");
        stream.complete = false;
        stream.insertion_point = 0;
        var tokenizer = parser.Tokenizer.initWithStreamManager(allocator, &stream);
        stream.attach(&tokenizer);
        defer {
            stream.deinit();
            tokenizer.deinit();
        }
        var builder = try parser.TreeBuilder.initWithStreamManager(allocator, &tokenizer, &stream);
        defer builder.deinit();
        try stream.insert(input[0..split]);
        try builder.parse();
        try stream.insert(input[split..]);
        try builder.parse();
        stream.complete = true;
        try builder.parse();
        const textarea = findElement(builder.document, "textarea").?;
        const text = textarea.first_child.?;
        try std.testing.expectEqual(TreeNode.NodeType.text, text.node_type);
        try std.testing.expectEqual(@as(?*TreeNode, null), text.next_sibling);
        try std.testing.expectEqualStrings(expected, text.text_content.toSlice());
        try std.testing.expect(textarea.next_sibling.?.hasTagName("p"));
        try std.testing.expectEqualStrings("after", textarea.next_sibling.?.first_child.?.text_content.toSlice());
        try std.testing.expect(stream.eof_processed);
    }
}

test "textarea RCDATA keeps markup literal and decodes references at every write boundary" {
    try expectAllSplits("<span>Filler</span> &amp; &lt; </nottextarea>", "<span>Filler</span> & < </nottextarea>");
}

test "textarea ignores only the first LF token across split writes and CRLF preprocessing" {
    try expectAllSplits("\n\nFiller", "\nFiller");
    try expectAllSplits("\r\nFiller\r\n", "Filler\n");
    try expectAllSplits("&#10;\nFiller", "\nFiller");
    try expectAllSplits("x\nFiller", "x\nFiller");
}

test "textarea saves text insertion mode and disables framesets before more input arrives" {
    const allocator = std.testing.allocator;
    var stream = try InputStreamManager.init(allocator, "");
    stream.complete = false;
    stream.insertion_point = 0;
    var tokenizer = parser.Tokenizer.initWithStreamManager(allocator, &stream);
    stream.attach(&tokenizer);
    defer {
        stream.deinit();
        tokenizer.deinit();
    }
    var builder = try parser.TreeBuilder.initWithStreamManager(allocator, &tokenizer, &stream);
    defer builder.deinit();
    try stream.insert("<textarea>");
    try builder.parse();
    try std.testing.expect(builder.currentNode().?.hasTagName("textarea"));
    try std.testing.expectEqual(parser.State.rcdata, tokenizer.state);
    try std.testing.expectEqual(parser.InsertionMode.text, builder.insertion_mode);
    try std.testing.expectEqual(parser.InsertionMode.in_body, builder.original_insertion_mode);
    try std.testing.expect(!builder.frameset_ok);
    try stream.insert("");
    try builder.parse();
    try stream.insert("\nFiller");
    try builder.parse();
    const textarea = builder.currentNode().?;
    try std.testing.expectEqualStrings("Filler", textarea.first_child.?.text_content.toSlice());
    stream.complete = true;
    try builder.parse();
    try std.testing.expectEqual(parser.InsertionMode.in_body, builder.insertion_mode);
    try std.testing.expect(stream.eof_processed);
}

test "empty textarea consumes its LF skip before the following element" {
    const allocator = std.testing.allocator;
    var tokenizer = parser.Tokenizer.init(allocator, "<textarea></textarea><p>\nFiller</p>");
    defer tokenizer.deinit();
    var builder = try parser.TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    const textarea = findElement(builder.document, "textarea").?;
    try std.testing.expectEqual(@as(?*TreeNode, null), textarea.first_child);
    try std.testing.expectEqualStrings("\nFiller", textarea.next_sibling.?.first_child.?.text_content.toSlice());
}
