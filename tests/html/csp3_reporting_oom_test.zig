//! Failed notification-task allocation must not wedge a reporting observer.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const engine = @import("engine");

fn exercise() !void {
    const allocator = std.testing.allocator;
    const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(20);
    const setup = try browser.evaluateScript(
        \\globalThis.reportsSeen = [];
        \\globalThis.observer = new ReportingObserver(reports => {
        \\  reportsSeen.push(...reports.map(report => report.body.sequence));
        \\}, {types: ['csp-violation']});
        \\observer.observe();
        \\0;
    );
    setup.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const global = dom.reporting.globalOf(realm) orelse return error.NoGlobal;
    const state = dom.global_settings.reportingOf(global) orelse return error.NoReporting;
    try std.testing.expectEqual(@as(usize, 1), state.observers.items.len);
    const observer = state.observers.items[0];
    const observer_allocator = observer.allocator;
    // Reserve the queue first so only ObserverTask's allocation can fail.
    try observer.queue.ensureUnusedCapacity(observer_allocator, 2);
    var failing = std.testing.FailingAllocator.init(observer_allocator, .{ .fail_index = 0 });
    observer.allocator = failing.allocator();
    defer observer.allocator = observer_allocator;
    try dom.reporting.generate(global, "csp-violation", "absent-endpoint", "https://example.test/", "{\"sequence\":1}");
    const queued_after_failure = observer.queue.items.len;
    const references_after_failure = state.buffer.items[0].references;
    try std.testing.expect(failing.has_induced_failure);
    observer.allocator = observer_allocator;
    try dom.reporting.generate(global, "csp-violation", "absent-endpoint", "https://example.test/", "{\"sequence\":2}");
    _ = try browser.runEventLoopBlocking(20);
    const observed = try browser.evaluateScript("reportsSeen.length === 1 && reportsSeen[0] === 2");
    defer observed.release();
    // Check recovery first: the unfixed queue suppresses the second report's
    // notification too, although the allocator is already working again.
    try std.testing.expect(engine.toBoolean(realm, observed.borrow()));
    try std.testing.expectEqual(@as(usize, 0), queued_after_failure);
    // Only the global's buffer and delivery queue retained the first record.
    try std.testing.expectEqual(@as(usize, 2), references_after_failure);
    try std.testing.expectEqual(@as(usize, 0), observer.queue.items.len);
}

test "Reporting observer recovers after its first notification allocation fails" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
