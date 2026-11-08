//! WindowRealmOptions.report_window_access [window_access_reporting]: the
//! binding of each CrossOriginProperties(Window) member, the indexed and
//! named getters and the opener setter tell the accessed realm's host who
//! used what - HTML 7.1.3.3 "check if an access between two browsing
//! contexts should be reported", where Chromium's DOMWindow::ReportCoopAccess
//! runs it (make_report_coop_access in its generated bindings) - same origin
//! or not, with the incumbent realm as the accessor, and never for a realm's
//! use of its own Window.
//!
//! The host here is the test's: it records each call. The realms are made as
//! a page's and its frame's are (createWindowRealm with the frame's parent),
//! with the page's `w` bound to the frame's WindowProxy. A realm of a Browser
//! (a BrowserScope) is asked only while its Browser's
//! `window_access_monitored` is set - Chromium's early return on a window
//! with no CoopAccessMonitor; a realm of no Browser always is.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! and makes its own agent per test.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The test's host: IsPlatformObjectSameOrigin's one answer, and every
/// access report call - its accessor, the Window used and the property.
const Host = struct {
    same_origin: bool = true,
    calls: std.ArrayListUnmanaged(Call) = .empty,

    const Call = struct { accessor: runtime.Context, window: *runtime.Instance, property: []const u8 };

    fn isPlatformObjectSameOrigin(host: ?*anyopaque, current: runtime.Context, object: *runtime.Instance) bool {
        _ = current;
        _ = object;
        const self: *Host = @ptrCast(@alignCast(host.?));
        return self.same_origin;
    }

    fn reportWindowAccess(host: ?*anyopaque, accessor: runtime.Context, window: *runtime.Instance, property: []const u8) void {
        const self: *Host = @ptrCast(@alignCast(host.?));
        // `property` is static (the protocol says so): kept as given.
        self.calls.append(testing.allocator, .{ .accessor = accessor, .window = window, .property = property }) catch {};
    }

    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }

    fn deinit(self: *Host) void {
        self.calls.deinit(testing.allocator);
    }

    /// The properties reported since the last call, joined with ",", each
    /// checked to be an access from `accessor` to `window`.
    fn take(self: *Host, accessor: runtime.Context, window: *runtime.Instance) ![]u8 {
        var out: std.ArrayListUnmanaged(u8) = .empty;
        errdefer out.deinit(testing.allocator);
        for (self.calls.items, 0..) |call, i| {
            try testing.expect(call.accessor == accessor);
            try testing.expect(call.window == window);
            if (i != 0) try out.append(testing.allocator, ',');
            try out.appendSlice(testing.allocator, call.property);
        }
        self.calls.clearRetainingCapacity();
        return out.toOwnedSlice(testing.allocator);
    }
};

fn ignoreReport(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
    _ = host;
    _ = info;
}

const Pair = struct {
    agent: *protocol.Agent,
    page: runtime.Context,
    frame: runtime.Context,

    fn open(host: *Host) !Pair {
        return openIn(host, null);
    }

    /// The pair, made as `scope`'s realms (null: of no Browser).
    fn openIn(host: *Host, scope: ?*runtime.BrowserScope) !Pair {
        test_process.start();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &.{}, .host = null });
        errdefer protocol.destroyAgent(agent);
        const page = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .browser_scope = scope,
            .create_global_object = Host.createGlobalObject,
            .is_platform_object_same_origin = Host.isPlatformObjectSameOrigin,
            .report_window_access = Host.reportWindowAccess,
            .host = host,
        });
        errdefer protocol.destroyWindowRealm(page, .global_detached);
        const frame = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://other.test",
            .parent = page,
            .browser_scope = scope,
            .create_global_object = Host.createGlobalObject,
            .is_platform_object_same_origin = Host.isPlatformObjectSameOrigin,
            .report_window_access = Host.reportWindowAccess,
            .host = host,
        });
        const saved = host.same_origin;
        host.same_origin = true;
        defer host.same_origin = saved;
        const proxy = try protocol.evaluateClassicScript(frame, .{ .utf8 = "globalThis" }, "", null, .{ .report = ignoreReport });
        defer proxy.release();
        const global = try protocol.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, .{ .report = ignoreReport });
        defer global.release();
        try protocol.defineOwnProperty(page, global.value, "w", proxy.value, .{ .writable = true, .enumerable = false, .configurable = true });
        return .{ .agent = agent, .page = page, .frame = frame };
    }

    fn close(self: Pair) void {
        protocol.destroyWindowRealm(self.frame, .navigable_destroyed);
        protocol.destroyWindowRealm(self.page, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn run(realm: runtime.Context, source: []const u8) !void {
        const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = ignoreReport });
        testing.allocator.free(got);
    }

    fn frameWindow(self: Pair) *runtime.Instance {
        const record = self.frame.getRealm().?;
        return @ptrCast(@alignCast(record.global_object.?));
    }
};

/// Run `f`, ignoring what it throws.
const attempt = "function attempt(f) { try { f(); } catch (e) {} }\n";

fn expectReported(host: *Host, pair: Pair, expected: []const u8) !void {
    const got = try host.take(pair.page, pair.frameWindow());
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

test "a same-origin page's use of a frame's cross-origin accessible members is reported, each use once" {
    var host: Host = .{};
    defer host.deinit();
    const pair = try Pair.open(&host);
    defer pair.close();
    host.calls.clearRetainingCapacity();
    // Each use in its own try: the report comes before the member's steps,
    // which a frame with no browsing context may refuse.
    try Pair.run(pair.page, attempt ++ "[() => w.self, () => w.window, () => w.frames, () => w.closed, () => w.length, () => w.top, () => w.parent, () => w.opener].forEach(attempt)");
    // A same-origin Window's `self` and `frames` are data properties whose
    // value is the global (protocol_realms bindWindowToGlobal): no binding
    // runs for them, so only their cross-origin [[Get]] reports (below).
    try expectReported(&host, pair, "window,closed,length,top,parent,opener");
    try Pair.run(pair.page, attempt ++ "[() => w.blur(), () => w.focus(), () => w.postMessage('x', '*'), () => { w.opener = null; }, () => w.location].forEach(attempt)");
    try expectReported(&host, pair, "blur,focus,postMessage,opener,location");
    // Members outside CrossOriginProperties, and an index naming no child:
    // nothing.
    try Pair.run(pair.page, attempt ++ "[() => w.name, () => w.document, () => w[0], () => w.innerWidth].forEach(attempt)");
    try expectReported(&host, pair, "");
}

test "a cross-origin page's use of a frame's cross-origin accessible members is reported" {
    var host: Host = .{ .same_origin = false };
    defer host.deinit();
    const pair = try Pair.open(&host);
    defer pair.close();
    host.calls.clearRetainingCapacity();
    try Pair.run(pair.page, attempt ++ "[() => w.self, () => w.frames, () => w.closed, () => w.length, () => w.blur()].forEach(attempt)");
    try expectReported(&host, pair, "self,frames,closed,length,blur");
}

test "a realm's use of its own Window is never reported" {
    var host: Host = .{};
    defer host.deinit();
    const pair = try Pair.open(&host);
    defer pair.close();
    host.calls.clearRetainingCapacity();
    try Pair.run(pair.frame, attempt ++ "[() => self, () => window, () => frames, () => closed, () => length, () => top, () => parent, () => opener, () => blur(), () => focus()].forEach(attempt)");
    try Pair.run(pair.page, attempt ++ "[() => self, () => window, () => closed, () => length].forEach(attempt)");
    try testing.expectEqual(@as(usize, 0), host.calls.items.len);
}

test "a Browser's realms ask the host only once its access monitoring has started" {
    var scope = runtime.BrowserScope.init(std.heap.c_allocator);
    defer scope.deinit();
    var host: Host = .{};
    defer host.deinit();
    const pair = try Pair.openIn(&host, &scope);
    defer pair.close();
    host.calls.clearRetainingCapacity();
    // Same origin: the attributes, the operation and the opener setter.
    // Cross origin: the cross-origin [[Get]] of self and frames.
    const same_origin = attempt ++ "[() => w.window, () => w.closed, () => w.blur(), () => { w.opener = null; }].forEach(attempt)";
    const cross_origin = attempt ++ "[() => w.self, () => w.frames].forEach(attempt)";
    // No virtual browsing context group has split in the Browser: no access
    // can be reported, and none is asked about.
    try Pair.run(pair.page, same_origin);
    host.same_origin = false;
    try Pair.run(pair.page, cross_origin);
    host.same_origin = true;
    try testing.expectEqual(@as(usize, 0), host.calls.items.len);
    // dom.coop_reporting.startMonitoring's store: every use is asked again.
    scope.window_access_monitored.store(true, .monotonic);
    try Pair.run(pair.page, same_origin);
    try expectReported(&host, pair, "window,closed,blur,opener");
    host.same_origin = false;
    try Pair.run(pair.page, cross_origin);
    host.same_origin = true;
    try expectReported(&host, pair, "self,frames");
}
