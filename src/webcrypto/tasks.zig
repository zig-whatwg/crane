//! WebCrypto §14.2: the crypto task source, on the realm's existing task queue.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const keys = @import("key.zig");
const crypto_keys = @import("dom").crypto_keys;

pub const Pair = struct { public_key: keys.Slots, private_key: keys.Slots };

/// Native results cross the task boundary; no caller's JS argument is retained.
pub const Result = union(enum) {
    none,
    bytes: []u8,
    json: []u8,
    boolean: bool,
    key: keys.Slots,
    key_pair: Pair,
    failure: anyerror,

    pub fn deinit(self: *Result, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .bytes, .json => |bytes| {
                std.crypto.secureZero(u8, bytes);
                allocator.free(bytes);
            },
            .key => |*key| key.deinit(),
            .key_pair => |*pair| {
                pair.public_key.deinit();
                pair.private_key.deinit();
            },
            else => {},
        }
        self.* = .none;
    }
};

/// Takes ownership of the native result on both success and failure. The
/// promise is created here and resolved/rejected only from the crypto task.
pub fn settle(realm: runtime.Context, computation: anyerror!Result) !runtime.JSValue {
    var result = computation catch |err| Result{ .failure = err };
    errdefer result.deinit(realm.allocator);
    const loop = realm.getOptionalEventLoop() orelse return error.NotSupportedError;
    var capability = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&capability);
    const promise = try engine.retainValue(realm, capability.promise);
    errdefer promise.release();
    const task = try realm.allocator.create(Task);
    task.* = .{ .realm = realm, .capability = capability, .result = result };
    // §14.3 methods' final queue-a-global-task step. HTML permits task sources
    // to share a queue; this payload identifies the crypto task source.
    loop.queueTask(.{ .callback = Task.run, .context = task, .drop = Task.drop });
    return promise.take();
}

const Task = struct {
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    result: Result,

    fn run(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data.?));
        defer self.finish();
        if (self.realm.hasEngine()) engine.runTaskInRealm(self.realm, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data.?));
        if (self.result == .failure) return self.reject(self.result.failure);
        const result_value = self.value() catch |err| return self.reject(err);
        defer result_value.release();
        engine.resolvePromise(&self.capability, result_value.borrow()) catch {};
    }

    fn value(self: *Task) !engine.Owned {
        return switch (self.result) {
            .bytes => |bytes| try engine.createArrayBuffer(self.realm, bytes),
            .json => |bytes| try engine.parseJsonToValue(self.realm, bytes),
            .boolean => |value_| .{ .value = .{ .boolean = value_ } },
            .key => |slots| blk: {
                // The hook takes slots only on success, then the wrapper owns
                // the key. The task no longer frees the transferred material.
                const instance = try crypto_keys.create(self.realm, slots);
                self.result = .none;
                errdefer if (!engine.hasWrapper(instance)) runtime.Instance.deinit(instance);
                break :blk try engine.retainValue(self.realm, .{ .instance = instance });
            },
            .key_pair => |pair| blk: {
                self.result = .none;
                break :blk try pairValue(self.realm, pair);
            },
            else => error.OperationError,
        };
    }

    fn reject(self: *Task, err: anyerror) void {
        const reason = if (err == error.TypeError)
            engine.createSimpleException(self.realm, .TypeError, "Invalid WebCrypto argument")
        else
            engine.createDOMException(self.realm, switch (err) {
                error.NotSupportedError, error.NotSupported => "NotSupportedError",
                error.InvalidAccessError => "InvalidAccessError",
                error.SyntaxError => "SyntaxError",
                error.DataError => "DataError",
                error.DataCloneError => "DataCloneError",
                else => "OperationError",
            }, "WebCrypto operation failed");
        const owned = reason catch {
            // Even failure to allocate an exception must not leave a live
            // realm's promise pending forever.
            engine.rejectPromise(&self.capability, .undefined) catch {};
            return;
        };
        defer owned.release();
        engine.rejectPromise(&self.capability, owned.borrow()) catch {};
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data.?));
        self.finish();
    }

    fn finish(self: *Task) void {
        self.result.deinit(self.realm.allocator);
        engine.releasePromiseCapability(&self.capability);
        self.realm.allocator.destroy(self);
    }
};

/// Owns both slot sets, including every failure before the pair is wrapped.
fn pairValue(realm: runtime.Context, pair: Pair) !engine.Owned {
    var slots = pair;
    var own_public = true;
    defer if (own_public) slots.public_key.deinit();
    var own_private = true;
    defer if (own_private) slots.private_key.deinit();
    const public_key = try crypto_keys.create(realm, slots.public_key);
    own_public = false;
    errdefer if (!engine.hasWrapper(public_key)) runtime.Instance.deinit(public_key);
    const public_value = try engine.retainValue(realm, .{ .instance = public_key });
    defer public_value.release();
    const private_key = try crypto_keys.create(realm, slots.private_key);
    own_private = false;
    errdefer if (!engine.hasWrapper(private_key)) runtime.Instance.deinit(private_key);
    const private_value = try engine.retainValue(realm, .{ .instance = private_key });
    defer private_value.release();
    return engine.createDictionaryObject(realm, &.{
        .{ .name = "publicKey", .value = public_value.borrow() },
        .{ .name = "privateKey", .value = private_value.borrow() },
    });
}
