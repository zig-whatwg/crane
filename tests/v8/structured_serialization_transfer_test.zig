//! StructuredSerializeWithTransfer and StructuredDeserializeWithTransfer
//! (HTML 2.7.5, 2.7.7) through the engine protocol, as a port's or a
//! worker's message carries a transfer list: the V8 adapter's
//! structured_serialization.zig and v8_wrapper.cpp's serializer.
//!
//! A transferred ArrayBuffer keeps its [[ArrayBufferMaxByteLength]]
//! (StructuredSerializeWithTransfer step 5.4.1 records a "ResizableArrayBuffer"
//! data holder; StructuredDeserializeWithTransfer step 3.3 makes it resizable
//! again, with the same maximum). Before, the receiving side made every
//! transferred buffer fixed-length, so a length-tracking view of one did not
//! deserialize and the message never arrived (workers/semantics/
//! structured-clone/{dedicated,shared}.html timed out).
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agents, and leaves no
//! isolate entered that it entered.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

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

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, reports.reporter());
    defer std.testing.allocator.free(got);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqualStrings(expected, got);
}

fn engineError(err: protocol.Error) runtime.EngineError {
    return switch (err) {
        error.ExceptionPending => error.ExceptionPending,
        error.DataCloneError => error.DataCloneError,
        error.OutOfMemory => error.OutOfMemory,
        else => error.OperationFailed,
    };
}

fn notTransferable(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
    return .not_transferable;
}

/// A message with a transfer list, between two realms: `post(value, list)`
/// in the sending realm converts `list` as the binding converts a
/// sequence<object> and serializes `value` with it; `receive()` in the
/// receiving realm deserializes it there, or answers "messageerror".
const Mailbox = struct {
    from: runtime.Context = undefined,
    to: runtime.Context = undefined,
    message: ?protocol.SerializedWithTransfer = null,

    post_function: protocol.BuiltinFunction = undefined,
    receive_function: protocol.BuiltinFunction = undefined,

    fn install(self: *Mailbox, from: runtime.Context, to: runtime.Context) !void {
        self.from = from;
        self.to = to;
        self.post_function = .{ .steps = post, .data = self };
        self.receive_function = .{ .steps = receive, .data = self };
        try protocol.defineBuiltinFunction(from, "post", 2, &self.post_function);
        try protocol.defineBuiltinFunction(to, "receive", 0, &self.receive_function);
    }

    fn clear(self: *Mailbox) void {
        if (self.message) |*message| message.deinit(std.heap.c_allocator);
        self.message = null;
    }

    fn post(data: ?*anyopaque, args: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        self.clear();
        const value = if (args.len > 0) args[0] else runtime.JSValue.jsUndefined;
        const list = if (args.len > 1) args[1] else runtime.JSValue.jsUndefined;
        const items = protocol.convertToSequenceOfObjects(self.from, list, std.heap.c_allocator) catch |err| return engineError(err);
        defer {
            for (items) |item| item.release();
            std.heap.c_allocator.free(items);
        }
        const values = std.heap.c_allocator.alloc(runtime.JSValue, items.len) catch return error.OutOfMemory;
        defer std.heap.c_allocator.free(values);
        for (items, values) |item, *v| v.* = item.value;
        self.message = protocol.structuredSerializeWithTransfer(self.from, value, values, notTransferable, null, std.heap.c_allocator) catch |err| return engineError(err);
        return runtime.JSValue.fromBoolean(true);
    }

    fn receive(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        const message = self.message orelse return runtime.JSValue.jsUndefined;
        const value = protocol.structuredDeserializeWithTransfer(self.to, message.serialized, message.array_buffers) catch
            return .{ .string = .{ .data = "messageerror", .owned = false } };
        return value.take();
    }
};

const Pair = struct {
    agent: *protocol.Agent,
    sender: runtime.Context,
    receiver: runtime.Context,
    mailbox: *Mailbox,

    fn open(mailbox: *Mailbox) !Pair {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
        errdefer protocol.destroyAgent(agent);
        const sender = try windowRealm(agent);
        const receiver = try windowRealm(agent);
        try mailbox.install(sender, receiver);
        return .{ .agent = agent, .sender = sender, .receiver = receiver, .mailbox = mailbox };
    }

    fn close(self: Pair) void {
        self.mailbox.clear();
        protocol.destroyWindowRealm(self.receiver, .global_detached);
        protocol.destroyWindowRealm(self.sender, .global_detached);
        protocol.destroyAgent(self.agent);
    }
};

test "transfer: a resizable ArrayBuffer arrives resizable, with its maxByteLength and contents" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\globalThis.buffer = new ArrayBuffer(16, { maxByteLength: 1024 });
        \\new Uint8Array(buffer)[3] = 4;
        \\[post(buffer, [buffer]), buffer.byteLength, buffer.detached].join()
    , "true,0,true");
    try expectEval(pair.receiver,
        \\(() => {
        \\  const b = receive();
        \\  const before = [b.byteLength, b.maxByteLength, b.resizable, new Uint8Array(b)[3]];
        \\  b.resize(100);
        \\  return before.concat(b.byteLength).join();
        \\})()
    , "16,1024,true,4,100");
}

test "transfer: a length-tracking view and a DataView of a transferred resizable buffer track its length" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => {
        \\  const ab = new ArrayBuffer(16, { maxByteLength: 1024 });
        \\  return post({ ta: new Uint8Array(ab), dv: new DataView(ab) }, [ab]);
        \\})()
    , "true");
    try expectEval(pair.receiver,
        \\(() => {
        \\  const { ta, dv } = receive();
        \\  ta.buffer.resize(32);
        \\  return [ta.buffer === dv.buffer, ta.buffer.resizable, ta.byteLength, dv.byteLength].join();
        \\})()
    , "true,true,32,32");
}

test "transfer: a fixed-length buffer stays fixed-length" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender, "(() => { const b = new Uint8Array([1, 2, 3]).buffer; return post(b, [b]); })()", "true");
    try expectEval(pair.receiver,
        \\(() => { const b = receive(); return [b.byteLength, b.maxByteLength, b.resizable, new Uint8Array(b)[2]].join(); })()
    , "3,3,false,3");
}

test "transfer: an out-of-bounds view of a transferred buffer is a DataCloneError, and nothing is detached" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => {
        \\  const ab = new ArrayBuffer(16, { maxByteLength: 1024 });
        \\  const ta = new Uint8Array(ab, 8);
        \\  ab.resize(0);
        \\  try { post(ta, [ab]); return "posted"; }
        \\  catch (e) { return [e instanceof DOMException && e.name === "DataCloneError", ab.detached].join(); }
        \\})()
    , "true,false");
}

test "transfer: a list of fixed and resizable buffers keeps each buffer's own shape" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => {
        \\  const fixed = new ArrayBuffer(4);
        \\  const resizable = new ArrayBuffer(8, { maxByteLength: 64 });
        \\  const fixed2 = new ArrayBuffer(2);
        \\  return post([fixed, resizable, fixed2], [fixed, resizable, fixed2]);
        \\})()
    , "true");
    try expectEval(pair.receiver,
        \\receive().map(b => [b.byteLength, b.resizable, b.maxByteLength].join("/")).join()
    , "4/false/4,8/true/64,2/false/2");
}

test "transfer: structuredClone with a transfer list keeps a resizable buffer resizable" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => {
        \\  const ab = new ArrayBuffer(4, { maxByteLength: 16 });
        \\  const view = new Uint16Array(ab);
        \\  view[1] = 7;
        \\  const copy = structuredClone(view, { transfer: [ab] });
        \\  copy.buffer.resize(16);
        \\  return [ab.detached, copy.buffer.resizable, copy.buffer.maxByteLength, copy.length, copy[1]].join();
        \\})()
    , "true,true,16,8,7");
}
