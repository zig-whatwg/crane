//! HTML 13.2: template insertion modes must not modify the outer document.
const std = @import("std");
const parser = @import("html").parser;
const TreeNode = parser.TreeNode;

fn find(node: *TreeNode, name: []const u8) ?*TreeNode {
    if (node.hasTagName(name)) return node;
    var child = node.first_child;
    while (child) |value| : (child = value.next_sibling) {
        if (find(value, name)) |found| return found;
    }
    return null;
}

test "template fragments ignore head and frame start tags" {
    const allocator = std.testing.allocator;
    const context = try TreeNode.initElement(allocator, "template", .html);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, "<head><title>x</title></head><frameset><frame></frameset>", .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.children.len);
    try std.testing.expect(result.children[0].hasTagName("title"));
}

test "fragment reset treats the cell context as the last node" {
    const allocator = std.testing.allocator;
    const context = try TreeNode.initElement(allocator, "td", .html);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, "<tr><td>x", .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.children.len);
    try std.testing.expectEqual(TreeNode.NodeType.text, result.children[0].node_type);
}

test "html fragment context starts before head when there is no head pointer" {
    const allocator = std.testing.allocator;
    const context = try TreeNode.initElement(allocator, "html", .html);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, "<title>x</title><p>y", .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.children.len);
    try std.testing.expect(result.children[0].hasTagName("head"));
    try std.testing.expect(result.children[1].hasTagName("body"));
}

test "template html and body tokens do not add attributes to the document" {
    const allocator = std.testing.allocator;
    var tokenizer = parser.Tokenizer.init(allocator, "<!doctype html><body><template><html data-template=html><body data-template=body><p>x</template>");
    defer tokenizer.deinit();
    var builder = try parser.TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    try std.testing.expect(find(builder.document, "html").?.getAttribute("data-template") == null);
    try std.testing.expect(find(builder.document, "body").?.getAttribute("data-template") == null);
    try std.testing.expectEqual(@as(usize, 0), builder.template_insertion_modes.len);
}

test "noscript in template uses raw text with scripting enabled" {
    const allocator = std.testing.allocator;
    var tokenizer = parser.Tokenizer.init(allocator, "<!doctype html><body><template><noscript><div>x</div></noscript></template>");
    defer tokenizer.deinit();
    var builder = try parser.TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    builder.scripting_enabled = true;
    try builder.parse();
    const noscript = find(builder.document, "noscript").?;
    try std.testing.expectEqual(TreeNode.NodeType.text, noscript.first_child.?.node_type);
    try std.testing.expectEqualStrings("<div>x</div>", noscript.first_child.?.text_content.toSlice());
    try std.testing.expect(noscript.first_child.?.next_sibling == null);
}

test "closing a nested template restores the table fragment context" {
    const allocator = std.testing.allocator;
    const context = try TreeNode.initElement(allocator, "table", .html);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, "<template></template><tr><td>x", .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.children.len);
    try std.testing.expect(result.children[0].hasTagName("template"));
    try std.testing.expect(result.children[1].hasTagName("tbody"));
    try std.testing.expect(result.children[1].first_child.?.hasTagName("tr"));
    try std.testing.expect(find(result.document, "head") == null);
    try std.testing.expect(find(result.document, "body") == null);
}

test "template form end tags preserve the outer form pointer" {
    const allocator = std.testing.allocator;
    var tokenizer = parser.Tokenizer.init(allocator, "<!doctype html><body><form id=outer><template><form id=inner></form></template><form id=ignored><input></form><form id=after>");
    defer tokenizer.deinit();
    var builder = try parser.TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    const body = find(builder.document, "body").?;
    const outer = body.first_child.?;
    try std.testing.expectEqualStrings("outer", outer.getAttribute("id").?);
    const template = outer.first_child.?;
    try std.testing.expect(template.hasTagName("template"));
    try std.testing.expectEqualStrings("inner", template.first_child.?.getAttribute("id").?);
    try std.testing.expect(template.next_sibling.?.hasTagName("input"));
    try std.testing.expectEqualStrings("after", outer.next_sibling.?.getAttribute("id").?);
}

test "frameset replaces an implicit body only while frameset-ok" {
    const allocator = std.testing.allocator;
    var tokenizer = parser.Tokenizer.init(allocator, "<!doctype html><head></head><div></div><frameset><frame></frameset>");
    defer tokenizer.deinit();
    var builder = try parser.TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    try std.testing.expect(find(builder.document, "body") == null);
    try std.testing.expect(find(builder.document, "frameset") != null);
}

test "frameset inside a template never removes the outer body" {
    const allocator = std.testing.allocator;
    var tokenizer = parser.Tokenizer.init(allocator, "<!doctype html><body><template><frameset></frameset></template><p>after");
    defer tokenizer.deinit();
    var builder = try parser.TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    try std.testing.expect(find(builder.document, "body") != null);
    try std.testing.expect(find(builder.document, "frameset") == null);
    try std.testing.expect(find(builder.document, "p") != null);
}

test "an explicit html root is owned exactly once during parser teardown" {
    const allocator = std.testing.allocator;
    var tokenizer = parser.Tokenizer.init(allocator, "<!doctype html><html><head></head><body><template><p>content</template></body></html>");
    defer tokenizer.deinit();
    var builder = try parser.TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    try std.testing.expect(find(builder.document, "template") != null);
}
