//! WebAssembly.Module through structured serialization, as the V8 adapter
//! does it (structured_serialization.zig, v8_wrapper.cpp's serializer
//! delegates) - what postMessage, MessagePort, BroadcastChannel, a worker's
//! messages and structuredClone carry.
//!
//! WebAssembly Web API section 3: a Module is [Serializable]. Its
//! serialization steps throw a "DataCloneError" DOMException for forStorage,
//! and otherwise record its bytes and the current realm's agent cluster; its
//! deserialization steps throw DataCloneError in another agent cluster, and
//! otherwise compile a WebAssembly module from the bytes in the target realm
//! (CSP's HostEnsureCanCompileWasmBytes first).
//!
//! Before: the adapter's ValueSerializer delegate had no
//! GetWasmModuleTransferId, so V8's WriteWasmModule wrote nothing and
//! reported success (value-serializer.cc); the payload did not deserialize,
//! and the message event never fired.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agents, and leaves no
//! isolate entered that it entered.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
/// Every worker realm has an event loop; this test drives none.
const inline_task_loop = @import("inline_task_loop.zig");

/// The incrementer module the WPT files post: one export,
/// `increment(i32) -> i32`, returning its argument plus one.
const incrementer =
    \\const incrementerBytes = new Uint8Array([
    \\  0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x06, 0x01, 0x60,
    \\  0x01, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x0d, 0x01, 0x09,
    \\  0x69, 0x6e, 0x63, 0x72, 0x65, 0x6d, 0x65, 0x6e, 0x74, 0x00, 0x00, 0x0a,
    \\  0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x41, 0x01, 0x6a, 0x0b]);
    \\
;

/// The test's host: whether WebAssembly may compile, and how often it was asked.
const Host = struct {
    wasm_allowed: bool = true,
    wasm_calls: usize = 0,

    const hooks: protocol.HostHooks = .{
        .ensureCanCompileWasmBytes = wasm,
    };

    fn wasm(host: ?*anyopaque, _: runtime.Context) bool {
        const self: *Host = @ptrCast(@alignCast(host.?));
        self.wasm_calls += 1;
        return self.wasm_allowed;
    }
};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
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

fn setup() !void {
    try protocol.initializeEngine(.{});
    // The runtime's pools start once per process: another file of the
    // directory may have started them.
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();
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

/// `source`'s completion value in `realm`, as a string (OWNED by the testing
/// allocator); nothing reported.
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

fn notTransferable(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
    return .not_transferable;
}

/// A message between realms, as a port or a window carries it: `post(value)`
/// in the sending realm serializes its argument - as the binding hands it
/// over - with StructuredSerializeWithTransfer (or, `postForStorage`, with
/// StructuredSerializeForStorage) and keeps the result; `receive()` in the
/// receiving realm deserializes it there and returns it, or the string
/// "messageerror" when it does not deserialize.
const Mailbox = struct {
    from: runtime.Context = undefined,
    to: runtime.Context = undefined,
    message: ?protocol.SerializedWithTransfer = null,
    stored: ?[]u8 = null,

    post_function: protocol.BuiltinFunction = undefined,
    store_function: protocol.BuiltinFunction = undefined,
    receive_function: protocol.BuiltinFunction = undefined,

    /// `post` and `postForStorage` in `from`, `receive` in `to`. The mailbox
    /// stays where it is until both realms are gone.
    fn install(self: *Mailbox, from: runtime.Context, to: runtime.Context) !void {
        self.from = from;
        self.to = to;
        self.post_function = .{ .steps = post, .data = self };
        self.store_function = .{ .steps = postForStorage, .data = self };
        self.receive_function = .{ .steps = receive, .data = self };
        try protocol.defineBuiltinFunction(from, "post", 1, &self.post_function);
        try protocol.defineBuiltinFunction(from, "postForStorage", 1, &self.store_function);
        try protocol.defineBuiltinFunction(to, "receive", 0, &self.receive_function);
    }

    fn clear(self: *Mailbox) void {
        if (self.message) |*message| message.deinit(std.heap.c_allocator);
        self.message = null;
        if (self.stored) |bytes| std.heap.c_allocator.free(bytes);
        self.stored = null;
    }

    fn post(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        self.clear();
        const value = if (args.len > 0) args[0] else runtime.JSValue.jsUndefined;
        self.message = protocol.structuredSerializeWithTransfer(self.from, value, &.{}, notTransferable, null, std.heap.c_allocator) catch |err| return engineError(err);
        return runtime.JSValue.fromBoolean(true);
    }

    fn postForStorage(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        self.clear();
        const value = if (args.len > 0) args[0] else runtime.JSValue.jsUndefined;
        self.stored = protocol.structuredSerializeForStorage(self.from, value, std.heap.c_allocator) catch |err| return engineError(err);
        return runtime.JSValue.fromBoolean(true);
    }

    fn receive(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        return self.deserializeIn(self.to);
    }

    fn deserializeIn(self: *Mailbox, realm: runtime.Context) runtime.EngineError!runtime.JSValue {
        const message = self.message orelse return runtime.JSValue.jsUndefined;
        const value = protocol.structuredDeserializeWithTransfer(realm, message.serialized, message.array_buffers, &.{}) catch
            return .{ .string = .{ .data = "messageerror", .owned = false } };
        return value.take();
    }
};

/// A protocol error as a built-in's steps report it: what serialization threw
/// stays pending for the script.
fn engineError(err: protocol.Error) runtime.EngineError {
    return switch (err) {
        error.ExceptionPending => error.ExceptionPending,
        error.DataCloneError => error.DataCloneError,
        error.OutOfMemory => error.OutOfMemory,
        else => error.OperationFailed,
    };
}

/// What a receiving realm checks of a module it was sent: a new
/// WebAssembly.Module of the incrementer's code.
const check_received =
    \\(() => {
    \\  const m = receive();
    \\  if (!(m instanceof WebAssembly.Module)) return "not a module: " + m;
    \\  const exports = WebAssembly.Module.exports(m).map(e => e.name + ":" + e.kind).join();
    \\  return exports + "," + new WebAssembly.Instance(m).exports.increment(41);
    \\})()
;

test "wasm serialization: structuredClone of a WebAssembly.Module is a new module of the same code" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    try expectEval(realm, incrementer ++
        \\const m = new WebAssembly.Module(incrementerBytes);
        \\const copy = structuredClone(m);
        \\[copy instanceof WebAssembly.Module, copy !== m,
        \\ new WebAssembly.Instance(copy).exports.increment(42)].join()
    , "true,true,43");
    // One module twice in a value is one new module, twice.
    try expectEval(realm,
        \\const pair = structuredClone({ a: m, b: [m] });
        \\[pair.a === pair.b[0], pair.a !== m, pair.a instanceof WebAssembly.Module].join()
    , "true,true,true");
}

test "wasm serialization: a module posted from one realm arrives in another realm of the agent" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const sender = try windowRealm(agent);
    defer protocol.destroyWindowRealm(sender, .global_detached);
    const receiver = try windowRealm(agent);
    defer protocol.destroyWindowRealm(receiver, .global_detached);
    var mailbox: Mailbox = .{};
    defer mailbox.clear();
    try mailbox.install(sender, receiver);

    try expectEval(sender, incrementer ++ "post({ module: new WebAssembly.Module(incrementerBytes), n: 1 })", "true");
    try expectEval(receiver,
        \\(() => {
        \\  const v = receive();
        \\  return [v.n, v.module instanceof WebAssembly.Module,
        \\          new WebAssembly.Instance(v.module).exports.increment(1)].join();
        \\})()
    , "1,true,2");
    // The serialization is the message's, read as often as it is delivered
    // (a BroadcastChannel delivers one to every channel): each read is a new
    // module.
    try expectEval(receiver,
        \\(() => {
        \\  const a = receive().module, b = receive().module;
        \\  return [a !== b, new WebAssembly.Instance(b).exports.increment(2)].join();
        \\})()
    , "true,3");
}

test "wasm serialization: forStorage serialization of a module is a DataCloneError" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    var mailbox: Mailbox = .{};
    defer mailbox.clear();
    try mailbox.install(realm, realm);

    try expectEval(realm, incrementer ++
        \\(() => {
        \\  const m = new WebAssembly.Module(incrementerBytes);
        \\  try { postForStorage({ inside: [m] }); return "stored"; }
        \\  catch (e) { return e instanceof DOMException && e.name === "DataCloneError"; }
        \\})()
    , "true");
}

test "wasm serialization: a realm that may not compile WebAssembly receives no module" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const sender = try windowRealm(agent);
    defer protocol.destroyWindowRealm(sender, .global_detached);
    const receiver = try windowRealm(agent);
    defer protocol.destroyWindowRealm(receiver, .global_detached);
    var mailbox: Mailbox = .{};
    defer mailbox.clear();
    try mailbox.install(sender, receiver);

    try expectEval(sender, incrementer ++ "post(new WebAssembly.Module(incrementerBytes))", "true");
    // Deserialization step 4, "compile a WebAssembly module", runs
    // HostEnsureCanCompileWasmBytes in the target realm (the CSP
    // integration's step 1): blocked, the message does not deserialize.
    const before = host.wasm_calls;
    host.wasm_allowed = false;
    try expectEval(receiver, "receive()", "messageerror");
    try std.testing.expect(host.wasm_calls > before);
    host.wasm_allowed = true;
    try expectEval(receiver, check_received, "increment:function,42");
}

/// The receiving side of a module sent to another thread: an agent of its
/// own there, a worker realm in it, the message deserialized into it.
const Receiver = struct {
    mailbox: *Mailbox,
    answer: [128]u8 = undefined,
    answer_len: usize = 0,
    failed: ?anyerror = null,

    fn run(self: *Receiver) void {
        self.receiveOnThisThread() catch |err| {
            self.failed = err;
        };
    }

    fn receiveOnThisThread(self: *Receiver) !void {
        // The context manager is per thread, as each worker thread's is.
        v8.context_manager.init(std.heap.page_allocator) catch {};
        var host: Host = .{};
        const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &Host.hooks, .host = &host, .allocator = std.heap.page_allocator });
        defer protocol.destroyAgent(agent);
        const worker = try protocol.createWorkerRealm(agent, &.{
            .url = "https://example.test/worker.js",
            .timer = null,
            .event_loop = inline_task_loop.eventLoop(),
            .allocator = std.heap.page_allocator,
        });
        defer protocol.destroyWorkerRealm(worker.realm, null, null);
        self.mailbox.to = worker.realm;
        var receive_function: protocol.BuiltinFunction = .{ .steps = Mailbox.receive, .data = self.mailbox };
        try protocol.defineBuiltinFunction(worker.realm, "receive", 0, &receive_function);
        var reports: Reports = .{};
        const text = try protocol.evaluateClassicScriptToString(worker.realm, .{ .utf8 = check_received }, "", null, std.heap.page_allocator, reports.reporter());
        defer std.heap.page_allocator.free(text);
        self.answer_len = @min(text.len, self.answer.len);
        @memcpy(self.answer[0..self.answer_len], text[0..self.answer_len]);
    }
};

test "wasm serialization: a module crosses to an agent on another thread" {
    try setup();
    var host: Host = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const sender = try windowRealm(agent);
    defer protocol.destroyWindowRealm(sender, .global_detached);
    var mailbox: Mailbox = .{};
    defer mailbox.clear();
    try mailbox.install(sender, sender);
    try expectEval(sender, incrementer ++ "post(new WebAssembly.Module(incrementerBytes))", "true");

    // A worker thread's agent reads the message: the serialized form holds
    // nothing of the sending isolate.
    var receiver: Receiver = .{ .mailbox = &mailbox };
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Receiver.run, .{&receiver});
    thread.join();
    if (receiver.failed) |err| return err;
    try std.testing.expectEqualStrings("increment:function,42", receiver.answer[0..receiver.answer_len]);
}

/// A host that keeps agent clusters: each realm's key, as HTML allocates
/// them; a realm it does not list names none.
const ClusterHost = struct {
    keys: [3]struct { realm: ?runtime.Context = null, key: u64 = 0 } = .{ .{}, .{}, .{} },

    const hooks: protocol.HostHooks = .{
        .agentClusterOf = clusterOf,
    };

    fn clusterOf(host: ?*anyopaque, realm: runtime.Context) u64 {
        const self: *ClusterHost = @ptrCast(@alignCast(host.?));
        for (self.keys) |entry| {
            if (entry.realm) |r| if (r == realm) return entry.key;
        }
        return 0;
    }
};

test "wasm serialization: a module is received only in the agent cluster that sent it" {
    try setup();
    var host: ClusterHost = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &ClusterHost.hooks, .host = &host });
    defer protocol.destroyAgent(agent);
    const sender = try windowRealm(agent);
    defer protocol.destroyWindowRealm(sender, .global_detached);
    const same = try windowRealm(agent);
    defer protocol.destroyWindowRealm(same, .global_detached);
    const other = try windowRealm(agent);
    defer protocol.destroyWindowRealm(other, .global_detached);
    // A same-site frame shares the sender's cluster; a cross-site one has
    // its own.
    host.keys = .{ .{ .realm = sender, .key = 7 }, .{ .realm = same, .key = 7 }, .{ .realm = other, .key = 9 } };

    var to_same: Mailbox = .{};
    defer to_same.clear();
    try to_same.install(sender, same);
    try expectEval(sender, incrementer ++ "post(new WebAssembly.Module(incrementerBytes))", "true");
    try expectEval(same, check_received, "increment:function,42");

    // Step 3: targetRealm's agent cluster is not serialized.[[AgentCluster]] -
    // a DataCloneError, so the message is a messageerror.
    const message = to_same.message.?;
    var to_other: Mailbox = .{ .to = other, .message = message };
    try std.testing.expectEqualStrings("messageerror", (try to_other.deserializeIn(other)).string.data);
    // A value with no module crosses clusters as before.
    try expectEval(sender, "post({ plain: [1, 2] })", "true");
    const plain = try protocol.structuredDeserializeWithTransfer(other, to_same.message.?.serialized, &.{}, &.{});
    plain.release();
}
