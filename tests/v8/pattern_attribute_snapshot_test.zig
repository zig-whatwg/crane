//! engine.matchesPatternAttribute in an agent restored from Crane's snapshot -
//! the agent every page of the browser and the WPT runner gets.
//!
//! The operation matches in a utility context of the agent's own (its first
//! call makes it; pattern_attribute_test.zig says why). It made that context
//! with a bare `Context::New(isolate)`, which in an isolate restored from the
//! snapshot deserializes the snapshot's DEFAULT context - Crane's Window
//! global, its interfaces and their internal fields - with no internal-field
//! deserializer, and the bootstrapper's InitializeExperimentalGlobal then
//! faulted installing Math.f16round (EXC_BAD_ACCESS: every page that read
//! `input.validity.patternMismatch` crashed once the binding called the
//! operation). pattern_attribute_test.zig's agents are made without a
//! snapshot, so it never saw that. These are its answers, and its
//! nothing-page-overridable guarantees, in a snapshot agent.
//!
//! The snapshot is the one this build generates, zig-out/bin/whatwg_snapshot.bin
//! (the `snapshot` step; `wpt-runner` depends on it). Without it the tests are
//! skipped, as tests/v8/snapshot_test.zig's are.
//!
//! They run only where this file is the first in its process to start V8: a
//! host gives the engine its snapshot when the process starts, before anything
//! else touches V8. In tests/v8's shared executable, where many files started
//! V8 earlier, restoring the snapshot crashed inside V8's isolate
//! deserialization (StringTable::InsertForIsolateDeserialization), before any
//! pattern code ran - the cause is not established. So in that executable
//! they skip, saying so. They run under `-Dtest-file=` and under
//! `-Dtest-isolation=file` (every file its own process; the integrator's run
//! each merge round). The engine is given the snapshot for these tests only and
//! forgets it after (deinitializeEngine).

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

    /// Null (the test skips) when this build's snapshot has not been generated, or when V8
    /// was started in this process before this file.
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

    fn matches(self: SnapshotPage, pattern: []const u8, value: []const u8) !bool {
        return protocol.matchesPatternAttribute(self.realm, pattern, value);
    }
};

test "snapshot agent: a pattern matches the whole value, compiled standalone with the v flag" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    try std.testing.expect(try page.holds("typeof Window === 'function' && globalThis instanceof Window"));
    try std.testing.expect(try page.matches("[a-z]+", "abc"));
    try std.testing.expect(!try page.matches("[a-z]+", "abc1"));
    try std.testing.expect(!try page.matches("a|b", "ab"));
    try std.testing.expect(try page.matches("", ""));
    try std.testing.expect(!try page.matches("", "x"));
    try std.testing.expectError(error.InvalidPattern, page.matches(")(", ""));
    try std.testing.expectError(error.InvalidPattern, page.matches("[(]", "("));
    try std.testing.expect(try page.matches("[[a-z]--[aeiou]]+", "bcd"));
    try std.testing.expect(!try page.matches("[[A-Z]&&[A-M]]+", "Z"));
    try std.testing.expect(try page.matches(".", "\u{1F600}"));
    // The page's own realm, its global and its RegExp, still work after the
    // utility context was made.
    try std.testing.expect(try page.holds("/^(?:[a-z]+)$/v.test('abc') && globalThis instanceof Window && typeof EventTarget === 'function'"));
}

test "snapshot agent: what the page did to RegExp does not matter" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    try page.run(
        \\globalThis.calls = 0;
        \\RegExp.prototype.exec = function () { calls++; return null; };
        \\RegExp.prototype.test = function () { calls++; return false; };
        \\RegExp.prototype[Symbol.match] = function () { calls++; return null; };
        \\Object.defineProperty(RegExp.prototype, 'flags', { get() { calls++; return ''; } });
        \\Object.defineProperty(Array.prototype, 'index', { set(v) { calls++; }, configurable: true });
        \\Object.defineProperty(Object.prototype, 'groups', { set(v) { calls++; }, configurable: true });
        \\globalThis.RegExp = function () { calls++; throw new Error('poisoned'); };
    );
    try std.testing.expect(try page.matches("[a-z]+", "abc"));
    try std.testing.expect(!try page.matches("[a-z]+", "ABC"));
    try std.testing.expect(try page.matches("(?<word>[a-z]+)", "abc"));
    try std.testing.expectError(error.InvalidPattern, page.matches("(", "("));
    try std.testing.expect(try page.holds("calls === 0"));
}

test "snapshot agent: the page's legacy RegExp statics do not see the value" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();
    try page.run("/(seen)/.exec('was seen');");
    try std.testing.expect(try page.matches("(secret)", "secret"));
    try std.testing.expect(try page.holds("RegExp.lastMatch === 'seen' && RegExp.$1 === 'seen' && RegExp.input === 'was seen'"));
}
