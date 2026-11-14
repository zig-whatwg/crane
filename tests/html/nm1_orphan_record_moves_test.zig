//! A realm's orphan record (runtime.orphan_roots) stays in proportion to the
//! realm's ORPHANS, not to its moves (lane nm1, 2026-11-14; the user's
//! question why a parsed span costs 489 B on the performance page).
//!
//! dom.mutation records every node it removes while no wrapper reaches it, so
//! that the realm's end can free a removed tree nothing else frees. "Insert"
//! of a DocumentFragment removes the fragment's children only to link each of
//! them into the parent a step later (DOM insert step 4.1, then 7.3): those
//! are moves. `host.innerHTML = <100,000 spans>` recorded all 100,000 - one
//! 2.2 MB block, 22 B per span, stale the moment the spans were linked and
//! kept to the realm's end, because the list compacts only when it is full
//! and never gave capacity back (MEASURED: malloc_history in the release
//! console, the block under mutation.removeHeld <- insert <- replaceAll).
//!
//! - A fragment's children moved by an insert are not recorded.
//! - A node that IS removed and left out of any tree is recorded as before:
//!   the lifetime side is unchanged, and the Browser's end on
//!   std.testing.allocator finds nothing left.
//! - The list gives capacity back when a compaction leaves it mostly empty.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

fn listOf(page: h.Page) !*runtime.orphan_roots.List {
    const context = page.browser.current_context orelse return error.NoPage;
    const realm = context.realm orelse return error.NoRealm;
    return &realm.orphan_roots;
}

fn fragmentMoveRecordsNothing() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.body.appendChild(document.createElement('div')); 0;");
    const list = try listOf(page);
    const before = list.count();
    // The HTML fragment parser's nodes are moved out of its fragment into the
    // host: 5,000 removals that are not removals.
    try page.run("host.innerHTML = '<span></span>'.repeat(5000); if (host.childNodes.length !== 5000) throw new Error('not parsed'); 0;");
    const recorded = list.count() - before;
    if (recorded != 0 or list.records.capacity >= 1024) {
        std.debug.print("after an innerHTML of 5,000 spans the realm's orphan list holds {d} more records, capacity {d} ({d} B)\n", .{ recorded, list.records.capacity, list.records.capacity * @sizeOf(runtime.orphan_roots.Record) });
        return error.MovesRecordedAsOrphans;
    }
    // The same through the other fragment paths script has.
    try page.run(
        \\(() => {
        \\  const t = document.createElement('template');
        \\  t.innerHTML = '<i></i>'.repeat(2000);
        \\  host.append(t.content);
        \\  host.insertAdjacentHTML('beforeend', '<b></b>'.repeat(2000));
        \\  const r = document.createRange();
        \\  host.appendChild(r.createContextualFragment('<u></u>'.repeat(2000)));
        \\  if (host.childNodes.length !== 11000) throw new Error('not moved: ' + host.childNodes.length);
        \\})(); 0;
    );
    const after_all = list.count() - before;
    if (after_all != 0) {
        std.debug.print("after three more fragment insertions the realm's orphan list holds {d} more records\n", .{after_all});
        return error.MovesRecordedAsOrphans;
    }
}

test "an insert that moves a fragment's children records none of them as a possible orphan" {
    try onFreshThread(fragmentMoveRecordsNothing);
}

fn realRemovalsAreStillRecorded() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.body.appendChild(document.createElement('div')); host.innerHTML = '<span></span>'.repeat(300); 0;");
    const list = try listOf(page);
    const before = list.count();
    // No script ever read the spans: each is removed unwrapped, and stays out
    // of any tree - an orphan, recorded so that the realm's end can free it.
    try page.run("host.replaceChildren(); 0;");
    try testing.expectEqual(@as(usize, 300), list.count() - before);
    // A removed subtree is one record: its root's.
    try page.run("host.innerHTML = '<p><b></b><i></i></p>'; host.replaceChildren(); 0;");
    try testing.expectEqual(@as(usize, 301), list.count() - before);
    // The Browser's end (std.testing.allocator, and refcount_teardown's
    // live-node check) finds none of them left.
}

test "a node removed and left out of every tree is recorded, as before" {
    try onFreshThread(realRemovalsAreStillRecorded);
}

fn capacityComesBack() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.body.appendChild(document.createElement('div')); host.innerHTML = '<span></span>'.repeat(4000); 0;");
    const list = try listOf(page);
    // 4,000 real orphans at once: the list grows to hold them.
    try page.run("host.replaceChildren(); 0;");
    const peak = list.records.capacity;
    try testing.expect(peak >= 4000);
    // They are freed (the counts' queue, then collections), and the page goes
    // on removing a few nodes at a time: the list fills, compacts to the few
    // that are still orphans, and must not keep 4,000 records' room for them.
    for (0..60) |_| {
        try page.collect();
        try page.run("host.innerHTML = '<span></span>'.repeat(100); host.replaceChildren(); 0;");
    }
    if (list.records.capacity * 2 > peak) {
        std.debug.print("the realm's orphan list held room for {d} records at its peak and still holds room for {d} ({d} records in it)\n", .{ peak, list.records.capacity, list.count() });
        return error.CapacityNeverReturned;
    }
}

test "the orphan list gives capacity back once a compaction leaves it mostly empty" {
    try onFreshThread(capacityComesBack);
}
