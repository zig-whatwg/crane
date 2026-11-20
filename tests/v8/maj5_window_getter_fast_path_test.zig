//! Window's `window`, `self` and `frames` getters (HTML 7.2.1.1: "return
//! this's relevant realm.[[GlobalEnv]].[[GlobalThisValue]]") read on the
//! getter's own global - nearly every read there is - are answered with no
//! handle, before the DOM-algorithm bracket (lane maj5,
//! binding_plumbing.answerWindowGetterOnOwnGlobal). These tests pin what that
//! path must keep:
//! - the value: the realm's WindowProxy, from its own script and from its
//!   parent's (`w.self`: the getter's creation realm is the frame's, the
//!   caller's is the parent's);
//! - HTML 7.1.3.3's access report: asked only while the Browser monitors
//!   access (Chromium's DOMWindow::ReportCoopAccess early return), each use
//!   once, never a realm's use of its own Window;
//! - every other receiver's result: another realm's WindowProxy, a missing
//!   receiver, a plain object, Object.create(Window.prototype), and a
//!   destroyed frame's WindowProxy, which the general path answers.
//!
//! The realms are made as a page's and its frame's are (createWindowRealm
//! with the frame's parent), with the page's `w` bound to the frame's
//! WindowProxy, as tests/v8/coi2_window_access_report_test.zig makes them.
//! The file shares tests/v8's process: it starts the engine as any file may
//! and makes its own agent per test.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The test's host: every access report call, as "<property>" joined by ",".
const Host = struct {
    calls: std.ArrayListUnmanaged(Call) = .empty,

    const Call = struct { accessor: runtime.Context, window: *runtime.Instance, property: []const u8 };

    fn isPlatformObjectSameOrigin(host: ?*anyopaque, current: runtime.Context, object: *runtime.Instance) bool {
        _ = host;
        _ = current;
        _ = object;
        return true;
    }

    fn reportWindowAccess(host: ?*anyopaque, accessor: runtime.Context, window: *runtime.Instance, property: []const u8) void {
        const self: *Host = @ptrCast(@alignCast(host.?));
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
    frame: ?runtime.Context,

    /// A page and its frame, as `scope`'s realms.
    fn open(host: *Host, scope: *runtime.BrowserScope) !Pair {
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
            .origin = "https://example.test",
            .parent = page,
            .browser_scope = scope,
            .create_global_object = Host.createGlobalObject,
            .is_platform_object_same_origin = Host.isPlatformObjectSameOrigin,
            .report_window_access = Host.reportWindowAccess,
            .host = host,
        });
        const proxy = try protocol.evaluateClassicScript(frame, .{ .utf8 = "globalThis" }, "", null, .{ .report = ignoreReport });
        defer proxy.release();
        const global = try protocol.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, .{ .report = ignoreReport });
        defer global.release();
        try protocol.defineOwnProperty(page, global.value, "w", proxy.value, .{ .writable = true, .enumerable = false, .configurable = true });
        return .{ .agent = agent, .page = page, .frame = frame };
    }

    /// The frame's navigable is destroyed: its realm ends, the page keeps
    /// its WindowProxy in `w`.
    fn destroyFrame(self: *Pair) void {
        if (self.frame) |frame| protocol.destroyWindowRealm(frame, .navigable_destroyed);
        self.frame = null;
    }

    fn close(self: *Pair) void {
        self.destroyFrame();
        protocol.destroyWindowRealm(self.page, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn frameWindow(self: Pair) *runtime.Instance {
        const record = self.frame.?.getRealm().?;
        return @ptrCast(@alignCast(record.global_object.?));
    }

    fn pageWindow(self: Pair) *runtime.Instance {
        const record = self.page.getRealm().?;
        return @ptrCast(@alignCast(record.global_object.?));
    }
};

/// `source`'s completion value, as a string, in `realm`.
fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = ignoreReport });
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, expected, got)) std.debug.print("{s}\n  expected {s}\n  got      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

fn expectReported(host: *Host, accessor: runtime.Context, window: *runtime.Instance, expected: []const u8) !void {
    const got = try host.take(accessor, window);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

/// Reads on a realm's own global: the bare names, `globalThis.x`, and each
/// getter called with no receiver (V8 makes it the function's global).
const own_reads =
    \\[self === globalThis, window === globalThis, frames === globalThis,
    \\ globalThis.self === globalThis, globalThis.frames === globalThis,
    \\ Object.getOwnPropertyDescriptor(globalThis, 'self').get.call(undefined) === globalThis,
    \\ Object.getOwnPropertyDescriptor(globalThis, 'frames').get.call(null) === globalThis,
    \\ Object.getOwnPropertyDescriptor(globalThis, 'window').get.call(globalThis) === globalThis].join()
;
const own_reads_result = "true,true,true,true,true,true,true,true";

/// The parent's reads of the frame's members: the getter is the frame's
/// (its creation realm, and the current one while it runs), the caller the
/// page.
const parent_reads = "[w.self === w, w.window === w, w.frames === w].join()";

test "self, window and frames on their own global answer the realm's WindowProxy, with no report while access is not monitored" {
    var scope = runtime.BrowserScope.init(std.heap.c_allocator);
    defer scope.deinit();
    var host: Host = .{};
    defer host.deinit();
    var pair = try Pair.open(&host, &scope);
    defer pair.close();
    host.calls.clearRetainingCapacity();
    try expectEval(pair.frame.?, own_reads, own_reads_result);
    try expectEval(pair.page, own_reads, own_reads_result);
    try expectEval(pair.page, parent_reads, "true,true,true");
    // Many reads in a loop, as script makes them.
    try expectEval(pair.page, "let k = 0; for (let i = 0; i < 1000; i++) if (w.self === w && self === window && w.frames === w) k++; String(k)", "1000");
    try testing.expectEqual(@as(usize, 0), host.calls.items.len);
}

test "once the Browser monitors access, the parent's reads are reported each once, the realm's own never" {
    var scope = runtime.BrowserScope.init(std.heap.c_allocator);
    defer scope.deinit();
    var host: Host = .{};
    defer host.deinit();
    var pair = try Pair.open(&host, &scope);
    defer pair.close();
    host.calls.clearRetainingCapacity();
    scope.window_access_monitored.store(true, .monotonic);
    try expectEval(pair.page, parent_reads, "true,true,true");
    try expectReported(&host, pair.page, pair.frameWindow(), "self,window,frames");
    try expectEval(pair.frame.?, own_reads, own_reads_result);
    try expectEval(pair.page, own_reads, own_reads_result);
    try testing.expectEqual(@as(usize, 0), host.calls.items.len);
    // Monitoring stops: nothing is asked again.
    scope.window_access_monitored.store(false, .monotonic);
    try expectEval(pair.page, parent_reads, "true,true,true");
    try testing.expectEqual(@as(usize, 0), host.calls.items.len);
}

/// Each getter called on `receiver` (a source expression): "proxy" for the
/// frame's WindowProxy, "window" for the page's, else the error's name.
const odd_receivers =
    \\(() => {
    \\  const out = [];
    \\  for (const name of ['self', 'window', 'frames']) {
    \\    const get = Object.getOwnPropertyDescriptor(globalThis, name).get;
    \\    for (const receiver of [w, undefined, null, {}, Object.create(Window.prototype)]) {
    \\      try {
    \\        const v = get.call(receiver);
    \\        out.push(v === w ? 'proxy' : v === globalThis ? 'window' : typeof v);
    \\      } catch (e) {
    \\        out.push(e.name);
    \\      }
    \\    }
    \\  }
    \\  return out.join();
    \\})()
;

test "the page's getters called on another receiver keep the general path's results" {
    var scope = runtime.BrowserScope.init(std.heap.c_allocator);
    defer scope.deinit();
    var host: Host = .{};
    defer host.deinit();
    var pair = try Pair.open(&host, &scope);
    defer pair.close();
    // The frame's WindowProxy acts on its Window (THE Window-receiver rule),
    // whose relevant realm is the frame's; a missing receiver is the page's
    // global; anything else is no Window.
    const each = "proxy,window,window,TypeError,TypeError";
    try expectEval(pair.page, odd_receivers, each ++ "," ++ each ++ "," ++ each);
}

test "a destroyed frame's WindowProxy, read from its parent" {
    var scope = runtime.BrowserScope.init(std.heap.c_allocator);
    defer scope.deinit();
    var host: Host = .{};
    defer host.deinit();
    var pair = try Pair.open(&host, &scope);
    defer pair.close();
    try expectEval(pair.page, "globalThis.getSelf = Object.getOwnPropertyDescriptor(w, 'self').get; 'ok'", "ok");
    pair.destroyFrame();
    const reads =
        \\[() => w.self === w, () => w.window === w, () => w.frames === w, () => getSelf.call(w) === w, () => getSelf.call(undefined) === w]
        \\  .map((f) => { try { return String(f()); } catch (e) { return e.name; } }).join()
    ;
    // The frame's realm ended with its global still attached: its getters
    // still answer it (self-et-al.window.js), with no Window to look up.
    try expectEval(pair.page, reads, "true,true,true,true,true");
    // While the Browser monitors access, too: the ended realm has no Window
    // to report a use of.
    host.calls.clearRetainingCapacity();
    scope.window_access_monitored.store(true, .monotonic);
    try expectEval(pair.page, reads, "true,true,true,true,true");
    try testing.expectEqual(@as(usize, 0), host.calls.items.len);
}
