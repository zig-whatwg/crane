//! Holders that keep a Window for a request or a kept page read it through
//! its realm or its slab generation, never through a slot reissued since
//! (lane winslot1, kinds 8 and 11).
//!
//! - A fetch's resource timing (and its CSP and integrity violation)
//!   reporter kept the client's global as a bare pointer for as long as the
//!   request lived: reported after that global's realm ended and its slot
//!   was reissued, the entry was marked in the timeline of whatever realm
//!   the newcomer belonged to. The reporter keeps the realm now, and
//!   resolves its global when it reports.
//! - The back/forward cache's kept page compared a Window or Document by
//!   address only: a Window made later in a kept page's Window's slot read
//!   as that page's.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const dom = @import("dom");
const fetch = @import("fetch");
const helpers = @import("winslot_helpers.zig");

fn timingAfterRealmEnd() !void {
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
    const frame = try helpers.newWindow(page.browser, before.items);
    // What a request of the frame's carries: the frame's timing reporter.
    const reporter = dom.performance_timeline.timingReporterFor(frame.window);

    // The frame's realm ends; its Window's slot goes back and is reissued to
    // an impostor of the page's realm.
    try page.run("f.remove(); delete globalThis.f;");
    try page.collect();
    try testing.expect(frame.ended());
    try helpers.releaseTornDown(frame);
    try helpers.reissue(page, frame);

    // The response ends now: fetch reports its timing.
    const entries_before = try page.eval("String(performance.getEntriesByType('resource').length)");
    defer testing.allocator.free(entries_before);
    var timing_info: fetch.internal.FetchTimingInfo = .{ .allocator = testing.allocator, .server_timing_headers = .empty };
    reporter.report(reporter.context, &.{
        .timing_info = &timing_info,
        .url = "https://example.test/winslot1-late-response",
        .initiator_type = .fetch,
        .cache_state = "",
        .body_info = .{},
        .response_status = 200,
    });
    // Nothing is marked for the page, whose realm the reissued slot is of.
    try page.expectEval("String(performance.getEntriesByType('resource').length)", entries_before);
}

test "a request's timing reported after its client's realm ended is marked nowhere, never in a reissued slot's realm" {
    try helpers.onFreshThread(timingAfterRealmEnd);
}

const delegates = .{};
const window_vtable = runtime.VTable{ .name = "Window", .deinit = null, .methods_ptr = &delegates };
const document_vtable = runtime.VTable{ .name = "Document", .deinit = null, .methods_ptr = &delegates };

fn noEvict(_: *const dom.bfcache.KeptPage) void {}
const no_steps: dom.bfcache.PageSteps = .{ .evict = &noEvict };

test "a kept page holds its Window and Document only while their slots are still theirs" {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();
    var realm = try runtime.ContextData.init(testing.allocator, .{});
    defer realm.deinit();
    const window = try slab.alloc(&window_vtable);
    const document = try slab.alloc(&document_vtable);
    var data: u8 = 0;
    const kept: dom.bfcache.KeptPage = .{
        .traversable = @ptrCast(&data),
        .document_state = 1,
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
        .window = window,
        .window_generation = runtime.SlabAllocator.generationOf(window),
        .realm = &realm,
        .data = @ptrCast(&data),
        .steps = &no_steps,
    };
    try testing.expect(kept.has(window));
    try testing.expect(kept.has(document));

    // The page's Window goes - its realm ended with its opener's - and a new
    // Window is made in its slot: it is no page of the cache.
    slab.free(window);
    const newcomer = try slab.alloc(&window_vtable);
    try testing.expectEqual(@intFromPtr(window), @intFromPtr(newcomer));
    try testing.expect(!kept.has(newcomer));
    try testing.expect(kept.has(document));
    slab.free(newcomer);
    slab.free(document);
}
