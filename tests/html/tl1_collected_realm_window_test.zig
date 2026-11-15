//! Between the moment the collector takes a detached realm and the task that ends that realm, native code
//! that still reaches the realm reads no freed object and leaves nothing unfreed (lane tl1).
//!
//! A navigated frame's old realm is detached: it lives while script reaches anything of it. When nothing
//! does, the collector takes its context (protocol_realms.realmCollected) and QUEUES the realm's end as a
//! task of the page's event loop. Until that task runs:
//! - the old Window and its document's tree are still allocated, so a native weak reference (an address and
//!   a slab generation) still resolves them;
//! - the objects of that realm that had wrappers - the Window's Performance object once script read
//!   `performance` - were freed by the collector with their wrappers, and the Window still names them;
//! - the realm has no engine behind it, so an object made in it is never wrapped, and
//!   Instance.releaseIfUnwrapped leaves it ("nothing is known about who else holds it").
//!
//! tests/html/tl1_pointer_after_realm_collected_test.zig is the one road known to reach that state (the
//! embedder's pointer). These tests are the state itself, with no pointer: the two things an event fired
//! there does.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const dom = @import("dom");
const h = @import("tl1_pending_timer_helpers.zig");

fn pageHtml(comptime frame_script: []const u8) []const u8 {
    return "<!doctype html><body>" ++
        "<iframe id=frame srcdoc=\"<!doctype html><body><button id=inside>inside</button>" ++ frame_script ++
        "</body>\"></iframe></body>";
}

fn collect(page: h.Page) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const agent = page.browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

/// A page whose frame has navigated away from its first document, that document's realm taken by the
/// collector and its end still queued: the realm, which stays a valid record until its agent ends.
fn collectedFrameRealm(page: h.Page) !runtime.Context {
    try page.run(
        \\globalThis.state = 'pending';
        \\globalThis.poll = setInterval(() => {
        \\  const inner = document.getElementById('frame').contentDocument;
        \\  if (inner && inner.getElementById('inside')) { state = 'loaded'; clearInterval(poll); }
        \\}, 5);
    );
    try page.waitForState("loaded");
    const context = page.browser.current_context orelse return error.NoPage;
    const document = context.document_instance orelse return error.NoDocument;
    const frame = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("frame"))) orelse return error.NoFrame;
    const frame_document = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoFrameDocument;
    const realm = frame_document.ctx;
    try page.run(
        \\state = 'pending';
        \\{
        \\  const frame = document.getElementById('frame');
        \\  frame.onload = () => { state = 'navigated'; };
        \\  frame.removeAttribute('srcdoc');
        \\  frame.src = 'about:blank';
        \\}
    );
    try page.waitForState("navigated");
    try testing.expect(realm.hasEngine());
    try collect(page);
    // The collector took it; its end has not run (the event loop has not turned).
    try testing.expect(!realm.hasEngine());
    return realm;
}

fn timestampOfCollectedRealm() !void {
    const page = try h.Page.open(comptime pageHtml("<script>performance.now();</script>"), "http://127.0.0.1:65533/start");
    defer page.close();
    const realm = try collectedFrameRealm(page);
    // DOM "inner event creation steps" step 3 reads this for an event made in the realm. On main's code it
    // read the Performance object the collector had freed.
    _ = dom.performance_timeline.now(realm);
}

fn eventMadeInCollectedRealm() !void {
    const page = try h.Page.open(comptime pageHtml(""), "http://127.0.0.1:65533/start");
    defer page.close();
    const realm = try collectedFrameRealm(page);
    // What firing an event at a node of the realm does: make it, dispatch it, hand it back. Refusing to
    // make it is as good; leaving it allocated is the leak.
    const event = interfaces.Event.call_constructor(realm, runtime.DOMString.initInterned("pointerout"), .notPassed()) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    event.releaseIfUnwrapped(generation);
}

fn onFreshThread(comptime body: fn () anyerror!void) !void {
    try h.onFreshThread(body);
}

test "the timestamp of a collected realm whose end is still queued reads no freed Performance object" {
    try onFreshThread(timestampOfCollectedRealm);
}

test "an event made in a collected realm whose end is still queued is freed when it is handed back" {
    try onFreshThread(eventMadeInCollectedRealm);
}
