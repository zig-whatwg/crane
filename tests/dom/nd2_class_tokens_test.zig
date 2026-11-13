//! An element's classes read through its class value's TOKEN LIST (lane nd2
//! batch 3): a value record carries its tokens - DOM's ordered set parser
//! over its bytes, each token the counted record of that token - made once,
//! on the value's first class read, and kept while the record lives or waits
//! in the ring. The class selector, classList and getElementsByClassName
//! read it; a compiled selector keeps its class name's id, so a check is
//! id == id. Blink's SpaceSplitString::Data per AtomicString (core/dom/
//! space_split_string.{h,cc}) and WebKit's SpaceSplitStringData (Source/
//! WebCore/dom/SpaceSplitString.{h,cpp}) are the model.
//!
//! The first test is the integrator's red test: a counter of the passes a
//! class read makes over a class value's bytes. Before the token list, every
//! class check scanned the value (selector_matching's classListHas); with
//! it, the first check of a value splits it and later checks scan nothing.
//!
//! Quirks mode: classes compare ASCII case-insensitively (Selectors 4 6.6,
//! DOM "list of elements with class names"). As Blink (Element::
//! ClassAttributeChanged -> ElementData::SetClassFoldingCase; CSSSelector::
//! SetValue(value, match_lower_case)) and WebKit (SpaceSplitString
//! ShouldFoldCase; CSSSelectorParser::consumeClass) do it: both sides
//! ASCII-lowercased, then the ids compared.
//!
//! These name only generated interfaces and src/dom: no impl (AGENTS.md "The
//! impls boundary").

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const attribute_values = dom.attribute_values;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const no_force: @import("webidl").Opt(bool) = .{ .was_passed = false, .value = undefined };

const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator, mode: dom.document_internals.Mode) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        try dom.document_internals.setMode(self.document, mode);
        self.div = try self.element("div");
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }

    fn element(self: *Page, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(self.document, str(name), .{ .was_passed = false, .value = undefined });
    }

    fn child(self: *Page, name: []const u8) !*runtime.Instance {
        const el = try self.element(name);
        _ = try interfaces.Node.call_appendChild(self.div, el);
        return el;
    }

    fn set(el: *runtime.Instance, name: []const u8, value: []const u8) !void {
        try interfaces.Element.call_setAttribute(el, str(name), .{ .domstring = str(value) });
    }

    fn matches(el: *runtime.Instance, selector: []const u8) !bool {
        return interfaces.Element.call_matches(el, str(selector));
    }

    fn table(self: *Page) *const attribute_values.Table {
        return attribute_values.tableOf(&self.scope).?;
    }

    /// The passes class reads made over class values' bytes so far.
    fn scans(self: *Page) usize {
        return self.table().class_scans;
    }

    /// How many elements of the document getElementsByClassName(`names`)
    /// finds.
    fn byClassNames(self: *Page, names: []const u8) !u32 {
        const list = try interfaces.Document.call_getElementsByClassName(self.document, str(names));
        defer runtime.gc.onObjectFreed(list);
        return interfaces.HTMLCollection.get_length(list);
    }

    /// How many elements querySelectorAll(`selector`) finds in the document.
    fn countAll(self: *Page, selector: []const u8) !u32 {
        const list = try interfaces.Document.call_querySelectorAll(self.document, str(selector));
        defer runtime.gc.onObjectFreed(list);
        return interfaces.NodeList.get_length(list);
    }
};

/// A DOMTokenList of `el`'s `name` attribute that the test owns: made and
/// associated as the reflection does (dom.reflection's getTokenList, through
/// dom.token_lists), so the test frees it (`runtime.gc.onObjectFreed`). The
/// [SameObject] getters (`classList`, `relList`) hand out the list the
/// element's State caches, which an engine-less page never collects: a test
/// that freed it would leave the cache dangling (lesson
/// architecture-a-getter-that-returns-a-kept-object-breaks-callers-that-free-it),
/// and one that kept it would leak it.
fn tokenList(el: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const list = try interfaces.DOMTokenList.init(el.ctx.allocator, el.ctx);
    errdefer interfaces.DOMTokenList.deinit(list);
    try dom.token_lists.associate(list, el, name);
    return list;
}

/// `el`'s classList, as its tokens and its value, for a comparison.
const Tokens = struct {
    items: [16][]u8 = undefined,
    len: usize = 0,
    value: []u8 = &.{},

    fn read(el: *runtime.Instance, page: *Page) !Tokens {
        const list = try tokenList(el, "class");
        defer runtime.gc.onObjectFreed(list);
        var self: Tokens = .{};
        const n = try interfaces.DOMTokenList.get_length(list);
        for (0..n) |i| {
            var token = (try interfaces.DOMTokenList.call_item(list, @intCast(i))).?;
            defer token.deinit(page.ctx.allocator);
            self.items[self.len] = try testing.allocator.dupe(u8, token.asSlice());
            self.len += 1;
        }
        try testing.expect((try interfaces.DOMTokenList.call_item(list, n)) == null);
        var value = try interfaces.DOMTokenList.get_value(list);
        defer value.deinit(page.ctx.allocator);
        self.value = try testing.allocator.dupe(u8, value.asSlice());
        return self;
    }

    fn deinit(self: *Tokens) void {
        for (self.items[0..self.len]) |item| testing.allocator.free(item);
        testing.allocator.free(self.value);
    }

    fn expect(self: *const Tokens, expected: []const []const u8) !void {
        try testing.expectEqual(expected.len, self.len);
        for (expected, self.items[0..self.len]) |want, got| try testing.expectEqualStrings(want, got);
    }
};

// ============================================================================
// The red test: one pass over a value, then none
// ============================================================================

test "a class check splits its value once: later checks of that value scan nothing" {
    if (builtin.mode != .debug) return error.SkipZigTest;
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");
    try Page.set(el, "class", "card featured item");
    const before = page.scans();
    for (0..100) |_| {
        try testing.expect(try Page.matches(el, ".item"));
        try testing.expect(try Page.matches(el, ".featured"));
        try testing.expect(!try Page.matches(el, ".items"));
    }
    // One split, at the first check; every later one read the token list.
    try testing.expectEqual(before + 1, page.scans());
}

test "a value shared by a thousand elements is split once, and has one token list" {
    if (builtin.mode != .debug) return error.SkipZigTest;
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    for (0..1000) |i| {
        const el = try page.child("li");
        try Page.set(el, "class", if (i % 2 == 0) "row odd" else "row even");
    }
    const before = page.scans();
    try testing.expectEqual(@as(u32, 1000), try page.countAll(".row"));
    try testing.expectEqual(@as(u32, 500), try page.countAll("li.even"));
    try testing.expectEqual(@as(u32, 500), try page.byClassNames("odd row"));
    // Two distinct values: two splits, two lists (paid once per distinct
    // string, not per element).
    try testing.expectEqual(before + 2, page.scans());
    try testing.expectEqual(@as(usize, 2), page.table().class_lists);
}

// ============================================================================
// DOM's ordered set parser
// ============================================================================

test "the five ASCII whitespace characters split classes; VT does not; duplicates count once; leading and trailing whitespace and empty values have no tokens" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");

    try Page.set(el, "class", " \ta\nb\x0Cc\rd e  ");
    for ([_][]const u8{ ".a", ".b", ".c", ".d", ".e", ".a.e" }) |selector| try testing.expect(try Page.matches(el, selector));
    {
        var tokens = try Tokens.read(el, &page);
        defer tokens.deinit();
        try tokens.expect(&.{ "a", "b", "c", "d", "e" });
        // value is the attribute verbatim.
        try testing.expectEqualStrings(" \ta\nb\x0Cc\rd e  ", tokens.value);
    }

    // VT (U+000B) is no ASCII whitespace (lesson spec-compliance-infra-
    // ascii-whitespace-is-not-std-ascii-iswhitespace): "a\x0Bb" is one token.
    try Page.set(el, "class", "a\x0Bb c");
    try testing.expect(!try Page.matches(el, ".a"));
    try testing.expect(try Page.matches(el, ".a\\b b"));
    try testing.expect(try Page.matches(el, ".c"));
    {
        var tokens = try Tokens.read(el, &page);
        defer tokens.deinit();
        try tokens.expect(&.{ "a\x0Bb", "c" });
    }

    // Duplicates: each token once, in first-seen order.
    try Page.set(el, "class", "b a b c a");
    {
        var tokens = try Tokens.read(el, &page);
        defer tokens.deinit();
        try tokens.expect(&.{ "b", "a", "c" });
    }
    try testing.expectEqual(@as(u32, 1), try page.byClassNames("a a  b"));

    // Empty and whitespace-only: no tokens; nothing matches.
    for ([_][]const u8{ "", "   ", "\t\n" }) |value| {
        try Page.set(el, "class", value);
        var tokens = try Tokens.read(el, &page);
        defer tokens.deinit();
        try tokens.expect(&.{});
        try testing.expectEqualStrings(value, tokens.value);
        try testing.expect(!try Page.matches(el, ".a"));
    }
}

test "a class selector whose name holds whitespace matches no element" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");
    // `.a\ b` names the class "a b", which no token can be (Blink: the token
    // vector never holds it; class="a b" is the tokens a and b).
    try Page.set(el, "class", "a b");
    try testing.expect(!try Page.matches(el, ".a\\ b"));
    try testing.expectEqual(@as(u32, 0), try page.countAll(".a\\ b"));
    try Page.set(el, "class", "a\tb");
    try testing.expect(!try Page.matches(el, ".a\\9 b"));
}

// ============================================================================
// Case
// ============================================================================

test "outside quirks mode classes compare identical-to" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");
    try Page.set(el, "class", "Foo bar");
    try testing.expect(try Page.matches(el, ".Foo"));
    try testing.expect(!try Page.matches(el, ".foo"));
    try testing.expect(!try Page.matches(el, ".BAR"));
    try testing.expectEqual(@as(u32, 0), try page.byClassNames("foo"));
    try testing.expectEqual(@as(u32, 1), try page.byClassNames("Foo bar"));
    // limited-quirks is not quirks.
    try dom.document_internals.setMode(page.document, .limited_quirks);
    try testing.expect(!try Page.matches(el, ".foo"));
}

test "in quirks mode classes compare ASCII case-insensitively: both sides lowercased, then ids compared" {
    var page: Page = undefined;
    try page.open(testing.allocator, .quirks);
    defer page.close();
    const a = try page.child("span");
    const b = try page.child("span");
    try Page.set(a, "class", "Foo bar");
    try Page.set(b, "class", "foo BAR\tÉcole");
    for ([_][]const u8{ ".foo", ".FOO", ".Foo", ".bar", ".Bar" }) |selector| {
        try testing.expect(try Page.matches(a, selector));
        try testing.expect(try Page.matches(b, selector));
        try testing.expectEqual(@as(u32, 2), try page.countAll(selector));
    }
    // ASCII only: É is not é.
    try testing.expect(try Page.matches(b, ".École"));
    try testing.expect(try Page.matches(b, ".éCOLE") == false);
    try testing.expect(try Page.matches(b, ".ÉCOLE"));
    try testing.expectEqual(@as(u32, 2), try page.byClassNames("FOO bar"));
    try testing.expectEqual(@as(u32, 0), try page.byClassNames("école"));
    try testing.expectEqual(@as(u32, 1), try page.byClassNames("ÉCOLE"));
    // DOMTokenList's tokens are the value's, case kept, in any mode.
    var tokens = try Tokens.read(a, &page);
    defer tokens.deinit();
    try tokens.expect(&.{ "Foo", "bar" });
    const list = try tokenList(a, "class");
    defer runtime.gc.onObjectFreed(list);
    try testing.expect(!try interfaces.DOMTokenList.call_contains(list, str("foo")));
    try testing.expect(try interfaces.DOMTokenList.call_contains(list, str("Foo")));
    // The mode is read at each check: the same element and selector compare
    // identical-to once the document is no longer in quirks mode.
    try dom.document_internals.setMode(page.document, .no_quirks);
    try testing.expect(!try Page.matches(a, ".foo"));
    try testing.expect(try Page.matches(a, ".Foo"));
    try dom.document_internals.setMode(page.document, .quirks);
    try testing.expect(try Page.matches(a, ".foo"));
}

// ============================================================================
// Sharing and lifetime
// ============================================================================

test "a token list two elements share: one element's class changes, the other's classes stay" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const a = try page.child("span");
    const b = try page.child("span");
    try Page.set(a, "class", "x y");
    try Page.set(b, "class", "x y");
    try testing.expect(try Page.matches(a, ".y"));
    try testing.expect(try Page.matches(b, ".y"));
    try testing.expectEqual(@as(usize, 1), page.table().class_lists);

    try Page.set(a, "class", "x z");
    try testing.expect(try Page.matches(a, ".z"));
    try testing.expect(!try Page.matches(a, ".y"));
    try testing.expect(try Page.matches(b, ".y"));
    try testing.expect(!try Page.matches(b, ".z"));

    // classList changes go through the attribute: b's list follows b only.
    const list = try tokenList(b, "class");
    defer runtime.gc.onObjectFreed(list);
    try testing.expect(try interfaces.DOMTokenList.call_toggle(list, str("w"), no_force));
    var class_b = (try interfaces.Element.call_getAttribute(b, str("class"))).?;
    defer class_b.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("x y w", class_b.asSlice());
    try testing.expect(try Page.matches(b, ".w"));
    try testing.expect(!try Page.matches(a, ".w"));
    try testing.expect(!try interfaces.DOMTokenList.call_toggle(list, str("x"), no_force));
    try testing.expect(!try Page.matches(b, ".x"));
    try testing.expect(try Page.matches(a, ".x"));
}

test "a parked value comes back with its token list: no second split" {
    if (builtin.mode != .debug) return error.SkipZigTest;
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");
    try Page.set(el, "class", "p q r");
    try testing.expect(try Page.matches(el, ".q"));
    const scans = page.scans();
    const lists = page.table().class_lists;
    // The last attribute leaves "p q r": parked, with its list.
    try Page.set(el, "class", "other");
    try testing.expect(page.table().find("p q r") != null);
    try testing.expectEqual(lists, page.table().class_lists);
    // It comes back: the same tokens, no new pass.
    try Page.set(el, "class", "p q r");
    try testing.expect(try Page.matches(el, ".r"));
    try testing.expect(!try Page.matches(el, ".other"));
    try testing.expectEqual(scans, page.scans());
}

test "a freed value lets its tokens go; at the end nothing is left" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");
    // Over the ring's per-record cap: freed at its last release, not parked.
    var long: [300]u8 = undefined;
    for (&long, 0..) |*c, i| c.* = if (i % 3 == 2) ' ' else 'a' + @as(u8, @intCast(i % 26));
    try Page.set(el, "class", &long);
    try testing.expect(try Page.matches(el, ".ab"));
    try testing.expect(page.table().find("ab") != null);
    try testing.expectEqual(@as(usize, 1), page.table().class_lists);
    try Page.set(el, "class", "solo");
    try testing.expect(page.table().find(&long) == null);
    try testing.expectEqual(@as(usize, 0), page.table().class_lists);
    // Its tokens lost their last reference: none is counted now.
    try testing.expectEqual(@as(usize, 1), page.table().liveCount());
}

// ============================================================================
// The compiled selector's operand is a weak id
// ============================================================================

/// Park distinct short values until `bytes`' record is gone from the table
/// (the ring frees its oldest record, one per park, once full).
fn evict(page: *Page, bytes: []const u8) !void {
    var i: usize = 0;
    while (page.table().find(bytes) != null) : (i += 1) {
        if (i > 10_000) return error.NeverEvicted;
        var buffer: [24]u8 = undefined;
        attribute_values.release(&page.scope, try attribute_values.intern(&page.scope, try std.fmt.bufPrint(&buffer, "filler {d}", .{i})));
    }
}

test "a selector's class id whose record was freed and whose id went to another value does not match that value" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const a = try page.child("span");
    try Page.set(a, "class", "y zz");
    // The document's selector cache keeps ".zz" compiled: its operand holds
    // the id of "zz", a token of "y zz".
    try testing.expect(try Page.matches(a, ".zz"));
    const old_id = page.table().find("zz").?;

    // "y zz" loses its element and is evicted from the ring; its list lets
    // "zz" go, which is parked and then evicted too: freed, its slot free.
    try Page.set(a, "class", "q");
    try evict(&page, "y zz");
    try evict(&page, "zz");

    // Values too long to park take that slot and free it at once: 255 of
    // them bring a Debug build's 8-bit slot generation back round, so the
    // next new value gets EXACTLY the id ".zz" kept.
    var big: [300]u8 = undefined;
    @memset(&big, 'x');
    for (0..255) |_| attribute_values.release(&page.scope, try attribute_values.intern(&page.scope, &big));
    const b = try page.child("span");
    try Page.set(b, "class", "other");
    try testing.expectEqual(old_id, page.table().find("other").?);

    // The old compiled ".zz" must not take "other" for "zz".
    try testing.expect(!try Page.matches(b, ".zz"));
    try testing.expect(try Page.matches(b, ".other"));
    try testing.expectEqual(@as(u32, 0), try page.countAll(".zz"));
    try Page.set(b, "class", "zz other");
    try testing.expect(try Page.matches(b, ".zz"));
}

test "values freed elsewhere leave a selector's class id valid" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const a = try page.child("span");
    const other = try page.child("p");
    try Page.set(a, "class", "card featured");
    try testing.expect(try Page.matches(a, ".featured"));
    const frees = page.table().operand_frees;
    var long: [400]u8 = undefined;
    for (0..200) |i| {
        @memset(&long, 'a' + @as(u8, @intCast(i % 26)));
        long[0] = @intCast('0' + i % 10);
        try Page.set(other, "data-x", &long);
        try testing.expect(try Page.matches(a, ".featured"));
        try testing.expect(!try Page.matches(a, ".missing"));
    }
    // Two hundred values freed at once, none a selector's operand: the
    // cells stayed valid.
    try testing.expectEqual(frees, page.table().operand_frees);
}

// ============================================================================
// getElementsByClassName and classList
// ============================================================================

test "getElementsByClassName: every name must be a class; a live list follows class changes" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const a = try page.child("span");
    const b = try page.child("span");
    try Page.set(a, "class", "one two three");
    try Page.set(b, "class", "two");
    try testing.expectEqual(@as(u32, 2), try page.byClassNames("two"));
    try testing.expectEqual(@as(u32, 1), try page.byClassNames(" three\tone "));
    try testing.expectEqual(@as(u32, 0), try page.byClassNames("one four"));
    try testing.expectEqual(@as(u32, 0), try page.byClassNames(" \t"));
    const live = try interfaces.Document.call_getElementsByClassName(page.document, str("two one"));
    defer runtime.gc.onObjectFreed(live);
    try testing.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(live));
    try Page.set(b, "class", "one two");
    try testing.expectEqual(@as(u32, 2), try interfaces.HTMLCollection.get_length(live));
    try Page.set(a, "class", "two");
    try testing.expectEqual(@as(u32, 1), try interfaces.HTMLCollection.get_length(live));
    try testing.expect((try interfaces.HTMLCollection.call_item(live, 0)) == b);
}

test "classList reads the value's tokens; its changes serialize the set and write the attribute" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");
    try Page.set(el, "class", "a  b a");
    const list = try tokenList(el, "class");
    defer runtime.gc.onObjectFreed(list);
    try testing.expectEqual(@as(u32, 2), try interfaces.DOMTokenList.get_length(list));
    try testing.expect(try interfaces.DOMTokenList.call_contains(list, str("b")));
    try testing.expect(!try interfaces.DOMTokenList.call_contains(list, str("a b")));

    // add: the set serialized (duplicates and extra whitespace gone).
    try interfaces.DOMTokenList.call_add(list, &.{ str("c"), str("a") });
    {
        var value = (try interfaces.Element.call_getAttribute(el, str("class"))).?;
        defer value.deinit(page.ctx.allocator);
        try testing.expectEqualStrings("a b c", value.asSlice());
    }
    // replace: the first of the two becomes the new token, the rest go.
    try Page.set(el, "class", "x a y b a");
    try testing.expect(try interfaces.DOMTokenList.call_replace(list, str("a"), str("b")));
    {
        var value = (try interfaces.Element.call_getAttribute(el, str("class"))).?;
        defer value.deinit(page.ctx.allocator);
        try testing.expectEqualStrings("x b y", value.asSlice());
    }
    try testing.expect(!try interfaces.DOMTokenList.call_replace(list, str("q"), str("r")));
    // remove() of the last token leaves an empty attribute; on an element
    // with no class attribute it adds none (the update steps' step 1).
    try interfaces.DOMTokenList.call_remove(list, &.{ str("x"), str("b"), str("y") });
    {
        var value = (try interfaces.Element.call_getAttribute(el, str("class"))).?;
        defer value.deinit(page.ctx.allocator);
        try testing.expectEqualStrings("", value.asSlice());
    }
    try interfaces.Element.call_removeAttribute(el, str("class"));
    try interfaces.DOMTokenList.call_remove(list, &.{str("x")});
    try testing.expect((try interfaces.Element.call_getAttribute(el, str("class"))) == null);
    try testing.expectEqual(@as(u32, 0), try interfaces.DOMTokenList.get_length(list));
    // Validation: empty and whitespace tokens throw before anything changes.
    try testing.expectError(error.SyntaxError, interfaces.DOMTokenList.call_add(list, &.{ str("ok"), str("") }));
    try testing.expectError(error.InvalidCharacterError, interfaces.DOMTokenList.call_toggle(list, str("a b"), no_force));
    try testing.expect((try interfaces.Element.call_getAttribute(el, str("class"))) == null);
}

test "a token list of another attribute (rel) reads its value's tokens the same way" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const link = try page.child("a");
    try Page.set(link, "rel", "noopener  NoReferrer noopener");
    const rel = try tokenList(link, "rel");
    defer runtime.gc.onObjectFreed(rel);
    try testing.expectEqual(@as(u32, 2), try interfaces.DOMTokenList.get_length(rel));
    try testing.expect(try interfaces.DOMTokenList.call_contains(rel, str("NoReferrer")));
    try testing.expect(!try interfaces.DOMTokenList.call_contains(rel, str("noreferrer")));
    // The same value as a class shares one record and one token list.
    try Page.set(link, "class", "noopener  NoReferrer noopener");
    try testing.expect(try Page.matches(link, ".NoReferrer"));
    try testing.expectEqual(@as(usize, 1), page.table().class_lists);
}

test "a token list with no element yet holds its own value; association lets it go" {
    var page: Page = undefined;
    try page.open(testing.allocator, .no_quirks);
    defer page.close();
    const el = try page.child("span");
    try Page.set(el, "class", "from attribute");
    const list = try interfaces.DOMTokenList.init(el.ctx.allocator, el.ctx);
    defer runtime.gc.onObjectFreed(list);
    // Element's getters set a new list's value before associating it.
    try interfaces.DOMTokenList.set_value(list, str("x  y x"));
    try testing.expectEqual(@as(u32, 2), try interfaces.DOMTokenList.get_length(list));
    var value = try interfaces.DOMTokenList.get_value(list);
    try testing.expectEqualStrings("x y", value.asSlice());
    value.deinit(page.ctx.allocator);
    try testing.expect(try interfaces.DOMTokenList.call_toggle(list, str("z"), no_force));
    try testing.expectEqual(@as(u32, 3), try interfaces.DOMTokenList.get_length(list));
    const own = page.table().find("x y z").?;
    try testing.expect(page.table().get(own).references > 0);
    // Associated: the set is the attribute's, and the own value is let go.
    try dom.token_lists.associate(list, el, "class");
    try testing.expectEqual(@as(u32, 2), try interfaces.DOMTokenList.get_length(list));
    try testing.expect(try interfaces.DOMTokenList.call_contains(list, str("attribute")));
    try testing.expectEqual(@as(u32, 0), page.table().get(own).references);
}
