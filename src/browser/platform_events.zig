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
//! Four events are turned into steps so far: the system visibility state of
//! a tab (`visibility_changed`, HTML 6.2: `systemVisibilityChanged`), a tab's
//! window rect (`window_rect_changed`: its viewport, src/browser/viewport.zig),
//! a tab's screen (`screen_changed`: html.screen_info.screenChanged - screen.*,
//! the media queries, screen.orientation) and memory pressure. What the browsers do with memory pressure (read 2026-11-16):
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
const dom = @import("dom");
const EventLoop = @import("event_loop.zig").EventLoop;

pub const PlatformEvents = struct {
    /// The scope's allocator, thread-safe: what an event's task carries is
    /// made on the poster's thread and freed on the loop's.
    allocator: std.mem.Allocator,
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
        return .{ .allocator = allocator };
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
            .visibility_changed => self.postSystemVisibility(event.tab, event.visibility),
            .window_rect_changed => self.postWindowRect(event.tab, event.rect),
            .screen_changed => self.postScreen(event.tab, event.screen),
            .position => self.postPosition(event.watch, event.position),
            // Not turned into steps yet (docs/platform-protocol.md 7; no
            // platform posts them).
            else => {},
        }
    }

    /// `window_rect_changed(tab, rect)`: one task for the window's loop,
    /// which makes the rect's size the tab's viewport
    /// (viewport.windowRectChanged). Any thread.
    fn postWindowRect(self: *PlatformEvents, tab: platform.TabId, rect: platform.Rect) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const sink = if (self.sink) |held| held.retain() else null;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        const held = sink orelse return;
        defer held.release();
        const scope = self.scope orelse return;
        const change = self.allocator.create(WindowRectChange) catch return;
        change.* = .{ .allocator = self.allocator, .scope = scope, .tab = tab, .rect = rect };
        // The sink takes the task whatever happens (see postSystemVisibility).
        _ = held.post(.{ .run = WindowRectChange.run, .drop = WindowRectChange.drop, .data = change });
    }

    /// `screen_changed(tab, screen)`: one task for the window's loop, which
    /// makes `screen` the tab's reported screen (html.screen_info.
    /// screenChanged). Any thread.
    fn postScreen(self: *PlatformEvents, tab: platform.TabId, screen: platform.ScreenInfo) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const sink = if (self.sink) |held| held.retain() else null;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        const held = sink orelse return;
        defer held.release();
        const scope = self.scope orelse return;
        const change = self.allocator.create(ScreenChange) catch return;
        change.* = .{ .allocator = self.allocator, .scope = scope, .tab = tab, .screen = screen };
        // The sink takes the task whatever happens (see postSystemVisibility).
        _ = held.post(.{ .run = ScreenChange.run, .drop = ScreenChange.drop, .data = change });
    }

    /// `position(watch, position)`: one task for the window's loop, delivering
    /// a platform watchPosition update to `html.geolocation.platformPositionEvent`.
    /// Any thread.
    fn postPosition(self: *PlatformEvents, watch: platform.WatchId, position: platform.PositionResult) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const sink = if (self.sink) |held| held.retain() else null;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        const held = sink orelse return;
        defer held.release();
        const scope = self.scope orelse return;
        const update = self.allocator.create(PositionUpdate) catch return;
        update.* = .{ .allocator = self.allocator, .scope = scope, .watch = watch, .position = position };
        _ = held.post(.{ .run = PositionUpdate.run, .drop = PositionUpdate.drop, .data = update });
    }

    /// `visibility_changed(tab, visibility)`: one task for the window's
    /// loop, which runs HTML 6.2's steps for the tab's traversable
    /// (`systemVisibilityChanged`). Any thread.
    fn postSystemVisibility(self: *PlatformEvents, tab: platform.TabId, visibility: platform.Visibility) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const sink = if (self.sink) |held| held.retain() else null;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        const held = sink orelse return;
        defer held.release();
        const scope = self.scope orelse return;
        const change = self.allocator.create(SystemVisibilityChange) catch return;
        change.* = .{ .allocator = self.allocator, .scope = scope, .tab = tab, .visibility = visibility };
        // The sink takes the task whatever happens: a closed one drops it
        // here (its `drop` frees the change), a loop that ends with it still
        // posted drops it there.
        _ = held.post(.{ .run = SystemVisibilityChange.run, .drop = SystemVisibilityChange.drop, .data = change });
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
        // The heap first (allocator-hardening design 5.4: PartitionAlloc's
        // 90% rule, 04875c40bc09): its quarantine purged, every empty span
        // decommitted - on this thread, the node partition's.
        if (loop.heap) |heap| _ = heap.relievePressure();
        engine.notifyMemoryPressure(loop.agent, .critical);
        // Refused while a release runs or the hold-off after the last one
        // has not passed: memory returned seconds ago is not asked for
        // again.
        _ = loop.memory_gate.release(.pressure);
    }

    fn dropNothing(_: ?*anyopaque) void {}

    /// The Browser's heap passed 90% of a partition's address space
    /// (runtime.heap.Engine.pressure_hook): answered as a critical
    /// memory-pressure event is. Any thread, possibly inside the heap's
    /// allocation: it only posts.
    pub fn heapPressure(context: *anyopaque, partition: runtime.heap.PartitionId) void {
        _ = partition;
        const self: *PlatformEvents = @ptrCast(@alignCast(context));
        self.postCritical();
    }
};

/// A tab's new window rect, on its way to the window's loop.
const WindowRectChange = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    tab: platform.TabId,
    rect: platform.Rect,

    fn run(data: ?*anyopaque) void {
        const self: *WindowRectChange = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        @import("viewport.zig").windowRectChanged(self.scope, self.tab, self.rect);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *WindowRectChange = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

/// A tab's new screen, on its way to the window's loop.
const ScreenChange = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    tab: platform.TabId,
    screen: platform.ScreenInfo,

    fn run(data: ?*anyopaque) void {
        const self: *ScreenChange = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        html.screen_info.screenChanged(self.scope, self.tab, self.screen);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *ScreenChange = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

/// A platform geolocation watch update, on its way to the window's loop.
const PositionUpdate = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    watch: platform.WatchId,
    position: platform.PositionResult,

    fn run(data: ?*anyopaque) void {
        const self: *PositionUpdate = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        html.geolocation.platformPositionEvent(self.scope, self.watch, self.position);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *PositionUpdate = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

/// A tab's new system visibility state, on its way to the window's loop.
const SystemVisibilityChange = struct {
    allocator: std.mem.Allocator,
    scope: *runtime.BrowserScope,
    tab: platform.TabId,
    visibility: platform.Visibility,

    fn run(data: ?*anyopaque) void {
        const self: *SystemVisibilityChange = @ptrCast(@alignCast(data orelse return));
        defer self.allocator.destroy(self);
        systemVisibilityChanged(self.scope, self.tab, self.visibility);
    }

    fn drop(data: ?*anyopaque) void {
        const self: *SystemVisibilityChange = @ptrCast(@alignCast(data orelse return));
        self.allocator.destroy(self);
    }
};

/// HTML 6.2: "When a user agent determines that the system visibility state
/// for traversable navigable traversable has changed to newState", for the
/// tab `tab` names - a top-level traversable by its browsing context's id
/// (the TabId the host lists: Browser.traversableIds), or every top-level
/// traversable of the Browser for tab 0 (a platform that tracks no tabs, as
/// the headless ones: docs/platform-protocol.md 6.10.4). The window's loop.
pub fn systemVisibilityChanged(scope: *runtime.BrowserScope, tab: platform.TabId, visibility: platform.Visibility) void {
    const navigables = dom.browser_state.existingNavigablesIn(scope) orelse return;
    const new_state: html.window.browsing_context.SystemVisibility = switch (visibility) {
        .visible => .visible,
        .hidden => .hidden,
    };
    for (navigables.contexts()) |traversable| {
        if (traversable.parent != null or traversable.is_closed) continue;
        if (tab != 0 and traversable.id != tab) continue;
        // The traversable's state is its tab's (runtime.TabScope).
        const tab_scope = traversable.tabScope() orelse continue;
        // Only a change is one ("has changed to newState").
        if (tab_scope.system_visibility == new_state) continue;
        tab_scope.system_visibility = new_state;
        const active: *runtime.Instance = @ptrCast(@alignCast(traversable.getActiveDocument() orelse continue));
        // 1. "Let navigables be the inclusive descendant navigables of
        // traversable's active document."
        var documents = dom.navigables.inclusiveDescendantDocuments(active, scope.allocator);
        defer documents.deinit(scope.allocator);
        // 2. "For each navigable of navigables" (in tree order, parents
        // first - "in what order?" is open; Blink's
        // Page::SetVisibilityState walks the frame tree the same way):
        for (documents.items) |entry| {
            // 2.1 "Let document be navigable's active document."
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            // 2.2 "Queue a global task on the user interaction task source
            // given document's relevant global object to update the
            // visibility state of document with newState."
            const loop = entry.document.ctx.getOptionalEventLoop() orelse continue;
            const task = scope.allocator.create(dom.visibility_state.UpdateTask) catch continue;
            task.* = .{ .allocator = scope.allocator, .document = entry.document, .generation = entry.generation, .state = switch (visibility) {
                .visible => .visible,
                .hidden => .hidden,
            } };
            // The task names its document by identity AND slab generation:
            // the loop runs a task only while its document is fully active
            // (HTML 8.1.7.1), read by that pair - a generation left at 0
            // reads "gone", and the task was dropped unrun (lane tpg:
            // life1_system_visibility_test never saw a document hidden).
            loop.queueTask(.{ .callback = dom.visibility_state.UpdateTask.run, .context = task, .drop = dom.visibility_state.UpdateTask.drop, .document = @ptrCast(entry.document), .document_generation = entry.generation, .source = .user_interaction });
        }
    }
}

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
