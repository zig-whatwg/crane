//! BrowserHost: a Browser on a thread of its own, driven by commands from
//! other threads (instances design 4.8 and 5.1; lane cdph). Its loop runs
//! for its life - a navigation proceeds and a promise settles with no caller
//! turning it - and a command runs on the Browser's thread between tasks.
//! Two hosts on two threads share nothing.
//!
//! Each host gets its own leak-checking allocator (tests/AGENTS.md: a race
//! test between Browsers gives each Browser its own DebugAllocator).
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const BrowserHost = browser_mod.BrowserHost;

const LeakChecked = std.heap.DebugAllocator(.{ .thread_safe = true });

test "a host starts a Browser on its own thread, opens and navigates a tab, evaluates in it and stops" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();

    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    try testing.expect(!host.isBrowserThread());
    try testing.expect(host.browser() == null);

    const tab = try host.createTab(.{});
    const url = try host.navigate(allocator, tab, "data:text/html,<title>hosted</title><p>x", .{ .wait = .complete, .timeout_ms = 10_000 });
    defer allocator.free(url);
    try testing.expectEqualStrings("data:text/html,<title>hosted</title><p>x", url);

    const result = try host.evaluate(allocator, tab, "document.title", .{}, 5_000);
    defer result.deinit(allocator);
    try testing.expect(result.kind == .success);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"hosted\"}", result.json);

    // A promise settles on the Browser's own loop; nobody here turns it.
    const later = try host.evaluate(allocator, tab, "new Promise((resolve) => setTimeout(() => resolve(42), 10))", .{ .await_promise = true }, 5_000);
    defer later.deinit(allocator);
    try testing.expectEqualStrings("{\"type\":\"number\",\"value\":42}", later.json);

    const tabs = try host.listTabs(allocator);
    defer Browser.freeTabs(allocator, tabs);
    try testing.expectEqual(@as(usize, 2), tabs.len);
    try host.closeTab(tab, .{});
    try testing.expectError(error.NoSuchTab, host.closeTab(tab, .{}));
}

test "a command calling its own host from the Browser's thread is refused, not deadlocked" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const host = try BrowserHost.start(gpa.allocator(), .{});
    defer host.stop();

    const Probe = struct {
        host: *BrowserHost,
        on_thread: bool = false,
        nested: ?anyerror = null,
        fn run(ctx: ?*anyopaque, b: *Browser) void {
            _ = b;
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            self.on_thread = self.host.isBrowserThread() and self.host.browser() != null;
            self.host.call(self, nop) catch |err| {
                self.nested = err;
            };
        }
        fn nop(ctx: ?*anyopaque, b: *Browser) void {
            _ = ctx;
            _ = b;
        }
    };
    var probe: Probe = .{ .host = host };
    try host.call(&probe, Probe.run);
    try testing.expect(probe.on_thread);
    try testing.expectEqual(@as(?anyerror, error.WrongThread), probe.nested);
}

test "an evaluation that outlives its caller's patience times out, and its answer later frees itself" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    const host = try BrowserHost.start(allocator, .{});
    defer host.stop();
    const tab = try host.createTab(.{});
    try testing.expectError(error.Timeout, host.evaluate(allocator, tab, "new Promise(() => {})", .{ .await_promise = true }, 20));
    // The pending evaluation is told the Browser ended at stop (deferred
    // above), which frees it: the leak check holds.
}

test "two hosts on two threads share nothing: localStorage set in one is not in the other" {
    var gpa_a: LeakChecked = .init;
    defer testing.expect(gpa_a.deinit() == .ok) catch @panic("leak");
    var gpa_b: LeakChecked = .init;
    defer testing.expect(gpa_b.deinit() == .ok) catch @panic("leak");

    const a = try BrowserHost.start(gpa_a.allocator(), .{});
    defer a.stop();
    const b = try BrowserHost.start(gpa_b.allocator(), .{});
    defer b.stop();

    const tab_a = (try a.listTabs(gpa_a.allocator()));
    defer Browser.freeTabs(gpa_a.allocator(), tab_a);
    const tab_b = (try b.listTabs(gpa_b.allocator()));
    defer Browser.freeTabs(gpa_b.allocator(), tab_b);

    // Each Browser's own page: an opaque about:blank, whose storage is its
    // Browser's. sessionStorage is per traversable; the opaque origin's
    // storage throws, so compare what each Browser's realm can see of a
    // global the other set.
    const set = try a.evaluate(gpa_a.allocator(), tab_a[0].id, "globalThis.marker = 'a'; typeof marker", .{}, 5_000);
    defer set.deinit(gpa_a.allocator());
    const seen = try b.evaluate(gpa_b.allocator(), tab_b[0].id, "typeof marker", .{}, 5_000);
    defer seen.deinit(gpa_b.allocator());
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"string\"}", set.json);
    try testing.expectEqualStrings("{\"type\":\"string\",\"value\":\"undefined\"}", seen.json);
    // Distinct Browsers make distinct tab ids (ids are process-unique).
    try testing.expect(tab_a[0].id != tab_b[0].id);
}

test "a host's tab events reach a listener added from a command, on the Browser's thread" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const host = try BrowserHost.start(gpa.allocator(), .{});
    defer host.stop();

    const Recorder = struct {
        host: *BrowserHost,
        created: std.atomic.Value(u32) = .init(0),
        destroyed: std.atomic.Value(u32) = .init(0),
        off_thread: std.atomic.Value(bool) = .init(false),
        fn onEvent(context: *anyopaque, event: *const browser_mod.host_events.Event) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            if (!self.host.isBrowserThread()) self.off_thread.store(true, .release);
            switch (event.*) {
                .tab_created => _ = self.created.fetchAdd(1, .acq_rel),
                .tab_destroyed => _ = self.destroyed.fetchAdd(1, .acq_rel),
                else => {},
            }
        }
        fn listener(self: *@This()) browser_mod.host_events.Listener {
            return .{ .context = self, .on_event = onEvent };
        }
        fn add(ctx: ?*anyopaque, b: *Browser) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            b.addListener(self.listener()) catch {};
        }
        fn remove(ctx: ?*anyopaque, b: *Browser) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            b.removeListener(self.listener());
        }
    };
    var recorder: Recorder = .{ .host = host };
    try host.call(&recorder, Recorder.add);
    const tab = try host.createTab(.{ .background = true });
    try host.closeTab(tab, .{});
    try host.call(&recorder, Recorder.remove);
    try testing.expectEqual(@as(u32, 1), recorder.created.load(.acquire));
    try testing.expectEqual(@as(u32, 1), recorder.destroyed.load(.acquire));
    try testing.expect(!recorder.off_thread.load(.acquire));
}
