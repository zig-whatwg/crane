//! WebCrypto §14.2: the crypto task source, on the realm's existing task queue.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const keys = @import("key.zig");
const crypto_keys = @import("dom").crypto_keys;

pub const Pair = keys.Pair;
pub const PendingJwk = struct {
    bytes: []u8,
    algorithm: @import("normalize.zig").Algorithm,
    extractable: bool,
    usages: keys.Usages,
    io: std.Io,
};

/// Native results cross the task boundary; no caller's JS argument is retained.
pub const Result = union(enum) {
    none,
    bytes: []u8,
    json: []u8,
    boolean: bool,
    key: keys.Slots,
    key_pair: Pair,
    import_jwk: PendingJwk,
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
            .import_jwk => |*pending| {
                std.crypto.secureZero(u8, pending.bytes);
                allocator.free(pending.bytes);
                pending.algorithm.deinit();
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
    var capability = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&capability);
    const promise = try engine.retainValue(realm, capability.promise);
    errdefer promise.release();
    const task = try realm.allocator.create(Task);
    task.* = .{ .realm = realm, .capability = capability, .result = result };
    // §14.3 methods' final queue-a-global-task step. HTML permits task sources
    // to share a queue; this payload identifies the crypto task source.
    task.queue(Task.run);
    return promise.take();
}

/// Own a copied native input on every path. T.run performs only native work;
/// T.deinit erases/releases that input. No JS value belongs in T.
pub fn submit(realm: runtime.Context, input: anytype) !runtime.JSValue {
    const job = try makeJob(realm.allocator, input);
    errdefer job.destroy(job.data, realm.allocator);
    var capability = try engine.createPromise(realm);
    errdefer engine.releasePromiseCapability(&capability);
    const promise = try engine.retainValue(realm, capability.promise);
    errdefer promise.release();
    const task = try realm.allocator.create(Task);
    task.* = .{ .realm = realm, .capability = capability, .result = .none, .job = job };
    // §14.3 "return promise, then in parallel". Until HTML's parallel-queue
    // facility exists, PBKDF2/RSA and other long native operations occupy the
    // realm's thread. The copied-input computation can move there unchanged.
    task.queue(Task.compute);
    return promise.take();
}

fn makeJob(box_allocator: std.mem.Allocator, input: anytype) !Job {
    const T = @TypeOf(input);
    const Box = struct {
        value: T,

        fn compute(data: *anyopaque, allocator: std.mem.Allocator) anyerror!Result {
            const self: *@This() = @ptrCast(@alignCast(data));
            return self.value.run(allocator);
        }

        fn destroy(data: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *@This() = @ptrCast(@alignCast(data));
            self.value.deinit(allocator);
            allocator.destroy(self);
        }
    };
    var owned_input = input;
    const box = box_allocator.create(Box) catch |err| {
        owned_input.deinit(box_allocator);
        return err;
    };
    box.* = .{ .value = owned_input };
    return .{ .data = box, .compute = Box.compute, .destroy = Box.destroy };
}

const Job = struct {
    data: *anyopaque,
    compute: *const fn (*anyopaque, std.mem.Allocator) anyerror!Result,
    destroy: *const fn (*anyopaque, std.mem.Allocator) void,
};

const Task = struct {
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    result: Result,
    job: ?Job = null,

    fn queue(self: *Task, callback: *const fn (?*anyopaque) void) void {
        // The realm's event loop - a window's, or a worker's own (every worker
        // runs its own loop on its own thread), whose end drops the task
        // through `Task.drop`.
        if (self.realm.getOptionalEventLoop()) |loop| {
            loop.queueTask(.{ .callback = callback, .context = self, .drop = Task.drop });
            return;
        }
        // A bare realm with no event loop (a unit test's) must still settle,
        // as FileReader does.
        callback(self);
    }

    fn compute(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data.?));
        if (!self.realm.hasEngine()) return self.finish();
        const job = self.job.?;
        self.result = job.compute(job.data, self.realm.allocator) catch |err| .{ .failure = err };
        job.destroy(job.data, self.realm.allocator);
        self.job = null;
        // Each method's final queue-a-global-task step: settlement is a LATER
        // task, with the event loop's intervening microtask checkpoint.
        self.queue(Task.run);
    }

    fn run(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data.?));
        if (self.realm.hasEngine()) engine.runTaskInRealm(self.realm, realmSteps, self) catch {};
        if (self.job != null) self.queue(Task.compute) else self.finish();
    }

    fn realmSteps(data: ?*anyopaque) void {
        const self: *Task = @ptrCast(@alignCast(data.?));
        const thrown = engine.completionOf(self.realm, steps, self) catch |err| return self.reject(err);
        if (thrown) |reason| {
            defer reason.release();
            engine.rejectPromise(&self.capability, reason.borrow()) catch {};
        }
    }

    fn steps(data: ?*anyopaque) engine.Error!void {
        const self: *Task = @ptrCast(@alignCast(data.?));
        if (self.result == .failure) return self.reject(self.result.failure);
        if (self.result == .import_jwk) {
            self.prepareJwk() catch |err| {
                if (err == error.ExceptionPending) return error.ExceptionPending;
                return self.reject(err);
            };
            return;
        }
        const result_value = self.value() catch |err| {
            if (err == error.ExceptionPending) return error.ExceptionPending;
            return self.reject(err);
        };
        defer result_value.release();
        engine.resolvePromise(&self.capability, result_value.borrow()) catch {};
    }

    fn prepareJwk(self: *Task) !void {
        const pending = self.result.import_jwk;
        // §14.3.12 step 15 and §9 parse-a-JWK: intrinsic JSON parse, then the
        // actual WebIDL dictionary conversion (including an abrupt completion).
        // Q19 interim: the parser currently uses this realm's prototypes.
        // Switch this single call to the fresh-global protocol operation once
        // the adapter lands it; dictionary conversion remains steps 5–6.
        const object = try engine.parseJsonToValue(self.realm, pending.bytes);
        defer object.release();
        var dictionary = try @import("inputs.zig").dictionary(self.realm, object.borrow());
        if (dictionary.data.kty == null) {
            dictionary.deinit(self.realm.allocator);
            return error.DataError;
        }
        const request: @import("operations.zig").Request = .{
            .operation = .import_key,
            .io = pending.io,
            .algorithm = pending.algorithm,
            .dictionary = dictionary,
            .format = .jwk,
            .extractable = pending.extractable,
            .usages = pending.usages,
        };
        std.crypto.secureZero(u8, pending.bytes);
        self.realm.allocator.free(pending.bytes);
        self.result = .none; // The new job takes both dictionary and algorithm.
        self.job = try makeJob(self.realm.allocator, request);
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
        if (self.job) |job| job.destroy(job.data, self.realm.allocator);
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
