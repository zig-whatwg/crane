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
    // Parsed elements with equal attributes share a list, which counts its
    // holders in one byte: the document's cache and up to 254 elements a
    // block, then a new block (dom.element_data SharingCache.share). So
    // 1,000 elements are four blocks of 16 - not one, as this test first
    // expected (its first green run: "expected 16 B in the figure, found 64").
    const per_block: usize = dom.element_data.AttributeList.max_holders - 1;
    const shared_blocks: usize = (count + per_block - 1) / per_block;
    try testing.expectEqual(@as(usize, 4), shared_blocks);
    const parsed_plain = try added(page, "globalThis.q = document.createElement('section'); q.innerHTML = '<p></p>'.repeat(1000); 0;");
    const parsed = try added(page, "globalThis.r = document.createElement('section'); r.innerHTML = '<p hidden></p>'.repeat(1000); 0;");
    try expectBytes("1,000 parsed elements sharing their attribute lists", shared_blocks * 16, parsed - parsed_plain);
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
    // The document's cache of shared lists keeps the block it last made for
    // the parsed elements - one; the three before it went with their last
    // elements - for 10 s after its last parse (dom.attribute_block_cache).
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

    // The elements alone, to take out of what follows: without it the
    // elements' own slots and State blocks satisfy any lower bound, and the
    // test passed on a tree that counted no value at all (lane vm1's first
    // red run: 3 of the file's 5 tests failed, this one did not).
    const plain = try added(page, "globalThis.p = []; for (let i = 0; i < 1000; i++) p.push(document.createElement('div')); 0;");
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
    // Over the elements themselves: at least each title's record (8 + 14
    // bytes: a block of 32) and each class value's. Without the values in
    // the figure the difference is 16 B an element - the rare block its
    // class read makes, counted before (this test's red run: 160,000 B
    // against the plain elements' 144,000) - so 64 an element cannot be met
    // by what was counted already.
    if (made < plain + count * (32 + 32)) {
        std.debug.print("1,000 elements with a title and a class value add {d} B to the figure, 1,000 plain ones {d} B: expected at least {d} B more in the figure\n", .{ made, plain, count * (32 + 32) });
        return error.FigureDiffers;
    }

    try page.run("a = p = null; 0;");
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

fn sharedAcrossDocumentsReturns() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..4) |_| try page.collect();
    const before = live(page);
    const dying_before = page.browser.scope.dom_memory.dying;

    // Every value here is over 256 bytes - each class token too - so no
    // record waits in the table's ring when its last attribute goes
    // (dom.attribute_values Parking.max_record_bytes): the figure must come
    // back to exactly where it began.
    try page.run(
        \\globalThis.long = (c) => c.repeat(300);
        \\globalThis.d1 = document.implementation.createHTMLDocument('one');
        \\globalThis.d2 = document.implementation.createHTMLDocument('two');
        \\// Parsed in d1: 200 elements sharing one attribute list and its
        \\// three value records, each with a text block of its own.
        \\d1.body.innerHTML = ('<p class="' + long('k') + ' ' + long('m') + '" title="' + long('t') + '" data-n="' + long('n') + '">' + long('x') + '</p>').repeat(200);
        \\if (!d1.body.firstChild.classList.contains(long('m'))) throw new Error('no class');
        \\// Imported into d2: clones share their sources' lists and records.
        \\for (const p of d1.body.children) d2.body.appendChild(d2.importNode(p, true));
        \\// Cloned inside d2, comments beside them.
        \\for (const p of [...d2.body.children]) { d2.body.appendChild(p.cloneNode(true)); d2.body.appendChild(d2.createComment(long('c'))); }
        \\// Adopted into the page's document: the blocks move with their nodes.
        \\globalThis.host = document.createElement('div');
        \\for (const p of [...d1.body.children].slice(0, 100)) host.appendChild(document.adoptNode(p));
        \\document.body.appendChild(host);
        \\0;
    );
    if (live(page) <= before) return error.NothingCounted;
    try page.run(
        \\// Writers: each makes a shared list its element's own, and gives
        \\// values back or takes new ones.
        \\let i = 0;
        \\for (const p of host.children) {
        \\  if (i % 4 === 0) p.setAttribute('title', long('u') + i);
        \\  if (i % 4 === 1) p.removeAttribute('data-n');
        \\  if (i % 4 === 2) p.className = long('k') + ' ' + long('z') + i;
        \\  if (i % 4 === 3) { p.firstChild.splitText(150); p.firstChild.appendData(long('y')); p.normalize(); }
        \\  i++;
        \\}
        \\for (const p of [...d2.body.children].slice(0, 100)) { while (p.attributes && p.attributes.length) p.removeAttribute(p.attributes[0].name); }
        \\for (const p of [...d2.body.childNodes].slice(100, 200)) p.textContent = '';
        \\// Half of d1's rest goes at once, the other half with its document.
        \\for (const p of [...d1.body.children].slice(0, 50)) p.remove();
        \\0;
    );
    // Everything dropped, in three steps with collections between: the
    // page's subtree, then one document, then the other.
    try page.run("host.remove(); host = null; 0;");
    for (0..3) |_| try page.collect();
    try page.run("d1 = null; 0;");
    for (0..3) |_| try page.collect();
    try page.run("d2 = null; long = null; 0;");
    for (0..6) |_| try page.collect();
    try expectBytes("after two documents and an adopted subtree that shared text and attribute blocks went", before, live(page));
    try testing.expectEqual(dying_before, page.browser.scope.dom_memory.dying);
    // No record is left that an attribute holds.
    if (dom.attribute_values.tableOf(page.browser.scope)) |table| {
        try testing.expectEqual(@as(usize, 0), table.liveCount());
    }
}

test "text and attribute blocks made in one document, shared by clones in a second and adopted into a third leave the figure where it began" {
    try h.onFreshThread(sharedAcrossDocumentsReturns);
}
