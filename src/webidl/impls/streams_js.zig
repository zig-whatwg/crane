//! JavaScript interop for the Streams implementation, over the engine
//! protocol (`@import("engine")`).
//!
//! The Streams algorithms are written in terms of four JavaScript notions -
//! values, promises you can settle, reactions to a promise, and invoking an
//! author callback - and each needs one exact behaviour that the older
//! streams code approximated (errors became TypeError strings, `start()` ran
//! with `this` undefined). This file is that behaviour, once, on engine
//! operations: no engine handle type appears here or in its consumers.
//!
//! ## Values
//!
//! A `Value` is an engine value together with the realm it belongs to, so the
//! realm-less `clone(v)` and `dispose(v)` keep working: holding a value needs
//! a realm (`engine.retainValue`), and a JavaScriptCore value always pairs
//! with its context anyway. A comment on each function says who owns what it
//! returns; "owned" means the caller disposes it exactly once. Disposing a
//! primitive, or a platform object named by `.instance`, does nothing -
//! neither holds an engine resource - so every Value may be disposed alike.
//!
//! ## Lifetime of the objects the reactions point at
//!
//! Reaction data points at Zig instances (a controller, a stream). Those stay
//! valid because the wrapper cache holds every streams-graph wrapper strongly
//! until the realm is torn down (`wrapper_cache.isStreamsGraphObject`) - see
//! the reasoning there. Blink traces the same edges; this engine cannot.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

/// An engine value and the realm it belongs to.
pub const Value = struct {
    value: runtime.JSValue,
    realm: runtime.Context,
};

pub const Error = error{
    /// A JavaScript exception is pending; the binding lets it propagate
    /// instead of throwing a second one.
    ExceptionPending,
    NoIsolate,
    NoContext,
    OutOfMemory,
    /// The engine refused to create a value or run a call (termination, no
    /// realm behind the context, out of handles).
    V8Failure,
    /// `Realm.wrap` of an object the wrapper cache does not hold strongly:
    /// its wrapper would be made and let go with nothing holding it. Hold
    /// such an object with `clone` instead.
    NotAStreamsGraphObject,
};

/// An engine failure as this file's error: what is pending stays pending,
/// anything else is a failure to act.
pub fn fromEngineError(err: engine.Error) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.ExceptionPending => error.ExceptionPending,
        else => error.V8Failure,
    };
}

/// An engine result as a Value of `realm`: the Owned's value, now the Value's
/// holder's to dispose.
fn adopt(realm: runtime.Context, owned: engine.Owned) Value {
    return .{ .value = owned.take(), .realm = realm };
}

/// The realm a streams object runs in.
pub const Realm = struct {
    ctx: runtime.Context,

    pub fn of(instance: *const runtime.Instance) Error!Realm {
        return ofContext(instance.ctx);
    }

    /// A realm with no engine realm behind it (retired, or never made) runs
    /// nothing.
    pub fn ofContext(ctx: runtime.Context) Error!Realm {
        if (ctx.engine_ctx == null) return error.NoContext;
        return .{ .ctx = ctx };
    }

    // ------------------------------------------------------------------
    // Values
    // ------------------------------------------------------------------

    /// Owned (a primitive: nothing to dispose).
    pub fn undefinedValue(self: Realm) Error!Value {
        return .{ .value = .undefined, .realm = self.ctx };
    }

    /// Owned (a primitive).
    pub fn number(self: Realm, n: f64) Value {
        return .{ .value = .{ .number = n }, .realm = self.ctx };
    }

    /// Owned.
    pub fn string(self: Realm, s: []const u8) Error!Value {
        const held = engine.retainValue(self.ctx, runtime.JSValue.fromStringRef(s)) catch |err| return fromEngineError(err);
        return adopt(self.ctx, held);
    }

    /// Owned copy of a value the binding handed in. The binding never
    /// disposes a `runtime.JSValue` argument's handle, and impl-to-impl
    /// callers keep theirs, so the argument is treated as BORROWED and held
    /// anew. A platform object is held as its wrapper, in its relevant realm.
    pub fn fromRuntime(self: Realm, value: runtime.JSValue) Error!Value {
        const held = engine.retainValue(self.ctx, value) catch |err| return fromEngineError(err);
        return adopt(self.ctx, held);
    }

    /// Owned; `.undefined` when the optional argument was not passed.
    pub fn fromOptional(self: Realm, value: anytype) Error!Value {
        return if (value.was_passed) self.fromRuntime(value.value) else self.undefinedValue();
    }

    /// `instance` as a Value, its wrapper made now: the wrapper cache keeps a
    /// streams-graph object's wrapper, and the instance with it, for the
    /// realm's life - which is what a Zig pointer to it needs. Borrowed:
    /// disposing it does nothing.
    ///
    /// Only a streams-graph object (runtime.streams_graph): any other
    /// wrapper is weak, and made and let go here it can be collected before
    /// the caller takes its own hold - setUpController did that with its
    /// AbortController, and a collection in between freed it. So anything
    /// else is refused (NotAStreamsGraphObject); hold it with `clone`.
    pub fn wrap(self: Realm, instance: *runtime.Instance) Error!Value {
        if (!runtime.streams_graph.isStreamsGraphObject(instance.vtable.name)) return error.NotAStreamsGraphObject;
        const wrapper = engine.retainValue(instance.ctx, .{ .instance = instance }) catch |err| return fromEngineError(err);
        wrapper.release();
        return .{ .value = .{ .instance = instance }, .realm = self.ctx };
    }

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------

    /// Owned: a new TypeError of this realm.
    pub fn typeError(self: Realm, message: []const u8) Error!Value {
        const e = engine.createSimpleException(self.ctx, .TypeError, message) catch |err| return fromEngineError(err);
        return adopt(self.ctx, e);
    }

    /// Owned: a new RangeError of this realm.
    pub fn rangeError(self: Realm, message: []const u8) Error!Value {
        const e = engine.createSimpleException(self.ctx, .RangeError, message) catch |err| return fromEngineError(err);
        return adopt(self.ctx, e);
    }

    /// Throw `value` into the calling script. Returns the error an impl
    /// returns so the binding leaves the exception in flight.
    pub fn throwValue(self: Realm, value: Value) error{ExceptionPending} {
        engine.throwValue(self.ctx, value.value) catch {};
        return error.ExceptionPending;
    }

    // ------------------------------------------------------------------
    // Calls
    // ------------------------------------------------------------------

    /// WebIDL "invoke a callback function" with "rethrow": call `function`
    /// with `this` (undefined when null) and return its completion. Both arms
    /// are owned.
    pub fn call(self: Realm, function: Value, this: ?Value, args: []const Value) Error!Completion {
        // Borrowed for the call: the function stays its holder's.
        const callback: engine.CallbackFunction = .{
            .function = .{ .value = function.value },
            .context = self.ctx,
        };
        var argument_values: [8]runtime.JSValue = undefined;
        if (args.len > argument_values.len) return error.V8Failure;
        for (args, 0..) |arg, i| argument_values[i] = arg.value;
        const this_arg: engine.CallbackThis = if (this) |t| .{ .value = t.value } else .undefined;
        const completion = engine.invokeCallbackFunction(self.ctx, &callback, this_arg, argument_values[0..args.len], .rethrow) catch |err|
            return fromEngineError(err);
        return switch (completion) {
            .normal => |v| .{ .normal = adopt(self.ctx, v) },
            .throw => |e| .{ .thrown = adopt(self.ctx, e) },
        };
    }

    /// WebIDL "invoke a callback function" whose return type is a promise:
    /// a throw becomes a rejected promise, a return value becomes "a promise
    /// resolved with" it. Owned.
    pub fn promiseCall(self: Realm, function: Value, this: ?Value, args: []const Value) Error!Value {
        const completion = try self.call(function, this, args);
        switch (completion) {
            .normal => |v| {
                defer dispose(v);
                return self.promiseResolvedWith(v);
            },
            .thrown => |e| {
                defer dispose(e);
                return self.promiseRejectedWith(e);
            },
        }
    }

    // ------------------------------------------------------------------
    // Promises
    // ------------------------------------------------------------------

    /// WebIDL "a promise resolved with": always a new promise, resolved with
    /// `value` - so a thenable is adopted, not returned. Owned.
    pub fn promiseResolvedWith(self: Realm, value: Value) Error!Value {
        const promise = engine.createResolvedPromise(self.ctx, value.value) catch |err| return fromEngineError(err);
        return adopt(self.ctx, promise);
    }

    /// Owned.
    pub fn promiseResolvedWithUndefined(self: Realm) Error!Value {
        return self.promiseResolvedWith(try self.undefinedValue());
    }

    /// WebIDL "a promise rejected with". Owned.
    pub fn promiseRejectedWith(self: Realm, reason: Value) Error!Value {
        const promise = engine.createRejectedPromise(self.ctx, reason.value) catch |err| return fromEngineError(err);
        return adopt(self.ctx, promise);
    }

    /// Owned: a promise rejected with a new TypeError.
    pub fn promiseRejectedWithTypeError(self: Realm, message: []const u8) Error!Value {
        const err = try self.typeError(message);
        defer dispose(err);
        return self.promiseRejectedWith(err);
    }

    /// WebIDL "react to" `promise`. `ctx` must stay valid until one of the
    /// handlers runs. The settled value is borrowed by the handler, as a
    /// Value of the realm the reaction runs in - the one it was made in.
    ///
    /// Exactly one of `on_fulfilled`, `on_rejected` and `on_dropped` runs
    /// (engine.PromiseReactionSteps): `on_dropped` when the reaction ends
    /// without a handler - its realm ended first, or the collector took the
    /// promise unsettled. A `ctx` the reaction owns is freed at the end of
    /// each handler and by `on_dropped`; one it borrows (an instance the
    /// wrapper cache owns) passes null. On an error none of them runs: `ctx`
    /// stays the caller's.
    pub fn react(
        self: Realm,
        promise: Value,
        comptime Ctx: type,
        ctx: *Ctx,
        comptime on_fulfilled: fn (*Ctx, Value) void,
        comptime on_rejected: fn (*Ctx, Value) void,
        comptime on_dropped: ?fn (*Ctx) void,
    ) Error!void {
        const Steps = struct {
            const steps: engine.PromiseReactionSteps = .{
                .fulfilled = fulfilled,
                .rejected = rejected,
                .dropped = if (on_dropped != null) dropped else null,
            };

            /// The reaction's function was made in the reacting realm, so
            /// that is the current realm while it runs.
            fn realmOfReaction() ?runtime.Context {
                return engine.currentRealm();
            }

            fn fulfilled(data: ?*anyopaque, value: runtime.JSValue) void {
                const realm = realmOfReaction() orelse return dropped(data);
                on_fulfilled(@ptrCast(@alignCast(data.?)), .{ .value = value, .realm = realm });
            }

            fn rejected(data: ?*anyopaque, reason: runtime.JSValue) void {
                const realm = realmOfReaction() orelse return dropped(data);
                on_rejected(@ptrCast(@alignCast(data.?)), .{ .value = reason, .realm = realm });
            }

            fn dropped(data: ?*anyopaque) void {
                if (on_dropped) |drop| drop(@ptrCast(@alignCast(data.?)));
            }
        };
        engine.reactToPromise(self.ctx, promise.value, &Steps.steps, ctx) catch |err| return fromEngineError(err);
    }
};

/// Result objects, arrays and microtasks.
pub const ResultOrder = enum {
    /// A ReadableStreamReadResult dictionary: members in lexicographic order.
    dictionary,
    /// ECMAScript CreateIterResultObject(value, done).
    iterator,
};

/// `{ value, done }` in `order`. Owned.
pub fn resultObject(realm: Realm, value: Value, done: bool, order: ResultOrder) Error!Value {
    const done_member: engine.DictionaryMember = .{ .name = "done", .value = .{ .boolean = done } };
    const value_member: engine.DictionaryMember = .{ .name = "value", .value = value.value };
    const members: [2]engine.DictionaryMember = switch (order) {
        .dictionary => .{ done_member, value_member },
        .iterator => .{ value_member, done_member },
    };
    const object = engine.createDictionaryObject(realm.ctx, &members) catch |err| return fromEngineError(err);
    return adopt(realm.ctx, object);
}

/// CreateArrayFromList(values). Owned.
pub fn arrayFrom(realm: Realm, values: []const Value) Error!Value {
    var buffer: [8]runtime.JSValue = undefined;
    if (values.len > buffer.len) return error.V8Failure;
    for (values, 0..) |v, i| buffer[i] = v.value;
    const array = engine.createSequenceOfValues(realm.ctx, buffer[0..values.len]) catch |err| return fromEngineError(err);
    return adopt(realm.ctx, array);
}

/// HTML "queue a microtask" running `callback(ctx)`.
pub fn queueMicrotask(realm: Realm, comptime Ctx: type, ctx: *Ctx, comptime callback: fn (*Ctx) void) void {
    const Steps = struct {
        fn run(data: ?*anyopaque) void {
            callback(@ptrCast(@alignCast(data.?)));
        }
    };
    const queued: engine.Error!void = if (realm.ctx.agent) |agent| engine.queueMicrotask(agent, Steps.run, ctx) else error.NotSupported;
    queued catch {
        // No agent to queue on (a realm with no engine behind it): run the
        // steps now. Later than a microtask would be never happens, so the
        // read loop they continue does not stall; the cost is that they run
        // inside the caller's steps instead of after them.
        callback(ctx);
    };
}

/// Owned boolean (a primitive).
pub fn boolean(realm: Realm, b: bool) Error!Value {
    return .{ .value = .{ .boolean = b }, .realm = realm.ctx };
}

// ============================================================================
// ArrayBuffers and views (Streams § 8.3)
// ============================================================================

/// An ArrayBufferView's kind, by its constructor ([[TypedArrayName]], or a
/// DataView).
pub const ViewKind = enum {
    int8,
    uint8,
    uint8_clamped,
    int16,
    uint16,
    int32,
    uint32,
    float32,
    float64,
    bigint64,
    biguint64,
    data_view,

    /// Element size from the typed array constructors table (1 for DataView).
    pub fn elementSize(self: ViewKind) usize {
        return switch (self) {
            .int8, .uint8, .uint8_clamped, .data_view => 1,
            .int16, .uint16 => 2,
            .int32, .uint32, .float32 => 4,
            .float64, .bigint64, .biguint64 => 8,
        };
    }

    fn toEngine(self: ViewKind) engine.ViewType {
        return switch (self) {
            .int8 => .int8_array,
            .uint8 => .uint8_array,
            .uint8_clamped => .uint8_clamped_array,
            .int16 => .int16_array,
            .uint16 => .uint16_array,
            .int32 => .int32_array,
            .uint32 => .uint32_array,
            .float32 => .float32_array,
            .float64 => .float64_array,
            .bigint64 => .bigint64_array,
            .biguint64 => .biguint64_array,
            .data_view => .data_view,
        };
    }

    fn fromEngine(view_type: engine.ViewType) ViewKind {
        return switch (view_type) {
            .int8_array => .int8,
            .uint8_array => .uint8,
            .uint8_clamped_array => .uint8_clamped,
            .int16_array => .int16,
            .uint16_array => .uint16,
            .int32_array => .int32,
            .uint32_array => .uint32,
            .float32_array => .float32,
            .float64_array => .float64,
            .bigint64_array => .bigint64,
            .biguint64_array => .biguint64,
            .data_view => .data_view,
        };
    }
};

/// What an ArrayBufferView is, and the buffer it views.
pub const ViewInfo = struct {
    kind: ViewKind,
    byte_offset: usize,
    byte_length: usize,
    /// [[ArrayLength]], or the byte length for a DataView.
    length: usize,
    /// The viewed buffer's byte length: 0 when it is detached.
    buffer_byte_length: usize,
    buffer_detached: bool,
    buffer_shared: bool,
};

pub fn describeView(view: Value) ?ViewInfo {
    const description = engine.describeArrayBufferView(view.realm, view.value) orelse return null;
    const kind = ViewKind.fromEngine(description.view_type);
    var buffer_byte_length: usize = 0;
    if (!description.detached) {
        if (engine.getViewedArrayBuffer(view.realm, view.value)) |buffer| {
            defer buffer.release();
            if (engine.borrowArrayBufferBytes(view.realm, buffer.value)) |bytes| buffer_byte_length = bytes.len;
        } else |_| {}
    }
    return .{
        .kind = kind,
        .byte_offset = description.byte_offset,
        .byte_length = description.byte_length,
        .length = description.byte_length / kind.elementSize(),
        .buffer_byte_length = buffer_byte_length,
        .buffer_detached = description.detached,
        .buffer_shared = description.shared,
    };
}

/// view.[[ViewedArrayBuffer]]. Owned.
pub fn viewBuffer(view: Value) Error!Value {
    const buffer = engine.getViewedArrayBuffer(view.realm, view.value) catch |err| return fromEngineError(err);
    return adopt(view.realm, buffer);
}

/// Construct(ctor-of-kind, « buffer, byteOffset, length »): `length` in
/// elements (bytes for a DataView). Owned.
pub fn newView(kind: ViewKind, buffer: Value, byte_offset: usize, length: usize) Error!Value {
    const view = engine.createArrayBufferView(buffer.realm, kind.toEngine(), buffer.value, byte_offset, length) catch |err|
        return fromEngineError(err);
    return adopt(buffer.realm, view);
}

/// TransferArrayBuffer(O). Owned; null when it cannot be transferred.
pub fn transferBuffer(buffer: Value) ?Value {
    const transferred = engine.transferArrayBuffer(buffer.realm, buffer.value) catch return null;
    return adopt(buffer.realm, transferred);
}

pub fn canTransferBuffer(buffer: Value) bool {
    return engine.canTransferArrayBuffer(buffer.realm, buffer.value);
}

pub fn isDetachedBuffer(buffer: Value) bool {
    return engine.isDetachedBuffer(buffer.realm, buffer.value);
}

/// The bytes of an ArrayBuffer, borrowed until script next runs or the
/// buffer detaches; null when detached.
pub fn bufferBytes(buffer: Value) ?[]u8 {
    return engine.borrowArrayBufferBytes(buffer.realm, buffer.value);
}

/// AllocateArrayBuffer(%ArrayBuffer% of `realm`, n). Owned; null on
/// allocation failure.
pub fn allocateBufferIn(realm: Realm, byte_length: usize) ?Value {
    const buffer = engine.allocateArrayBuffer(realm.ctx, byte_length) catch return null;
    return adopt(realm.ctx, buffer);
}

/// The completion of a call: a normal return value or a thrown value.
pub const Completion = union(enum) {
    normal: Value,
    thrown: Value,

    pub fn deinit(self: Completion) void {
        switch (self) {
            .normal, .thrown => |v| dispose(v),
        }
    }
};

/// A promise together with the capability to settle it - the spec's
/// "a new promise", later "resolve"d or "reject"ed.
///
/// [[PromiseState]] has no engine operation (JavaScriptCore has none): a
/// Deferred's promise is settled only through the Deferred, so the Deferred
/// records it, in a cell of its own that its copies share.
pub const Deferred = struct {
    capability: engine.PromiseCapability,
    /// Owned: the Deferred's own hold on the promise, which outlives the
    /// capability (`deinitResolverOnly` keeps it for the caller).
    promise: Value,
    /// Whether resolve or reject has run. Allocated with `allocator`.
    settled: *bool,
    allocator: std.mem.Allocator,

    pub fn init(realm: Realm) Error!Deferred {
        var capability = engine.createPromise(realm.ctx) catch |err| return fromEngineError(err);
        errdefer engine.releasePromiseCapability(&capability);
        const promise = engine.retainValue(realm.ctx, capability.promise) catch |err| return fromEngineError(err);
        errdefer promise.release();
        const allocator = realm.ctx.allocator;
        const settled = try allocator.create(bool);
        settled.* = false;
        return .{
            .capability = capability,
            .promise = adopt(realm.ctx, promise),
            .settled = settled,
            .allocator = allocator,
        };
    }

    /// A new promise already resolved with undefined.
    pub fn initResolved(realm: Realm) Error!Deferred {
        var d = try init(realm);
        d.resolve(realm, try realm.undefinedValue());
        return d;
    }

    /// A new promise already rejected with `reason`.
    pub fn initRejected(realm: Realm, reason: Value) Error!Deferred {
        var d = try init(realm);
        d.reject(realm, reason);
        return d;
    }

    /// Settling an already-settled promise is a no-op, as in the spec.
    pub fn resolve(self: Deferred, realm: Realm, value: Value) void {
        _ = realm;
        if (self.settled.*) return;
        var capability = self.capability;
        engine.resolvePromise(&capability, value.value) catch return;
        self.settled.* = true;
    }

    pub fn resolveUndefined(self: Deferred, realm: Realm) void {
        self.resolve(realm, .{ .value = .undefined, .realm = realm.ctx });
    }

    pub fn reject(self: Deferred, realm: Realm, reason: Value) void {
        _ = realm;
        if (self.settled.*) return;
        var capability = self.capability;
        engine.rejectPromise(&capability, reason.value) catch return;
        self.settled.* = true;
    }

    /// [[PromiseState]] is "pending".
    pub fn isPending(self: Deferred) bool {
        return !self.settled.*;
    }

    /// Set [[PromiseIsHandled]] to true.
    pub fn markHandled(self: Deferred) void {
        engine.markPromiseAsHandled(self.promise.realm, self.promise.value);
    }

    /// The promise as the call's result, handed over (`toReturnOwned`): for a
    /// Deferred made for this call and kept nowhere once it returns. Only the
    /// promise is handed over: the caller still releases the rest
    /// (`deinitResolverOnly`).
    pub fn returnOwned(self: Deferred) runtime.JSValue {
        return toReturnOwned(self.promise);
    }

    pub fn deinit(self: Deferred) void {
        self.deinitResolverOnly();
        dispose(self.promise);
    }

    /// Release the capability, keeping `promise` for the caller.
    pub fn deinitResolverOnly(self: Deferred) void {
        var capability = self.capability;
        engine.releasePromiseCapability(&capability);
        self.allocator.destroy(self.settled);
    }
};

/// Owned: a second hold on `value`.
pub fn clone(value: Value) Error!Value {
    const held = engine.retainValue(value.realm, value.value) catch |err| return fromEngineError(err);
    return adopt(value.realm, held);
}

pub fn dispose(value: Value) void {
    engine.releaseValue(.{ .value = value.value });
}

pub fn disposeOptional(value: *?Value) void {
    if (value.*) |v| dispose(v);
    value.* = null;
}

/// The value BORROWED, as an engine operation takes it. Never an impl's
/// result: the binding releases what an impl returns - a value the impl keeps
/// goes back as `toReturnKept`, one made for the return as `toReturnOwned`.
pub fn toReturn(value: Value) runtime.JSValue {
    return (engine.Owned{ .value = value.value }).borrow();
}

/// A value the impl keeps (a stored promise), as the call's result: a hold of
/// the binding's own, which it releases once it is the result.
pub fn toReturnKept(value: Value) Error!runtime.JSValue {
    const held = engine.retainValue(value.realm, value.value) catch |err| return fromEngineError(err);
    return held.take();
}

/// A value made only to be returned, handed over: the binding releases it
/// once it is the call's result. Only for a value the impl keeps nowhere - a
/// stored promise (a writer's [[closeRequest]], say) must use `toReturnKept`,
/// or the binding frees it under its holder.
pub fn toReturnOwned(value: Value) runtime.JSValue {
    return value.value;
}

/// An IDL value's engine handle - an ArrayBufferView argument's, say - as a
/// Value of `realm`, owned: the caller disposes it, as the IDL value's owner
/// would have.
pub fn adoptHandle(realm: Realm, handle: *anyopaque) Value {
    return .{
        .value = .{ .handle = .{ .ptr = handle } },
        .realm = realm.ctx,
    };
}

/// The engine handle `value` is, BORROWED - for an IDL value that carries
/// one (an ArrayBufferView's `js`). Null for a value that is none (a
/// primitive, or a platform object named by `.instance`).
pub fn handleOf(value: Value) ?*anyopaque {
    return switch (value.value) {
        .handle => |h| h.ptr,
        else => null,
    };
}

pub fn isUndefined(value: Value) bool {
    return switch (value.value) {
        .undefined => true,
        .handle => engine.typeOf(value.realm, value.value) == .undefined,
        else => false,
    };
}

pub fn isFunction(value: Value) bool {
    return engine.isCallable(value.realm, value.value);
}

/// Type(value) is Object - functions included.
pub fn isObject(value: Value) bool {
    return switch (value.value) {
        .instance => true,
        .handle => engine.typeOf(value.realm, value.value) == .object,
        else => false,
    };
}

/// Read one member of a dictionary being converted from `object` (WebIDL
/// §3.2.18 step "Let jsMemberValue be ? Get(jsDict, key)"). Owned, and null
/// when the member is undefined - i.e. not present. A throwing getter leaves
/// its exception pending and returns error.ExceptionPending.
pub fn getMember(realm: Realm, object: Value, key: []const u8) Error!?Value {
    const member = engine.getProperty(realm.ctx, object.value, key) catch |err| return fromEngineError(err);
    const value = adopt(realm.ctx, member);
    if (isUndefined(value)) {
        dispose(value);
        return null;
    }
    return value;
}

/// A dictionary member whose type is a callback function: undefined means
/// absent, anything not callable is a TypeError (WebIDL §3.2.20). Owned.
pub fn getCallbackMember(realm: Realm, object: Value, key: []const u8) Error!?Value {
    const value = (try getMember(realm, object, key)) orelse return null;
    if (!isFunction(value)) {
        dispose(value);
        const err = try realm.typeError("dictionary member is not a function");
        defer dispose(err);
        return realm.throwValue(err);
    }
    return value;
}
