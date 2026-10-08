//! PLAINTEXT remains the tokenizer state across successive document writes.
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inbody

const std = @import("std");
const parser = @import("html").parser;

test "plaintext closes a paragraph and keeps markup literal across writes" {
    const allocator = std.testing.allocator;
    var stream = try parser.document_write.InputStreamManager.init(allocator, "");
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
    try stream.insert("<body><p>before<plaintext>Filler ");
    try builder.parse();
    const plaintext = builder.currentNode().?;
    try std.testing.expect(plaintext.hasTagName("plaintext"));
    try std.testing.expect(plaintext.parent.?.hasTagName("body"));
    try stream.insert("<b>literal &amp;\r\n");
    try builder.parse();
    const text = plaintext.first_child.?;
    try std.testing.expectEqual(@as(?*parser.TreeNode, null), text.next_sibling);
    try std.testing.expectEqual(parser.TreeNode.NodeType.text, text.node_type);
    try std.testing.expectEqualStrings("Filler <b>literal &amp;\n", text.text_content.toSlice());
    stream.complete = true;
    try builder.parse();
    try std.testing.expect(stream.eof_processed);
}
