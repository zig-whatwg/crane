//! Token-level tree construction rules, independent of DOM bindings.
const std = @import("std");
const parser = @import("html").parser;
const TreeNode = parser.TreeNode;

fn writeTree(node: *TreeNode, output: *std.ArrayList(u8)) !void {
    const allocator = std.testing.allocator;
    if (node.node_type == .text) {
        try output.appendSlice(allocator, node.text_content.toSlice());
        return;
    }
    if (node.node_type == .comment) {
        try output.appendSlice(allocator, "<!--");
        try output.appendSlice(allocator, node.text_content.toSlice());
        try output.appendSlice(allocator, "-->");
        return;
    }
    try output.appendSlice(allocator, node.local_name orelse "#");
    try output.append(allocator, '[');
    var child = node.first_child;
    while (child) |value| : (child = value.next_sibling) try writeTree(value, output);
    try output.append(allocator, ']');
}

fn expectFragment(context_name: []const u8, input: []const u8, expected: []const u8) !void {
    const allocator = std.testing.allocator;
    const context = try TreeNode.initElement(allocator, context_name, .html);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, input, .{});
    defer result.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    for (result.children) |child| try writeTree(child, &output);
    try std.testing.expectEqualStrings(expected, output.items);
}

test "pre listing and textarea ignore only the next LF token" {
    inline for (.{ "pre", "listing", "textarea" }) |tag| {
        try expectFragment("div", "<" ++ tag ++ ">\nx</" ++ tag ++ ">", tag ++ "[x]");
        try expectFragment("div", "<" ++ tag ++ ">\n\nx</" ++ tag ++ ">", tag ++ "[\nx]");
        try expectFragment("div", "<" ++ tag ++ ">\r\nx</" ++ tag ++ ">", tag ++ "[x]");
        try expectFragment("div", "<" ++ tag ++ ">&#10;x</" ++ tag ++ ">", tag ++ "[x]");
        try expectFragment("div", "<" ++ tag ++ ">x\ny</" ++ tag ++ ">", tag ++ "[x\ny]");
    }
    try expectFragment("div", "<pre><!--c-->\nx</pre>", "pre[<!--c-->\nx]");
    try expectFragment("div", "<template><pre>\nx</pre></template>", "template[pre[x]]");
}

test "fragment contexts do not discard their first newline" {
    inline for (.{ "pre", "listing", "textarea" }) |tag| {
        try expectFragment(tag, "\nx", "\nx");
    }
}

test "textarea content enters RCDATA and returns to its previous mode" {
    try expectFragment("div", "<textarea>\n<b>&amp;</textarea><p>after", "textarea[<b>&]p[after]");
}

test "br end tags become attribute-free HTML start tags after foreign breakout" {
    const allocator = std.testing.allocator;
    inline for (.{ "", "<svg>", "<math>" }) |prefix| {
        const context = try TreeNode.initElement(allocator, "div", .html);
        defer context.deinit();
        var result = try parser.parseFragment(allocator, context, prefix ++ "</br data-drop=yes>tail", .{});
        defer result.deinit();
        const index: usize = if (prefix.len == 0) 0 else 1;
        try std.testing.expectEqual(index + 2, result.children.len);
        const br = result.children[index];
        try std.testing.expect(br.hasTagName("br"));
        try std.testing.expectEqual(parser.Namespace.html, br.namespace);
        try std.testing.expect(br.getAttribute("data-drop") == null);
        try std.testing.expectEqualStrings("tail", result.children[index + 1].text_content.toSlice());
    }
}
