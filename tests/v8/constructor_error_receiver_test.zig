//! A constructor that fails releases the receiver V8 made for it.
//!
//! The binding's constructorCallback takes `info.getThis()` - a Global<Object>
//! the caller owns - and hands it to the wrapper cache once the instance is
//! bound to it (`WrapperCache.set` keeps that exact handle as the entry's
//! wrapper). Every exit that never reached the cache kept it instead: both
//! returns of `callConstructorWithArgs(...) catch` - an argument conversion
//! that threw (ExceptionPending) and an impl that failed (the WebIDL error
//! the binding throws) - so each failing `new X(...)`, of any interface, left
//! one 16-byte Global<Object> and the object it holds alive for the agent's
//! life (Codex row 14 Q16: `leaks --atExit` named
//! constructorCallback -> v8_FunctionCallbackInfo_This; gc_bench read 1.00
//! live_object_globals per failed `new Event(...)`).
//!
//! Each test runs one failing construction 64 times and reads the live
//! Global<Object> count (v8_Debug_LiveObjectGlobals) before and after.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
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

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

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

    /// `source`'s completion value as a string; nothing reported.
    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        var reports: Reports = .{};
        const got = protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter()) catch |err| {
            std.debug.print("evaluating failed ({s}, {d} reported): {s}\n", .{ @errorName(err), reports.count, source });
            return err;
        };
        defer std.testing.allocator.free(got);
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        try std.testing.expectEqualStrings(expected, got);
    }

    /// Runs `source` - which answers "64" when each of its 64 constructions
    /// failed as it should - once to warm up (the first call makes what
    /// later ones reuse), then again, and fails when the second run left
    /// live Global<Object> handles behind.
    fn expectNoReceiverLeft(self: Page, source: []const u8) !void {
        try self.expect(source, "64");
        const before = ffi.v8_Debug_LiveObjectGlobals();
        try self.expect(source, "64");
        const after = ffi.v8_Debug_LiveObjectGlobals();
        if (after != before) {
            std.debug.print("live_object_globals {d} -> {d} over 64 failed constructions\n", .{ before, after });
            return error.ReceiverLeaked;
        }
    }
};

test "a constructor whose argument conversion throws releases its receiver" {
    const page = try Page.open();
    defer page.close();
    // The dictionary member's getter throws while the binding converts the
    // arguments: ExceptionPending, and that exception is what script sees.
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    try { new Event('x', { get bubbles() { throw 7; } }); } catch (e) { if (e === 7) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a constructor whose impl fails releases its receiver" {
    const page = try Page.open();
    defer page.close();
    // The arguments convert; URL's constructor steps fail to parse and the
    // binding throws the TypeError.
    try page.expectNoReceiverLeft(
        \\(() => {
        \\  let n = 0;
        \\  for (let i = 0; i < 64; i++) {
        \\    try { new URL('not a url'); } catch (e) { if (e instanceof TypeError) n++; }
        \\  }
        \\  return String(n);
        \\})()
    );
}

test "a constructor that succeeds still hands its receiver to the wrapper cache" {
    const page = try Page.open();
    defer page.close();
    // The successful path keeps its handoff: the receiver is the result, its
    // instance bound, its identity and expandos kept across a collection.
    try page.expect(
        \\globalThis.kept = new Event('ok');
        \\kept.expando = 5;
        \\try { new Event('x', { get bubbles() { throw 7; } }); } catch (e) {}
        \\try { new URL('not a url'); } catch (e) {}
        \\String(kept.type === 'ok' && kept.expando === 5 && kept instanceof Event)
    , "true");
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    try protocol.runInRealm(page.realm, Collect.steps, page.agent);
    try page.expect("String(kept.type === 'ok' && kept.expando === 5)", "true");
}
