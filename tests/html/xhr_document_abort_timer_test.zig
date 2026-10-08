//! A Window host can supply timers without an event loop. Cancellation
//! must remain deferred and every timer end must release the pending owner.
const std = @import("std");
const runtime = @import("runtime");
const browser_mod = @import("browser");
const async_fetch = @import("fetch").algorithms.async_fetch;

const Scenario = enum { delivery, replacement, clear_miss, dropped, allocation_failed, no_timer };

const Timer = struct {
    entry: ?struct { callback: runtime.TimerCallback, data: ?*anyopaque, drop: runtime.TimerDrop } = null,
    clear_miss: bool = false,
    allocation_failed: bool = false,

    fn interface(self: *@This()) runtime.TimerInterface {
        return .{ .ctx = self, .vtable = &vtable };
    }

    fn plain(_: *anyopaque, _: u64, _: runtime.TimerCallback, _: ?*anyopaque) runtime.TimerId {
        return 0;
    }

    fn owned(context: *anyopaque, _: u64, callback: runtime.TimerCallback, data: ?*anyopaque, drop_fn: runtime.TimerDrop) runtime.TimerId {
        const self: *@This() = @ptrCast(@alignCast(context));
        if (self.allocation_failed) return 0;
        std.debug.assert(self.entry == null);
        self.entry = .{ .callback = callback, .data = data, .drop = drop_fn };
        return 17;
    }

    fn clear(context: *anyopaque, id: runtime.TimerId) bool {
        const self: *@This() = @ptrCast(@alignCast(context));
        if (self.clear_miss or id != 17 or self.entry == null) return false;
        self.entry = null;
        return true;
    }

    fn run(self: *@This()) void {
        const entry = self.entry orelse return;
        self.entry = null;
        entry.callback(entry.data);
    }

    fn drop(self: *@This()) void {
        const entry = self.entry orelse return;
        self.entry = null;
        entry.drop(entry.data);
    }

    const vtable: runtime.TimerVTable = .{ .setTimeout = plain, .setTimeoutOwned = owned, .clearTimeout = clear };
};

fn check(scenario: Scenario) !void {
    const Run = struct {
        scenario: Scenario,
        failure: ?anyerror = null,

        fn thread(self: *@This()) void {
            self.body() catch |err| {
                self.failure = err;
            };
        }

        fn body(self: *@This()) !void {
            const allocator = std.testing.allocator;
            var browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigate("about:blank", .window);
            const page = browser.current_context orelse return error.TestUnexpectedResult;
            try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
            const realm = page.realm orelse return error.TestUnexpectedResult;
            const saved_loop = realm.event_loop;
            const saved_timer = realm.timer;
            defer {
                realm.event_loop = saved_loop;
                realm.timer = saved_timer;
            }
            var timer: Timer = .{
                .clear_miss = self.scenario == .clear_miss,
                .allocation_failed = self.scenario == .allocation_failed,
            };
            defer timer.drop();
            realm.event_loop = null;
            realm.timer = timer.interface();
            const before = async_fetch.inFlight();
            try page.runScript(
                \\globalThis.events = [];
                \\globalThis.request = new XMLHttpRequest();
                \\request.open('GET', 'http://127.0.0.1:65533/pending');
                \\request.onabort = () => events.push('abort');
                \\request.onloadend = () => events.push('loadend');
                \\request.send();
            );
            try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            if (self.scenario == .no_timer) realm.timer = null;
            try page.runScript("window.stop(); if (request.readyState !== 1 || events.length !== 0) throw new Error('stop delivered inline')");
            try std.testing.expectEqual(before, async_fetch.inFlight());
            if (self.scenario == .allocation_failed or self.scenario == .no_timer) {
                try std.testing.expect(timer.entry == null);
                return;
            }
            try std.testing.expect(timer.entry != null);
            switch (self.scenario) {
                .delivery => {
                    timer.run();
                    try page.runScript("if (request.readyState !== 4 || events.join(',') !== 'abort,loadend') throw new Error('timer lost error delivery')");
                },
                .replacement, .clear_miss => {
                    try page.runScript("request.open('GET', 'http://127.0.0.1:65533/replacement')");
                    try std.testing.expectEqual(self.scenario == .clear_miss, timer.entry != null);
                    timer.run();
                    try page.runScript("if (request.readyState !== 1 || events.length !== 0) throw new Error('old timer reached replacement')");
                },
                .dropped => {
                    timer.drop();
                    try page.runScript("if (events.length !== 0) throw new Error('timer drop dispatched events')");
                },
                .allocation_failed, .no_timer => unreachable,
            }
        }
    };
    var run: Run = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

test "timer-only Window delivers document abort on its owned timer" {
    try check(.delivery);
}
test "open cancels a queued timer-only document abort" {
    try check(.replacement);
}
test "failed clear preserves owner until timer callback suppresses delivery" {
    try check(.clear_miss);
}
test "timer teardown drops document abort without events or leaked owner" {
    try check(.dropped);
}
test "failed owned timer allocation safely discards document abort" {
    try check(.allocation_failed);
}
test "lost host scheduling safely discards document abort" {
    try check(.no_timer);
}
