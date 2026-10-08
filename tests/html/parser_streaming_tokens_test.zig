//! A script-created HTML parser suspends without treating a write boundary as EOF.
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization

const std = @import("std");
const parser = @import("html").parser;
const Tokenizer = parser.Tokenizer;
const InputStreamManager = parser.document_write.InputStreamManager;

fn collect(tokenizer: *Tokenizer, output: *std.ArrayList(u8)) !void {
    const allocator = std.testing.allocator;
    while (try tokenizer.nextToken()) |token| {
        var owned = token;
        defer owned.deinit();
        switch (owned) {
            .text_run => |run| try output.appendSlice(allocator, run.data),
            .character => |cp| {
                var encoded: [4]u8 = undefined;
                const length = try std.unicode.utf8Encode(cp, &encoded);
                try output.appendSlice(allocator, encoded[0..length]);
            },
            .comment => |comment| {
                try output.appendSlice(allocator, "<!--");
                try output.appendSlice(allocator, comment.getData());
                try output.appendSlice(allocator, "-->");
            },
            .doctype => |doctype| {
                try output.appendSlice(allocator, "<!doctype ");
                try output.appendSlice(allocator, doctype.getName() orelse "(missing)");
                try output.appendSlice(allocator, doctype.getPublicIdentifier() orelse "(missing)");
                try output.appendSlice(allocator, doctype.getSystemIdentifier() orelse "(missing)");
                try output.append(allocator, if (doctype.force_quirks) 'q' else '>');
            },
            .start_tag, .end_tag => |tag| {
                try output.appendSlice(allocator, if (owned == .end_tag) "</" else "<");
                try output.appendSlice(allocator, tag.getTagName());
                for (tag.attributes.toSlice()) |attribute| {
                    try output.append(allocator, ' ');
                    try output.appendSlice(allocator, attribute.getName());
                    try output.append(allocator, '=');
                    try output.appendSlice(allocator, attribute.getValue());
                }
                try output.appendSlice(allocator, if (tag.self_closing) "/>" else ">");
            },
            .eof => try output.appendSlice(allocator, "(EOF)"),
        }
        if (owned == .eof) return;
    }
}

fn expectAllSplits(input: []const u8) !void {
    const allocator = std.testing.allocator;
    var whole = Tokenizer.init(allocator, input);
    defer whole.deinit();
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try collect(&whole, &expected);

    for (0..input.len + 1) |split| {
        var stream = try InputStreamManager.init(allocator, "");
        stream.complete = false;
        stream.insertion_point = 0;
        var tokenizer = Tokenizer.initWithStreamManager(allocator, &stream);
        defer {
            stream.deinit();
            tokenizer.deinit();
        }
        stream.attach(&tokenizer);
        var actual: std.ArrayList(u8) = .empty;
        defer actual.deinit(allocator);

        try stream.insert(input[0..split]);
        try collect(&tokenizer, &actual);
        try std.testing.expect(tokenizer.suspended);
        try stream.insert(input[split..]);
        try collect(&tokenizer, &actual);
        try std.testing.expect(tokenizer.suspended);
        stream.complete = true;
        try collect(&tokenizer, &actual);
        try std.testing.expectEqualStrings(expected.items, actual.items);
    }
}

test "script-created parser retains attributes and references at every write boundary" {
    try expectAllSplits("<p title='a &notit; &amp; &#65;x &#x42;y'>a &amp; &notin; &CounterClockwiseContourIntegral; z</p>");
}

test "script-created parser retains declaration lookahead at every write boundary" {
    try expectAllSplits("<!DOCTYPE html PUBLIC 'public' 'system'><!--split--><![CDATA[html]]>");
}

test "script-created parser retains CRLF preprocessing across writes" {
    try expectAllSplits("<p>a\r\nb\rc\nd</p>");
}
