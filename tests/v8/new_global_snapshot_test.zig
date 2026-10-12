//! A new global - a context made with no global template of its own - in an
//! agent restored from Crane's snapshot, the agent every page of the browser
//! and the WPT runner gets.
//!
//! engine.parseJsonInNewGlobal (WebCrypto "parse a JWK" step 4: JSON.parse
//! "in the context of a new global object") made its new global with a bare
//! `Context::New(isolate)` (v8_Context_New), the same call that crashed
//! engine.matchesPatternAttribute (lesson architecture-a-bare-context-new-in-
//! a-snapshot-agent-deserializes-crane-s-window-context): in an isolate
//! restored from the snapshot it deserializes the snapshot's DEFAULT context,
//! Crane's Window global with its internal fields, around a global proxy
//! sized for no template, and the bootstrapper's InitializeExperimentalGlobal
//! faults installing Math.f16round. conversions_protocol_test.zig makes its
//! isolate without a snapshot, so it never saw that. v8_Context_New and
//! v8_Context_NewWithMicrotaskQueue (no caller today, the same bare call) are
//! pinned here too, in that agent.
//!
//! The snapshot is the one this build generates, zig-out/bin/whatwg_snapshot.bin
//! (the `snapshot` step; `wpt-runner` depends on it). Without it the tests are
//! skipped, as tests/v8/snapshot_test.zig's are.
//!
//! They run only where this file is the first in its process to start V8, as
//! pattern_attribute_snapshot_test.zig's do and for its reason: in tests/v8's
//! shared executable, restoring the snapshot after other files had started V8
//! crashed inside V8's isolate deserialization, before any code of the
//! operation ran. So there they skip, saying so; they run under
//! `-Dtest-file=` and `-Dtest-isolation=file`. The engine is given the
//! snapshot for these tests only and forgets it after (deinitializeEngine).

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

const snapshot_path = "zig-out/bin/whatwg_snapshot.bin";

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

/// Whether V8 was not yet started in this process when this file first
/// asked: decided once, by the first test here to open a page.
var first_in_process: ?bool = null;

const no_hooks: protocol.HostHooks = .{};

/// An agent restored from the snapshot, and a Window realm of it restored
/// from the snapshot's context. The engine holds the snapshot while it is
/// open.
const SnapshotPage = struct {
    bytes: []u8,
    agent: *protocol.Agent,
    realm: runtime.Context,

    /// Null (the test skips) when this build's snapshot has not been
    /// generated, or when V8 was started in this process before this file.
    fn open() !?SnapshotPage {
        if (first_in_process == null) first_in_process = !ffi.v8_Platform_IsInitialized();
        if (!first_in_process.?) {
            std.log.warn("skipping: V8 was started in this process before this file; run it with -Dtest-file= or -Dtest-isolation=file", .{});
            return null;
        }
        const io = std.testing.io;
        const file = std.Io.Dir.cwd().openFile(io, snapshot_path, .{}) catch |err| {
            std.log.warn("skipping: no snapshot at {s} ({s}); `zig build snapshot` makes it", .{ snapshot_path, @errorName(err) });
            return null;
        };
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);

        try protocol.initializeEngine(.{ .snapshot = bytes });
        errdefer protocol.deinitializeEngine();
        if (!pools_ready) {
            interfaces.process_hooks.startHooksForTest();
            runtime.initializeRuntime(std.heap.page_allocator);
            pools_ready = true;
        }
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        // Restored, not made afresh: v8_Isolate_NewFromSnapshot keeps the
        // blob's StartupData in the isolate's record (createAgent falls back
        // to a fresh isolate, with a warning, when the snapshot does not
        // restore - which would make these tests pass for the wrong reason).
        if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .bytes = bytes, .agent = agent, .realm = realm };
    }

    fn close(self: SnapshotPage) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
        protocol.deinitializeEngine();
        std.heap.c_allocator.free(self.bytes);
    }

    fn run(self: SnapshotPage, source: []const u8) !void {
        var reports: Reports = .{};
        try protocol.runClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try std.testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn holds(self: SnapshotPage, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.toBoolean(self.realm, held.value);
    }

    /// `value` as the page's global property `name`.
    fn expose(self: SnapshotPage, name: []const u8, value: protocol.JSValue) !void {
        var reports: Reports = .{};
        const global = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = "globalThis" }, "", null, reports.reporter());
        defer global.release();
        try protocol.setProperty(self.realm, global.value, name, value);
    }

    fn isolate(self: SnapshotPage) *ffi.Isolate {
        return @ptrCast(@alignCast(self.agent));
    }
};

/// Whether `source`, run in `context` (a context of the entered isolate),
/// evaluates to 1.
fn holdsIn(isolate: *ffi.Isolate, context: *ffi.Context, source: []const u8) !bool {
    const text = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(text);
    const script = ffi.v8_Script_Compile(context, text) orelse return error.CompileFailed;
    defer ffi.v8_Script_Dispose(script);
    const value = ffi.v8_Script_Run(context, script) orelse return error.RunFailed;
    defer ffi.v8_Value_Dispose(value);
    return ffi.v8_Value_Int32Value(value, context) == 1;
}

test "snapshot agent: parseJsonInNewGlobal parses in a new global, not the page's" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    try std.testing.expect(try page.holds("typeof Window === 'function' && globalThis instanceof Window"));
    try page.run("Object.prototype.kty = 'oct'; Array.prototype.polluted = 1;");
    const parsed = try protocol.parseJsonInNewGlobal(page.realm, "{\"a\":[1,2],\"b\":{},\"k\":\"AAAA\"}");
    defer parsed.release();
    try page.expose("fresh", parsed.value);
    try std.testing.expect(try page.holds(
        \\Object.getPrototypeOf(fresh) !== Object.prototype &&
        \\Object.getPrototypeOf(fresh.a) !== Array.prototype &&
        \\fresh.kty === undefined && fresh.b.kty === undefined && fresh.a.polluted === undefined &&
        \\fresh.a.length === 2 && fresh.a[1] === 2 && fresh.k === 'AAAA'
    ));
    // The page's own realm still works after the new global was made.
    try std.testing.expect(try page.holds("({}).kty === 'oct' && globalThis instanceof Window && typeof EventTarget === 'function'"));
}

test "snapshot agent: parseJsonInNewGlobal, again and again, each in a global of its own" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    for (0..8) |i| {
        const parsed = try protocol.parseJsonInNewGlobal(page.realm, "\xEF\xBB\xBF[\"x\"]");
        defer parsed.release();
        try page.expose(if (i % 2 == 0) "even" else "odd", parsed.value);
    }
    try std.testing.expect(try page.holds(
        \\even.length === 1 && even[0] === 'x' && odd[0] === 'x' &&
        \\Object.getPrototypeOf(even) !== Object.getPrototypeOf(odd) &&
        \\Object.getPrototypeOf(even) !== Array.prototype
    ));
}

test "snapshot agent: v8_Context_New and v8_Context_NewWithMicrotaskQueue make a plain global" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    const isolate = page.isolate();
    const enter = ffi.v8_Isolate_GetCurrent() != isolate;
    if (enter) ffi.v8_Isolate_Enter(isolate);
    defer if (enter) ffi.v8_Isolate_Exit(isolate);

    // The intrinsics the bootstrapper faulted installing, and JSON's.
    const intrinsics = "typeof Math.f16round === 'function' && JSON.parse('[1,2]').length === 2 && typeof globalThis === 'object' ? 1 : 0";
    for (0..2) |_| {
        const plain = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
        defer ffi.v8_Context_Dispose(plain);
        try std.testing.expect(try holdsIn(isolate, plain, intrinsics));
        const queued = ffi.v8_Context_NewWithMicrotaskQueue(isolate, null) orelse return error.ContextCreationFailed;
        defer ffi.v8_Context_Dispose(queued);
        try std.testing.expect(try holdsIn(isolate, queued, intrinsics));
    }
    try std.testing.expect(try page.holds("globalThis instanceof Window && typeof Document === 'function'"));
}
