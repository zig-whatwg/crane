//! A Browser's receiver for platform events (docs/platform-protocol.md
//! section 7): the EventSink Browser.init gives `createBrowserPlatform`.
//!
//! The platform's observers post from threads of their own - a dispatch
//! queue, a poller thread - at any time between the Browser's platform
//! state being made and `destroyBrowserPlatform` returning. Nothing of the
//! Browser runs inside a post (the contract: "Never runs script inside"):
//! `post` only queues tasks on the event loops that need the event, through
//! their TaskSinks, which is what any other thread may touch of a loop.
//!
//! One event is turned into steps so far, memory pressure. What the
//! browsers do with it (read 2026-11-16):
//!
//! - Chromium: every level reaches V8. content/renderer/
//!   blink_isolates_pressure_listener.cc OnReleaseMemory ->
//!   blink::MemoryPressureNotificationToAllIsolates sends
//!   Isolate::MemoryPressureNotification kModerate at its moderate level and
//!   kCritical at critical (kModerate instead while the renderer is
//!   visible), for the main thread's isolate and every worker's.
//! - WebKit: Source/WebCore/page/MemoryRelease.cpp releaseMemory. Not
//!   critical: caches only, and no collection of script memory on macOS or
//!   Linux. Critical: its allocator's free memory is returned
//!   (releaseFastMallocFreeMemory, and the system malloc's), compiled code
//!   is dropped, script garbage is collected now, and every worker thread
//!   is asked to do the same.
//! - Firefox: answers at its low-memory (critical) level only by default
//!   (widget/cocoa/nsAppShell.mm, xpcom/base/AvailableMemoryWatcher*.cpp;
//!   the "memory-pressure" / "low-memory" observers: mozjemalloc's dirty
//!   pages are purged - AvailableMemoryTracker.cpp - and script memory gets
//!   a shrinking collection - nsJSEnvironmentObserver); a warning from macOS
//!   collects nothing.
//!
//! No browser alone, mechanism by mechanism (golden rule 2):
//!
//! - critical: a full collection in the window's agent (all three; a
//!   visible Chromium renderer gets the moderate notice), the same in every
//!   running worker's, each on its own thread (Chromium and WebKit), and
//!   the allocator's free memory returned (WebKit and Firefox). That is
//!   `engine.notifyMemoryPressure(.critical)` and then one release at
//!   `.pressure` through the window loop's gate (memory_release.zig) - once,
//!   on the window's loop: the allocator is the process's, and the gate's
//!   hold-off is its rule for how often.
//! - warning: nothing (WebKit and Firefox; Chromium alone sends V8 a
//!   moderate notice, which starts an incremental collection).
//! - normal: nothing in any of them but bookkeeping.
//!
//! The steps are tasks, so a critical event that arrives while a page works
//! is answered at the loop's next turn, and one that arrives for a worker
//! that is suspended (its Document in the back/forward cache) is answered
//! when it resumes.
//!
//! Lifetime. The sink is a supplement of the Browser's scope, made before
//! the Browser's platform state so that it ends after it (supplements end in
//! reverse): the platform borrows the EventSink until its observers have
//! stopped. Browser.init attaches the window's event loop once it exists,
//! and Browser.deinit detaches it before the loop ends; a post before the
//! one or after the other finds no loop and does nothing. What a post
//! touches under the sink's lock is a reference to the loop's TaskSink,
//! which outlives its loop for as long as a holder has it; the loop itself
//! is touched only by its own tasks.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const platform = @import("platform");
const html = @import("html");
const EventLoop = @import("event_loop.zig").EventLoop;

pub const PlatformEvents = struct {
    /// Protects `loop` and `sink`. Held for a few instructions, never
    /// across a post.
    mutex: std.Io.Mutex = .init,
    /// The scope this is a supplement of: where the Browser's workers are
    /// registered. Set once, by `make`, before any post can arrive.
    scope: ?*runtime.BrowserScope = null,
    /// The window's event loop while it is attached: only ever handed to a
    /// task of that loop, never read here.
    loop: ?*EventLoop = null,
    /// The loop's TaskSink, a reference, while the loop is attached.
    sink: ?*runtime.TaskSink = null,

    pub fn init(allocator: std.mem.Allocator) PlatformEvents {
        _ = allocator;
        return .{};
    }

    /// With the scope, after the Browser's platform state: no observer
    /// posts any more.
    pub fn deinit(self: *PlatformEvents) void {
        self.detach();
    }

    /// The EventSink to give `createBrowserPlatform`. BORROWS `self`, which
    /// outlives the platform state.
    pub fn eventSink(self: *PlatformEvents) platform.EventSink {
        return .{ .context = self, .post = post };
    }

    /// The Browser's window event loop exists: events become its tasks
    /// from now on. The loop's thread.
    pub fn attach(self: *PlatformEvents, loop: *EventLoop) void {
        const sink = loop.taskSink().retain();
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const previous = self.sink;
        self.loop = loop;
        self.sink = sink;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        if (previous) |old| old.release();
    }

    /// The loop is about to end: no task is posted to it from now on. What
    /// was posted and has not run is dropped when the loop closes its sink.
    pub fn detach(self: *PlatformEvents) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const sink = self.sink;
        self.loop = null;
        self.sink = null;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        // Outside the lock: the last reference closes the sink.
        if (sink) |held| held.release();
    }

    /// EventSink.post: any thread; the event is borrowed for the call.
    fn post(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
        const self: *PlatformEvents = @ptrCast(@alignCast(context orelse return));
        switch (event.kind) {
            .memory_pressure => switch (event.memory_pressure) {
                .critical => self.postCritical(),
                // No browser collects script memory for these on a desktop
                // but Chromium at its moderate level (the header).
                .warning, .normal => {},
            },
            // Not turned into steps yet (docs/platform-protocol.md 7; no
            // platform posts them).
            else => {},
        }
    }

    /// Critical memory pressure: one task for the window's loop, one for
    /// each running worker's. Any thread.
    fn postCritical(self: *PlatformEvents) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const loop = self.loop;
        const sink = if (self.sink) |held| held.retain() else null;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        // Before the loop is attached, or after it is detached: the Browser
        // is starting or ending, and has nothing to give back.
        const held = sink orelse return;
        defer held.release();
        // The task's data is the loop itself: a task runs only inside its
        // loop's turn, and a loop that ends closes its sink, which drops
        // the task without touching the data.
        _ = held.post(.{ .run = collectAndRelease, .drop = dropNothing, .data = loop });
        // The workers, each through its own sink. (A Browser that never
        // made a worker has no registry.)
        const scope = self.scope orelse return;
        if (scope.existing(html.WorkerRegistry)) |registry| _ = registry.collectUnderPressure();
    }

    /// The window loop's task for a critical event: collect everything that
    /// can be collected, then give the allocator's free memory back - what
    /// the collection freed with it.
    fn collectAndRelease(data: ?*anyopaque) void {
        const loop: *EventLoop = @ptrCast(@alignCast(data.?));
        engine.notifyMemoryPressure(loop.agent, .critical);
        // Refused while a release runs or the hold-off after the last one
        // has not passed: memory returned seconds ago is not asked for
        // again.
        _ = loop.memory_gate.release(.pressure);
    }

    fn dropNothing(_: ?*anyopaque) void {}
};

/// Make `scope`'s receiver for platform events - before the Browser's
/// platform state, which borrows its EventSink - and answer it. A scope
/// that has one already keeps it.
pub fn make(scope: *runtime.BrowserScope) !*PlatformEvents {
    const events = try scope.of(PlatformEvents);
    events.scope = scope;
    return events;
}

/// `scope`'s receiver, if it was made.
pub fn of(scope: *runtime.BrowserScope) ?*PlatformEvents {
    return scope.existing(PlatformEvents);
}
