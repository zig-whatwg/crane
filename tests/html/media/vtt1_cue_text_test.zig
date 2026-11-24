//! The WebVTT cue text parsing rules (WebVTT 6.4, specs/w3c/webvtt.md), tests
//! first. Cases from webvtt/parsing/cue-text-parsing/dat/*.dat, serialized as
//! that directory's common.js `test_serializer` serializes the DOM tree the
//! WebVTT cue text DOM construction rules (6.5) make of the parsed nodes:
//! a class object is a span, a voice a span with title, a language a span
//! with lang, a timestamp a <?timestamp ...> processing instruction.
const std = @import("std");
const testing = std.testing;
const webvtt = @import("html").webvtt;

fn serialize(allocator: std.mem.Allocator, input: []const u8, language: ?[]const u8) ![]u8 {
    var tree = try webvtt.parseCueText(allocator, input, language);
    defer tree.deinit();
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "#document-fragment");
    for (tree.root.children.items) |child| try serializeNode(allocator, &out, child, 0);
    return out.toOwnedSlice(allocator);
}

fn indent(allocator: std.mem.Allocator, out: *std.ArrayList(u8), depth: usize) !void {
    try out.appendSlice(allocator, "\n| ");
    for (0..depth) |_| try out.appendSlice(allocator, "  ");
}

fn serializeNode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), node: *const webvtt.CueNode, depth: usize) !void {
    try indent(allocator, out, depth);
    switch (node.kind) {
        .text => try out.print(allocator, "\"{s}\"", .{node.value}),
        .timestamp => {
            var buffer: [32]u8 = undefined;
            try out.print(allocator, "<?timestamp {s}>", .{webvtt.formatTimestamp(&buffer, node.time)});
        },
        else => {
            try out.print(allocator, "<{s}>", .{node.kind.localName()});
            // Attributes, sorted by name: class, lang, title.
            if (node.classes.len != 0) {
                try indent(allocator, out, depth + 1);
                try out.appendSlice(allocator, "class=\"");
                for (node.classes, 0..) |class, i| {
                    if (i != 0) try out.append(allocator, ' ');
                    try out.appendSlice(allocator, class);
                }
                try out.append(allocator, '"');
            }
            if (node.kind == .language) {
                try indent(allocator, out, depth + 1);
                try out.print(allocator, "lang=\"{s}\"", .{node.language orelse ""});
            }
            if (node.kind == .voice) {
                try indent(allocator, out, depth + 1);
                try out.print(allocator, "title=\"{s}\"", .{node.value});
            }
            for (node.children.items) |child| try serializeNode(allocator, out, child, depth + 1);
        },
    }
}

fn expectTree(input: []const u8, expected: []const u8) !void {
    const got = try serialize(testing.allocator, input, null);
    defer testing.allocator.free(got);
    testing.expectEqualStrings(expected, got) catch |err| {
        std.debug.print("input: {s}\n", .{input});
        return err;
    };
}

test "vtt1 cue text: text and character references (text.dat, entities.dat)" {
    try expectTree("test", "#document-fragment\n| \"test\"");
    try expectTree("&", "#document-fragment\n| \"&\"");
    try expectTree("&amp", "#document-fragment\n| \"&\"");
    try expectTree("&amp;", "#document-fragment\n| \"&\"");
    try expectTree("&AMP;", "#document-fragment\n| \"&\"");
    try expectTree("&lt;&gt;", "#document-fragment\n| \"<>\"");
    try expectTree("a&lrm;b", "#document-fragment\n| \"a\u{200E}b\"");
    try expectTree("&nbsp;", "#document-fragment\n| \"\u{A0}\"");
    try expectTree("&&", "#document-fragment\n| \"&&\"");
    try expectTree("&1", "#document-fragment\n| \"&1\"");
    try expectTree("&1;", "#document-fragment\n| \"&1;\"");
    try expectTree("&<", "#document-fragment\n| \"&\"");
    try expectTree("&<c", "#document-fragment\n| \"&\"\n| <span>");
    try expectTree("&#32;", "#document-fragment\n| \" \"");
    try expectTree("&#x20;", "#document-fragment\n| \" \"");
    try expectTree("&#x;", "#document-fragment\n| \"&#x;\"");
    try expectTree("&;", "#document-fragment\n| \"&;\"");
    try expectTree("&ClockwiseContourIntegral;", "#document-fragment\n| \"\u{2232}\"");
    try expectTree("&nsubE;", "#document-fragment\n| \"\u{2AC5}\u{338}\"");
    try expectTree("&notin;", "#document-fragment\n| \"\u{2209}\"");
    try expectTree("&not", "#document-fragment\n| \"\u{AC}\"");
    try expectTree("&notit;", "#document-fragment\n| \"\u{AC}it;\"");
    // HTML 13.2.5.84: the numeric reference end state's replacements.
    try expectTree("&#0;&#x80;&#xD800;&#x110000;", "#document-fragment\n| \"\u{FFFD}\u{20AC}\u{FFFD}\u{FFFD}\"");
}

test "vtt1 cue text: tags (tags.dat)" {
    for ([_][]const u8{ "<", "<<", "<\t", "<\n", "< ", "<.", "</" }) |input| try expectTree(input, "#document-fragment");
    try expectTree("<c.", "#document-fragment\n| <span>");
    try expectTree("<c></>x", "#document-fragment\n| <span>\n|   \"x\"");
    try expectTree("<c></ c>x", "#document-fragment\n| <span>\n|   \"x\"");
    try expectTree("a<c.d e>b</c>c", "#document-fragment\n| \"a\"\n| <span>\n|   class=\"d\"\n|   \"b\"\n| \"c\"");
    try expectTree("a<i.d e>b</i>c", "#document-fragment\n| \"a\"\n| <i>\n|   class=\"d\"\n|   \"b\"\n| \"c\"");
    try expectTree("a<b.d e>b</b>c", "#document-fragment\n| \"a\"\n| <b>\n|   class=\"d\"\n|   \"b\"\n| \"c\"");
    try expectTree("a<u.d e>b</u>c", "#document-fragment\n| \"a\"\n| <u>\n|   class=\"d\"\n|   \"b\"\n| \"c\"");
    try expectTree("a<ruby.f g>b<rt.h j>c</rt>d</ruby>e", "#document-fragment\n| \"a\"\n| <ruby>\n|   class=\"f\"\n|   \"b\"\n|   <rt>\n|     class=\"h\"\n|     \"c\"\n|   \"d\"\n| \"e\"");
    // An rt start tag outside ruby is ignored.
    try expectTree("<rt>test", "#document-fragment\n| \"test\"");
    try expectTree("<v>test", "#document-fragment\n| <span>\n|   title=\"\"\n|   \"test\"");
    try expectTree("<v a b>test", "#document-fragment\n| <span>\n|   title=\"a b\"\n|   \"test\"");
    try expectTree("<v.a.b>test", "#document-fragment\n| <span>\n|   class=\"a b\"\n|   title=\"\"\n|   \"test\"");
    try expectTree("a<v.d e>b</v>c", "#document-fragment\n| \"a\"\n| <span>\n|   class=\"d\"\n|   title=\"e\"\n|   \"b\"\n| \"c\"");
    try expectTree("a<lang.d e>b</lang>c", "#document-fragment\n| \"a\"\n| <span>\n|   class=\"d\"\n|   lang=\"e\"\n|   \"b\"\n| \"c\"");
    // The annotation: leading and trailing whitespace removed, runs collapsed
    // to one space; a character reference in it is consumed.
    try expectTree("<v \t a \n\x0c b \t>x", "#document-fragment\n| <span>\n|   title=\"a b\"\n|   \"x\"");
    try expectTree("<v a&amp;b>x", "#document-fragment\n| <span>\n|   title=\"a&b\"\n|   \"x\"");
    // An LF in a start tag's name or class starts the annotation with it.
    try expectTree("<v\nx>t", "#document-fragment\n| <span>\n|   title=\"x\"\n|   \"t\"");
    // Unknown tags are ignored.
    try expectTree("<x>a</x>b", "#document-fragment\n| \"a\"\n| \"b\"");
}

test "vtt1 cue text: timestamps (timestamps.dat)" {
    for ([_][]const u8{ "<0", "<0.500", "<0:00.500", "<00:\x0000:00.500>", "test<100:00:00.000x>test" }) |input| {
        const got = try serialize(testing.allocator, input, null);
        defer testing.allocator.free(got);
        try testing.expect(std.mem.indexOf(u8, got, "timestamp") == null);
    }
    try expectTree("<00:00.500", "#document-fragment\n| <?timestamp 00:00:00.500>");
    try expectTree("<00:00:00.500", "#document-fragment\n| <?timestamp 00:00:00.500>");
    try expectTree("test<00:00:00.500>test", "#document-fragment\n| \"test\"\n| <?timestamp 00:00:00.500>\n| \"test\"");
    try expectTree("test<10:00:00.000>test", "#document-fragment\n| \"test\"\n| <?timestamp 10:00:00.000>\n| \"test\"");
    try expectTree("test<100:00:00.000>test", "#document-fragment\n| \"test\"\n| <?timestamp 100:00:00.000>\n| \"test\"");
}

test "vtt1 cue text: tree building (tree-building.dat)" {
    try expectTree("<ruby>test<rt>test", "#document-fragment\n| <ruby>\n|   \"test\"\n|   <rt>\n|     \"test\"");
    try expectTree("<ruby>test<rt>test</ruby>test", "#document-fragment\n| <ruby>\n|   \"test\"\n|   <rt>\n|     \"test\"\n| \"test\"");
    try expectTree("<ruby>test<rt><b>test</rt></ruby>test", "#document-fragment\n| <ruby>\n|   \"test\"\n|   <rt>\n|     <b>\n|       \"test\"\n|       \"test\"");
    try expectTree("<ruby>test<rt><b>test</rt></b></ruby>test", "#document-fragment\n| <ruby>\n|   \"test\"\n|   <rt>\n|     <b>\n|       \"test\"\n| \"test\"");
    try expectTree("<ruby>test<rt><b>test</rt></b>test</ruby>test", "#document-fragment\n| <ruby>\n|   \"test\"\n|   <rt>\n|     <b>\n|       \"test\"\n|     \"test\"\n| \"test\"");
}

test "vtt1 cue text: the language stack and applicable language (6.4 steps 5-6, lang)" {
    var tree = try webvtt.parseCueText(testing.allocator, "<lang en><i>a</i><lang fr>b</lang><b>c</b></lang><u>d</u>", "de");
    defer tree.deinit();
    try testing.expectEqualStrings("de", tree.root.language.?);
    const lang = tree.root.children.items[0];
    try testing.expectEqual(webvtt.CueNode.Kind.language, lang.kind);
    try testing.expectEqualStrings("en", lang.language.?);
    try testing.expectEqualStrings("en", lang.children.items[0].language.?);
    try testing.expectEqualStrings("fr", lang.children.items[1].language.?);
    try testing.expectEqualStrings("en", lang.children.items[2].language.?);
    // After </lang> the stack's top is the fallback language again.
    try testing.expectEqualStrings("de", tree.root.children.items[1].language.?);
}

test "vtt1 cue text: a WebVTT timestamp, every component, hours at least two digits (6.5)" {
    var buffer: [32]u8 = undefined;
    try testing.expectEqualStrings("00:00:00.000", webvtt.formatTimestamp(&buffer, 0));
    try testing.expectEqualStrings("00:01:01.250", webvtt.formatTimestamp(&buffer, 61.25));
    try testing.expectEqualStrings("01:00:00.001", webvtt.formatTimestamp(&buffer, 3600.001));
    try testing.expectEqualStrings("123:04:05.678", webvtt.formatTimestamp(&buffer, 123 * 3600 + 4 * 60 + 5.678));
}

test "vtt1 cue text: allocation failure frees what was made" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            var tree = try webvtt.parseCueText(allocator, "a<v.x y>b<ruby>c<rt.d>e</rt></ruby>&amp;<00:00.500></v>", "en");
            tree.deinit();
        }
    }.run, .{});
}
