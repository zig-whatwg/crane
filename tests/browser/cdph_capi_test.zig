//! The host API's C ABI (include/crane.h, src/browser/capi.zig; lane cdph),
//! called as a C embedder calls it: two Browsers on two threads, each with
//! its tabs and events, sharing nothing (the instances design's B6 measure:
//! "a C test runs two Browsers on two threads through the C ABI").
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).

const std = @import("std");
const testing = std.testing;
const capi = @import("browser").capi;

const Events = struct {
    created: std.atomic.Value(u32) = .init(0),
    destroyed: std.atomic.Value(u32) = .init(0),

    fn onEvent(context: ?*anyopaque, event: *const capi.Event) callconv(.c) void {
        const self: *Events = @ptrCast(@alignCast(context.?));
        switch (event.kind) {
            @backingInt(capi.EventKind.tab_created) => _ = self.created.fetchAdd(1, .acq_rel),
            @backingInt(capi.EventKind.tab_destroyed) => _ = self.destroyed.fetchAdd(1, .acq_rel),
            else => {},
        }
    }
};

/// One embedder thread's whole use of a Browser.
fn useOneBrowser(failed: *std.atomic.Value(bool), marker: []const u8) void {
    run(marker) catch failed.store(true, .release);
}

fn run(marker: []const u8) !void {
    var events: Events = .{};
    var handle: ?*capi.Handle = null;
    const options: capi.BrowserOptions = .{ .struct_size = @sizeOf(capi.BrowserOptions), .on_event = Events.onEvent, .event_context = &events };
    if (capi.crane_browser_create(&options, &handle) != .ok) return error.CreateFailed;
    defer capi.crane_browser_destroy(handle);

    var tab: u64 = 0;
    if (capi.crane_tab_create(handle, "data:text/html,<title>c</title>", false, &tab) != .ok) return error.TabFailed;
    var navigated: capi.NavigateResult = .{};
    if (capi.crane_tab_navigate(handle, tab, "data:text/html,<title>c2</title>", @backingInt(capi.Readiness.complete), &navigated) != .ok) return error.NavigateFailed;
    capi.crane_navigate_result_free(&navigated);

    var buffer: [128]u8 = undefined;
    const source = try std.fmt.bufPrint(&buffer, "globalThis.marker = '{s}'; document.title + ':' + marker", .{marker});
    var result: capi.EvaluateResult = .{};
    if (capi.crane_tab_evaluate(handle, tab, source.ptr, source.len, 0, &result) != .ok) return error.EvaluateFailed;
    defer capi.crane_evaluate_result_free(&result);
    if (result.exception) return error.Threw;
    var expected: [128]u8 = undefined;
    const want = try std.fmt.bufPrint(&expected, "{{\"type\":\"string\",\"value\":\"c2:{s}\"}}", .{marker});
    if (!std.mem.eql(u8, want, std.mem.span(result.json.?))) return error.WrongResult;

    var infos: ?[*]capi.TabInfo = null;
    var count: usize = 0;
    if (capi.crane_tab_list(handle, &infos, &count) != .ok) return error.ListFailed;
    defer capi.crane_tab_info_free(infos, count);
    if (count != 2) return error.WrongTabCount;

    if (capi.crane_tab_close(handle, tab, false) != .ok) return error.CloseFailed;
    if (capi.crane_tab_close(handle, tab, false) != .no_such_tab) return error.ClosedTwice;
    if (events.created.load(.acquire) != 1 or events.destroyed.load(.acquire) != 1) return error.WrongEvents;
}

test "two Browsers on two threads through the C ABI: tabs, navigation, evaluation, events, nothing shared" {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(&.{ .struct_size = @sizeOf(capi.ProcessOptions) }));
    var failed: std.atomic.Value(bool) = .init(false);
    const a = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, useOneBrowser, .{ &failed, "a" });
    const b = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, useOneBrowser, .{ &failed, "b" });
    a.join();
    b.join();
    try testing.expect(!failed.load(.acquire));
}

test "the C ABI refuses what it cannot do: a profile directory, a PAC proxy, null arguments" {
    try testing.expectEqual(capi.Status.ok, capi.crane_process_init(null));
    var handle: ?*capi.Handle = null;
    try testing.expectEqual(capi.Status.unsupported, capi.crane_browser_create(&.{ .struct_size = @sizeOf(capi.BrowserOptions), .profile_dir = "/tmp/crane-profile" }, &handle));
    const pac: capi.Proxy = .{ .kind = @backingInt(capi.ProxyKind.pac), .pac_url = "http://example.test/proxy.pac" };
    try testing.expectEqual(capi.Status.unsupported, capi.crane_browser_create(&.{ .struct_size = @sizeOf(capi.BrowserOptions), .proxy = &pac }, &handle));
    try testing.expectEqual(capi.Status.invalid_argument, capi.crane_browser_create(null, null));
    try testing.expectEqual(capi.Status.invalid_argument, capi.crane_tab_close(null, 1, false));
}
