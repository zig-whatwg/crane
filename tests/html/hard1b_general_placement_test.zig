//! Allocator hardening, batch B, red test B1 (the B1 merge's part): a
//! Browser's general memory - what `std.mem.Allocator` traffic its realms,
//! its tables and its states make - lives in its own heap, split by what the
//! block holds (tmp/plans/allocator-hardening-design.md, 3.1 and section 7
//! batch B items 1-2):
//!
//! - bytes the page chooses (converted strings, attribute values, text) in
//!   the BYTES range: a block whose alignment is below a pointer's cannot
//!   hold a pointer;
//! - pointer-bearing blocks (tables, records with pointers) in the OBJECTS
//!   range;
//!
//! so a freed list of pointers is never reclaimed by a string of the page's
//! choosing (design 2.2, "type confusion through reuse").
//!
//! Every assertion here FAILS today: each block is in the host allocator's
//! memory (std.testing.allocator here, libc malloc in production), outside
//! the Browser's reservation. The cage part of B1 (satellites: a rare block,
//! a node's listener list, an attribute entry block) is the B2 merge's.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");

const Heap = runtime.BrowserScope.Heap;

/// Where an address lies in a Browser's reservation (H1's layout).
const Range = enum { outside, cage, objects, bytes, metadata };

fn rangeOf(heap: *const Heap.BrowserHeap, ptr: *const anyopaque) Range {
    const address = @intFromPtr(ptr);
    if (address < heap.reserved.base or address - heap.reserved.base >= heap.reserved.size) return .outside;
    const offset: u64 = address - heap.window_base;
    const l = Heap.layout;
    if (offset >= l.cage.offset and offset < l.cage.end()) return .cage;
    if (offset >= l.objects.offset and offset < l.objects.end()) return .objects;
    if (offset >= l.bytes.offset and offset < l.bytes.end()) return .bytes;
    return .metadata;
}

/// The Browser's heap, or a skip where its rung has no general pools (a
/// sanitizer's address map, RLIMIT_AS: general memory stays on the host's
/// allocator there, by design 4.2).
fn heapOf(page: helpers.Page) !*Heap.BrowserHeap {
    const heap = page.browser.scope.heap orelse return error.NoHeap;
    if (!heap.general_pools) return error.SkipZigTest;
    return heap;
}

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn allocatorRouting() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    const allocator = runtime.allocatorOf(try documentOf(page));

    // Page bytes: alignment 1 and 2.
    const text = try allocator.alloc(u8, 200);
    defer allocator.free(text);
    try testing.expectEqual(Range.bytes, rangeOf(heap, text.ptr));
    const units = try allocator.alloc(u16, 100);
    defer allocator.free(units);
    try testing.expectEqual(Range.bytes, rangeOf(heap, units.ptr));

    // Pointer-bearing: a record with a pointer field, and a table of words.
    const Record = struct { next: ?*anyopaque, count: usize };
    const record = try allocator.create(Record);
    defer allocator.destroy(record);
    try testing.expectEqual(Range.objects, rangeOf(heap, record));
    const words = try allocator.alloc(usize, 40);
    defer allocator.free(words);
    try testing.expectEqual(Range.objects, rangeOf(heap, words.ptr));
}

test "B1: the Browser's general allocator puts page bytes in the bytes range and pointer-bearing blocks in the objects range" {
    try helpers.onFreshThread(allocatorRouting);
}

fn realmAllocator() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    const context = page.browser.current_context orelse return error.NoPage;
    const realm = context.realm orelse return error.NoRealm;
    // The realm's allocator is what a binding converts a script string with
    // when it passes the stack buffer (conversions: one block per string
    // argument over 128 B, freed after the call - the general pools'
    // hottest path, census 1.4 item 1).
    const converted = try realm.allocator.alloc(u8, 300);
    defer realm.allocator.free(converted);
    try testing.expectEqual(Range.bytes, rangeOf(heap, converted.ptr));
}

test "B1: the realm's allocator, which converts script strings, is the same heap's: a string's bytes are in the bytes range" {
    try helpers.onFreshThread(realmAllocator);
}

fn domFamilies() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const heap = try heapOf(page);
    try page.run(
        \\const holder = document.createElement('div');
        \\holder.id = 'b1';
        \\holder.setAttribute('data-b1', 'v'.repeat(300));
        \\document.body.appendChild(holder);
        \\document.body.appendChild(document.createTextNode('t'.repeat(300)));
    );
    const document = try documentOf(page);
    const holder = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("b1"))) orelse return error.NoHolder;
    const text = (try interfaces.Node.get_nextSibling(holder)) orelse return error.NoText;

    // An attribute value record: a count, a length, then the page's bytes
    // (Blink's StringImpl shape, in PartitionAlloc's Buffer partition).
    const table = dom.attribute_values.tableOf(page.browser.scope) orelse return error.NoValueTable;
    const value: [300]u8 = @splat('v');
    const id = table.find(&value) orelse return error.NoValueRecord;
    try testing.expectEqual(Range.bytes, rangeOf(heap, table.bytesOf(id).ptr));

    // A Text node's text past its 8 inline bytes: the page's bytes.
    const data = dom.character_data.dataOf(text) orelse return error.NoTextData;
    try testing.expectEqual(@as(usize, 300), data.len);
    try testing.expectEqual(Range.bytes, rangeOf(heap, data.ptr));

    // The value table's id slots: words that hold record addresses - a
    // pointer-bearing table, in the objects range.
    try testing.expect(table.ids.slots.items.len != 0);
    try testing.expectEqual(Range.objects, rangeOf(heap, table.ids.slots.items.ptr));
}

test "B1: an attribute value record and a Text node's heap text are in the bytes range, the value table's id slots in the objects range" {
    try helpers.onFreshThread(domFamilies);
}
