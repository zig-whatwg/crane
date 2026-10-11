//! `window[i]` takes no lasting reference on the document, and leaves no
//! Global behind, whichever way it finds the frame. The adapter's indexed
//! lookup (context_manager.zig) has a lazy branch for an iframe whose
//! browsing context does not exist yet: it reads
//! document.getElementsByTagName('iframe') natively, a list script never
//! sees. That list is live and holds its root (refcount 5h, lane rc5) - one
//! counted reference on the document and an edge waiting, held strongly, for
//! a wrapper that never comes - so the branch must let it go. Today every
//! connected iframe gets its navigable in its post-connection steps, so
//! script reaches the branch only when that creation failed; this pins the
//! counts for the path script does reach, beside a control that asks for
//! contentWindow first.
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const h = @import("refcount_holders_helpers.zig");

fn counterValue(name: []const u8) !i64 {
    const counters = try engine.diagnosticCounters(testing.allocator);
    defer testing.allocator.free(counters);
    for (counters) |counter| {
        if (std.mem.eql(u8, counter.name, name)) return counter.value;
    }
    return error.NoCounter;
}

fn liveObjectGlobals() !i64 {
    return counterValue("live_object_globals");
}

fn liveContextGlobals() !i64 {
    return counterValue("live_context_globals");
}

/// Live object Globals after 20 iframes are added, each looked up as
/// `window[i]` - first asking for its contentWindow when `control` (the first
/// 20 frames), so the indexed lookup finds its window and reads no list.
fn globalsAfterFrames(page: h.Page, control: bool) !i64 {
    const after_content_window =
        \\for (let i = 0; i < 20; i++) {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  void frame.contentWindow;
        \\  void window[i];
        \\}
    ;
    const by_lookup =
        \\for (let i = 0; i < 20; i++) {
        \\  document.body.appendChild(document.createElement('iframe'));
        \\  void window[20 + i];
        \\}
    ;
    try page.run(if (control) after_content_window else by_lookup);
    return liveObjectGlobals();
}

fn lookupLetsItsListGo() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.doc = document;");
    const document = try page.node("doc");
    const before = h.dom.refcount.count(document);
    const start = try liveObjectGlobals();
    const after_control = try globalsAfterFrames(page, true);
    const after_lookup = try globalsAfterFrames(page, false);
    try h.expectCount(before, document, "the document, after 40 indexed lookups");
    const control = after_control - start;
    const lookup = after_lookup - after_control;
    if (lookup - control > 2) {
        std.debug.print("live object Globals: +{d} for 20 frames looked up after contentWindow, +{d} for 20 found by the lookup\n", .{ control, lookup });
        return error.LeakedGlobals;
    }
}

test "window[i] lets go of the iframe list it reads" {
    try h.onFreshThread(lookupLetsItsListGo);
}

fn indexedReadsLeaveNoGlobal() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.frame = document.body.appendChild(document.createElement('iframe')); void window[0];");
    const before = try liveObjectGlobals() + try liveContextGlobals();
    try page.run("for (let i = 0; i < 500; i++) { void window[0]; void window[1]; }");
    const after = try liveObjectGlobals() + try liveContextGlobals();
    // 1,000 indexed reads: the getter's context and global handles are its
    // own and released, so the count does not grow with the reads.
    if (after - before > 20) {
        std.debug.print("live object and context Globals: {d} -> {d} over 1,000 indexed reads\n", .{ before, after });
        return error.LeakedGlobals;
    }
}

test "window[i] leaves no Global behind" {
    try h.onFreshThread(indexedReadsLeaveNoGlobal);
}
