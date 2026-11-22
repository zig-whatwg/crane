//! A Browser thread's pause: HTML's "pause" (8.1.7.3 - "While a user agent
//! has a paused task, the corresponding event loop must not run further
//! tasks, and any script in the currently running task must block") and the
//! debugger's nested message loop, with one mechanism and two policies (lane
//! cdph; the integrator's ruling 8:09 PM ET 2026-11-21, agreed with lane
//! cdpt):
//! - `.dialog`: a simple dialog (alert, confirm, prompt, beforeunload's
//!   prompt) or the print dialog waits for its answer alone; the session
//!   messages other threads post meanwhile stay queued (Chrome: a renderer
//!   blocked on a dialog runs no other page message);
//! - `.debugger`: V8's inspector paused the agent (a `debugger;` statement, a
//!   breakpoint) and asked its client to run a message loop until it says
//!   quit; the loop runs the session messages posted meanwhile, in order, and
//!   nothing else - no task, timer or rendering. Blink's
//!   MainThreadDebugger::runMessageLoopOnPause -> ClientMessageLoop::Run,
//!   which takes only the inspector's interrupting tasks
//!   (third_party/blink/renderer/core/inspector/main_thread_debugger.cc,
//!   inspector_task_runner.cc; BSD-3 - reproduced, not copied).
//!
//! Session messages (browser.BrowserHost.postSessionMessage: every message of
//! a page session, from the devtools thread) are queued here AND announced to
//! the Browser's loop: not paused, the loop's task runs the oldest; paused in
//! the debugger, the nested loop does. Each runs once, in posting order.
//!
//! One per Browser: a supplement of its scope. Any thread posts and wakes;
//! only the Browser's thread takes and pauses.

const std = @import("std");
const Allocator = std.mem.Allocator;
const task_sink = @import("task_sink.zig");
const CrossThreadTask = task_sink.CrossThreadTask;

pub const Policy = enum { dialog, debugger };

/// What a pause waits for: asked each time the pause wakes, on the Browser's
/// thread. It must not run script.
pub const Goal = struct {
    context: *anyopaque,
    met: *const fn (context: *anyopaque) bool,
};

pub const BrowserPause = struct {
    allocator: Allocator,
    /// Protects `messages` and `closed`; never held across a message's run.
    mutex: std.Io.Mutex = .init,
    /// Session messages not yet run, oldest first.
    messages: std.ArrayListUnmanaged(CrossThreadTask) = .empty,
    closed: bool = false,
    /// Bumped by every post, `notify` and close: the futex word a pause
    /// waits on.
    wake: std.atomic.Value(u32) = .init(0),
    /// How deep the Browser thread is paused now (a dialog inside a debugger
    /// pause, or the reverse): read on the Browser's thread only.
    depth: u32 = 0,

    pub fn init(allocator: Allocator) BrowserPause {
        return .{ .allocator = allocator };
    }

    /// The scope's end: what was never run is dropped.
    pub fn deinit(self: *BrowserPause) void {
        self.close();
        self.messages.deinit(self.allocator);
    }

    /// Queue a session message. False - its `drop` already ran - once the
    /// Browser has ended.
    pub fn postMessage(self: *BrowserPause, task: CrossThreadTask) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        const accepted = if (self.closed) false else if (self.messages.append(self.allocator, task)) true else |_| false;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        if (!accepted) {
            task.drop(task.data);
            return false;
        }
        self.notify();
        return true;
    }

    /// The Browser's thread: the oldest session message, taken off the queue.
    pub fn takeMessage(self: *BrowserPause) ?CrossThreadTask {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (self.messages.items.len == 0) return null;
        return self.messages.orderedRemove(0);
    }

    /// Wake a pause so it asks its goal again (an answer came, quit was
    /// asked). Any thread.
    pub fn notify(self: *BrowserPause) void {
        _ = self.wake.fetchAdd(1, .release);
        futexIo().futexWake(u32, &self.wake.raw, std.math.maxInt(u32));
    }

    /// Whether the Browser's thread is paused now (its own question).
    pub fn isPaused(self: *const BrowserPause) bool {
        return self.depth > 0;
    }

    /// The Browser's thread: block until `goal` is met. `.debugger` runs each
    /// session message posted meanwhile, in order, as it comes; `.dialog`
    /// leaves them queued. Nothing else of the thread runs.
    pub fn pauseUntil(self: *BrowserPause, goal: Goal, policy: Policy) void {
        self.depth += 1;
        defer self.depth -= 1;
        while (true) {
            // Read the word before asking: a wake that lands after the
            // question has bumped it, and the wait returns at once.
            const seen = self.wake.load(.acquire);
            if (goal.met(goal.context)) return;
            if (policy == .debugger) {
                if (self.takeMessage()) |message| {
                    message.run(message.data);
                    continue;
                }
            }
            if (self.isClosed()) return;
            futexIo().futexWaitTimeout(u32, &self.wake.raw, seen, .none) catch {};
        }
    }

    pub fn isClosed(self: *BrowserPause) bool {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        return self.closed;
    }

    /// The Browser ends: posts fail from now on, and every queued message
    /// is dropped (outside the lock).
    pub fn close(self: *BrowserPause) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        self.closed = true;
        var queued = self.messages;
        self.messages = .empty;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        for (queued.items) |task| task.drop(task.data);
        queued.deinit(self.allocator);
        self.notify();
    }
};

fn futexIo() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

test "a dialog pause leaves session messages queued; a debugger pause runs them in order until its goal" {
    const testing = std.testing;
    var pause = BrowserPause.init(testing.allocator);
    defer pause.deinit();
    const Log = struct {
        ran: std.ArrayListUnmanaged(u8) = .empty,
        quit_after: u8 = 0,
        fn run(data: ?*anyopaque) void {
            const entry: *Entry = @ptrCast(@alignCast(data.?));
            entry.log.ran.append(testing.allocator, entry.tag) catch {};
        }
        fn drop(data: ?*anyopaque) void {
            _ = data;
        }
        fn quit(context: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(context));
            return self.ran.items.len >= self.quit_after;
        }
        fn answered(context: *anyopaque) bool {
            const flag: *bool = @ptrCast(@alignCast(context));
            return flag.*;
        }
        const Entry = struct { log: *@This(), tag: u8 };
    };
    var log: Log = .{ .quit_after = 2 };
    defer log.ran.deinit(testing.allocator);
    var a: Log.Entry = .{ .log = &log, .tag = 'a' };
    var b: Log.Entry = .{ .log = &log, .tag = 'b' };
    try testing.expect(pause.postMessage(.{ .run = Log.run, .drop = Log.drop, .data = &a }));
    try testing.expect(pause.postMessage(.{ .run = Log.run, .drop = Log.drop, .data = &b }));
    // A dialog already answered returns at once and runs nothing.
    var answered = true;
    pause.pauseUntil(.{ .context = &answered, .met = Log.answered }, .dialog);
    try testing.expectEqualStrings("", log.ran.items);
    // The debugger's loop runs both, in order, then its goal is met.
    pause.pauseUntil(.{ .context = &log, .met = Log.quit }, .debugger);
    try testing.expectEqualStrings("ab", log.ran.items);
    try testing.expect(!pause.isPaused());
}
