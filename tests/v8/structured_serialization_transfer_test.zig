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
//! A transferable platform object that is also inside the value - a port
//! posted as `postMessage({ port }, [port])` or `postMessage(port, [port])` -
//! is the transferred object where the value refers to it: the transfer list
//! fills `memory` first (StructuredSerializeWithTransfer step 2.4,
//! StructuredDeserializeWithTransfer steps 3.5 and 4). Before, the
//! serializer saw the port as a platform object that is not [Serializable]
//! and threw DataCloneError.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent), makes its own agents, and leaves no
//! isolate entered that it entered.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

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

/// A message with a transfer list, between two realms, as a MessagePort
/// carries one: `post(value, list)` in the sending realm converts `list` as
/// the binding converts a sequence<object>, serializes `value` with it and
/// runs each transferred port's transfer steps (ships its end); `receive()`
/// in the receiving realm runs their transfer-receiving steps (new ports on
/// the ends) and deserializes the value there with them, or answers
/// "messageerror"; `receivedPorts()` is those ports, in transfer-list order.
/// `receiveWithoutPorts()` deserializes with none of them.
const Mailbox = struct {
    from: runtime.Context = undefined,
    to: runtime.Context = undefined,
    message: ?protocol.SerializedWithTransfer = null,
    /// The shipped ports' ends, until `receive` takes them.
    ends: std.ArrayListUnmanaged(*anyopaque) = .empty,
    /// The ports `receive` made, in transfer-list order.
    received: std.ArrayListUnmanaged(*runtime.Instance) = .empty,

    post_function: protocol.BuiltinFunction = undefined,
    receive_function: protocol.BuiltinFunction = undefined,
    ports_function: protocol.BuiltinFunction = undefined,
    without_ports_function: protocol.BuiltinFunction = undefined,

    fn install(self: *Mailbox, from: runtime.Context, to: runtime.Context) !void {
        self.from = from;
        self.to = to;
        self.post_function = .{ .steps = post, .data = self };
        self.receive_function = .{ .steps = receive, .data = self };
        self.ports_function = .{ .steps = receivedPorts, .data = self };
        self.without_ports_function = .{ .steps = receiveWithoutPorts, .data = self };
        try protocol.defineBuiltinFunction(from, "post", 2, &self.post_function);
        try protocol.defineBuiltinFunction(to, "receive", 0, &self.receive_function);
        try protocol.defineBuiltinFunction(to, "receivedPorts", 0, &self.ports_function);
        try protocol.defineBuiltinFunction(to, "receiveWithoutPorts", 0, &self.without_ports_function);
    }

    fn clear(self: *Mailbox) void {
        if (self.message) |*message| message.deinit(std.heap.c_allocator);
        self.message = null;
        for (self.ends.items) |end| dom.message_ports.discard(end);
        self.ends.clearAndFree(std.heap.c_allocator);
        self.received.clearAndFree(std.heap.c_allocator);
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
        self.message = protocol.structuredSerializeWithTransfer(self.from, value, values, transferablePort, null, std.heap.c_allocator) catch |err| return engineError(err);
        // Step 5.5: the transfer steps of each transferred port.
        for (self.message.?.platform_objects) |port| {
            const end = dom.message_ports.ship(port) orelse return error.DataCloneError;
            self.ends.append(std.heap.c_allocator, end) catch return error.OutOfMemory;
        }
        return runtime.JSValue.fromBoolean(true);
    }

    fn receive(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        const message = self.message orelse return runtime.JSValue.jsUndefined;
        // StructuredDeserializeWithTransfer step 3: the transfer-receiving
        // steps, before the value is deserialized.
        for (self.ends.items) |end| {
            const port = dom.message_ports.receive(self.to, end) catch return error.OperationFailed;
            self.received.append(std.heap.c_allocator, port) catch return error.OutOfMemory;
        }
        self.ends.clearRetainingCapacity();
        const value = protocol.structuredDeserializeWithTransfer(self.to, message.serialized, message.array_buffers, self.received.items) catch
            return .{ .string = .{ .data = "messageerror", .owned = false } };
        return value.take();
    }

    fn receivedPorts(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        const array = protocol.createSequenceOfPlatformObjects(self.to, self.received.items) catch |err| return engineError(err);
        return array.take();
    }

    /// The message deserialized as if no port had been received: a value
    /// that refers to a transferred port then refers past the list.
    fn receiveWithoutPorts(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Mailbox = @ptrCast(@alignCast(data.?));
        const message = self.message orelse return runtime.JSValue.jsUndefined;
        const value = protocol.structuredDeserializeWithTransfer(self.to, message.serialized, message.array_buffers, &.{}) catch
            return .{ .string = .{ .data = "messageerror", .owned = false } };
        return value.take();
    }
};

/// What a port's postMessage can transfer: MessagePorts that are not
/// detached (MessagePort's own answer, as worker_host asks it).
fn transferablePort(_: ?*anyopaque, instance: *runtime.Instance) runtime.TransferableState {
    return dom.message_ports.transferableState(instance);
}

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

test "transfer: a port both in the value and in the transfer list arrives as the transferred port" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\globalThis.channel = new MessageChannel();
        \\post({ port: channel.port2, nested: { again: [channel.port2] } }, [channel.port2])
    , "true");
    try expectEval(pair.receiver,
        \\(() => {
        \\  const v = receive();
        \\  const [port] = receivedPorts();
        \\  return [v.port instanceof MessagePort, v.port === port, v.nested.again[0] === port].join();
        \\})()
    , "true,true,true");
}

test "transfer: a port that is the value itself arrives as the transferred port" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender, "(() => { const c = new MessageChannel(); return post(c.port2, [c.port2]); })()", "true");
    try expectEval(pair.receiver, "receive() === receivedPorts()[0]", "true");
}

test "transfer: ports and buffers in one list - each port is found by its place among the transferred ports" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => {
        \\  const a = new MessageChannel(), b = new MessageChannel();
        \\  const buffer = new Uint8Array([9]).buffer;
        \\  return post({ second: b.port1, buffer, first: a.port1 }, [a.port1, buffer, b.port1]);
        \\})()
    , "true");
    try expectEval(pair.receiver,
        \\(() => {
        \\  const v = receive();
        \\  const ports = receivedPorts();
        \\  return [ports.length, v.first === ports[0], v.second === ports[1], new Uint8Array(v.buffer)[0]].join();
        \\})()
    , "2,true,true,9");
}

test "transfer: a port in the value but not in the transfer list is still a DataCloneError" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => {
        \\  const c = new MessageChannel();
        \\  try { post({ port: c.port1 }, [c.port2]); return "posted"; }
        \\  catch (e) { return [e instanceof DOMException && e.name === "DataCloneError", c.port2 instanceof MessagePort].join(); }
        \\})()
    , "true,true");
}

test "transfer: a reference past the transferred objects given to the deserializer is a messageerror, not a crash" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => { const c = new MessageChannel(); return post({ p: c.port2 }, [c.port2]); })()
    , "true");
    // The receiving side deserializes with none of the transferred ports: the
    // value's reference to the first one points past the list.
    try expectEval(pair.receiver, "receiveWithoutPorts()", "messageerror");
}

test "transfer: structuredClone transfers a MessagePort, which is then detached" {
    var mailbox: Mailbox = .{};
    const pair = try Pair.open(&mailbox);
    defer pair.close();
    try expectEval(pair.sender,
        \\(() => {
        \\  const c = new MessageChannel();
        \\  const copy = structuredClone({ p: c.port2, q: [c.port2] }, { transfer: [c.port2] });
        \\  let again;
        \\  try { structuredClone(c.port2, { transfer: [c.port2] }); again = "cloned"; } catch (e) { again = e.name; }
        \\  const unused = new MessageChannel();
        \\  const plain = structuredClone(1, { transfer: [unused.port1] });
        \\  return [copy.p instanceof MessagePort, copy.p !== c.port2, copy.p === copy.q[0], again, plain].join();
        \\})()
    , "true,true,true,DataCloneError,1");
}
