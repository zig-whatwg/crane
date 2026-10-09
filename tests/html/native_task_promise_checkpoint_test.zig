//! A promise a native task settles has its reactions run before the next
//! task, though nothing in the task runs script.
//!
//! HTML 8.1.7.3, the event loop processing model: after a task runs, "perform
//! a microtask checkpoint". Resolving a promise from native code performs no
//! checkpoint of its own - V8's kAuto policy used to run one whenever
//! Promise::Resolver::Resolve returned to call depth 0, which is no point
//! HTML has, and v8_wrapper.cpp's NativeStepScope now holds it off - so the
//! reaction runs only because the window's event loop checkpoints after every
//! task: each queued task (EventLoop.runQueuedTasks) and each timer, a task of
//! its own ("run steps after a timeout"; NativeTimerManager.AfterEach).
//!
//! The observing step reads the reaction's mark with [[Get]], which runs no
//! script: had the checkpoint not happened, it would read undefined.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const browser_mod = @import("browser");

/// What the two native steps share.
const Probe = struct {
    realm: runtime.Context,
    global: engine.Owned,
    capability: engine.PromiseCapability,
    /// What the observing step read: whether the reaction had run.
    reaction_seen: ?bool = null,

    /// A native task's steps: resolve the promise, and nothing else.
    fn resolve(context: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(context.?));
        engine.resolvePromise(&self.capability, .{ .number = 1 }) catch {};
    }

    /// The next task's steps: whether the reaction ran, read without script.
    fn observe(context: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(context.?));
        const mark = engine.getProperty(self.realm, self.global.value, "reactionRan") catch return;
        defer mark.release();
        // undefined until the reaction set it.
        self.reaction_seen = engine.typeOf(self.realm, mark.value) == .boolean and engine.toBoolean(self.realm, mark.value);
    }
};

/// A page with a promise script reacts to - `p.then(() => reactionRan =
/// true)` - whose capability the native steps settle.
fn openProbe(browser: *browser_mod.Browser) !Probe {
    try browser.navigate("about:blank", .window);
    // Let the navigation settle before the page's realm is used.
    _ = try browser.runEventLoopBlocking(20);
    const page = browser.current_context orelse return error.NoPage;
    const realm = page.realm orelse return error.NoRealm;
    const global = try page.evaluateScript("globalThis");
    errdefer global.release();
    var capability = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&capability);
    try engine.setProperty(realm, global.value, "p", capability.promise);
    try page.runScript("p.then(() => { globalThis.reactionRan = true; });");
    return .{ .realm = realm, .global = global, .capability = capability };
}

fn closeProbe(probe: *Probe) void {
    engine.releasePromiseCapability(&probe.capability);
    probe.global.release();
}

test "a promise a native task resolves has its reaction run before the next task" {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var probe = try openProbe(browser);
    defer closeProbe(&probe);

    const loop = probe.realm.getOptionalEventLoop() orelse return error.NoEventLoop;
    loop.queueTask(.{ .callback = Probe.resolve, .context = &probe });
    loop.queueTask(.{ .callback = Probe.observe, .context = &probe });
    _ = try browser.runEventLoopBlocking(50);

    // Observed at all (a read that failed leaves null), and after the reaction.
    try std.testing.expect(probe.reaction_seen != null);
    try std.testing.expectEqual(@as(?bool, true), probe.reaction_seen);
}

test "a promise a native timer resolves has its reaction run before the next timer" {
    const browser = try browser_mod.Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var probe = try openProbe(browser);
    defer closeProbe(&probe);

    const event_loop = browser.event_loop orelse return error.NoEventLoop;
    const timers = event_loop.timerInterface() orelse return error.NoTimers;
    // Two timers due in one poll: each is a task of its own.
    _ = timers.setTimeout(0, Probe.resolve, &probe);
    _ = timers.setTimeout(0, Probe.observe, &probe);
    _ = try browser.runEventLoopBlocking(50);

    try std.testing.expect(probe.reaction_seen != null);
    try std.testing.expectEqual(@as(?bool, true), probe.reaction_seen);
}
