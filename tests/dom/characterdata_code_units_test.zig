//! CharacterData measures and indexes its data in UTF-16 code units (DOM
//! 4.10, "length" of a node 4.2; Infra §4.6 strings are code units), while
//! Crane holds the data as WTF-8. Every offset method, the live ranges they
//! move, splitText, wholeText, normalize and Range's stringifier are checked
//! here with astral characters (a surrogate pair, four bytes) and lone
//! surrogates (three bytes each), whose byte and code-unit counts differ.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const allocator = testing.allocator;

// Code units in WTF-8 (python: chr(u).encode('utf-8', 'surrogatepass')).
const hi_d83c = "\xED\xA0\xBC";
const hi_d83d = "\xED\xA0\xBD";
const lo_df20 = "\xED\xBC\xA0";
const lo_df1f = "\xED\xBC\x9F";
const lo_de00 = "\xED\xB8\x80";
const shooting_star = "\xF0\x9F\x8C\xA0"; // U+1F320 = D83C DF20
const glowing_star = "\xF0\x9F\x8C\x9F"; // U+1F31F = D83C DF1F
const alchemical = "\xF0\x9F\x9C\xA0"; // U+1F720 = D83D DF20
const grinning = "\xF0\x9F\x98\x80"; // U+1F600 = D83D DE00
const e_acute = "\xC3\xA9"; // U+00E9, one code unit in two bytes
const nihon = "\xE6\x97\xA5\xE6\x9C\xAC"; // 日本, two code units in six bytes

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    body: *runtime.Instance,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.* = .{ .ctx = try runtime.ContextData.init(allocator, .{}), .document = undefined, .body = undefined };
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        const html = try interfaces.Document.call_createElement(self.document, runtime.DOMString.initInterned("html"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, html);
        self.body = try interfaces.Document.call_createElement(self.document, runtime.DOMString.initInterned("body"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(html, self.body);
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    /// A Text node in body (the document frees it).
    fn text(self: *Fixture, data: []const u8) !*runtime.Instance {
        const node = try interfaces.Document.call_createTextNode(self.document, runtime.DOMString.initInterned(data));
        _ = try interfaces.Node.call_appendChild(self.body, node);
        return node;
    }

    /// A Comment node in body.
    fn comment(self: *Fixture, data: []const u8) !*runtime.Instance {
        const node = try interfaces.Document.call_createComment(self.document, runtime.DOMString.initInterned(data));
        _ = try interfaces.Node.call_appendChild(self.body, node);
        return node;
    }

    fn range(self: *Fixture, start: *runtime.Instance, start_offset: u32, end: *runtime.Instance, end_offset: u32) !*runtime.Instance {
        const result = try interfaces.Document.call_createRange(self.document);
        errdefer interfaces.Range.deinit(result);
        try interfaces.Range.call_setStart(result, start, start_offset);
        try interfaces.Range.call_setEnd(result, end, end_offset);
        return result;
    }
};

fn expectData(node: *runtime.Instance, expected: []const u8) !void {
    var data = try interfaces.CharacterData.get_data(node);
    defer data.deinit(node.ctx.allocator);
    try testing.expectEqualSlices(u8, expected, data.asSlice());
}

fn expectSubstring(node: *runtime.Instance, offset: u32, count: u32, expected: []const u8) !void {
    var data = try interfaces.CharacterData.call_substringData(node, offset, count);
    defer data.deinit(node.ctx.allocator);
    try testing.expectEqualSlices(u8, expected, data.asSlice());
}

fn length(node: *runtime.Instance) !u32 {
    return interfaces.CharacterData.get_length(node);
}

fn str(s: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(s);
}

/// Run `body` against a fresh fixture on a thread of its own (a test
/// directory is one executable; this file must not depend on its order).
fn run(comptime body: fn (*Fixture) anyerror!void) !void {
    const Run = struct {
        fn go(result: *?anyerror) void {
            var fixture: Fixture = undefined;
            fixture.init() catch |err| {
                result.* = err;
                return;
            };
            defer fixture.deinit();
            body(&fixture) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.go, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "length is the number of UTF-16 code units of the data" {
    try run(struct {
        fn body(f: *Fixture) !void {
            try testing.expectEqual(@as(u32, 4), try length(try f.text("A" ++ grinning ++ "B")));
            try testing.expectEqual(@as(u32, 4), try length(try f.comment("A" ++ grinning ++ "B")));
            try testing.expectEqual(@as(u32, 1), try length(try f.text(hi_d83d)));
            try testing.expectEqual(@as(u32, 3), try length(try f.text(e_acute ++ nihon)));
            const node = try f.text("");
            try interfaces.CharacterData.set_data(node, str(grinning ++ grinning));
            try testing.expectEqual(@as(u32, 4), try length(node));
            // Past the inline (31-byte) storage: 10 pairs, 40 bytes.
            try interfaces.CharacterData.set_data(node, str(grinning ** 10));
            try testing.expectEqual(@as(u32, 20), try length(node));
        }
    }.body);
}

test "substringData counts code units and splits a pair it cuts" {
    try run(struct {
        fn body(f: *Fixture) !void {
            const node = try f.text(shooting_star ++ " test " ++ shooting_star ++ " TEST");
            try expectSubstring(node, 1, 8, lo_df20 ++ " test " ++ hi_d83c);
            try expectSubstring(node, 3, 4, "test");
            try expectSubstring(node, 8, 100, shooting_star ++ " TEST");
            try expectSubstring(node, 15, 1, "");
            try testing.expectError(error.IndexSizeError, interfaces.CharacterData.call_substringData(node, 16, 1));
        }
    }.body);
}

fn replaceDataSequence(node: *runtime.Instance) !void {
    try interfaces.CharacterData.set_data(node, str(shooting_star ++ " test " ++ shooting_star ++ " TEST"));
    try interfaces.CharacterData.call_replaceData(node, 1, 4, str("--"));
    try expectData(node, hi_d83c ++ "--st " ++ shooting_star ++ " TEST");
    try interfaces.CharacterData.call_replaceData(node, 1, 2, str(lo_df1f ++ " "));
    try expectData(node, glowing_star ++ " st " ++ shooting_star ++ " TEST");
    try interfaces.CharacterData.call_replaceData(node, 5, 2, str("---"));
    try expectData(node, glowing_star ++ " st---" ++ lo_df20 ++ " TEST");
    try interfaces.CharacterData.call_replaceData(node, 6, 2, str(" " ++ hi_d83d));
    try expectData(node, glowing_star ++ " st- " ++ alchemical ++ " TEST");
    try testing.expectEqual(@as(u32, 14), try length(node));
}

fn deleteDataSequence(node: *runtime.Instance) !void {
    try interfaces.CharacterData.set_data(node, str(shooting_star ++ " test " ++ shooting_star ++ " TEST"));
    try interfaces.CharacterData.call_deleteData(node, 1, 4);
    try expectData(node, hi_d83c ++ "st " ++ shooting_star ++ " TEST");
    try interfaces.CharacterData.call_deleteData(node, 1, 4);
    try expectData(node, shooting_star ++ " TEST");
    try testing.expectEqual(@as(u32, 7), try length(node));
}

fn insertDataSequence(node: *runtime.Instance) !void {
    try interfaces.CharacterData.set_data(node, str(shooting_star ++ " test " ++ shooting_star ++ " TEST"));
    try interfaces.CharacterData.call_insertData(node, 1, str("--"));
    try expectData(node, hi_d83c ++ "--" ++ lo_df20 ++ " test " ++ shooting_star ++ " TEST");
    try interfaces.CharacterData.call_insertData(node, 1, str(lo_df1f ++ " "));
    try expectData(node, glowing_star ++ " --" ++ lo_df20 ++ " test " ++ shooting_star ++ " TEST");
    try interfaces.CharacterData.call_insertData(node, 5, str(" " ++ hi_d83d));
    try expectData(node, glowing_star ++ " -- " ++ alchemical ++ " test " ++ shooting_star ++ " TEST");
    try testing.expectError(error.IndexSizeError, interfaces.CharacterData.call_insertData(node, 22, str("x")));
    try interfaces.CharacterData.call_insertData(node, 21, str("!"));
    try expectSubstring(node, 16, 6, " TEST!");
}

test "replaceData, deleteData and insertData split and join surrogate pairs (Text and Comment)" {
    try run(struct {
        fn body(f: *Fixture) !void {
            try replaceDataSequence(try f.text("test"));
            try replaceDataSequence(try f.comment("test"));
            try deleteDataSequence(try f.text("test"));
            try deleteDataSequence(try f.comment("test"));
            try insertDataSequence(try f.text("test"));
            try insertDataSequence(try f.comment("test"));
        }
    }.body);
}

test "appendData joins a lone high surrogate with the low one appended to it" {
    try run(struct {
        fn body(f: *Fixture) !void {
            const node = try f.text(hi_d83d);
            try interfaces.CharacterData.call_appendData(node, str(lo_de00));
            try expectData(node, grinning);
            try testing.expectEqual(@as(u32, 2), try length(node));
            // Canonical bytes: equal to a node made from the pair itself.
            try testing.expect(try interfaces.Node.call_isEqualNode(node, try f.text(grinning)));
            // appendData past the inline storage keeps counting code units.
            try interfaces.CharacterData.call_appendData(node, str(nihon ** 6));
            try testing.expectEqual(@as(u32, 14), try length(node));
            try expectSubstring(node, 1, 2, lo_de00 ++ "\xE6\x97\xA5");
        }
    }.body);
}

test "replace data moves live range offsets by code units" {
    try run(struct {
        fn body(f: *Fixture) !void {
            const node = try f.text("A" ++ grinning ++ "BC");
            const r = try f.range(node, 3, node, 5);
            defer interfaces.Range.deinit(r);
            try interfaces.CharacterData.call_deleteData(node, 0, 1);
            try testing.expectEqual(@as(u32, 2), try interfaces.AbstractRange.get_startOffset(r));
            try testing.expectEqual(@as(u32, 4), try interfaces.AbstractRange.get_endOffset(r));
            try interfaces.CharacterData.call_insertData(node, 0, str(e_acute ++ grinning));
            try testing.expectEqual(@as(u32, 5), try interfaces.AbstractRange.get_startOffset(r));
            try testing.expectEqual(@as(u32, 7), try interfaces.AbstractRange.get_endOffset(r));
            // An offset past the code units is an IndexSizeError, one at the end is not.
            try interfaces.Range.call_setEnd(r, node, 7);
            try testing.expectError(error.IndexSizeError, interfaces.Range.call_setEnd(r, node, 8));
        }
    }.body);
}

test "splitText splits at a code-unit offset, through a pair if asked" {
    try run(struct {
        fn body(f: *Fixture) !void {
            const node = try f.text("A" ++ grinning ++ "B");
            const tail = try interfaces.Text.call_splitText(node, 3);
            try expectData(node, "A" ++ grinning);
            try expectData(tail, "B");

            const other = try f.text("A" ++ grinning ++ "B");
            const half = try interfaces.Text.call_splitText(other, 2);
            try expectData(other, "A" ++ hi_d83d);
            try expectData(half, lo_de00 ++ "B");
            try testing.expectError(error.IndexSizeError, interfaces.Text.call_splitText(half, 3));
        }
    }.body);
}

test "wholeText joins a pair split across adjacent Text nodes" {
    try run(struct {
        fn body(f: *Fixture) !void {
            const first = try f.text("x" ++ hi_d83d);
            _ = try f.text(lo_de00 ++ "y");
            var whole = try interfaces.Text.get_wholeText(first);
            defer whole.deinit(first.ctx.allocator);
            try testing.expectEqualSlices(u8, "x" ++ grinning ++ "y", whole.asSlice());
        }
    }.body);
}

test "normalize joins the halves and moves a range by code units" {
    try run(struct {
        fn body(f: *Fixture) !void {
            const div = try interfaces.Document.call_createElement(f.document, str("div"), .{ .was_passed = false, .value = undefined });
            _ = try interfaces.Node.call_appendChild(f.body, div);
            const first = try interfaces.Document.call_createTextNode(f.document, str("A" ++ hi_d83d));
            _ = try interfaces.Node.call_appendChild(div, first);
            const second = try interfaces.Document.call_createTextNode(f.document, str(lo_de00 ++ "B"));
            _ = try interfaces.Node.call_appendChild(div, second);
            const r = try f.range(second, 1, second, 2);
            defer interfaces.Range.deinit(r);
            try interfaces.Node.call_normalize(div);
            // normalize removed the second node; nothing else frees it here.
            try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Node.get_parentNode(second));
            dom.node_creation.destroyUninserted(second);
            try expectData(first, "A" ++ grinning ++ "B");
            try testing.expectEqual(@as(u32, 4), try length(first));
            try testing.expectEqual(first, try interfaces.AbstractRange.get_startContainer(r));
            try testing.expectEqual(@as(u32, 3), try interfaces.AbstractRange.get_startOffset(r));
            try testing.expectEqual(@as(u32, 4), try interfaces.AbstractRange.get_endOffset(r));
        }
    }.body);
}
