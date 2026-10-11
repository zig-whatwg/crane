//! The Window's named-property interceptors keep no handle per call.
//!
//! context_manager.windowNamedPropertyGetter and windowNamedPropertyQuery
//! (HTML 7.2.2.3, named access on the Window object) took the current context
//! and - for a receiver with no Window behind it - the realm's global object,
//! both owned Globals, and released neither; the query kept the attributes
//! Integer it set as its result too. Lane rc5 fixed the same leak in the
//! indexed getter (7a929a0b53) and named these two as the remaining ones.
//!
//! Neither is installed on a template today (only registered as external
//! references), so this test installs both on an object template of its own
//! and reaches them through an instance of it: its receiver has no internal
//! field, so both look the Window up through the realm's global, as they do
//! for a receiver that is not the Window.
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

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

fn printReport(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
    _ = host;
    std.debug.print("reported: {s}\n", .{info.message});
}

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

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    /// `globalThis.namedProbe`: an object whose named properties both
    /// interceptors answer.
    fn installProbe(self: Page) !void {
        const Install = struct {
            fn steps(data: ?*anyopaque) void {
                const iso: *ffi.Isolate = @ptrCast(@alignCast(data.?));
                const scope = ffi.v8_HandleScope_New(iso) orelse return;
                defer ffi.v8_HandleScope_Dispose(scope);
                const context = ffi.v8_Isolate_GetCurrentContext(iso) orelse return;
                defer ffi.v8_Context_Dispose(context);
                const template = ffi.v8_ObjectTemplate_New(iso);
                defer ffi.v8_ObjectTemplate_Dispose(template);
                ffi.v8_ObjectTemplate_SetNamedPropertyHandlerFull(
                    template,
                    v8.context_manager.windowNamedPropertyGetter,
                    null,
                    v8.context_manager.windowNamedPropertyQuery,
                    null,
                    null,
                    null,
                    .kNone,
                );
                const probe = ffi.v8_ObjectTemplate_NewInstance(template, context) orelse return;
                defer ffi.v8_Object_Dispose(probe);
                const global = ffi.v8_Context_Global(context) orelse return;
                defer ffi.v8_Object_Dispose(global);
                const key = ffi.v8_String_NewFromUtf8(iso, "namedProbe", 10) orelse return;
                defer ffi.v8_String_Dispose(key);
                _ = ffi.v8_Object_Set(global, context, @ptrCast(key), @ptrCast(probe));
            }
        };
        try protocol.runInRealm(self.realm, Install.steps, self.isolate());
    }

    fn run(self: Page, source: []const u8) ![]u8 {
        return protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = printReport }) catch |err| {
            std.debug.print("evaluating failed ({s}): {s}\n", .{ @errorName(err), source });
            return err;
        };
    }

    /// The global handle bytes 64 runs of `statement` leave once a first
    /// round has made what later ones reuse.
    fn handleBytesLeftBy(self: Page, comptime statement: []const u8) !i64 {
        const loop =
            \\(() => {
            \\  for (var k = 0; k < 64; k++) {
        ++ statement ++
            \\;
            \\  }
            \\  return "ok";
            \\})()
        ;
        testing.allocator.free(try self.run(loop));
        try self.collect();
        const before: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        const got = try self.run(loop);
        defer testing.allocator.free(got);
        try testing.expectEqualStrings("ok", got);
        try self.collect();
        const after: i64 = @intCast(ffi.v8_Isolate_GetGlobalHandleBytes(self.isolate()));
        return after - before;
    }
};

test "the probe reaches both interceptors" {
    const page = try Page.open();
    defer page.close();
    try page.installProbe();
    // Nothing is named "zzz": the getter and the query both answer kNo.
    const got = try page.run("String(namedProbe.zzz) + ' ' + ('zzz' in namedProbe)");
    defer testing.allocator.free(got);
    try testing.expectEqualStrings("undefined false", got);
}

test "the named getter releases the context and the global it reads" {
    const page = try Page.open();
    defer page.close();
    try page.installProbe();
    const left = try page.handleBytesLeftBy("void namedProbe.zzz");
    if (left > 0) std.debug.print("namedProbe.zzz: {d} global handle bytes left over 64 reads\n", .{left});
    try testing.expect(left <= 0);
}

test "the named query releases the context and the global it reads" {
    const page = try Page.open();
    defer page.close();
    try page.installProbe();
    const left = try page.handleBytesLeftBy("void ('zzz' in namedProbe)");
    if (left > 0) std.debug.print("'zzz' in namedProbe: {d} global handle bytes left over 64 queries\n", .{left});
    try testing.expect(left <= 0);
}
