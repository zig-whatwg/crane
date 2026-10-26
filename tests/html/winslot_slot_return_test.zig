//! A Window's slab slot goes back once its realm has ended (lane winslot1,
//! the switch): every holder kind reads a Window through a generation check,
//! is cleared at the Window's teardown, or keeps its WindowProxy
//! (runtime.window_holders.reusable), so the realm's end gives the slot
//! back (protocol_realms.endRealm step 5). Every page load kept its Window's
//! slot until the Browser ended before: lane pageretention1 measured one
//! Window per file of a navigation-heavy WPT list left behind.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const helpers = @import("winslot_helpers.zig");

fn liveWindows(page: helpers.Page) !usize {
    var list: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer list.deinit(testing.allocator);
    try helpers.windows(page.browser, &list);
    return list.items.len;
}

fn navigationChurn() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.pending = 1;
        \\globalThis.f = document.body.appendChild(document.createElement('iframe'));
        \\let loads = 0;
        \\f.onload = () => { if (++loads < 12) f.srcdoc = '<body>' + loads + '</body>'; else pending = 0; };
        \\f.srcdoc = '<body>0</body>';
    );
    try page.settle();
    try page.collect();
    // The page's Window and the frame's current one; none of the eleven its
    // navigations replaced.
    const live = try liveWindows(page);
    if (live != 2) std.debug.print("live Windows after 12 frame navigations: {d}\n", .{live});
    try testing.expectEqual(@as(usize, 2), live);
    try page.expectEval("f.contentDocument.body.textContent + ':' + (frames[0] === f.contentWindow)", "11:true");
}

test "a frame navigated twelve times leaves only its current Window's slot issued" {
    try helpers.onFreshThread(navigationChurn);
}

fn pageChurn() !void {
    const page = try helpers.Page.open();
    defer page.close();
    var steady: ?usize = null;
    for (0..8) |i| {
        try page.browser.navigate("about:blank", .window);
        const context = page.browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        try page.run("globalThis.pending = 1; const f = document.body.appendChild(document.createElement('iframe')); f.onload = () => { pending = 0; }; f.srcdoc = '<p>x</p>';");
        try page.settle();
        try page.collect();
        // This page's Windows, and nothing of the pages before: the count is
        // the first page's at every page.
        const live = try liveWindows(page);
        if (steady == null) steady = live;
        if (live != steady.?) std.debug.print("page {d}: {d} live Windows, the first page left {d}\n", .{ i + 1, live, steady.? });
        try testing.expectEqual(steady.?, live);
    }
}

test "pages loaded one after another give their Windows' slots back" {
    try helpers.onFreshThread(pageChurn);
}

fn automaticRelease() !void {
    const page = try helpers.Page.open();
    defer page.close();
    var before: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer before.deinit(testing.allocator);
    try helpers.windows(page.browser, &before);
    try page.run(
        \\globalThis.pending = 1;
        \\globalThis.f = document.body.appendChild(document.createElement('iframe'));
        \\f.addEventListener('load', () => { pending = 0; }, { once: true });
        \\f.srcdoc = '<body>one</body>';
    );
    try page.settle();
    const old = try helpers.newWindow(page.browser, before.items);
    try page.run(
        \\globalThis.holders = { view: new MouseEvent('x', { view: f.contentWindow }), source: new MessageEvent('m', { source: f.contentWindow }) };
        \\globalThis.saved = f.contentWindow;
        \\globalThis.pending = 1;
        \\f.addEventListener('load', () => { pending = 0; }, { once: true });
        \\f.srcdoc = '<body>two</body>';
    );
    try page.settle();
    try page.collect();
    // The realm's end gave the old Window's slot back by itself: nothing
    // kept the old realm - the holders keep the proxy, the new realm's.
    try testing.expect(runtime.SlabAllocator.generationOf(old.window) != old.generation);
    try helpers.reissue(page, old);
    try page.expectEval("[holders.view.view === saved, holders.source.source === saved, saved.document.body.textContent].join(',')", "true,true,two");
}

test "a navigated frame's old Window's slot goes back by itself and its proxy holders read the proxy" {
    try helpers.onFreshThread(automaticRelease);
}

fn liveSlots(page: helpers.Page) usize {
    var live: usize = 0;
    var slab = page.browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) != runtime.SlabAllocator.dead_generation) live += 1;
        }
    }
    return live;
}

fn hundredNavigations() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.f = document.body.appendChild(document.createElement('iframe'));
        \\globalThis.navigateTo = (n) => new Promise(resolve => { f.addEventListener('load', resolve, { once: true }); f.srcdoc = '<body>' + n + '</body>'; });
        \\globalThis.pending = 1; navigateTo(0).then(() => { pending = 0; });
    );
    try page.settle();
    var first_slots: ?usize = null;
    var n: usize = 0;
    while (n < 100) {
        try page.run(
            \\globalThis.pending = 1;
            \\(async () => { for (let i = 0; i < 20; i++) await navigateTo(i + 1); pending = 0; })();
        );
        try page.settle();
        n += 20;
        try page.collect();
        const windows = try liveWindows(page);
        const slots = liveSlots(page);
        if (first_slots == null) first_slots = slots;
        std.debug.print("after {d} navigations: {d} live Windows, {d} live slots\n", .{ n, windows, slots });
        // The page's Window and the frame's current one, at every checkpoint;
        // and the slab no fuller than after the first twenty (a few slots of
        // slack for whatever a checkpoint's own script leaves).
        try testing.expectEqual(@as(usize, 2), windows);
        try testing.expect(slots <= first_slots.? + 16);
    }
}

test "a hundred navigations of one frame keep the Window count and the slab flat" {
    try helpers.onFreshThread(hundredNavigations);
}
