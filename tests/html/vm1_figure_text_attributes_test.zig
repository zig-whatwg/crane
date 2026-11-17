//! Lane vm1: the figure a Browser tells its window agent's engine about its
//! DOM (runtime.BrowserScope.dom_memory) counts a node's TEXT and its
//! ATTRIBUTE VALUES.
//!
//! It counted a node's slab slot, its State block and its rare data, and
//! nothing that hangs off them: a Text node of 4 KB was 200-odd bytes to V8,
//! and so was an element with a 4 KB attribute. V8 schedules its collections
//! by the figure, so a page of text-heavy garbage was collected later than
//! its real bytes justified (lane nm2: the node figure fell 9.2% where the
//! real bytes fell 6.3%, and parser.dom-parser's steady memory rose 7.7%).
//! Blink's strings are counted by V8 through its C++ heap's and
//! PartitionAlloc's reports; here the two stores say it themselves:
//!
//! - a CharacterData node's data in a block of its own
//!   (dom.character_data.Data: over 8 bytes and not shared whitespace), where
//!   the block is made and freed, and in the walk that weighs a dying tree
//!   (dom.tree_teardown.measureUpTo), so a dead tree's text leaves the figure
//!   with its nodes;
//! - an attribute value's record (dom.attribute_values: one per distinct
//!   value in the Browser, counted references), where the record is made and
//!   freed - shared, so no tree's walk sums it;
//! - an element's attribute list (dom.element_data.AttributeList: one block,
//!   shared by parsed elements with equal attributes), likewise.
//!
//! Every block is counted at malloc's granule: its bytes to the next
//! multiple of 16 (runtime.gc.ExternalMemory.blockBytes), a floor on macOS
//! and glibc alike. What enters leaves: each test ends where it began.
const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const testing = h.testing;
const dom = h.dom;
const runtime = h.runtime;

const count = 1000;

fn live(page: h.Page) usize {
    return page.browser.scope.dom_memory.live;
}

/// What `source` adds to the figure.
fn added(page: h.Page, source: []const u8) !usize {
    const before = live(page);
    try page.run(source);
    return live(page) - before;
}

fn expectBytes(what: []const u8, expected: usize, found: usize) !void {
    if (expected == found) return;
    std.debug.print("{s}: expected {d} B in the figure, found {d} B\n", .{ what, expected, found });
    return error.FigureDiffers;
}

fn textIsCounted() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..4) |_| try page.collect();
    const before = live(page);

    // Eight bytes are in the node itself; whitespace is a slice of one
    // static blob: neither has a block.
    const in_word = try added(page, "globalThis.a = []; for (let i = 0; i < 1000; i++) a.push(document.createTextNode('abcdefgh')); 0;");
    const whitespace = try added(page, "globalThis.w = []; for (let i = 0; i < 1000; i++) w.push(document.createTextNode('\\n' + ' '.repeat(20))); 0;");
    try expectBytes("1,000 whitespace texts against 1,000 of 8 bytes", in_word, whitespace);

    // 100 bytes: a block of 112.
    const long = try added(page, "globalThis.b = []; for (let i = 0; i < 1000; i++) b.push(document.createTextNode('x'.repeat(100))); 0;");
    try expectBytes("1,000 texts of 100 bytes over 1,000 of 8", count * 112, long - in_word);

    // A comment's data is the same store.
    const comments = try added(page, "globalThis.c = []; for (let i = 0; i < 1000; i++) c.push(document.createComment('x'.repeat(100))); 0;");
    const short_comments = try added(page, "globalThis.d = []; for (let i = 0; i < 1000; i++) d.push(document.createComment('abcdefgh')); 0;");
    try expectBytes("1,000 comments of 100 bytes over 1,000 of 8", count * 112, comments - short_comments);

    // Every change of the data moves the figure by the blocks' difference:
    // 300 bytes are a block of 304, 320 one of 320, 5 none.
    const at_long = live(page);
    try page.run("for (const t of b) t.data = 'y'.repeat(300); 0;");
    try expectBytes("the texts set to 300 bytes", at_long + count * (304 - 112), live(page));
    try page.run("for (const t of b) t.appendData('z'.repeat(20)); 0;");
    try expectBytes("20 bytes appended", at_long + count * (320 - 112), live(page));
    try page.run("for (const t of b) t.deleteData(0, 315); 0;");
    try expectBytes("the texts cut to 5 bytes", at_long - count * 112, live(page));
    try page.run("for (const t of b) t.data = 'x'.repeat(100); 0;");
    try expectBytes("the texts set to 100 bytes again", at_long, live(page));

    // What entered leaves.
    try page.run("a = b = c = d = w = null; 0;");
    for (0..4) |_| try page.collect();
    try expectBytes("after the texts' teardown", before, live(page));
    try testing.expectEqual(@as(usize, 0), page.browser.scope.dom_memory.dying);
}

test "a text node's data in a block of its own is in the figure, moves with each change and leaves with the node" {
    try h.onFreshThread(textIsCounted);
}

fn aDyingTreesTextIsSummed() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..4) |_| try page.collect();
    const before = live(page);

    try page.run("globalThis.short = document.createElement('section'); short.innerHTML = '<p>abcdefgh</p>'.repeat(700); 0;");
    try page.run("globalThis.long = document.createElement('section'); long.innerHTML = ('<p>' + 'x'.repeat(100) + '</p>').repeat(700); 0;");
    const cap = runtime.gc.DeferredTeardown.high_water;
    const short = dom.tree_teardown.measureUpTo(try page.node("short"), cap);
    const long = dom.tree_teardown.measureUpTo(try page.node("long"), cap);
    try testing.expectEqual(@as(usize, 1 + 700 * 2), short.nodes);
    try testing.expectEqual(short.nodes, long.nodes);
    // The walk that weighs a dying tree sums its texts' blocks: they leave
    // the figure where the tree is decided dead, not slice by slice.
    try expectBytes("a tree of 700 texts of 100 bytes over one of 700 of 8, as its queueing weighs it", 700 * 112, long.bytes - short.bytes);

    try page.run("short = long = null; 0;");
    for (0..4) |_| try page.collect();
    try expectBytes("after the trees' teardown", before, live(page));
    try testing.expectEqual(@as(usize, 0), page.browser.scope.dom_memory.dying);
}

test "the walk that weighs a dying tree sums its texts' blocks, and the tree's teardown returns the figure to where it was" {
    try h.onFreshThread(aDyingTreesTextIsSummed);
}

fn attributeValuesAreCounted() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..4) |_| try page.collect();
    const before = live(page);

    // An element's attribute list is a block of its own: its 8-byte header
    // and 8 bytes an attribute, 16 for one. The empty value has no record.
    const plain = try added(page, "globalThis.p = []; for (let i = 0; i < 1000; i++) p.push(document.createElement('div')); 0;");
    const empty = try added(page, "globalThis.a = []; for (let i = 0; i < 1000; i++) { const e = document.createElement('div'); e.setAttribute('data-v', ''); a.push(e); } 0;");
    try expectBytes("1,000 lists of one attribute with the empty value", count * 16, empty - plain);
    // Parsed elements with equal attributes share one list (the document's
    // cache holds it too): one block for 1,000 elements.
    const parsed_plain = try added(page, "globalThis.q = document.createElement('section'); q.innerHTML = '<p></p>'.repeat(1000); 0;");
    const parsed = try added(page, "globalThis.r = document.createElement('section'); r.innerHTML = '<p hidden></p>'.repeat(1000); 0;");
    try expectBytes("1,000 parsed elements sharing one attribute list", 16, parsed - parsed_plain);
    // 1,000 distinct values of 304 bytes: a record each, its 8-byte header
    // and its bytes in one block of 320.
    const distinct = try added(page, "globalThis.b = []; for (let i = 0; i < 1000; i++) { const e = document.createElement('div'); e.setAttribute('data-v', 'v'.repeat(300) + String(i).padStart(4, '0')); b.push(e); } 0;");
    try expectBytes("1,000 distinct attribute values of 304 bytes", count * 320, distinct - empty);
    // One value on 1,000 elements: one record.
    const shared = try added(page, "globalThis.c = []; for (let i = 0; i < 1000; i++) { const e = document.createElement('div'); e.setAttribute('data-v', 's'.repeat(304)); c.push(e); } 0;");
    try expectBytes("one attribute value of 304 bytes on 1,000 elements", 320, shared - empty);

    // A changed value: the old record goes with its last attribute (one over
    // 256 bytes never waits in the table's ring), the new one is counted.
    const at_distinct = live(page);
    try page.run("for (const e of b) e.setAttribute('data-v', e.getAttribute('data-v') + 'w'.repeat(16)); 0;");
    try expectBytes("each distinct value 16 bytes longer", at_distinct + count * 16, live(page));
    try page.run("for (const e of b) e.removeAttribute('data-v'); 0;");
    // Each element's list goes with its last attribute.
    try expectBytes("the distinct values' attributes removed", at_distinct - count * (320 + 16), live(page));

    try page.run("a = b = c = p = q = r = null; 0;");
    for (0..4) |_| try page.collect();
    // The document's cache of shared lists keeps the parsed elements' one
    // block for 10 s after its last parse (dom.attribute_block_cache).
    try expectBytes("after the elements' teardown", before + 16, live(page));
}

test "an attribute value's record is in the figure once, however many attributes share it, and leaves with its last attribute" {
    try h.onFreshThread(attributeValuesAreCounted);
}

fn shortValuesWaitBounded() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..4) |_| try page.collect();
    const before = live(page);

    // Short values, and the class names a class read splits a value into.
    const made = try added(page,
        \\globalThis.a = [];
        \\for (let i = 0; i < 1000; i++) {
        \\  const e = document.createElement('div');
        \\  e.setAttribute('title', 'title number ' + i);
        \\  e.className = 'row row-' + i + ' other';
        \\  if (!e.classList.contains('other')) throw new Error('no class');
        \\  a.push(e);
        \\}
        \\0;
    );
    // At least each title's record (8 + 14 bytes: a block of 32) and each
    // class value's.
    try testing.expect(made >= count * (32 + 32));

    try page.run("a = null; 0;");
    for (0..4) |_| try page.collect();
    // A record with no attribute left waits in its table's ring for the
    // next attribute with its value - at most 16 KB of them
    // (dom.attribute_values Parking.max_bytes) - and is counted while it is
    // allocated.
    // The ring bounds the blocks' own bytes; the figure counts each to the
    // next 16: up to 256 records and their class names.
    const bound = 16 * 1024 + 256 * 2 * 16;
    const left = live(page) - before;
    if (left > bound) {
        std.debug.print("{d} B of attribute values are still in the figure after their elements' teardown (at most {d} wait)\n", .{ left, bound });
        return error.ValuesKept;
    }
}

test "short attribute values and their class names are counted, and at most the table's waiting ring stays after their elements" {
    try h.onFreshThread(shortValuesWaitBounded);
}
