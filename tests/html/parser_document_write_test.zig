//! The HTML parser's input stream and document.write(): inserting at the
//! insertion point, and the parser processing what was inserted before
//! document.write() returns.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-input-byte-stream
//!       ("insertion point")
//! Spec: https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#document-write-steps
//!       (steps 10-11)
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#scriptEndTag
//!       (the insertion point around a parser-inserted script)

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;
const InputStreamManager = parser.document_write.InputStreamManager;

test "an insertion goes before the insertion point, which moves past it" {
    var stream = try InputStreamManager.init(testing.allocator, "ab");
    defer stream.deinit();
    stream.insertion_point = 1;
    try stream.insert("XY");
    try stream.insert("Z");
    try testing.expectEqualStrings("aXYZb", stream.buffer.items);
    try testing.expectEqual(@as(?usize, 4), stream.insertion_point);
}

test "an insertion before a saved insertion point shifts it, one after does not" {
    var stream = try InputStreamManager.init(testing.allocator, "abcdef");
    defer stream.deinit();
    var tokenizer = Tokenizer.init(testing.allocator, "");
    defer tokenizer.deinit();
    stream.attach(&tokenizer);

    // An outer script ended at 4; a nested one at 2.
    tokenizer.input.position = 4;
    stream.pushInsertionPoint();
    tokenizer.input.position = 2;
    stream.pushInsertionPoint();
    try stream.insert("--");
    try testing.expectEqualStrings("ab--cdef", stream.buffer.items);
    stream.popInsertionPoint();
    // The outer insertion point still sits between "d" and "e".
    try testing.expectEqual(@as(?usize, 6), stream.insertion_point);
    stream.popInsertionPoint();
    try testing.expectEqual(@as(?usize, null), stream.insertion_point);
}

test "the tokenizer suspends at the end of what it may read, and resumes where it stopped" {
    var stream = try InputStreamManager.init(testing.allocator, "");
    defer stream.deinit();
    stream.complete = false;
    var tokenizer = Tokenizer.initWithStreamManager(testing.allocator, &stream);
    defer tokenizer.deinit();
    stream.attach(&tokenizer);

    stream.insertion_point = 0;
    try stream.insert("<di");
    try testing.expect((try tokenizer.nextToken()) == null);
    try testing.expect(tokenizer.suspended);

    try stream.insert("v class=a>");
    var token = (try tokenizer.nextToken()).?;
    defer token.deinit();
    try testing.expectEqualStrings("div", token.start_tag.getTagName());
    try testing.expectEqualStrings("a", token.start_tag.attributes.toSlice()[0].getValue());
}

/// The document.write() a test script performs: `writes` maps a script's text
/// to what it writes.
const Writer = struct {
    stream: *InputStreamManager,
    builder: *TreeBuilder,
    writes: []const [2][]const u8,

    fn scriptEnded(node: *TreeNode, context: ?*anyopaque) void {
        const self: *Writer = @ptrCast(@alignCast(context.?));
        const text = if (node.first_child) |c| c.text_content.toSlice() else "";
        for (self.writes) |w| {
            if (!std.mem.eql(u8, w[0], text)) continue;
            // document write steps 10 and 11.
            self.stream.insert(w[1]) catch unreachable;
            self.stream.processInserted();
        }
    }

    fn process(context: *anyopaque) void {
        const self: *Writer = @ptrCast(@alignCast(context));
        self.builder.parse() catch unreachable;
    }
};

fn serializeBody(allocator: std.mem.Allocator, builder: *TreeBuilder) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    const body = builder.document.first_child.?.last_child.?;
    var child = body.first_child;
    while (child) |c| : (child = c.next_sibling) {
        switch (c.node_type) {
            .element => {
                try out.appendSlice(allocator, c.local_name.?);
                if (c.first_child) |t| {
                    if (t.node_type == .text) {
                        try out.append(allocator, '(');
                        try out.appendSlice(allocator, t.text_content.toSlice());
                        try out.append(allocator, ')');
                    }
                }
                try out.append(allocator, ' ');
            },
            else => {},
        }
    }
    return out.toOwnedSlice(allocator);
}

fn parseWithWrites(input: []const u8, writes: []const [2][]const u8) ![]u8 {
    const allocator = testing.allocator;
    var stream = try InputStreamManager.init(allocator, input);
    defer stream.deinit();
    var tokenizer = Tokenizer.initWithStreamManager(allocator, &stream);
    defer tokenizer.deinit();
    stream.attach(&tokenizer);
    var builder = try TreeBuilder.initWithStreamManager(allocator, &tokenizer, &stream);
    defer builder.deinit();
    builder.scripting_enabled = true;

    var writer = Writer{ .stream = &stream, .builder = &builder, .writes = writes };
    builder.setScriptExecutionCallback(&Writer.scriptEnded, &writer);
    stream.processor = .{ .context = &writer, .process = &Writer.process };

    try builder.parse();
    return serializeBody(allocator, &builder);
}

test "what a script writes is parsed before the markup after it, and before write() returns" {
    const body = try parseWithWrites("<body><script>A</script><p>after</p>", &.{
        .{ "A", "<b>written</b>" },
    });
    defer testing.allocator.free(body);
    try testing.expectEqualStrings("script(A) b(written) p(after) ", body);
}

test "a written script that writes nests: its output comes first" {
    const body = try parseWithWrites("<body><script>A</script><p>after</p>", &.{
        .{ "A", "<script>B</script><i>a</i>" },
        .{ "B", "<u>b</u>" },
    });
    defer testing.allocator.free(body);
    try testing.expectEqualStrings("script(A) script(B) u(b) i(a) p(after) ", body);
}

test "two writes from one script land in order" {
    const body = try parseWithWrites("<body><script>A</script><p>after</p>", &.{
        .{ "A", "<b>1</b>" },
        .{ "A", "<i>2</i>" },
    });
    defer testing.allocator.free(body);
    try testing.expectEqualStrings("script(A) b(1) i(2) p(after) ", body);
}

test "a write that ends mid-tag is finished by the markup after the script" {
    const body = try parseWithWrites("<body><script>A</script>b>x</b>", &.{
        .{ "A", "<" },
    });
    defer testing.allocator.free(body);
    try testing.expectEqualStrings("script(A) b(x) ", body);
}
