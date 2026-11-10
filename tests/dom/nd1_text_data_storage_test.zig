//! Where a CharacterData node's data lives (lane nd1, batch 1: N8 of
//! tmp/redesign/nodedata-design.md, techniques.md T8).
//!
//! Three storages behind one 16-byte Data, told apart by the length and a
//! bit, never by where the bytes happen to be (lesson
//! debugging-a-heuristic-over-pointer-ranges-breaks-when-the-allocators-layout-moves):
//! - up to 8 bytes in the Data's own word (Lightpanda's small string,
//!   src/string.zig, keeps 12 there; tendril keeps 8);
//! - whitespace of the shape Gecko shares - an optional space, up to 7
//!   newlines, then up to 50 spaces or 50 tabs - a slice of ONE static blob
//!   (Gecko's sSpaceSharedString/sTabSharedString,
//!   dom/base/CharacterDataBuffer.cpp; it covers Blink's
//!   NewlineThenWhitespaceStringsTable, a newline then up to 30 spaces,
//!   platform/wtf/text/wtf_string.h), never freed and never written;
//! - anything else one exact-size block of the node's allocator.
//! A change to data in the word or the blob writes a new copy first, as
//! Gecko copies a shared buffer out before it appends.
//!
//! The data stays WTF-8, its byte length and its UTF-16 length exact through
//! every storage change: the astral and lone-surrogate cases below sit on the
//! word's 8-byte edge (lesson spec-compliance-dom-offsets-are-utf16-code-units-over-wtf8-bytes).
//!
//! The DOM tests reach a node's data as its generated State's `_embedded`
//! (AGENTS.md "The impls boundary": generated States and src/dom types only).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const Data = dom.character_data.Data;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

fn expectData(data: *const Data, storage: Data.Storage, bytes: []const u8, units: u32) !void {
    try testing.expectEqualStrings(bytes, data.getData());
    try testing.expectEqual(@as(u32, @intCast(bytes.len)), data.byteLength());
    try testing.expectEqual(units, data.getLength());
    try testing.expectEqual(storage, data.storage());
}

const spaces: [64]u8 = @splat(' ');
const tabs: [64]u8 = @splat('\t');
const newlines: [8]u8 = @splat('\n');

// ============================================================================
// The word
// ============================================================================

test "empty data is in the word" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    try expectData(&data, .in_word, "", 0);
}

test "up to 8 bytes live in the word; the 9th byte takes an exact block" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    try data.setData(testing.allocator, "x");
    try expectData(&data, .in_word, "x", 1);
    try data.setData(testing.allocator, "12345678");
    try expectData(&data, .in_word, "12345678", 8);
    try data.setData(testing.allocator, "123456789");
    try expectData(&data, .heap, "123456789", 9);
    try data.setData(testing.allocator, "Hi");
    try expectData(&data, .in_word, "Hi", 2);
}

test "an astral character on the word's edge keeps both lengths exact" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    // U+1F600: 4 bytes, 2 code units.
    try data.setData(testing.allocator, "abcd\u{1F600}");
    try expectData(&data, .in_word, "abcd\u{1F600}", 6);
    // Inserting between its surrogates splits the pair (DOM offsets are code
    // units): 4 + 3 + 1 + 3 = 11 bytes, off the word.
    try data.replaceData(testing.allocator, 5, 0, "x");
    try expectData(&data, .heap, "abcd\xED\xA0\xBDx\xED\xB8\x80", 7);
    // Removing it lets the halves meet again: the pair, back in the word.
    try data.replaceData(testing.allocator, 5, 1, "");
    try expectData(&data, .in_word, "abcd\u{1F600}", 6);
    try data.replaceData(testing.allocator, 4, 0, "e");
    try expectData(&data, .heap, "abcde\u{1F600}", 7);
}

test "a lone surrogate in the word is its three WTF-8 bytes, one code unit" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    try data.setData(testing.allocator, "\xED\xA0\x80abcde");
    try expectData(&data, .in_word, "\xED\xA0\x80abcde", 6);
    var sub = try data.substring(testing.allocator, 0, 2);
    defer testing.allocator.free(sub);
    try testing.expectEqualStrings("\xED\xA0\x80a", sub);
    try data.replaceData(testing.allocator, 1, 5, "\xED\xB0\x80");
    // A lead and a trail that meet are one pair (WTF-8 never keeps a
    // surrogate pair as two three-byte sequences).
    try expectData(&data, .in_word, "\u{10000}", 2);
    testing.allocator.free(sub);
    sub = try data.substring(testing.allocator, 1, 1);
    try testing.expectEqualStrings("\xED\xB0\x80", sub);
}

// ============================================================================
// The shared whitespace blob
// ============================================================================

test "whitespace of Gecko's shared shape is a slice of the static blob" {
    const shapes = [_][]const u8{
        "\n" ++ spaces[0..30], // Blink's longest NewlineThenWhitespace string
        " " ++ newlines[0..7] ++ tabs[0..50], // Gecko's longest: 58 bytes
        newlines[0..7] ++ spaces[0..2],
        tabs[0..9],
        spaces[0..9],
        " " ++ spaces[0..50],
        "\n" ++ tabs[0..12],
        " " ++ newlines[0..3] ++ spaces[0..20],
    };
    for (shapes) |shape| {
        var a: Data = .empty;
        defer a.deinit(testing.allocator);
        var b: Data = .empty;
        defer b.deinit(testing.allocator);
        try a.setData(testing.allocator, shape);
        try b.setData(testing.allocator, shape);
        try expectData(&a, .shared, shape, @intCast(shape.len));
        try expectData(&b, .shared, shape, @intCast(shape.len));
        // One copy for every node with the same text.
        try testing.expectEqual(a.getData().ptr, b.getData().ptr);
    }
}

test "whitespace outside the shared shape takes a block" {
    const others = [_][]const u8{
        newlines[0..8] ++ " ", // 8 newlines: Gecko keeps 7
        " " ++ spaces[0..51], // 51 spaces after the lead: Gecko keeps 50
        "\n" ++ spaces[0..10] ++ "\t", // spaces then a tab
        "\n" ++ tabs[0..10] ++ " ",
        "\r\n" ++ spaces[0..8],
        " \n \n" ++ spaces[0..8],
        "\x0c" ++ spaces[0..8],
        spaces[0..8] ++ "\n",
        spaces[0..10] ++ "x",
    };
    for (others) |other| {
        var data: Data = .empty;
        defer data.deinit(testing.allocator);
        try data.setData(testing.allocator, other);
        try expectData(&data, .heap, other, @intCast(other.len));
    }
}

test "short whitespace stays in the word" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    try data.setData(testing.allocator, "\n    ");
    try expectData(&data, .in_word, "\n    ", 5);
    try data.setData(testing.allocator, " ");
    try expectData(&data, .in_word, " ", 1);
}

test "a change to shared data writes a copy; the blob is untouched" {
    const shape = "\n" ++ spaces[0..10];
    var a: Data = .empty;
    defer a.deinit(testing.allocator);
    var b: Data = .empty;
    defer b.deinit(testing.allocator);
    try a.setData(testing.allocator, shape);
    try b.setData(testing.allocator, shape);

    try a.replaceData(testing.allocator, 1, 0, "x"); // insertData
    try expectData(&a, .heap, "\nx" ++ spaces[0..10], 12);
    try expectData(&b, .shared, shape, 11);

    try b.replaceData(testing.allocator, 11, 0, "y"); // appendData
    try expectData(&b, .heap, shape ++ "y", 12);
    try b.replaceData(testing.allocator, 0, 11, ""); // deleteData into the word
    try expectData(&b, .in_word, "y", 1);

    // A fresh node with the shape still reads the blob's whitespace.
    var c: Data = .empty;
    defer c.deinit(testing.allocator);
    try c.setData(testing.allocator, shape);
    try expectData(&c, .shared, shape, 11);
}

test "replace data whose result has the shape shares the blob and frees the block" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    try data.setData(testing.allocator, "x\n" ++ spaces[0..10]);
    try expectData(&data, .heap, "x\n" ++ spaces[0..10], 12);
    try data.replaceData(testing.allocator, 0, 1, ""); // deleteData(0, 1)
    try expectData(&data, .shared, "\n" ++ spaces[0..10], 11);
    // And the other way: a heap text the data setter turns to whitespace.
    try data.setData(testing.allocator, "a long text that lives on the heap");
    try expectData(&data, .heap, "a long text that lives on the heap", 34);
    try data.replaceData(testing.allocator, 0, 34, tabs[0..20]);
    try expectData(&data, .shared, tabs[0..20], 20);
    // Shared to shared: no block either way.
    try data.replaceData(testing.allocator, 20, 0, tabs[0..5]);
    try expectData(&data, .shared, tabs[0..25], 25);
}

test "substring reads every storage" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    const cases = [_]struct { bytes: []const u8, storage: Data.Storage }{
        .{ .bytes = "abcdefgh", .storage = .in_word },
        .{ .bytes = "\n" ++ spaces[0..20], .storage = .shared },
        .{ .bytes = "abcdefghijklmnopqrstuvwxyz", .storage = .heap },
    };
    for (cases) |case| {
        try data.setData(testing.allocator, case.bytes);
        try testing.expectEqual(case.storage, data.storage());
        const sub = try data.substring(testing.allocator, 1, 5);
        defer testing.allocator.free(sub);
        try testing.expectEqualStrings(case.bytes[1..6], sub);
    }
}

// ============================================================================
// Data set from its own bytes
// ============================================================================

test "the data setter given the data's own bytes copies before it frees" {
    var data: Data = .empty;
    defer data.deinit(testing.allocator);
    try data.setData(testing.allocator, "0123456789abcdefghij");
    try data.setData(testing.allocator, data.getData()[2..6]); // heap -> word
    try expectData(&data, .in_word, "2345", 4);
    try data.setData(testing.allocator, data.getData()[1..3]); // word -> word
    try expectData(&data, .in_word, "34", 2);
    try data.setData(testing.allocator, "0123456789abcdefghij");
    try data.setData(testing.allocator, data.getData()[1..15]); // heap -> heap
    try expectData(&data, .heap, "123456789abcde", 14);
    try data.setData(testing.allocator, "\n" ++ spaces[0..20]);
    try data.setData(testing.allocator, data.getData()[0..15]); // shared -> shared
    try expectData(&data, .shared, "\n" ++ spaces[0..14], 15);
}

// ============================================================================
// Through the DOM: the parser, splitText, normalize, cloneNode, textContent
// ============================================================================

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

fn dataOf(node: *runtime.Instance) *const Data {
    return &node.stateAs(interfaces.CharacterData.State).?._embedded;
}

fn child(parent: *runtime.Instance, index: usize) !*runtime.Instance {
    var node = (try interfaces.Node.get_firstChild(parent)).?;
    for (0..index) |_| node = (try interfaces.Node.get_nextSibling(node)).?;
    return node;
}

fn expectText(node: *runtime.Instance, storage: Data.Storage, bytes: []const u8) !void {
    try expectData(dataOf(node), storage, bytes, @intCast(@import("infra").wtf8.codeUnitLength(bytes)));
}

test "the parser's whitespace text is shared, its short text in the word, the rest in a block" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const indent = "\n" ++ spaces[0..12];
    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str(indent ++ "<b>bold</b>" ++ indent ++ "<i>a longer run of text</i><!--" ++ indent ++ "-->") });
    try expectText(try child(page.div, 0), .shared, indent);
    try expectText(try child(try child(page.div, 1), 0), .in_word, "bold");
    try expectText(try child(page.div, 2), .shared, indent);
    try expectText(try child(try child(page.div, 3), 0), .heap, "a longer run of text");
    // A comment's data is CharacterData's too.
    try expectText(try child(page.div, 4), .shared, indent);

    // Adjacent character tokens coalesce into one Text node ("insert a
    // character" step 5): a character reference splits the tokens here.
    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str("\n&#32;" ++ spaces[0..10]) });
    try expectText(try child(page.div, 0), .shared, "\n" ++ spaces[0..11]);
    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str("ab&amp;cd&#x1F600;") });
    try expectText(try child(page.div, 0), .heap, "ab&cd\u{1F600}");
}

test "splitText, normalize, cloneNode and textContent over every storage" {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    var page: Page = undefined;
    try page.open(debug.allocator());
    defer page.close();

    const indent = "\n" ++ spaces[0..20];
    try interfaces.Element.set_innerHTML(page.div, .{ .domstring = str(indent) });
    const text = try child(page.div, 0);
    try expectText(text, .shared, indent);

    // splitText(9): the node keeps 9 code units, a new node takes the rest.
    const rest = try interfaces.Text.call_splitText(text, 9);
    try expectText(text, .shared, indent[0..9]);
    try expectText(rest, .shared, indent[9..]);

    // cloneNode copies the data: the clone shares the blob too.
    const clone = try interfaces.Node.call_cloneNode(rest, .passed(false));
    try expectText(clone, .shared, indent[9..]);
    _ = try interfaces.Node.call_appendChild(page.div, clone);

    // textContent concatenates every storage.
    const word = try interfaces.Document.call_createTextNode(page.document, str("x\u{1F600}"));
    _ = try interfaces.Node.call_appendChild(page.div, word);
    {
        var content = (try interfaces.Node.get_textContent(page.div)).?;
        defer content.deinit(page.div.ctx.allocator);
        try testing.expectEqualStrings(indent ++ indent[9..] ++ "x\u{1F600}", content.asSlice());
    }

    // normalize joins adjacent Text nodes into the first: whitespace, then
    // more whitespace and a word, which leaves the shape for a block.
    try interfaces.Node.call_normalize(page.div);
    const joined = try child(page.div, 0);
    try testing.expect(joined == text);
    try expectText(joined, .heap, indent ++ indent[9..] ++ "x\u{1F600}");
    try testing.expect((try interfaces.Node.get_nextSibling(joined)) == null);

    // The data setter and appendData on a shared node.
    try interfaces.CharacterData.set_data(joined, str(spaces[0..30]));
    try expectText(joined, .shared, spaces[0..30]);
    try interfaces.CharacterData.call_appendData(joined, str("!"));
    try expectText(joined, .heap, spaces[0..30] ++ "!");
    try interfaces.CharacterData.call_deleteData(joined, 0, 25);
    try expectText(joined, .in_word, spaces[0..5] ++ "!");
}
