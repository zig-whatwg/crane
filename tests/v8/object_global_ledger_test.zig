//! The adapter's `live_object_globals` ledger counts every live Global<Object>
//! the wrapper hands out, whichever entry point made it and whichever dispose
//! releases it.
//!
//! It drifted NEGATIVE on main (lane worklets): `v8_Object_New` - and its
//! siblings `v8_Object_NewWithNullPrototype` and `v8_Object_NewInContext`,
//! with eleven more Global<Object> entry points - did not count the handle
//! they made, while `v8_Object_Dispose` took one away for every handle it was
//! given. And the six entry points that did count (`v8_Context_Global`,
//! `This`, the prototype getters, `NewInstance`) left one counted for every
//! handle released through a generic dispose (`v8_Global_Dispose`,
//! `v8_Value_Dispose`), which never took one away: the binding releases a
//! result as a Value. A ledger kept by entry point is only as good as its
//! least-counted site (docs/lessons/testing-a-counter-that-drifts-per-call-
//! hides-a-leak-per-call.md), and one kept by dispose type drifts on generic
//! disposal (testing-typed-handle-counters-can-drift-on-generic-disposal.md).
//!
//! So the ledger is kept by HANDLE, as `live_string_globals` is: every
//! Global<Object> is marked when it is made, and every dispose a handle can
//! reach reads the mark back. These tests pin that: N made and N released -
//! by the typed dispose or a generic one - leave the ledger where it started,
//! and N held read N. V8's own global handle bytes are the cross-check with
//! no bookkeeping in it.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

fn setup() !void {
    try protocol.initializeEngine(.{});
    interfaces.process_hooks.startHooksForTest();
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
}

const no_hooks: protocol.HostHooks = .{};

const N = 64;

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn isolate(self: Page) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }

    fn context(self: Page) *ffi.Context {
        return @ptrCast(@alignCast(self.realm.engine_ctx.?));
    }
};

fn ledger() i64 {
    return ffi.v8_Debug_LiveObjectGlobals();
}

/// How a test releases a handle it made.
const Release = enum {
    object_dispose,
    global_dispose,
    value_dispose,

    fn run(self: Release, handle: *ffi.Object) void {
        switch (self) {
            .object_dispose => ffi.v8_Object_Dispose(handle),
            .global_dispose => ffi.v8_Global_Dispose(@ptrCast(handle)),
            .value_dispose => ffi.v8_Value_Dispose(@ptrCast(handle)),
        }
    }
};

/// What a test makes a handle with.
const Make = enum {
    object_new,
    object_new_with_null_prototype,
    object_new_in_context,
    context_global,

    fn run(self: Make, page: Page) ?*ffi.Object {
        return switch (self) {
            .object_new => ffi.v8_Object_New(page.isolate()),
            .object_new_with_null_prototype => ffi.v8_Object_NewWithNullPrototype(page.context()),
            .object_new_in_context => ffi.v8_Object_NewInContext(page.context()),
            .context_global => ffi.v8_Context_Global(page.context()),
        };
    }
};

/// N handles made with `make` read +N while held, and the ledger is back
/// where it started once `release` has released them all.
fn expectBalanced(page: Page, make: Make, release: Release) !void {
    var handles: [N]*ffi.Object = undefined;
    const start = ledger();
    const bytes_start = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    for (&handles) |*handle| handle.* = make.run(page) orelse return error.NoObject;
    const held = ledger();
    const bytes_held = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    for (handles) |handle| release.run(handle);
    const end = ledger();
    const bytes_end = ffi.v8_Isolate_GetGlobalHandleBytes(page.isolate());
    if (held - start != N or end != start) {
        std.debug.print("{d} x {s} then {s}: live_object_globals {d} -> {d} held -> {d} released (global handle bytes {d} -> {d} -> {d})\n", .{ N, @tagName(make), @tagName(release), start, held, end, bytes_start, bytes_held, bytes_end });
    }
    // The cross-check: V8 itself saw N handles made and N released.
    try testing.expect(bytes_held > bytes_start);
    try testing.expectEqual(bytes_start, bytes_end);
    try testing.expectEqual(@as(i64, N), held - start);
    try testing.expectEqual(start, end);
}

test "v8_Object_New is counted when made and when released by v8_Object_Dispose" {
    const page = try Page.open();
    defer page.close();
    try expectBalanced(page, .object_new, .object_dispose);
}

test "v8_Object_New released as a Value (the binding's release) leaves the ledger where it started" {
    const page = try Page.open();
    defer page.close();
    try expectBalanced(page, .object_new, .global_dispose);
    try expectBalanced(page, .object_new, .value_dispose);
}

test "the other object constructors are counted the same way" {
    const page = try Page.open();
    defer page.close();
    try expectBalanced(page, .object_new_with_null_prototype, .object_dispose);
    try expectBalanced(page, .object_new_in_context, .object_dispose);
    try expectBalanced(page, .object_new_in_context, .global_dispose);
}

test "a counted entry point released through a generic dispose leaves nothing counted" {
    const page = try Page.open();
    defer page.close();
    try expectBalanced(page, .context_global, .object_dispose);
    try expectBalanced(page, .context_global, .global_dispose);
    try expectBalanced(page, .context_global, .value_dispose);
}

test "a binding call that makes and releases objects leaves the ledger where it started" {
    const page = try Page.open();
    defer page.close();
    var reports: usize = 0;
    const Reporter = struct {
        fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
            const count: *usize = @ptrCast(@alignCast(host.?));
            count.* += 1;
            std.debug.print("reported: {s}\n", .{info.message});
        }
    };
    const loop =
        \\(() => {
        \\  // Made once: a wrapper lives until the collector takes it.
        \\  const rect = globalThis.rect ||= new DOMRect(1, 2, 3, 4);
        \\  const point = globalThis.point ||= new DOMPoint(1, 2);
        \\  for (var k = 0; k < 64; k++) { rect.toJSON(); point.toJSON(); rect.x; point.matrixTransform; }
        \\  return "ok";
        \\})()
    ;
    // A first round makes what later rounds reuse (templates, caches).
    {
        const got = try protocol.evaluateClassicScriptToString(page.realm, .{ .utf8 = loop }, "", null, testing.allocator, .{ .report = Reporter.report, .host = &reports });
        testing.allocator.free(got);
    }
    const start = ledger();
    {
        const got = try protocol.evaluateClassicScriptToString(page.realm, .{ .utf8 = loop }, "", null, testing.allocator, .{ .report = Reporter.report, .host = &reports });
        defer testing.allocator.free(got);
        try testing.expectEqualStrings("ok", got);
    }
    const end = ledger();
    try testing.expectEqual(@as(usize, 0), reports);
    if (end != start) std.debug.print("128 toJSON() calls and 128 reads: live_object_globals {d} -> {d}\n", .{ start, end });
    try testing.expectEqual(start, end);
}
