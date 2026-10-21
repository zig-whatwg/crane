//! Structured serialization owns shared backing stores, independent of agents.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

const Host = struct {
    isolated: bool = true,
    cluster: u64 = 71,

    fn clusterOf(data: ?*anyopaque, _: runtime.Context) u64 {
        const self: *Host = @ptrCast(@alignCast(data.?));
        return self.cluster;
    }
    fn isolatedCapability(data: ?*anyopaque, _: runtime.Context) bool {
        const self: *Host = @ptrCast(@alignCast(data.?));
        return self.isolated;
    }
    const hooks: engine.HostHooks = blk: {
        var result: engine.HostHooks = .{ .agentClusterOf = clusterOf };
        if (@hasField(engine.HostHooks, "crossOriginIsolatedCapability")) result.crossOriginIsolatedCapability = isolatedCapability;
        break :blk result;
    };
};

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}

fn realmOf(agent: *engine.Agent, scope: *runtime.BrowserScope) !runtime.Context {
    return engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://bf1.test", .create_global_object = createGlobal, .browser_scope = scope });
}

fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
const reporter: engine.Reporter = .{ .report = report, .host = null };

fn evaluate(realm: runtime.Context, source: []const u8) !engine.Owned {
    return engine.evaluateClassicScript(realm, .{ .utf8 = source }, "bf1-shared-memory.js", null, reporter);
}

fn expectScript(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const text = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "bf1-shared-memory.js", null, std.testing.allocator, reporter);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings(expected, text);
}

fn noTransfer(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
    return .not_transferable;
}

fn serialize(realm: runtime.Context, value: runtime.JSValue) !engine.SerializedWithTransfer {
    const Call = struct {
        realm: runtime.Context,
        value: runtime.JSValue,
        result: ?engine.SerializedWithTransfer = null,
        fn steps(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            self.result = try engine.structuredSerializeWithTransfer(self.realm, self.value, &.{}, noTransfer, null, std.testing.allocator);
        }
    };
    var call: Call = .{ .realm = realm, .value = value };
    if (try engine.completionOf(realm, Call.steps, &call)) |thrown| {
        thrown.release();
        return error.DataCloneError;
    }
    return call.result orelse error.NoSerialization;
}

fn expectStorageRejected(realm: runtime.Context, value: runtime.JSValue) !void {
    const Call = struct {
        realm: runtime.Context,
        value: runtime.JSValue,
        fn steps(data: ?*anyopaque) engine.Error!void {
            const self: *@This() = @ptrCast(@alignCast(data.?));
            const bytes = try engine.structuredSerializeForStorage(self.realm, self.value, std.testing.allocator);
            std.testing.allocator.free(bytes);
        }
    };
    var call: Call = .{ .realm = realm, .value = value };
    const exception = try engine.completionOf(realm, Call.steps, &call);
    try std.testing.expect(exception != null);
    defer exception.?.release();
    const name = try engine.getProperty(realm, exception.?.value, "name");
    defer name.release();
    const text = try engine.convertToDOMString(realm, name.value, std.testing.allocator);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("DataCloneError", text);
}

const Delivery = struct {
    realm: runtime.Context,
    message: *const engine.SerializedWithTransfer,
    fn read(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *Delivery = @ptrCast(@alignCast(data.?));
        const value = if (comptime @hasDecl(engine, "structuredDeserializeWithOptions"))
            engine.structuredDeserializeWithOptions(self.realm, self.message.serialized, .{ .array_buffers = self.message.array_buffers, .shared_memory = self.message.shared_memory })
        else
            engine.structuredDeserializeWithTransfer(self.realm, self.message.serialized, self.message.array_buffers, &.{});
        const owned = value catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.DataCloneError,
        };
        return owned.take();
    }
};

fn receive(message: *const engine.SerializedWithTransfer, expected: []const u8) !void {
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    var host: Host = .{};
    const agent = try engine.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &Host.hooks, .host = &host, .allocator = std.testing.allocator });
    defer engine.destroyAgent(agent);
    const realm = try realmOf(agent, &scope);
    defer engine.destroyWindowRealm(realm, .global_detached);
    var delivery: Delivery = .{ .realm = realm, .message = message };
    const builtin: engine.BuiltinFunction = .{ .steps = Delivery.read, .data = &delivery };
    try engine.defineBuiltinFunction(realm, "receive", 0, &builtin);
    try expectScript(realm,
        \\globalThis.copy = receive();
        \\const old = Atomics.load(copy.view, 0);
        \\Atomics.store(copy.view, 0, 29);
        \\copy.growable.grow(24);
        \\[copy.buffer === copy.again, copy.view.buffer === copy.buffer,
        \\ old, copy.growable.byteLength, copy.growable.maxByteLength].join()
    , expected);
}

fn receiveThread(message: *const engine.SerializedWithTransfer, result: *anyerror!void) void {
    result.* = receive(message, "true,true,17,24,64");
}

const Case = enum { sharing, sender_shutdown, policy, dropped_message };

fn check(comptime which: Case) !void {
    try engine.initializeEngine(.{});
    var message: ?engine.SerializedWithTransfer = null;
    defer if (message) |*m| m.deinit(std.testing.allocator);
    {
        var scope = runtime.BrowserScope.init(std.testing.allocator);
        defer scope.deinit();
        interfaces.process_hooks.startHooksForTest();
        var host: Host = .{};
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &Host.hooks, .host = &host, .allocator = std.testing.allocator });
        defer engine.destroyAgent(agent);
        const realm = try realmOf(agent, &scope);
        defer engine.destroyWindowRealm(realm, .global_detached);
        const subject = try evaluate(realm,
            \\globalThis.buffer = new SharedArrayBuffer(16);
            \\globalThis.view = new Int32Array(buffer); view[0] = 17;
            \\globalThis.growable = new SharedArrayBuffer(8, {maxByteLength: 64});
            \\({buffer, again: buffer, view, growable})
        );
        defer subject.release();
        if (which == .policy) {
            try expectStorageRejected(realm, subject.value);
            host.isolated = false;
            try std.testing.expectError(error.DataCloneError, serialize(realm, subject.value));
            host.isolated = true;
        }
        message = try serialize(realm, subject.value);
        if (comptime @hasField(engine.SerializedWithTransfer, "shared_memory")) {
            const memory = message.?.shared_memory orelse return error.NoSharedOwner;
            try std.testing.expectEqual(@as(usize, 1), ffi.v8_test_SharedMemory_RefCount(@ptrCast(memory)));
            const retained = memory.retain();
            var retained_live = true;
            defer if (retained_live) retained.release();
            try std.testing.expectEqual(@as(usize, 2), ffi.v8_test_SharedMemory_RefCount(@ptrCast(memory)));
            const RefLoop = struct {
                fn run(shared: *engine.SharedMemory) void {
                    for (0..10000) |_| shared.retain().release();
                }
            };
            const a = try std.Thread.spawn(.{}, RefLoop.run, .{memory});
            var a_joined = false;
            defer if (!a_joined) a.join();
            const b = try std.Thread.spawn(.{}, RefLoop.run, .{memory});
            b.join();
            a.join();
            a_joined = true;
            try std.testing.expectEqual(@as(usize, 2), ffi.v8_test_SharedMemory_RefCount(@ptrCast(memory)));
            retained.release();
            retained_live = false;
            try std.testing.expectEqual(@as(usize, 1), ffi.v8_test_SharedMemory_RefCount(@ptrCast(memory)));
        }
        if (which == .dropped_message) {
            const PortMessage = @import("dom").port_channels.PortMessage;
            const memory = message.?.shared_memory orelse return error.NoSharedOwner;
            const observer = memory.retain();
            defer observer.release();
            var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
            try std.testing.expectError(error.OutOfMemory, PortMessage.create(failing.allocator(), &message.?, &.{}));
            try std.testing.expect(message.?.shared_memory == memory);
            try std.testing.expectEqual(@as(usize, 2), ffi.v8_test_SharedMemory_RefCount(@ptrCast(memory)));
            const queued = try PortMessage.create(std.testing.allocator, &message.?, &.{});
            try std.testing.expectEqual(@as(?*engine.SharedMemory, null), message.?.shared_memory);
            queued.destroy();
            try std.testing.expectEqual(@as(usize, 1), ffi.v8_test_SharedMemory_RefCount(@ptrCast(memory)));
            return;
        }
        if (which == .policy) {
            var delivery: Delivery = .{ .realm = realm, .message = &message.? };
            host.cluster = 72;
            try std.testing.expectError(error.DataCloneError, Delivery.read(&delivery, &.{}));
            host.cluster = 71;
            host.isolated = false;
            try std.testing.expectError(error.DataCloneError, Delivery.read(&delivery, &.{}));
            return;
        }
        if (which == .sharing) {
            var result: anyerror!void = {};
            const thread = try std.Thread.spawn(.{}, receiveThread, .{ &message.?, &result });
            thread.join();
            try result;
            try expectScript(realm, "[Atomics.load(view, 0), growable.byteLength, growable.maxByteLength].join()", "29,24,64");
        }
    }
    if (which == .sender_shutdown) {
        // The sending isolate and its allocator have gone. No V8 handle can
        // be kept in the message; its shared backing-store owner is enough.
        var result: anyerror!void = {};
        const thread = try std.Thread.spawn(.{}, receiveThread, .{ &message.?, &result });
        thread.join();
        try result;
    }
}

fn onThread(comptime which: Case) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check(which);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

test "shared serialization preserves identity, views and growth across two live agents" {
    try onThread(.sharing);
}
test "shared serialization owns memory past the sending agent's shutdown" {
    try onThread(.sender_shutdown);
}
test "shared serialization rejects storage, nonisolated and cross-cluster access" {
    try onThread(.policy);
}

test "shared message allocation failure and drop keep exactly one sidecar owner" {
    try onThread(.dropped_message);
}
