//! The engine protocol's runningScriptLocation on V8 (CSP 2.4.1 step 2: the
//! running script's source file, line and column), read where the host
//! reads it: from inside a host hook the engine calls while script runs -
//! the code generation check a violation of 'unsafe-eval' is reported from.
//! A classic script reports the URL it was compiled with; eval and Function
//! code report their `//# sourceURL=`; nothing running is null.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agent, and leaves no
//! isolate entered that it entered.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The test's host: the location its code generation hook read, each time
/// it was asked.
const Host = struct {
    agent: ?*protocol.Agent = null,
    calls: usize = 0,
    failed: bool = false,
    found: bool = false,
    url_buffer: [256]u8 = undefined,
    url_len: usize = 0,
    line: u32 = 0,
    column: u32 = 0,
    /// Extra reads the next call makes, measuring live global-handle bytes
    /// around them.
    rounds: usize = 0,
    rounds_ran: usize = 0,
    bytes_before: usize = 0,
    bytes_after: usize = 0,

    const hooks: protocol.HostHooks = .{ .ensureCanCompileStrings = ensure };

    fn ensure(host: ?*anyopaque, realm: runtime.Context, compilation: *const protocol.StringCompilation) protocol.StringCompilationVerdict {
        _ = realm;
        _ = compilation;
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.calls += 1;
        self.found = false;
        if (self.rounds > 0) {
            const isolate: *ffi.Isolate = @ptrCast(@alignCast(self.agent.?));
            self.bytes_before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
            while (self.rounds > 0) : (self.rounds -= 1) {
                const extra = protocol.runningScriptLocation(self.agent.?, std.testing.allocator) catch null;
                if (extra) |l| l.deinit(std.testing.allocator);
                self.rounds_ran += 1;
            }
            self.bytes_after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
        }
        const location = protocol.runningScriptLocation(self.agent.?, std.testing.allocator) catch {
            self.failed = true;
            return .allowed;
        };
        if (location) |l| {
            defer l.deinit(std.testing.allocator);
            self.found = true;
            self.url_len = @min(l.url.len, self.url_buffer.len);
            @memcpy(self.url_buffer[0..self.url_len], l.url[0..self.url_len]);
            self.line = l.line;
            self.column = l.column;
        }
        return .allowed;
    }

    fn url(self: *const Host) []const u8 {
        return self.url_buffer[0..self.url_len];
    }
};

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
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

fn windowRealm(agent: *protocol.Agent) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

/// Run `source` as a classic script whose URL is `url`; nothing reported.
fn run(realm: runtime.Context, source: []const u8, url: []const u8) !void {
    var reports: Reports = .{};
    const result = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, url, null, std.testing.allocator, reports.reporter());
    std.testing.allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
}

test "runningScriptLocation: a classic script's URL, and the 1-based line and column of the call being made" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    host.agent = agent;
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    try run(realm, "var a = 1;\n    eval('a + 1');", "https://example.test/dir/script.js");
    try std.testing.expect(!host.failed);
    try std.testing.expect(host.found);
    try std.testing.expectEqualStrings("https://example.test/dir/script.js", host.url());
    try std.testing.expectEqual(@as(u32, 2), host.line);
    try std.testing.expectEqual(@as(u32, 5), host.column);

    // The Function constructor's call, from inside a function the script
    // called: the topmost frame is the function's.
    try run(realm, "function f() {\n  return new Function('return 1');\n}\nf();", "https://example.test/f.js");
    try std.testing.expect(host.found);
    try std.testing.expectEqualStrings("https://example.test/f.js", host.url());
    try std.testing.expectEqual(@as(u32, 2), host.line);
    try std.testing.expectEqual(@as(u32, 10), host.column);
}

test "runningScriptLocation: eval and Function code name themselves with //# sourceURL" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    host.agent = agent;
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    // The inner eval is called from the outer eval's code, which has no
    // name of its own: its sourceURL is its URL.
    try run(realm, "eval(\"\\n  eval('1');\\n//# sourceURL=https://example.test/named.js\");", "https://example.test/page.js");
    try std.testing.expect(host.found);
    try std.testing.expectEqualStrings("https://example.test/named.js", host.url());
    try std.testing.expectEqual(@as(u32, 2), host.line);
    try std.testing.expectEqual(@as(u32, 3), host.column);

    // A Function's body, the same way.
    try run(realm, "new Function(\"eval('1');\\n//# sourceURL=webpack://bundle/fn.js\")();", "https://example.test/page.js");
    try std.testing.expect(host.found);
    try std.testing.expectEqualStrings("webpack://bundle/fn.js", host.url());

    // A script with no URL and no sourceURL: "".
    try run(realm, "eval('1');", "");
    try std.testing.expect(host.found);
    try std.testing.expectEqualStrings("", host.url());
    try std.testing.expectEqual(@as(u32, 1), host.line);
}

test "runningScriptLocation: null when no script is running" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    host.agent = agent;
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    // Outside any script.
    try std.testing.expectEqual(@as(?protocol.ScriptLocation, null), try protocol.runningScriptLocation(agent, std.testing.allocator));
    // Inside the realm, with no script on the stack.
    const Steps = struct {
        agent: *protocol.Agent,
        result: ?protocol.ScriptLocation = null,
        failed: bool = false,
        fn steps(data: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = protocol.runningScriptLocation(self.agent, std.testing.allocator) catch blk: {
                self.failed = true;
                break :blk null;
            };
        }
    };
    var steps: Steps = .{ .agent = agent };
    try protocol.runInRealm(realm, Steps.steps, &steps);
    try std.testing.expect(!steps.failed);
    try std.testing.expectEqual(@as(?protocol.ScriptLocation, null), steps.result);
}

test "runningScriptLocation: reading the location leaves no Global behind" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    host.agent = agent;
    host.rounds = 32;
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    // Inside the hook, with script running: 32 more reads, the live
    // global-handle bytes read before and after them - the operation alone.
    // (Measured around whole script runs instead, the bytes take one 32-byte
    // node once over 32 rounds with no read at all: the run's, not this
    // operation's.)
    try run(realm, "eval(\"eval('1');\\n//# sourceURL=https://example.test/leak.js\");", "https://example.test/page.js");
    try std.testing.expect(host.found);
    try std.testing.expect(host.rounds_ran == 32);
    try std.testing.expect(host.bytes_after <= host.bytes_before);
}
