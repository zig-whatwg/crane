//! WebAssembly Web API 2 [webassembly_streaming], as the V8 adapter wires it
//! (protocol_webassembly.zig, v8_wrapper.cpp): V8 defines
//! WebAssembly.compileStreaming and instantiateStreaming in the realms of an
//! agent whose host has HostHooks.compilePotentialWebAssemblyResponse, hands
//! that hook what each call's source fulfilled with, and compiles the bytes
//! the host appends once it finishes - or rejects with the reason it aborts
//! with.
//!
//! The hook is handed `source` as V8 hands it to the WasmStreamingCallback:
//! a handle the host reads through the protocol, as the binding hands an
//! `any` value. Every compilation is ended once: by the host, by its realm's
//! end (unsettled), or - its record - by the agent's end.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agents, and leaves no
//! isolate entered that it entered.

const std = @import("std");
const clock = @import("clock");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// Whether the protocol has the operations at all (false before them: every
/// test then fails, which is the red this file was written against).
const api = @hasDecl(protocol, "WebAssemblyResponseCompilation");
const Compilation = if (api) protocol.WebAssemblyResponseCompilation else anyopaque;

/// The test's host: what the hook was handed, kept for the test to end.
const Host = struct {
    calls: usize = 0,
    realm: ?runtime.Context = null,
    /// What the source fulfilled with, held so the test can compare it.
    source: ?protocol.Owned = null,
    compilation: ?*Compilation = null,

    fn take(host: ?*anyopaque, realm: runtime.Context, source: runtime.JSValue, compilation: *Compilation) void {
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.calls += 1;
        self.realm = realm;
        if (self.source) |held| held.release();
        self.source = protocol.retainValue(realm, source) catch null;
        self.compilation = compilation;
    }

    fn releaseSource(self: *Host) void {
        if (self.source) |held| held.release();
        self.source = null;
    }
};

const hooked: protocol.HostHooks = if (api) .{ .compilePotentialWebAssemblyResponse = Host.take } else .{};
const unhooked: protocol.HostHooks = .{};

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
    runtime.initializeRuntime(std.heap.page_allocator);
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

/// `source`'s completion value in `realm`, as a string; nothing reported.
fn evalString(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const result = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    return result;
}

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try evalString(realm, source);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

/// Run script, then the microtasks it queued - where V8 calls the hook.
fn run(agent: *protocol.Agent, realm: runtime.Context, source: []const u8) !void {
    const got = try evalString(realm, source);
    std.testing.allocator.free(got);
    try protocol.performMicrotaskCheckpoint(agent);
}

/// Turn the engine - its posted tasks (the compile finishes on a background
/// thread and posts the task that settles) and the microtasks after them -
/// until `check` evaluates to "true" in `realm`.
fn settle(agent: *protocol.Agent, realm: runtime.Context, check: []const u8) !void {
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        const got = try evalString(realm, check);
        defer std.testing.allocator.free(got);
        if (std.mem.eql(u8, got, "true")) return;
        _ = protocol.runEngineTasks(agent);
        try protocol.performMicrotaskCheckpoint(agent);
        clock.sleep(5 * std.time.ns_per_ms);
    }
    std.debug.print("never settled: {s}\n", .{check});
    return error.NeverSettled;
}

/// The compilations `agent`'s adapter record holds.
fn compilationsOf(agent: *protocol.Agent) *v8.protocol_agents.WebAssemblyCompilations {
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    return &v8.protocol_agents.recordOf(isolate).?.webassembly_compilations;
}

/// (module (func (export "inc") (param i32) (result i32)
///   local.get 0 i32.const 1 i32.add))
const incrementer = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x01, 0x60,
    0x01, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x07, 0x01, 0x03,
    0x69, 0x6e, 0x63, 0x00, 0x00, 0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00,
    0x41, 0x01, 0x6a, 0x0b,
};

/// (module (func (export "trap") unreachable))
const trapper = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x04, 0x01, 0x60,
    0x00, 0x00, 0x03, 0x02, 0x01, 0x00, 0x07, 0x08, 0x01, 0x04, 0x74, 0x72,
    0x61, 0x70, 0x00, 0x00, 0x0a, 0x05, 0x01, 0x03, 0x00, 0x00, 0x0b,
};

test "webassembly streaming: an agent with the hook has compileStreaming and instantiateStreaming in its realms; one without has neither" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try expectEval(realm, "typeof WebAssembly.compileStreaming + ' ' + typeof WebAssembly.instantiateStreaming", "function function");
    try expectEval(realm, "WebAssembly.compileStreaming.length + ' ' + WebAssembly.instantiateStreaming.length", "1 1");

    const plain = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &unhooked });
    defer protocol.destroyAgent(plain);
    const plain_realm = try windowRealm(plain);
    defer protocol.destroyWindowRealm(plain_realm, .global_detached);
    try expectEval(plain_realm, "typeof WebAssembly.compileStreaming + ' ' + typeof WebAssembly.instantiateStreaming", "undefined undefined");
}

test "webassembly streaming: the hook is handed what the source fulfilled with, in the caller's realm, and the bytes it appends resolve a Module" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host, .allocator = std.testing.allocator });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    // Released while its realm and agent are alive.
    defer host.releaseSource();

    try run(agent, realm,
        \\globalThis.marker = { kind: 'response' };
        \\globalThis.result = 'pending';
        \\WebAssembly.compileStreaming(Promise.resolve(marker)).then(
        \\  (m) => { result = m instanceof WebAssembly.Module ? 'module' : 'other'; },
        \\  (e) => { result = 'rejected: ' + e; });
    );
    try std.testing.expectEqual(@as(usize, 1), host.calls);
    try std.testing.expectEqual(realm, host.realm.?);
    var reports: Reports = .{};
    const marker = try protocol.evaluateClassicScript(realm, .{ .utf8 = "marker" }, "", null, reports.reporter());
    defer marker.release();
    try std.testing.expect(protocol.sameValue(realm, marker.value, host.source.?.value));
    try std.testing.expectEqual(@as(usize, 1), compilationsOf(agent).count);

    // The bytes in two parts: they compile as one module.
    try protocol.appendWebAssemblyResponseBytes(host.compilation.?, incrementer[0..10]);
    try protocol.appendWebAssemblyResponseBytes(host.compilation.?, incrementer[10..]);
    protocol.finishWebAssemblyResponse(host.compilation.?, "https://example.test/inc.wasm");
    try std.testing.expectEqual(@as(usize, 0), compilationsOf(agent).count);
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result", "module");
}

test "webassembly streaming: instantiateStreaming instantiates the module it compiles" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host, .allocator = std.testing.allocator });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    // Released while its realm and agent are alive.
    defer host.releaseSource();

    try run(agent, realm,
        \\globalThis.result = 'pending';
        \\WebAssembly.instantiateStreaming({}, {}).then(
        \\  (r) => { result = (r.module instanceof WebAssembly.Module) + ' ' + r.instance.exports.inc(41); },
        \\  (e) => { result = 'rejected: ' + e; });
    );
    try std.testing.expectEqual(@as(usize, 1), host.calls);
    try protocol.appendWebAssemblyResponseBytes(host.compilation.?, &incrementer);
    protocol.finishWebAssemblyResponse(host.compilation.?, "");
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result", "true 42");
}

test "webassembly streaming: an abort with a reason rejects with that value; invalid bytes reject with a CompileError" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host, .allocator = std.testing.allocator });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    // Released while its realm and agent are alive.
    defer host.releaseSource();

    // The reason is the source itself, so identity shows.
    try run(agent, realm,
        \\globalThis.marker = {};
        \\globalThis.result = 'pending';
        \\WebAssembly.compileStreaming(marker).then(
        \\  () => { result = 'resolved'; },
        \\  (e) => { result = e === marker ? 'the reason' : 'another: ' + e; });
    );
    protocol.abortWebAssemblyResponse(host.compilation.?, host.source.?.value);
    try std.testing.expectEqual(@as(usize, 0), compilationsOf(agent).count);
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result", "the reason");

    // An inline value is made one of the realm.
    try run(agent, realm,
        \\globalThis.result = 'pending';
        \\WebAssembly.compileStreaming({}).then(() => { result = 'resolved'; }, (e) => { result = e; });
    );
    protocol.abortWebAssemblyResponse(host.compilation.?, .{ .number = 7 });
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result === 7", "true");

    // Not a module: the engine's CompileError.
    try run(agent, realm,
        \\globalThis.result = 'pending';
        \\WebAssembly.compileStreaming({}).then(() => { result = 'resolved'; },
        \\  (e) => { result = e instanceof WebAssembly.CompileError ? 'CompileError' : 'other: ' + e; });
    );
    try protocol.appendWebAssemblyResponseBytes(host.compilation.?, &[_]u8{ 0, 0, 0, 0 });
    protocol.finishWebAssemblyResponse(host.compilation.?, "");
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result", "CompileError");

    // No bytes at all: a CompileError too (an empty or null body).
    try run(agent, realm,
        \\globalThis.result = 'pending';
        \\WebAssembly.compileStreaming({}).then(() => { result = 'resolved'; },
        \\  (e) => { result = e instanceof WebAssembly.CompileError ? 'CompileError' : 'other: ' + e; });
    );
    protocol.finishWebAssemblyResponse(host.compilation.?, "");
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result", "CompileError");
}

test "webassembly streaming: a source that rejects never reaches the hook" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host, .allocator = std.testing.allocator });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    // Released while its realm and agent are alive.
    defer host.releaseSource();

    try run(agent, realm,
        \\globalThis.marker = { name: 'custom error' };
        \\globalThis.result = 'pending';
        \\WebAssembly.instantiateStreaming(Promise.reject(marker)).then(
        \\  () => { result = 'resolved'; },
        \\  (e) => { result = e === marker ? 'the reason' : 'another'; });
    );
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result", "the reason");
    try std.testing.expectEqual(@as(usize, 0), host.calls);
}

test "webassembly streaming: the URL the host finishes with names the module's functions in a stack" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host, .allocator = std.testing.allocator });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    // Released while its realm and agent are alive.
    defer host.releaseSource();

    try run(agent, realm,
        \\globalThis.result = 'pending';
        \\WebAssembly.instantiateStreaming({}).then(
        \\  (r) => { try { r.instance.exports.trap(); result = 'no trap'; } catch (e) { result = String(e.stack); } },
        \\  (e) => { result = 'rejected: ' + e; });
    );
    try protocol.appendWebAssemblyResponseBytes(host.compilation.?, &trapper);
    protocol.finishWebAssemblyResponse(host.compilation.?, "https://example.test/trap.wasm");
    try settle(agent, realm, "result !== 'pending'");
    try expectEval(realm, "result.includes('https://example.test/trap.wasm:wasm-function[0]')", "true");
}

test "webassembly streaming: a compilation the host never ends ends with its realm, unsettled, and its record with the agent" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host, .allocator = std.testing.allocator });
    defer protocol.destroyAgent(agent);
    {
        const realm = try windowRealm(agent);
        defer protocol.destroyWindowRealm(realm, .global_detached);
        try run(agent, realm, "globalThis.p = WebAssembly.compileStreaming({})");
        try std.testing.expectEqual(@as(usize, 1), host.calls);
        try protocol.appendWebAssemblyResponseBytes(host.compilation.?, incrementer[0..8]);
        try std.testing.expectEqual(@as(usize, 1), compilationsOf(agent).liveNative());
        host.releaseSource();
    }
    // The realm's end ended V8's side; the record is still the host's...
    try std.testing.expectEqual(@as(usize, 0), compilationsOf(agent).liveNative());
    try std.testing.expectEqual(@as(usize, 1), compilationsOf(agent).count);
    // ... and appending to it now does nothing. The agent's end frees it
    // (std.testing.allocator fails the test if it does not).
    try protocol.appendWebAssemblyResponseBytes(host.compilation.?, incrementer[8..]);
}

test "webassembly streaming: the host's end after its realm ended only frees the record" {
    if (comptime !api) return error.WebAssemblyStreamingIsNotInTheProtocol;
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooked, .host = &host, .allocator = std.testing.allocator });
    defer protocol.destroyAgent(agent);
    {
        const realm = try windowRealm(agent);
        defer protocol.destroyWindowRealm(realm, .global_detached);
        try run(agent, realm, "WebAssembly.compileStreaming({}); WebAssembly.instantiateStreaming({})");
        try std.testing.expectEqual(@as(usize, 2), host.calls);
        try std.testing.expectEqual(@as(usize, 2), compilationsOf(agent).count);
        host.releaseSource();
    }
    try std.testing.expectEqual(@as(usize, 2), compilationsOf(agent).count);
    // The last one handed over: ended by the host, the other by the agent.
    protocol.finishWebAssemblyResponse(host.compilation.?, "");
    try std.testing.expectEqual(@as(usize, 1), compilationsOf(agent).count);
}
