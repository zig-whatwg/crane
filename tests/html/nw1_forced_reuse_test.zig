//! The host page's old Window, once a load gave its navigable a new one
//! (lane newwin1, B3): its realm is detached and, once collected, ends - and
//! winslot1's switch gives its slab slot back. Reissued to another type, the
//! slot is never read as that Window through the page's WindowProxy or any
//! holder of it: the holders keep the proxy, which shows the new Window
//! (docs/lessons/architecture-a-slot-goes-back-only-when-every-holder-kind-is-on-an-allowlist.md).
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const runtime = @import("runtime");
const helpers = @import("winslot_helpers.zig");

fn hostWindowSlotReissued() !void {
    const page = try helpers.Page.open();
    defer page.close();
    // Holders of the page WindowProxy outlive the page on purpose.
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&page.browser.agent_host.deferred_teardown, "holders of the old WindowProxy outlive the page, which is what this tests");
    const context = page.browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><title>one</title>", .{ .base_url = "http://example.test/one" });
    // Holders of the page's WindowProxy in a realm that outlives the page's
    // Window: a popup's (it moves with the page's navigable, B7).
    // Made by a function of the popup's realm: nothing of the page's realm
    // is stored there - a plain object of it would keep that realm alive,
    // as any object keeps its realm.
    try page.run(
        \\globalThis.popup = window.open('about:blank', 'holders');
        \\popup.Function('w', 'globalThis.holders = { view: new MouseEvent("x", { view: w }), source: new MessageEvent("m", { source: w }) }; globalThis.savedOpener = w;')(window);
    );
    const held_popup = try context.evaluateScript("popup");
    defer held_popup.release();
    const old: helpers.Held = .{ .window = context.window_instance.?, .generation = runtime.SlabAllocator.generationOf(context.window_instance.?) };

    try context.loadHTML("<!doctype html><title>two</title>", .{ .base_url = "http://example.test/two" });
    try testing.expect(context.window_instance.? != old.window);
    try page.collect();
    // The old realm ended and gave its Window's slot back by itself.
    if (!old.ended() or runtime.SlabAllocator.generationOf(old.window) == old.generation) {
        std.debug.print("old Window: ended={} generation {d} -> {d}\n", .{ old.ended(), old.generation, runtime.SlabAllocator.generationOf(old.window) });
        return error.OldWindowKept;
    }
    try helpers.reissue(page, old);

    const realm = context.realm.?;
    const global = try engine.getProperty(realm, .{ .instance = context.window_instance.? }, "window");
    defer global.release();
    try engine.setProperty(realm, global.value, "heldPopup", held_popup.value);
    try page.expectEval(
        "[heldPopup.holders.view.view === window, heldPopup.holders.source.source === window, heldPopup.savedOpener === window, heldPopup.opener === window, heldPopup.holders.view.view.document.title].join()",
        "true,true,true,true,two",
    );
}

test "the host page's old Window's slot, reissued to another type, is never read through its WindowProxy or a holder of it" {
    try helpers.onFreshThread(hostWindowSlotReissued);
}
