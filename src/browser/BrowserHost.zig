//! A Browser on a thread of its own, driven from other threads: the host
//! API's thread-safe surface (the instances design, 4.8 and 5.1; roadmap
//! `instances`, item "Host API"; lane cdph).
//!
//! A `Browser` is single-threaded: everything of it runs on the thread that
//! made it. `BrowserHost.start` spawns that thread (platform.spawnThread),
//! makes the Browser there and runs its event loop for its whole life - HTML
//! "spin the event loop" with nothing to stop it but the host's `stop` - so
//! timers fire, fetches complete, workers post and navigations proceed with
//! no caller turning the loop. A host on any other thread reaches the
//! Browser through COMMANDS: each is a task posted to the loop's cross-thread
//! inbox (its TaskSink) and run on the Browser's thread between tasks, like
//! any task - `post` without waiting, `call` blocking the caller until the
//! command has run. That is the shape of Chrome's browser process posting to
//! a renderer's main thread, and of every other cross-thread path in Crane
//! (a worker's messages, a port's).
//!
//! Who uses it: CDP (src/devtools: a browser context per BrowserHost, its
//! sessions' commands posted here), the WebDriver server (one per session),
//! and embedders through the C ABI (capi.zig, include/crane.h).
//!
//! The rules a command keeps: it runs as a task, so it never spins the loop
//! (a navigation it starts proceeds as tasks after it; Browser's tab API
//! returns at once); it runs no script outside the engine's own entry points;
//! and it never calls `call` on its own host (error.WrongThread - the thread
//! would wait for itself).

const std = @import("std");
const runtime = @import("runtime");
const platform = @import("platform");
const browser_mod = @import("Browser.zig");
const Browser = browser_mod.Browser;
const BrowserConfig = browser_mod.BrowserConfig;
const Signal = runtime.task_sink.Signal;

const log = std.log.scoped(.browser_host);

/// The Browser's thread's stack: as a worker's (html.worker_thread), V8's
/// stack limit about 1 MiB below where the isolate is entered.
pub const stack_size = 16 * 1024 * 1024;

pub const BrowserHost = struct {
    /// Thread-safe: commands are allocated on the posting thread and freed on
    /// the Browser's (or wherever a dropped one is dropped). The Browser
    /// itself allocates from it on its thread.
    allocator: std.mem.Allocator,
    config: BrowserConfig,
    thread: ?platform.Thread = null,
    /// The Browser's thread, once it runs.
    browser_thread: std.atomic.Value(u64) = .init(0),
    /// The Browser: written on its thread before `started` is set, then read
    /// only there (and by `browser()` for a caller on that thread).
    browser_ptr: ?*Browser = null,
    /// The loop's inbox, held for the host's life: a post after the
    /// Browser's end finds it closed, never freed.
    sink: ?*runtime.TaskSink = null,
    /// The Browser's scope and its pause (runtime.BrowserPause), set before
    /// `started`: what other threads reach of the Browser without its thread
    /// - a paused thread's session messages, an open dialog's answer.
    scope: ?*runtime.BrowserScope = null,
    pause: ?*runtime.BrowserPause = null,
    start_error: ?anyerror = null,
    started: Signal = .{},
    /// Set by the stop command, on the Browser's thread: the loop stops
    /// after the turn that ran it.
    stop_requested: bool = false,
    /// The readiness waits of `navigate` and `reload` callers, checked
    /// between the loop's turns (the spin's goal). Browser-thread only.
    readiness_waits: std.ArrayListUnmanaged(*ReadinessWait) = .empty,
    /// The `evaluate` calls whose evaluation runs or awaits now. Browser-
    /// thread only.
    evaluations: std.ArrayListUnmanaged(*EvaluationWaiter) = .empty,

    /// Start a Browser on a thread of its own, made with `config` (BORROWED
    /// until this returns: Browser.init runs while the caller waits). The
    /// allocator must be thread-safe. Returns once the Browser is up, or with
    /// Browser.init's error.
    pub fn start(allocator: std.mem.Allocator, config: BrowserConfig) !*BrowserHost {
        const self = try allocator.create(BrowserHost);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .config = config };
        self.thread = try platform.spawnThread(.{ .name = .from("crane-browser"), .stack_size = stack_size, .qos = .user_interactive }, threadMain, self);
        self.started.wait();
        if (self.start_error) |err| {
            platform.joinThread(self.thread.?);
            return err;
        }
        return self;
    }

    /// End the Browser - every tab closed without prompting, as
    /// Browser.deinit closes them (BiDi browser.removeUserContext, CDP
    /// Target.disposeBrowserContext) - on its thread, join the thread, free
    /// the host. Commands still queued are dropped: a `call` waiting on one
    /// returns error.BrowserGone. Not from the Browser's own thread.
    pub fn stop(self: *BrowserHost) void {
        std.debug.assert(!self.isBrowserThread());
        if (self.sink) |sink| {
            _ = sink.post(.{ .run = stopTask, .drop = ignoreDrop, .data = self });
        }
        if (self.thread) |thread| platform.joinThread(thread);
        if (self.sink) |sink| sink.release();
        self.allocator.destroy(self);
    }

    /// Whether the calling thread is the Browser's.
    pub fn isBrowserThread(self: *const BrowserHost) bool {
        const id = self.browser_thread.load(.acquire);
        return id != 0 and id == currentThreadId();
    }

    /// The Browser, for a caller on its own thread (a command, an event
    /// listener). Null anywhere else, and after its end.
    pub fn browser(self: *BrowserHost) ?*Browser {
        if (!self.isBrowserThread()) return null;
        return self.browser_ptr;
    }

    /// Post `run(ctx, browser)` to run on the Browser's thread as a task, and
    /// return at once. False when the Browser has ended (or is ending): then
    /// `drop(ctx)` has already run - here, or on whichever thread found the
    /// command unrun - and must free what `ctx` carries without touching the
    /// Browser. Exactly one of `run` and `drop` runs.
    pub fn post(self: *BrowserHost, ctx: ?*anyopaque, run: *const fn (ctx: ?*anyopaque, b: *Browser) void, drop: *const fn (ctx: ?*anyopaque) void) bool {
        const sink = self.sink orelse {
            drop(ctx);
            return false;
        };
        const command = self.allocator.create(PostedCommand) catch {
            drop(ctx);
            return false;
        };
        command.* = .{ .host = self, .ctx = ctx, .run = run, .drop = drop };
        return sink.post(.{ .run = PostedCommand.runTask, .drop = PostedCommand.dropTask, .data = command });
    }

    /// Post a page session's message (lane cdpt's devtools thread sends
    /// every one through this): an ordinary FIFO command, as `post`, while
    /// the Browser's thread runs its loop; while the debugger has it paused
    /// (runtime.BrowserPause, policy .debugger: Blink's ClientMessageLoop),
    /// the nested loop runs it, in order, so Debugger.resume and the
    /// inspector's other methods are answered there. During a dialog's pause
    /// it waits, as Chrome's page messages wait for a renderer blocked on a
    /// dialog. Exactly one of `run` and `drop` runs; false when the Browser
    /// has ended (`drop` already ran).
    pub fn postSessionMessage(self: *BrowserHost, ctx: ?*anyopaque, run: *const fn (ctx: ?*anyopaque, b: *Browser) void, drop: *const fn (ctx: ?*anyopaque) void) bool {
        const pause = self.pause orelse return self.post(ctx, run, drop);
        const sink = self.sink orelse {
            drop(ctx);
            return false;
        };
        const command = self.allocator.create(PostedCommand) catch {
            drop(ctx);
            return false;
        };
        command.* = .{ .host = self, .ctx = ctx, .run = run, .drop = drop };
        if (!pause.postMessage(.{ .run = PostedCommand.runTask, .drop = PostedCommand.dropTask, .data = command })) return false;
        // The loop's turn for it: runs the oldest queued session message,
        // unless the nested loop of a pause already ran it.
        _ = sink.post(.{ .run = runNextSessionMessage, .drop = ignoreDrop, .data = self });
        return true;
    }

    fn runNextSessionMessage(data: ?*anyopaque) void {
        const self: *BrowserHost = @ptrCast(@alignCast(data.?));
        const pause = self.pause orelse return;
        const message = pause.takeMessage() orelse return;
        message.run(message.data);
    }

    /// Answer the simple dialog open on tab `tab` (html.simple_dialogs:
    /// accept or dismiss, a prompt's text), from any thread - while the
    /// Browser's thread is paused on it, which is the only time one is open.
    /// False when no dialog of that tab is open, or it was answered already.
    /// The same call as the DialogAnswer of host_events' dialog_opening
    /// (WebDriver's Accept and Dismiss Alert, CDP's
    /// Page.handleJavaScriptDialog).
    pub fn answerUserPrompt(self: *BrowserHost, tab: Browser.TabId, accept: bool, prompt_text: []const u8) bool {
        const scope = self.scope orelse return false;
        const pending = @import("html").simple_dialogs.pendingOf(scope) orelse return false;
        return pending.answerForTab(tab, accept, prompt_text);
    }

    /// The simple dialog open now, copied into `allocator` (WebDriver's Get
    /// Alert Text, its unhandled prompt behaviour), or null. Any thread.
    pub fn userPromptOf(self: *BrowserHost, allocator: std.mem.Allocator) !?@import("html").simple_dialogs.Info {
        const scope = self.scope orelse return null;
        const pending = @import("html").simple_dialogs.pendingOf(scope) orelse return null;
        return pending.snapshot(allocator);
    }

    /// Run `run(ctx, browser)` on the Browser's thread as a task and wait
    /// until it has returned: what it computed is in `ctx` when this
    /// returns. error.BrowserGone when the Browser ended before the command
    /// ran; error.WrongThread on the Browser's own thread (it would wait for
    /// itself).
    pub fn call(self: *BrowserHost, ctx: ?*anyopaque, run: *const fn (ctx: ?*anyopaque, b: *Browser) void) error{ BrowserGone, WrongThread }!void {
        if (self.isBrowserThread()) return error.WrongThread;
        const sink = self.sink orelse return error.BrowserGone;
        var command: CalledCommand = .{ .host = self, .ctx = ctx, .run = run };
        _ = sink.post(.{ .run = CalledCommand.runTask, .drop = CalledCommand.dropTask, .data = &command });
        command.done.wait();
        if (command.gone) return error.BrowserGone;
    }

    // ========================================================================
    // The host API, thread-safe: each a `call` of Browser's tab API.
    // ========================================================================

    /// Browser.createTab on the Browser's thread.
    pub fn createTab(self: *BrowserHost, options: Browser.CreateTabOptions) !Browser.TabId {
        const Call = struct {
            options: Browser.CreateTabOptions,
            result: anyerror!Browser.TabId = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.result = b.createTab(c.options);
            }
        };
        var c: Call = .{ .options = options };
        try self.call(&c, Call.run);
        return c.result;
    }

    /// Browser.closeTab on the Browser's thread.
    pub fn closeTab(self: *BrowserHost, tab: Browser.TabId, options: Browser.CloseTabOptions) !void {
        const Call = struct {
            tab: Browser.TabId,
            options: Browser.CloseTabOptions,
            result: anyerror!void = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.result = b.closeTab(c.tab, c.options);
            }
        };
        var c: Call = .{ .tab = tab, .options = options };
        try self.call(&c, Call.run);
        return c.result;
    }

    /// Browser.activateTab on the Browser's thread.
    pub fn activateTab(self: *BrowserHost, tab: Browser.TabId) !void {
        const Call = struct {
            tab: Browser.TabId,
            result: anyerror!void = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.result = b.activateTab(c.tab);
            }
        };
        var c: Call = .{ .tab = tab };
        try self.call(&c, Call.run);
        return c.result;
    }

    /// Browser.releaseTab on the Browser's thread.
    pub fn releaseTab(self: *BrowserHost, tab: Browser.TabId) !void {
        const Call = struct {
            tab: Browser.TabId,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                b.releaseTab(c.tab);
            }
        };
        var c: Call = .{ .tab = tab };
        try self.call(&c, Call.run);
    }

    /// Browser.listTabs on the Browser's thread, copied into `allocator`
    /// (which must be thread-safe): `Browser.freeTabs`.
    pub fn listTabs(self: *BrowserHost, allocator: std.mem.Allocator) ![]Browser.TabInfo {
        const Call = struct {
            allocator: std.mem.Allocator,
            result: anyerror![]Browser.TabInfo = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.result = b.listTabs(c.allocator);
            }
        };
        var c: Call = .{ .allocator = allocator };
        try self.call(&c, Call.run);
        return c.result;
    }

    /// The navigables' tree (Browser.navigableTree) on the Browser's thread,
    /// in `allocator` (thread-safe): `Browser.freeNavigableTree`.
    pub fn navigableTree(self: *BrowserHost, allocator: std.mem.Allocator, root: ?u64, max_depth: ?u32) ![]Browser.NavigableInfo {
        const Call = struct {
            allocator: std.mem.Allocator,
            root: ?u64,
            max_depth: ?u32,
            result: anyerror![]Browser.NavigableInfo = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.result = b.navigableTree(c.allocator, c.root, c.max_depth);
            }
        };
        var c: Call = .{ .allocator = allocator, .root = root, .max_depth = max_depth };
        try self.call(&c, Call.run);
        return c.result;
    }

    /// When `navigate` and `reload` return (BiDi browsingContext.ReadinessState).
    pub const Readiness = enum {
        /// Once the navigation has started (its tasks run on).
        none,
        /// Once the new document's readiness is "interactive" or later
        /// (DOMContentLoaded).
        interactive,
        /// Once the new document has loaded (its load event ran).
        complete,
    };

    pub const NavigateOptions = struct {
        wait: Readiness = .none,
        /// How long a wait lasts at most, in ms (real time).
        timeout_ms: u64 = 300_000,
    };

    /// HTML "navigate" tab (or traversable) `tab` to `url` as the browser's
    /// UI does (Browser.navigateTraversable: user involvement "browser UI"),
    /// waiting as `options.wait` asks: error.Timeout when that does not come
    /// in time. What it returns: the active document's URL then, OWNED by
    /// `allocator`.
    pub fn navigate(self: *BrowserHost, allocator: std.mem.Allocator, tab: Browser.TabId, url: []const u8, options: NavigateOptions) ![]u8 {
        const Start = struct {
            tab: Browser.TabId,
            url: []const u8,
            result: anyerror!?Browser.TraversableState = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                const before = b.traversableState(c.tab);
                c.result = if (b.navigateTraversable(c.tab, c.url)) before else |err| err;
            }
        };
        var start_call: Start = .{ .tab = tab, .url = url };
        try self.call(&start_call, Start.run);
        const before = try start_call.result;
        try self.waitForReadiness(tab, before, options.wait, options.timeout_ms);
        return self.tabUrl(allocator, tab);
    }

    /// HTML "reload" tab `tab` as the browser's reload button does
    /// (Browser.reloadTraversable), waiting as `options.wait` asks.
    pub fn reload(self: *BrowserHost, allocator: std.mem.Allocator, tab: Browser.TabId, options: NavigateOptions) ![]u8 {
        const Start = struct {
            tab: Browser.TabId,
            result: anyerror!?Browser.TraversableState = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                const before = b.traversableState(c.tab);
                c.result = if (b.reloadTraversable(c.tab)) before else |err| err;
            }
        };
        var start_call: Start = .{ .tab = tab };
        try self.call(&start_call, Start.run);
        const before = try start_call.result;
        try self.waitForReadiness(tab, before, options.wait, options.timeout_ms);
        return self.tabUrl(allocator, tab);
    }

    /// HTML "traverse the history by a delta" for tab `tab`
    /// (Browser.traverseHistoryByDelta): false when there is no entry
    /// `delta` steps away.
    pub fn traverseHistory(self: *BrowserHost, tab: Browser.TabId, delta: i32) !bool {
        const Call = struct {
            tab: Browser.TabId,
            delta: i32,
            result: anyerror!bool = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.result = b.traverseHistoryByDelta(c.tab, c.delta);
            }
        };
        var c: Call = .{ .tab = tab, .delta = delta };
        try self.call(&c, Call.run);
        return c.result;
    }

    /// `traverseHistory`, then wait as `options.wait` asks for the document
    /// the traversal shows (WebDriver's Back and Forward: "traverse the
    /// history by a delta", then wait for the navigation to complete). False
    /// - with no wait - when there was no entry `delta` steps away.
    pub fn traverseHistoryAndWait(self: *BrowserHost, tab: Browser.TabId, delta: i32, options: NavigateOptions) !bool {
        const Start = struct {
            tab: Browser.TabId,
            delta: i32,
            before: ?Browser.TraversableState = null,
            result: anyerror!bool = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.before = b.traversableState(c.tab);
                c.result = b.traverseHistoryByDelta(c.tab, c.delta);
            }
        };
        var start_call: Start = .{ .tab = tab, .delta = delta };
        try self.call(&start_call, Start.run);
        if (!try start_call.result) return false;
        try self.waitForReadiness(tab, start_call.before, options.wait, options.timeout_ms);
        return true;
    }

    /// Tab `tab`'s active document's URL, OWNED by `allocator`.
    pub fn tabUrl(self: *BrowserHost, allocator: std.mem.Allocator, tab: Browser.TabId) ![]u8 {
        const Call = struct {
            allocator: std.mem.Allocator,
            tab: Browser.TabId,
            result: anyerror![]u8 = error.BrowserGone,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.result = b.traversableUrl(c.allocator, c.tab);
            }
        };
        var c: Call = .{ .allocator = allocator, .tab = tab };
        try self.call(&c, Call.run);
        return c.result;
    }

    /// What `evaluate` answers: `json` OWNED by the allocator it was given.
    pub const EvaluateResult = struct {
        kind: @FieldType(Browser.EvaluateResult, "kind"),
        json: []u8,

        pub fn deinit(self: EvaluateResult, allocator: std.mem.Allocator) void {
            allocator.free(self.json);
        }
    };

    /// Browser.evaluateInTab on the Browser's thread, waiting for its answer
    /// - with `await_promise`, until its promise settles (as long as
    /// `timeout_ms`: error.Timeout; the evaluation's answer, when it comes,
    /// is then dropped).
    pub fn evaluate(self: *BrowserHost, allocator: std.mem.Allocator, tab: Browser.TabId, source: []const u8, options: Browser.EvaluateOptions, timeout_ms: u64) !EvaluateResult {
        const waiter = try self.allocator.create(EvaluationWaiter);
        const copy = self.allocator.dupe(u8, source) catch |err| {
            self.allocator.destroy(waiter);
            return err;
        };
        waiter.* = .{ .host = self, .result_allocator = allocator, .tab = tab, .source = copy, .options = options };
        // Two holders: this caller, and the evaluation (released when its
        // callback ran, or when it was dropped unrun).
        waiter.refs.store(2, .monotonic);
        defer waiter.release();
        if (!self.post(waiter, EvaluationWaiter.start, EvaluationWaiter.dropUnrun)) return error.BrowserGone;
        if (!waitSignal(&waiter.done, timeout_ms)) {
            waiter.abandoned.store(true, .release);
            return error.Timeout;
        }
        return waiter.result;
    }

    // ========================================================================
    // Internals
    // ========================================================================

    /// Wait until tab `tab` shows a document other than `before`'s with the
    /// readiness `wait` asks for, or it stops navigating without one (a 204,
    /// a download; a navigation that failed to an error page made a
    /// document). Checked on the Browser's thread between the loop's turns
    /// (`goalMet`), so no check waits for a poll interval; error.Timeout
    /// after `timeout_ms`.
    fn waitForReadiness(self: *BrowserHost, tab: Browser.TabId, before: ?Browser.TraversableState, wait: Readiness, timeout_ms: u64) !void {
        if (wait == .none) return;
        const waiter = try self.allocator.create(ReadinessWait);
        waiter.* = .{ .host = self, .tab = tab, .before = before, .wait = wait };
        // Two holders: this caller, and the Browser's list once added.
        waiter.refs.store(2, .monotonic);
        defer waiter.release();
        if (!self.post(waiter, ReadinessWait.add, ReadinessWait.dropUnrun)) return error.BrowserGone;
        if (!waitSignal(&waiter.done, timeout_ms)) {
            waiter.abandoned.store(true, .release);
            return error.Timeout;
        }
        return waiter.result;
    }

    fn readinessMet(b: *Browser, tab: Browser.TabId, before: ?Browser.TraversableState, wait: Readiness) !bool {
        const state = b.traversableState(tab) orelse return error.NoSuchTab;
        if (state.navigating) return false;
        const changed = if (before) |old| old.document != state.document or old.document_generation != state.document_generation else true;
        // No navigation under way and the same document: it ended without
        // a new one.
        if (!changed) return true;
        return switch (wait) {
            .none => true,
            .complete => state.loaded,
            .interactive => blk: {
                const window = b.traversableWindow(tab) orelse break :blk true;
                const document = @import("interfaces").Window.get_document(window) catch break :blk true;
                const ready = @import("interfaces").Document.get_readyState(document) catch break :blk true;
                break :blk ready != ._loading_;
            },
        };
    }

    /// The Browser's events, on its thread: a dialog opening on a tab ends
    /// the readiness waits and evaluations its callers wait on, with
    /// error.UserPromptOpen - the thread is paused on the dialog until a host
    /// answers it, and a caller that waited on would wait for itself (W3C
    /// WebDriver: a command whose script or navigation opened a prompt
    /// returns, and the prompt is handled by the next).
    fn hostEvent(context: *anyopaque, event: *const @import("host_events.zig").Event) void {
        const self: *BrowserHost = @ptrCast(@alignCast(context));
        switch (event.*) {
            .dialog_opening => |opening| self.promptOpened(opening.tab),
            else => {},
        }
    }

    fn promptOpened(self: *BrowserHost, tab: Browser.TabId) void {
        var i: usize = 0;
        while (i < self.readiness_waits.items.len) {
            const waiter = self.readiness_waits.items[i];
            if (waiter.tab != tab) {
                i += 1;
                continue;
            }
            _ = self.readiness_waits.swapRemove(i);
            waiter.result = error.UserPromptOpen;
            waiter.done.set();
            waiter.release();
        }
        for (self.evaluations.items) |waiter| {
            if (waiter.tab != tab or waiter.abandoned.load(.acquire)) continue;
            // Its answer, when the script ends after the dialog, is dropped.
            waiter.result = error.UserPromptOpen;
            waiter.abandoned.store(true, .release);
            waiter.done.set();
        }
    }

    /// The spin's goal, asked between the loop's turns: the readiness waits
    /// checked, then whether the host asked the loop to stop.
    fn goalMet(context: *anyopaque) bool {
        const self: *BrowserHost = @ptrCast(@alignCast(context));
        if (self.readiness_waits.items.len > 0) self.checkReadinessWaits();
        return self.stop_requested;
    }

    fn checkReadinessWaits(self: *BrowserHost) void {
        const b = self.browser_ptr orelse return;
        var i: usize = 0;
        while (i < self.readiness_waits.items.len) {
            const waiter = self.readiness_waits.items[i];
            const finished: bool = if (waiter.abandoned.load(.acquire)) true else if (readinessMet(b, waiter.tab, waiter.before, waiter.wait)) |met| met else |err| blk: {
                waiter.result = err;
                break :blk true;
            };
            if (!finished) {
                i += 1;
                continue;
            }
            _ = self.readiness_waits.swapRemove(i);
            waiter.done.set();
            waiter.release();
        }
    }

    /// The Browser ends: every readiness wait still listed is told so.
    fn endReadinessWaits(self: *BrowserHost) void {
        while (self.readiness_waits.pop()) |waiter| {
            waiter.result = error.BrowserGone;
            waiter.done.set();
            waiter.release();
        }
        self.readiness_waits.deinit(self.allocator);
    }

    /// Block until `signal` is set, at most `timeout_ms` (real time):
    /// whether it was.
    fn waitSignal(signal: *Signal, timeout_ms: u64) bool {
        const deadline = platform.monotonicNow().ns +| timeout_ms *| std.time.ns_per_ms;
        while (true) {
            const now = platform.monotonicNow().ns;
            if (now >= deadline) return signal.isSet();
            if (signal.waitTimeout(deadline - now)) return true;
        }
    }

    fn threadMain(context: ?*anyopaque) callconv(.c) void {
        const self: *BrowserHost = @ptrCast(@alignCast(context.?));
        self.browser_thread.store(currentThreadId(), .release);
        const b = Browser.init(self.allocator, self.config) catch |err| {
            self.start_error = err;
            self.started.set();
            return;
        };
        self.browser_ptr = b;
        const loop = b.event_loop orelse {
            b.deinit();
            self.browser_ptr = null;
            self.start_error = error.NotInitialized;
            self.started.set();
            return;
        };
        self.sink = loop.taskSink().retain();
        self.scope = b.scope;
        self.pause = b.scope.of(runtime.BrowserPause) catch null;
        // A dialog that opens ends the waits of its tab's callers (WebDriver:
        // a navigation or a script that opened a prompt returns while it is
        // open).
        b.addListener(.{ .context = self, .on_event = hostEvent }) catch {};
        self.started.set();
        // HTML "spin the event loop" for the Browser's life: its turns run -
        // tasks, timers, the network, posted commands, microtask checkpoints
        // - until the stop command. A turn blocks in the loop's own wait
        // (TaskSink.waitForWork), which a posted command wakes.
        while (!self.stop_requested) {
            _ = b.spinEventLoopUntil(.{ .context = self, .met = goalMet }, std.math.maxInt(u32)) catch |err| {
                log.err("the Browser's loop stopped: {}", .{err});
                break;
            };
        }
        // The Browser's end: the readiness waits told, every tab closed, its
        // loop's inbox closed - commands still queued dropped (their callers
        // told) - on this thread.
        self.endReadinessWaits();
        self.evaluations.deinit(self.allocator);
        b.removeListener(.{ .context = self, .on_event = hostEvent });
        self.browser_ptr = null;
        b.deinit();
    }

    fn stopTask(data: ?*anyopaque) void {
        const self: *BrowserHost = @ptrCast(@alignCast(data.?));
        self.stop_requested = true;
    }

    fn ignoreDrop(data: ?*anyopaque) void {
        _ = data;
    }

    fn currentThreadId() u64 {
        return @intCast(std.Thread.getCurrentId());
    }

    /// A `post`ed command, freed when it ran or was dropped.
    const PostedCommand = struct {
        host: *BrowserHost,
        ctx: ?*anyopaque,
        run: *const fn (ctx: ?*anyopaque, b: *Browser) void,
        drop: *const fn (ctx: ?*anyopaque) void,

        fn runTask(data: ?*anyopaque) void {
            const self: *PostedCommand = @ptrCast(@alignCast(data.?));
            const host = self.host;
            defer host.allocator.destroy(self);
            if (host.browser_ptr) |b| self.run(self.ctx, b) else self.drop(self.ctx);
        }

        fn dropTask(data: ?*anyopaque) void {
            const self: *PostedCommand = @ptrCast(@alignCast(data.?));
            const allocator = self.host.allocator;
            self.drop(self.ctx);
            allocator.destroy(self);
        }
    };

    /// A `call`ed command, on its caller's stack until `done`.
    const CalledCommand = struct {
        host: *BrowserHost,
        ctx: ?*anyopaque,
        run: *const fn (ctx: ?*anyopaque, b: *Browser) void,
        done: Signal = .{},
        gone: bool = false,

        fn runTask(data: ?*anyopaque) void {
            const self: *CalledCommand = @ptrCast(@alignCast(data.?));
            if (self.host.browser_ptr) |b| self.run(self.ctx, b) else self.gone = true;
            self.done.set();
        }

        fn dropTask(data: ?*anyopaque) void {
            const self: *CalledCommand = @ptrCast(@alignCast(data.?));
            self.gone = true;
            self.done.set();
        }
    };

    /// One `evaluate`: shared by its caller, who may stop waiting
    /// (`abandoned`), and the evaluation on the Browser's thread, whose
    /// answer may come from a promise reaction much later.
    const EvaluationWaiter = struct {
        host: *BrowserHost,
        result_allocator: std.mem.Allocator,
        tab: Browser.TabId,
        /// OWNED (the host's allocator): the caller may stop waiting before
        /// the evaluation starts.
        source: []u8,
        options: Browser.EvaluateOptions,
        refs: std.atomic.Value(u32) = .init(0),
        abandoned: std.atomic.Value(bool) = .init(false),
        done: Signal = .{},
        result: anyerror!EvaluateResult = error.BrowserGone,

        fn release(self: *EvaluationWaiter) void {
            if (self.refs.fetchSub(1, .acq_rel) != 1) return;
            if (self.result) |r| {
                if (self.abandoned.load(.acquire)) r.deinit(self.result_allocator);
            } else |_| {}
            self.host.allocator.free(self.source);
            self.host.allocator.destroy(self);
        }

        fn start(ctx: ?*anyopaque, b: *Browser) void {
            const self: *EvaluationWaiter = @ptrCast(@alignCast(ctx.?));
            self.host.evaluations.append(self.host.allocator, self) catch {};
            b.evaluateInTab(self.tab, self.source, self.options, .{ .context = self, .done = answered });
        }

        fn answered(context: *anyopaque, result: anyerror!Browser.EvaluateResult) void {
            const self: *EvaluationWaiter = @ptrCast(@alignCast(context));
            defer self.release();
            for (self.host.evaluations.items, 0..) |item, i| {
                if (item != self) continue;
                _ = self.host.evaluations.swapRemove(i);
                break;
            }
            if (!self.abandoned.load(.acquire)) {
                self.result = if (result) |r|
                    if (self.result_allocator.dupe(u8, r.json)) |json| .{ .kind = r.kind, .json = json } else |err| err
                else |err|
                    err;
            }
            self.done.set();
        }

        fn dropUnrun(ctx: ?*anyopaque) void {
            const self: *EvaluationWaiter = @ptrCast(@alignCast(ctx.?));
            self.result = error.BrowserGone;
            self.done.set();
            self.release();
        }
    };

    /// One `navigate`/`reload` caller's wait for a readiness: shared by the
    /// caller, who may stop waiting (`abandoned`), and the Browser's list.
    const ReadinessWait = struct {
        host: *BrowserHost,
        tab: Browser.TabId,
        before: ?Browser.TraversableState,
        wait: Readiness,
        refs: std.atomic.Value(u32) = .init(0),
        abandoned: std.atomic.Value(bool) = .init(false),
        done: Signal = .{},
        result: anyerror!void = {},

        fn release(self: *ReadinessWait) void {
            if (self.refs.fetchSub(1, .acq_rel) != 1) return;
            self.host.allocator.destroy(self);
        }

        /// On the Browser's thread: listed, then checked at once.
        fn add(ctx: ?*anyopaque, b: *Browser) void {
            _ = b;
            const self: *ReadinessWait = @ptrCast(@alignCast(ctx.?));
            self.host.readiness_waits.append(self.host.allocator, self) catch {
                self.result = error.OutOfMemory;
                self.done.set();
                self.release();
                return;
            };
            self.host.checkReadinessWaits();
        }

        fn dropUnrun(ctx: ?*anyopaque) void {
            const self: *ReadinessWait = @ptrCast(@alignCast(ctx.?));
            self.result = error.BrowserGone;
            self.done.set();
            self.release();
        }
    };
};
