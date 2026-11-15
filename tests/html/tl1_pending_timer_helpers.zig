//! Lane tl1's tests share this: one Browser under std.testing.allocator whose page arms something on a
//! timer and then ends with the timer still pending.
//!
//! A timer armed with heap data frees that data when it fires or when its owner cancels it. A Browser's end
//! is the third way a timer ends: the timer manager goes with its event loop and no timer fires again
//! (docs/lessons/architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md). Each test
//! arms one kind of timer, ends the Browser, and the allocator names what nobody freed.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");

/// A fresh thread has none of the per-thread state other tests of this executable left.
pub fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            exercise() catch |err| {
                std.debug.print("test thread failed: {s}\n", .{@errorName(err)});
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

pub const Page = struct {
    browser: *browser_mod.Browser,

    /// A Browser showing `html`, its document's URL `base_url`.
    pub fn open(html: []const u8, base_url: []const u8) !Page {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigateWithOptions(base_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML(html, .{ .base_url = base_url });
        return .{ .browser = browser };
    }

    /// The Browser's end, whatever is still pending.
    pub fn close(self: Page) void {
        self.browser.deinit();
    }

    /// Run `source`; a thrown error fails the test.
    pub fn run(self: Page, source: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        page.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    /// The page's realm: its `timer` is where the page's objects arm their timers.
    pub fn realm(self: Page) !runtime.Context {
        const page = self.browser.current_context orelse return error.NoPage;
        return page.realm orelse error.NoRealm;
    }

    /// Turn the event loop for about `ms` milliseconds of real time.
    pub fn turn(self: Page, ms: u64) !void {
        _ = try self.browser.runEventLoopBlocking(ms);
    }

    /// Turn the event loop until the page's global `state` is no longer 'pending', and expect `want`.
    pub fn waitForState(self: Page, want: []const u8) !void {
        const page = self.browser.current_context orelse return error.NoPage;
        for (0..500) |_| {
            _ = try self.browser.runEventLoopBlocking(10);
            const state = try page.evaluateScriptToString("String(globalThis.state)", testing.allocator);
            defer testing.allocator.free(state);
            if (std.mem.eql(u8, state, "pending")) continue;
            try testing.expectEqualStrings(want, state);
            return;
        }
        return error.StateStillPending;
    }
};

/// The script that sets `frame` to the window of the page's first iframe.
pub const frame_window =
    \\const frame = document.querySelector('iframe').contentWindow;
    \\if (!frame || frame === window) throw new Error('the page has no second window');
    \\
;

/// A timer that ENDS BEFORE the objects that armed timers on it, as a timer manager does when its event loop
/// goes first (NativeTimerManager.deinit): at its end an owned timer's data is dropped, a plain timer's data
/// is left to whoever armed it, nothing fires again, and a clearTimeout that still reaches it finds nothing.
/// It records what a test needs to see of that path:
/// - `plain_left`: plain timers armed with data when it ended - data only the armer can still free;
/// - `dropped`: owned timers whose data its end dropped;
/// - `clears_after_end`: clearTimeout calls made on it after its end - on a real manager, calls into freed
///   memory.
/// A test installs it as its page's realm's timer for the script that arms, then puts the realm's own back.
/// Declare it BEFORE the Browser: what armed on it keeps its interface until the Browser's end.
pub const EndingTimer = struct {
    entries: [capacity]?Entry = @splat(null),
    next_id: runtime.TimerId = 1000,
    ended: bool = false,
    plain_left: usize = 0,
    dropped: usize = 0,
    clears_after_end: usize = 0,

    const capacity = 16;

    const Entry = struct {
        id: runtime.TimerId,
        callback: runtime.TimerCallback,
        data: ?*anyopaque,
        drop: ?runtime.TimerDrop,
    };

    pub fn interface(self: *EndingTimer) runtime.TimerInterface {
        return .{ .ctx = self, .vtable = &vtable };
    }

    /// The same timer as one that cannot promise a drop: it has no owned form (TimerVTable.setTimeoutOwned
    /// is null, so TimerInterface.setTimeoutOwned answers 0), only the plain one.
    pub fn plainOnly(self: *EndingTimer) runtime.TimerInterface {
        return .{ .ctx = self, .vtable = &plain_only_vtable };
    }

    /// How many timers are armed on it now.
    pub fn armed(self: *const EndingTimer) usize {
        var count: usize = 0;
        for (self.entries) |entry| {
            if (entry != null) count += 1;
        }
        return count;
    }

    /// The timer's end.
    pub fn end(self: *EndingTimer) void {
        // Taken first, as the manager takes its timers: a drop must find nothing armed.
        const entries = self.entries;
        self.entries = @splat(null);
        self.ended = true;
        for (entries) |maybe| {
            const entry = maybe orelse continue;
            if (entry.drop) |drop| {
                self.dropped += 1;
                drop(entry.data);
            } else if (entry.data != null) {
                self.plain_left += 1;
            }
        }
    }

    /// Fire the one timer armed on it (a test's control: the same record through its callback).
    pub fn fireOne(self: *EndingTimer) !void {
        for (&self.entries) |*slot| {
            const entry = slot.* orelse continue;
            slot.* = null;
            entry.callback(entry.data);
            return;
        }
        return error.NothingArmed;
    }

    fn arm(self: *EndingTimer, callback: runtime.TimerCallback, data: ?*anyopaque, drop: ?runtime.TimerDrop) runtime.TimerId {
        if (self.ended) return 0;
        for (&self.entries) |*slot| {
            if (slot.* != null) continue;
            const id = self.next_id;
            self.next_id += 1;
            slot.* = .{ .id = id, .callback = callback, .data = data, .drop = drop };
            return id;
        }
        return 0;
    }

    fn plain(context: *anyopaque, _: u64, callback: runtime.TimerCallback, data: ?*anyopaque) runtime.TimerId {
        const self: *EndingTimer = @ptrCast(@alignCast(context));
        return self.arm(callback, data, null);
    }

    fn owned(context: *anyopaque, _: u64, callback: runtime.TimerCallback, data: ?*anyopaque, drop: runtime.TimerDrop) runtime.TimerId {
        const self: *EndingTimer = @ptrCast(@alignCast(context));
        return self.arm(callback, data, drop);
    }

    fn clear(context: *anyopaque, id: runtime.TimerId) bool {
        const self: *EndingTimer = @ptrCast(@alignCast(context));
        if (self.ended) {
            self.clears_after_end += 1;
            return false;
        }
        for (&self.entries) |*slot| {
            const entry = slot.* orelse continue;
            if (entry.id != id) continue;
            slot.* = null;
            return true;
        }
        return false;
    }

    const vtable: runtime.TimerVTable = .{ .setTimeout = plain, .setTimeoutOwned = owned, .clearTimeout = clear };
    const plain_only_vtable: runtime.TimerVTable = .{ .setTimeout = plain, .clearTimeout = clear };
};

/// What every "the timer ends first" test checks once its page has armed `count` timers on `timer`: the
/// timer ends, then the Browser - and the timer's end freed each timer's data (none was a plain timer's,
/// left to an owner that can no longer clear it), and nothing reached the timer after its end.
pub fn endTimerThenBrowser(page: Page, timer: *EndingTimer, count: usize) !void {
    var closed = false;
    defer if (!closed) page.close();
    try testing.expectEqual(count, timer.armed());
    timer.end();
    const plain_left = timer.plain_left;
    const dropped = timer.dropped;
    page.close();
    closed = true;
    try testing.expectEqual(@as(usize, 0), plain_left);
    try testing.expectEqual(count, dropped);
    try testing.expectEqual(@as(usize, 0), timer.clears_after_end);
}
