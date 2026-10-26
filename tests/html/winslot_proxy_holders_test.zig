//! A WindowProxy holder in another realm - UIEvent's view, MessageEvent's
//! source (posted and constructed) - keeps the PROXY, never the old Window
//! (lane winslot1, kinds 3 and 4; the integrator's ruling of 2026-10-25 on
//! the three-browser probe tmp/analysis/integrator-probes-1025n).
//!
//! Firefox 158, and the majority mechanism by mechanism (navigation keeps
//! the proxy: Firefox and Safari 27; removal keeps it, closed: Chrome 155
//! and Firefox):
//! - after the frame navigates, the holder answers the SAME proxy, now
//!   showing the new document;
//! - after the iframe is removed, the same proxy, `closed` true - the holder
//!   keeps it (a traced edge, never a root), and with it the removed frame's
//!   realm for exactly as long as the holder lives.
//! Either way it never answers the object a reissued slot holds: the old
//! Window's realm ends (the navigated case) and its slot is given back and
//! reissued to an impostor before the holders are read.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const helpers = @import("winslot_helpers.zig");

/// A frame showing "one", its Window found, and three holders of its proxy
/// made in the parent: a MouseEvent's view, the MessageEvent the frame
/// posted, and a constructed MessageEvent.
fn frameWithHolders(page: helpers.Page) !helpers.Held {
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
    const held = try helpers.newWindow(page.browser, before.items);
    try page.run(
        \\globalThis.pending = 1;
        \\globalThis.holders = {};
        \\window.addEventListener('message', e => { if (e.data === 'winslot1') { holders.posted = e; pending = 0; } });
        \\holders.view = new MouseEvent('x', { view: f.contentWindow });
        \\holders.constructed = new MessageEvent('m', { source: f.contentWindow });
        \\f.contentWindow.eval("parent.postMessage('winslot1', '*')");
    );
    try page.settle();
    return held;
}

/// What each holder answers now, against `proxy`: "proxy:<text>:<closed>",
/// "null", "IMPOSTOR" or what else it is.
const describe =
    \\(proxy) => [holders.view.view, holders.posted.source, holders.constructed.source].map(v => {
    \\  if (v === null) return 'null';
    \\  if (v && v.id === 'impostor') return 'IMPOSTOR';
    \\  if (proxy !== undefined && v === proxy) {
    \\    let text; try { text = v.document.body.textContent; } catch (e) { text = e.name; }
    \\    return 'proxy:' + text + ':' + v.closed;
    \\  }
    \\  return 'other:' + String(v);
    \\}).join(',')
;

fn navigated() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const old = try frameWithHolders(page);
    // The frame navigates; its WindowProxy goes on to the new Window.
    try page.run(
        \\globalThis.saved = f.contentWindow;
        \\globalThis.pending = 1;
        \\f.addEventListener('load', () => { pending = 0; }, { once: true });
        \\f.srcdoc = '<body>two</body>';
    );
    try page.settle();
    // The old Window's realm ends once the collector takes it: nothing
    // holds it - the holders keep the proxy, which is the new realm's.
    try page.collect();
    try testing.expect(old.ended());
    try helpers.releaseTornDown(old);
    try helpers.reissue(page, old);
    try page.expectEval("(" ++ describe ++ ")(saved)", "proxy:two:false,proxy:two:false,proxy:two:false");
}

test "after its frame navigates, a holder in the parent answers the same WindowProxy, never a reissued slot" {
    try helpers.onFreshThread(navigated);
}

fn removed() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const old = try frameWithHolders(page);
    // The parent keeps no reference of its own to the proxy, only a weak one.
    try page.run(
        \\globalThis.savedRef = new WeakRef(f.contentWindow);
        \\f.remove();
        \\delete globalThis.f;
    );
    try page.collect();
    if (old.ended()) {
        // A holder that kept only the Window let the realm go: whatever the
        // holders answer now, it must not be the object in the reissued slot.
        try helpers.releaseTornDown(old);
        try helpers.reissue(page, old);
    }
    // The holders keep the proxy, and so the removed frame's realm: the same
    // proxy, closed.
    try page.expectEval("(" ++ describe ++ ")(savedRef.deref())", "proxy:one:true,proxy:one:true,proxy:one:true");
    try testing.expect(!old.ended());

    // Once the holders go, nothing keeps the realm: it ends.
    try page.run("delete globalThis.holders;");
    try page.collect();
    try testing.expect(old.ended());
}

test "after its iframe is removed, a holder in the parent keeps the same WindowProxy, closed, until the holder goes" {
    try helpers.onFreshThread(removed);
}

fn neverWrapped() !void {
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
    // The frame posts to a parent with no message listener: the
    // MessageEvent the parent's realm makes, its source the frame's proxy,
    // is never wrapped, and goes once dispatched.
    try page.run(
        \\globalThis.pending = 1;
        \\f.contentWindow.eval("parent.postMessage('unheard', '*')");
        \\setTimeout(() => { pending = 0; }, 0);
    );
    try page.settle();
    try page.run("f.remove(); delete globalThis.f;");
    try page.collect();
    // Nothing keeps the removed frame's realm: it ended.
    try testing.expect(frame.ended());
}

test "a holder of a removed frame's WindowProxy that was never wrapped does not keep its realm" {
    try helpers.onFreshThread(neverWrapped);
}
