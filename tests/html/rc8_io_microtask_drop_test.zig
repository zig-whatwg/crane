//! Lane refcount8 (H-RC8-IO, the integrator's 2026-10-29 item): an
//! IntersectionObserver's update microtask carries heap data (its observer's
//! address and generation), and engine.queueMicrotask has no dropped end -
//! a microtask whose queue is discarded under it (a terminated checkpoint:
//! V8 deletes the rest of its queue, which is what a WPT timeout does) never
//! tells the host, and the data leaked (lane leaks1 found the class). The
//! update goes through engine.queueRealmMicrotask, whose dropped end frees it.
//!
//! The queue, in order: a native microtask that aborts the running script, a
//! script job that loops (its back edges see the interrupt, and V8 discards
//! the queue), then the observer's update. std.testing.allocator fails the
//! test on the update's leaked context.
const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const engine = h.engine;

const Abort = struct {
    agent: *engine.Agent,
    ran: bool = false,

    fn run(data: ?*anyopaque) void {
        const self: *Abort = @ptrCast(@alignCast(data.?));
        self.ran = true;
        engine.abortRunningScript(self.agent);
    }
};

fn discardedUpdateIsFreed() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.observer = new IntersectionObserver(() => {}); 0;");
    const agent = page.browser.getAgent() orelse return error.NoAgent;
    var abort: Abort = .{ .agent = agent };
    try engine.queueMicrotask(agent, Abort.run, &abort);
    // The script's own checkpoint runs: the abort, then the looping job -
    // terminated, so V8 discards what is left: the observer's update.
    page.run(
        \\Promise.resolve().then(() => { for (let i = 0; i < 1e9; i++) {} });
        \\observer.observe(document.body);
        \\0;
    ) catch {};
    engine.resumeScripts(agent);
    try std.testing.expect(abort.ran);
}

test "an IntersectionObserver's update microtask discarded with its queue is freed" {
    try h.onFreshThread(discardedUpdateIsFreed);
}
