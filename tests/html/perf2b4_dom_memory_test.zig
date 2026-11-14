//! Lane perf2 batch 4: what a Browser tells its engine its DOM holds
//! (runtime.BrowserScope.dom_memory, runtime.gc.ExternalMemory), which V8
//! schedules DOM-driven collections by - the engine protocol's
//! AgentOptions.external_memory, passed to
//! Isolate::AdjustAmountOfExternalAllocatedMemory by the V8 adapter
//! (src/runtime/engines/v8/external_memory.zig).
//!
//! It counted a node's slab slot, its State block and its NodeBase (368 B
//! for a div once R6 part 1 took the NodeBase to 208 B), while the node held
//! about 2,450 B (tmp/plans/perf2b4-design.md 1.5): every level's
//! InternalState block was missing, so the smaller NodeBase made V8 collect
//! less often and the perf window's garbage-heavy rows kept more memory
//! (MEMORY 1.032; load.docs 1.990). Now each InternalState block is counted
//! at its arena class when it is made and uncounted when it goes back, and so
//! are the NodeBase's rare data and registered observer entries.
//!
//! - A div is reported as more than its slot, State block and NodeBase.
//! - Nodes with rare data (a script element's node name, an observed node's
//!   registration) and plain ones: once torn down, the reported total is
//!   exactly what it was before they were made.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

fn reported(page: h.Page) usize {
    return page.browser.scope.dom_memory.live;
}

/// Live slab slots of `browser` whose interface is `name`.
fn liveOf(browser: *browser_mod.Browser, name: []const u8) usize {
    var count: usize = 0;
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            if (std.mem.eql(u8, instance.vtable.name, name)) count += 1;
        }
    }
    return count;
}

fn divReportedWhole() !void {
    const page = try h.Page.open();
    defer page.close();
    const before = reported(page);
    try page.run("globalThis.d = document.createElement('div'); 0;");
    const delta = reported(page) - before;
    // Its slot and its State block - which since lane perf2 batch 5 (Z7)
    // holds every level's InternalState and the NodeBase by value: all of it,
    // and nothing for a div beyond it.
    const State = interfaces.HTMLDivElement.State;
    const whole = runtime.SlabAllocator.slot_bytes + runtime.ArenaAllocator.heldBytes(@sizeOf(State), @alignOf(State));
    if (@sizeOf(State) <= @sizeOf(dom.NodeBase) or delta != whole) {
        std.debug.print("a div is reported as {d} B; its slot + whole State block ({d} B) are {d} B\n", .{ delta, @sizeOf(State), whole });
        return error.InternalStatesNotCounted;
    }
}

test "a div is reported to the engine as its slot and its whole State block: its InternalStates and NodeBase inside it" {
    try onFreshThread(divReportedWhole);
}

fn teardownReturnsToZero() !void {
    const page = try h.Page.open();
    defer page.close();
    // A quiet page first, so nothing else is made or freed while we count.
    for (0..4) |_| try page.collect();
    const before = reported(page);
    try page.run(
        \\(() => {
        \\  const plain = document.createElement('div');
        \\  plain.appendChild(document.createTextNode('x'));
        \\  // A node name: rare data.
        \\  const script = document.createElement('script');
        \\  // A registered observer: rare data and one entry.
        \\  const observed = document.createElement('section');
        \\  globalThis.mo = new MutationObserver(() => {});
        \\  mo.observe(observed, { attributes: true });
        \\})();
        \\0;
    );
    if (reported(page) <= before) return error.NothingReported;
    for (0..4) |_| try page.collect();
    try testing.expectEqual(@as(usize, 0), liveOf(page.browser, "HTMLDivElement"));
    try testing.expectEqual(@as(usize, 0), liveOf(page.browser, "HTMLScriptElement"));
    try testing.expectEqual(@as(usize, 0), liveOf(page.browser, "Text"));
    // The section is an HTMLElement; the page's own body is one too.
    const after = reported(page);
    if (after != before) {
        std.debug.print("reported {d} B before, {d} B after the nodes' teardown\n", .{ before, after });
        return error.ReportedTotalDidNotReturn;
    }
}

test "nodes with and without rare data return the reported total to where it was once torn down" {
    try onFreshThread(teardownReturnsToZero);
}
