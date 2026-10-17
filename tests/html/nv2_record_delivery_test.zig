//! Promise-reaction delivery owns its existing event-record wait hold until
//! the callback returns, including a blur handler that starts a navigation.
//! Blink NavigateEvent::React binds the event into its promise reaction;
//! ReactDone then calls PotentiallyResetTheFocus while that event is live.
const std = @import("std");
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");

fn reentrantDelivery() !void {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body tabindex=-1><button id=focused>Focus</button></body>", .{ .base_url = "http://example.test/nv2-record" });
    try page.runScript(
        \\globalThis.completed = false;
        \\globalThis.failure = null;
        \\const nav = navigation;
        \\focused.focus();
        \\let inner;
        \\let releaseInner;
        \\const innerGate = new Promise(resolve => releaseInner = resolve);
        \\nav.onnavigate = e => e.intercept(e.destination.url.endsWith('#inner')
        \\  ? {focusReset: 'manual', handler: () => innerGate}
        \\  : {handler: () => Promise.resolve()});
        \\focused.onblur = () => {
        \\  focused.onblur = null;
        \\  inner = nav.navigate('#inner');
        \\};
        \\const outer = nav.navigate('#outer');
        \\outer.committed.catch(() => {});
        \\outer.finished.then(async () => {
        \\  if (!inner) throw new Error('focus reset did not start the nested navigation');
        \\  releaseInner();
        \\  const entry = await inner.finished;
        \\  if (entry !== nav.currentEntry || location.hash !== '#inner')
        \\    throw new Error('nested navigation did not settle its current entry');
        \\  completed = true;
        \\}).catch(error => failure = String(error));
    );
    _ = try browser.runEventLoopBlocking(100);
    try page.runScript(
        \\if (failure !== null) throw new Error(failure);
        \\if (!completed) throw new Error('navigation delivery did not finish');
    );
}

test "navigation delivery keeps its event record through focus-reset reentry" {
    try helpers.onFreshThread(reentrantDelivery);
}
