//! Instances B2's measurement (tmp/plans/instances-design.md section 7): two
//! agents on two threads - no Browser - each running for-await, Intl,
//! ShadowRealm, JSON modules and ObservableArray 200 times at once.
//!
//! Each of those reaches state the V8 adapter keeps per isolate: the
//! interface and iterator templates (isolate_templates), the Intl objects'
//! cells and the ObservableArray states (the agent record), the agent's
//! ShadowRealms, the JSON modules waiting for evaluation (v8_wrapper.cpp's
//! per-isolate data). None of it may be shared with, or ended by, the other
//! agent: no V8_Fatal, every answer right on both sides, and the live weak
//! callback records (v8_Debug_LiveWeakCallbackData, process-wide) flat while
//! the agents run and back where they started once both have ended.
//!
//! ShadowRealm needs an agent restored from Crane's snapshot (shadow_realm.zig
//! makes its context from the snapshot's), so the first test runs restored
//! agents and skips - saying so - unless this file is the first in its process
//! to start V8 and `zig build snapshot` has made zig-out/bin/whatwg_snapshot.bin
//! (new_global_snapshot_test.zig's reason: restoring after other files had
//! started V8 crashed inside V8's deserialization). Run it with
//! `-Dtest-file=`. The second test runs everything else in fresh agents,
//! wherever it runs.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

const iterations = 200;
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

const no_hooks: protocol.HostHooks = .{};

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const answer = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(answer);
    if (reports.count != 0) return error.ScriptThrew;
    if (!std.mem.eql(u8, expected, answer)) {
        std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, answer });
        return error.WrongAnswer;
    }
}

fn parsed(result: protocol.ParseResult) !*protocol.ModuleRecord {
    return switch (result) {
        .record => |record| record,
        .parse_error => |e| {
            e.release();
            return error.DidNotParse;
        },
    };
}

/// The one JSON module a main module imports.
const JsonGraph = struct {
    json: *protocol.ModuleRecord,

    fn resolve(data: ?*anyopaque, referrer: *protocol.ModuleRecord, request: protocol.ModuleRequest) ?*protocol.ModuleRecord {
        _ = referrer;
        const self: *JsonGraph = @ptrCast(@alignCast(data.?));
        if (!std.mem.eql(u8, request.specifier, "./d.json")) return null;
        return self.json;
    }
};

/// One round of everything, in `realm` of `agent`.
fn round(realm: runtime.Context, agent: *protocol.Agent, n: usize, shadow_realm: bool) !void {
    // for-await over a stream: its async iterator and promise reactions.
    try expectEval(realm,
        \\globalThis.sum = 0;
        \\(async () => {
        \\  for await (const chunk of new ReadableStream({ start(c) { c.enqueue(2); c.enqueue(3); c.close(); } })) sum += chunk;
        \\})();
        \\'started'
    , "started");
    for (0..8) |_| try protocol.performMicrotaskCheckpoint(agent);
    try expectEval(realm, "String(sum)", "5");

    // Intl: each object's cell is the agent's.
    try expectEval(realm, "new Intl.NumberFormat('en-US').format(1234.5) + '|' + new Intl.Collator('en').compare('a', 'b') + '|' + new Intl.PluralRules('en').select(1)", "1,234.5|-1|one");

    // ShadowRealm: the agent's, made from the snapshot's context.
    if (shadow_realm) try expectEval(realm, "String(new ShadowRealm().evaluate('6 * 7'))", "42");

    // A JSON module, imported and evaluated.
    var source_buf: [64]u8 = undefined;
    const json_source = try std.fmt.bufPrint(&source_buf, "{{\"n\": {d}}}", .{n});
    const json = try parsed(try protocol.parseJSONModule(realm, json_source, "https://agents.test/d.json", null));
    defer protocol.releaseModuleRecord(json);
    const main = try parsed(try protocol.parseModule(realm, "import d from './d.json' with { type: 'json' }; globalThis.fromJson = d.n;", .{}, "https://agents.test/main.js", null));
    defer protocol.releaseModuleRecord(main);
    var graph: JsonGraph = .{ .json = json };
    if (try protocol.linkModule(realm, main, JsonGraph.resolve, &graph)) |link_error| {
        link_error.release();
        return error.LinkFailed;
    }
    const scope = try protocol.prepareToRunScript(realm);
    const evaluation = try protocol.evaluateModule(realm, main);
    protocol.cleanUpAfterRunningScript(scope);
    switch (evaluation) {
        .completed => {},
        .rejected, .pending => |value| {
            value.release();
            return error.ModuleDidNotComplete;
        },
    }
    var expected_buf: [32]u8 = undefined;
    try expectEval(realm, "String(fromJson)", try std.fmt.bufPrint(&expected_buf, "{d}", .{n}));
    // One parsed and never evaluated: released with its record.
    const unevaluated = try parsed(try protocol.parseJSONModule(realm, "[1, 2, 3]", "https://agents.test/u.json", null));
    protocol.releaseModuleRecord(unevaluated);

    // An ObservableArray: a document's adoptedStyleSheets.
    try expectEval(realm, "(() => { const doc = new Document(); return Array.isArray(doc.adoptedStyleSheets) && doc.adoptedStyleSheets.length === 0; })()", "true");
}

/// One agent's run on its own thread.
const Side = struct {
    from_snapshot: bool,
    failure: ?anyerror = null,
    rounds: usize = 0,
    /// v8_Debug_LiveWeakCallbackData after this agent's collection at round
    /// 20 and after its last round.
    weak_early: i64 = 0,
    weak_late: i64 = 0,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(self: *Side) !void {
        var scope = runtime.BrowserScope.init(std.heap.page_allocator);
        defer scope.deinit();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = self.from_snapshot, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        // Restored, not made afresh (createAgent falls back to a fresh
        // isolate, with a warning, when the snapshot does not restore).
        if (self.from_snapshot and !ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = self.from_snapshot,
            .timer = null,
            .origin = "https://agents.test",
            .browser_scope = &scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
        defer protocol.destroyWindowRealm(realm, .global_detached);

        for (0..iterations) |n| {
            try round(realm, agent, n, self.from_snapshot);
            self.rounds += 1;
            // Collected every ten rounds, so what the other agent's
            // collections wait for stays small beside a leak's growth.
            if (n % 10 == 9) protocol.notifyMemoryPressure(agent, .critical);
            if (n == 19) self.weak_early = ffi.v8_Debug_LiveWeakCallbackData();
        }
        self.weak_late = ffi.v8_Debug_LiveWeakCallbackData();
    }
};

fn runBoth(from_snapshot: bool) !void {
    const weak_before = ffi.v8_Debug_LiveWeakCallbackData();
    var sides = [_]Side{ .{ .from_snapshot = from_snapshot }, .{ .from_snapshot = from_snapshot } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| {
        if (side.failure) |err| return err;
        try testing.expectEqual(@as(usize, iterations), side.rounds);
        // Flat while it ran: a record kept per round would grow by at least
        // one per round on each side.
        if (side.weak_late - side.weak_early >= iterations - 20) {
            std.debug.print("live weak callback records: {d} at round 20, {d} at round {d}\n", .{ side.weak_early, side.weak_late, iterations });
            return error.WeakCallbackRecordsGrew;
        }
    }
    // And back where they started once both agents have ended.
    const weak_after = ffi.v8_Debug_LiveWeakCallbackData();
    if (weak_after > weak_before) {
        std.debug.print("live weak callback records: {d} before the agents, {d} after\n", .{ weak_before, weak_after });
        return error.WeakCallbackRecordsOutlivedTheirAgents;
    }
}

var first_in_process: ?bool = null;

test "two agents restored from the snapshot, on two threads: for-await, Intl, ShadowRealm, JSON modules and ObservableArray 200 times at once" {
    if (first_in_process == null) first_in_process = !ffi.v8_Platform_IsInitialized();
    if (!first_in_process.?) {
        std.log.warn("skipping: V8 was started in this process before this file; run it with -Dtest-file= or -Dtest-isolation=file", .{});
        return error.SkipZigTest;
    }
    const io = testing.io;
    const file = std.Io.Dir.cwd().openFile(io, snapshot_path, .{}) catch |err| {
        std.log.warn("skipping: no snapshot at {s} ({s}); `zig build snapshot` makes it", .{ snapshot_path, @errorName(err) });
        return error.SkipZigTest;
    };
    defer file.close(io);
    const size = (try file.stat(io)).size;
    const bytes = try std.heap.c_allocator.alloc(u8, size);
    defer std.heap.c_allocator.free(bytes);
    _ = try file.readPositionalAll(io, bytes, 0);

    try protocol.initializeEngine(.{ .snapshot = bytes });
    defer protocol.deinitializeEngine();
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();
    try runBoth(true);
}

test "two fresh agents on two threads: for-await, Intl, JSON modules and ObservableArray 200 times at once" {
    if (first_in_process == null) first_in_process = !ffi.v8_Platform_IsInitialized();
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();
    try runBoth(false);
}
