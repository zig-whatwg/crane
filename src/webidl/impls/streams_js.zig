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
//! Streams objects reach each other through Zig pointers, and a streams
//! object lives exactly as long as its wrapper: the wrappers are weak, as any
//! platform object's, and the collector frees an instance with its wrapper.
//! So every pointer that must stay valid is one of two things
//! (tmp/plans/streams-lifetime-design.md; Blink's core/streams classes
//! Trace() the same members):
//! - a traced edge (engine.traceChild): between the objects of one stream - a
//!   stream and its controller, its reader, a BYOB request - and from a
//!   controller to what its algorithms close over; peers die together;
//! - a `Hold` (below): pending work - a reaction, a pipe, a tee, an iterator,
//!   a network source - keeps what it will touch until it ends, given back
//!   in exactly one of its ends. A new stream is held by its setup, then by
//!   its start reaction until start's promise settles (a microtask at the
//!   soonest), so whoever made it has it by then.
//! The JavaScript values a controller runs (an underlying source's
//! callbacks and `this`, a size function) are traced from it too
//! (`TracedAlgorithms`): a strong handle on a closure that reaches the
//! controller would keep the whole stream for its realm's life.

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

    /// `instance` as a Value - an argument to a call, which the engine
    /// converts to its wrapper there. Makes no wrapper: one made and let go
    /// here could be collected before anything held it (lesson "a wrapper
    /// made and released before you take your hold"); the instance must be
    /// kept by an edge or a `Hold` while the Value is used. Borrowed:
    /// disposing it does nothing.
    pub fn instanceValue(self: Realm, object: *runtime.Instance) Value {
        return .{ .value = .{ .instance = object }, .realm = self.ctx };
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
    /// promise unsettled. Whatever `ctx` owns or holds - its memory, a `Hold`
    /// on the streams object it points at - is let go at the end of each
    /// handler and by `on_dropped`. On an error none of them runs: `ctx`
    /// stays the caller's. A `ctx` that is a streams object itself goes
    /// through `reactHolding`, which holds it.
    pub fn react(
        self: Realm,
        promise: Value,
        comptime Ctx: type,
        ctx: *Ctx,
        comptime on_fulfilled: fn (*Ctx, Value) void,
        comptime on_rejected: fn (*Ctx, Value) void,
        comptime on_dropped: fn (*Ctx) void,
    ) Error!void {
        const Steps = struct {
            const steps: engine.PromiseReactionSteps = .{
                .fulfilled = fulfilled,
                .rejected = rejected,
                .dropped = dropped,
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
                on_dropped(@ptrCast(@alignCast(data.?)));
            }
        };
        engine.reactToPromise(self.ctx, promise.value, &Steps.steps, ctx) catch |err| return fromEngineError(err);
    }

    /// `react` with steps on `object` - a controller, a stream - that the
    /// reaction HOLDS until it ends: the steps run with it alive however
    /// little else reaches it, and a reaction that never runs (its promise
    /// collected unsettled, its realm ended) gives it back. A step is skipped
    /// for an object its own realm's end freed meanwhile.
    ///
    /// The promise is usually script's (a source's start() or pull(), a
    /// sink's write()): until script settles it nothing else may reach the
    /// stream, and the step must still find it.
    ///
    /// `keeper`, when given, is where `object` keeps the hold while it lasts,
    /// so that it can give it back early (`ReactionHold.giveEarly`) once the
    /// steps can do nothing observable - a readable controller's pull and
    /// start once its algorithms are cleared: a TransformStream's readable
    /// side pulls on a promise that stays pending after the stream closes.
    pub fn reactHolding(
        self: Realm,
        promise: Value,
        object: *runtime.Instance,
        keeper: ?*?*ReactionHold,
        comptime on_fulfilled: fn (*runtime.Instance, Value) void,
        comptime on_rejected: fn (*runtime.Instance, Value) void,
    ) Error!void {
        const Held = struct {
            reaction_hold: ReactionHold,
            allocator: std.mem.Allocator,

            fn finish(held: *@This()) void {
                const allocator = held.allocator;
                held.reaction_hold.give();
                allocator.destroy(held);
            }

            fn fulfilled(held: *@This(), value: Value) void {
                defer held.finish();
                if (held.reaction_hold.hold.alive()) on_fulfilled(held.reaction_hold.hold.instance, value);
            }

            fn rejected(held: *@This(), reason: Value) void {
                defer held.finish();
                if (held.reaction_hold.hold.alive()) on_rejected(held.reaction_hold.hold.instance, reason);
            }
        };
        const held = try self.ctx.allocator.create(Held);
        held.* = .{ .reaction_hold = .{ .hold = Hold.take(object), .keeper = keeper }, .allocator = self.ctx.allocator };
        if (keeper) |k| k.* = &held.reaction_hold;
        self.react(promise, Held, held, Held.fulfilled, Held.rejected, Held.finish) catch |err| {
            held.finish();
            return err;
        };
    }
};

/// A reaction's hold (`Realm.reactHolding`) that its object may give back
/// before the reaction ends. Given exactly once: by the reaction's end, or
/// earlier by its object - after which the object may be collected, and the
/// reaction's steps, which check the hold's liveness, skip it.
pub const ReactionHold = struct {
    hold: Hold,
    given: bool = false,
    /// Where the object keeps this while it is held (a controller's field);
    /// cleared when it is given. Read only while not given - while the hold
    /// keeps the object, and the field with it, alive.
    keeper: ?*?*ReactionHold = null,

    fn give(self: *ReactionHold) void {
        if (self.given) return;
        self.given = true;
        if (self.keeper) |k| {
            if (k.* == self) k.* = null;
        }
        self.hold.give();
    }

    /// The object's early give of the hold `at` keeps, if one is: the
    /// reaction's steps can no longer do anything observable.
    pub fn giveEarly(at: *?*ReactionHold) void {
        const reaction_hold = at.* orelse return;
        reaction_hold.give();
    }
};

/// The traced edges and values of streams objects (engine.TracedSlot), one
/// per member - Blink's Trace() of the same members: a ReadableStream visits
/// readable_stream_controller_ and reader_, a reader its
/// owner_readable_stream_, a controller its stream and its algorithms
/// (core/streams). Names are per owner; the namespace is streams code's alone
/// (no streams interface has a [SameObject] attribute).
pub const slot = struct {
    /// A stream's [[controller]]; a TransformStream's [[controller]]; a BYOB
    /// request's [[controller]].
    pub const controller: engine.TracedSlot = .{ .name = "streams:controller" };
    /// A ReadableStream's [[reader]].
    pub const reader: engine.TracedSlot = .{ .name = "streams:reader" };
    /// A WritableStream's [[writer]].
    pub const writer: engine.TracedSlot = .{ .name = "streams:writer" };
    /// A controller's, a reader's or a writer's [[stream]].
    pub const stream: engine.TracedSlot = .{ .name = "streams:stream" };
    /// A byte controller's [[byobRequest]].
    pub const byob_request: engine.TracedSlot = .{ .name = "streams:byobRequest" };
    /// The platform object a controller's algorithms close over: a
    /// TransformStream (both its sides), a tee's source stream (both
    /// branches), a Blob (its stream()).
    pub const source: engine.TracedSlot = .{ .name = "streams:source" };
    /// The TransformStream of a TextDecoderStream, TextEncoderStream,
    /// CompressionStream or DecompressionStream (their [[transform]]).
    pub const transform_stream: engine.TracedSlot = .{ .name = "streams:transformStream" };
    /// A TransformStream's [[readable]] and [[writable]].
    pub const readable: engine.TracedSlot = .{ .name = "streams:readable" };
    pub const writable: engine.TracedSlot = .{ .name = "streams:writable" };
    /// A tee's branches, kept by its source stream (Blink's TeeEngine traces
    /// both; an unread branch lives as long as its source, as in Chrome).
    pub const tee_branch1: engine.TracedSlot = .{ .name = "streams:teeBranch1" };
    pub const tee_branch2: engine.TracedSlot = .{ .name = "streams:teeBranch2" };
    /// A writable controller's [[abortController]].
    pub const abort_controller: engine.TracedSlot = .{ .name = "streams:abortController" };
    /// The algorithms' JavaScript values: the underlying source's, sink's or
    /// transformer's `this` and callbacks, and the strategy's size function.
    pub const this: engine.TracedSlot = .{ .name = "streams:algorithms:this" };
    pub const start: engine.TracedSlot = .{ .name = "streams:algorithms:start" };
    pub const pull: engine.TracedSlot = .{ .name = "streams:algorithms:pull" };
    pub const cancel: engine.TracedSlot = .{ .name = "streams:algorithms:cancel" };
    pub const write: engine.TracedSlot = .{ .name = "streams:algorithms:write" };
    pub const close: engine.TracedSlot = .{ .name = "streams:algorithms:close" };
    pub const abort: engine.TracedSlot = .{ .name = "streams:algorithms:abort" };
    pub const transform: engine.TracedSlot = .{ .name = "streams:algorithms:transform" };
    pub const flush: engine.TracedSlot = .{ .name = "streams:algorithms:flush" };
    pub const size: engine.TracedSlot = .{ .name = "streams:algorithms:size" };
};

/// `owner` and `member` keep each other: two traced edges, `member` in
/// `owner`'s `to_member` and `owner` in `member`'s `to_owner` - a stream and
/// its controller, its reader. They are kept whole while anything reaches
/// either, and collected together otherwise.
///
/// The edges make both wrappers, and the wrapper cache owns both from then
/// on. A wrapper the engine could not cache (out of memory: the edge is
/// silently not drawn) leaves its object owned by nobody, so that is
/// error.OutOfMemory - the caller's failure path frees what is unwrapped,
/// as a failed `wrap` once made it (tests/v8/sa_transform_setup_oom_test.zig
/// fails each allocation of a setup in turn).
pub fn traceBoth(owner: *runtime.Instance, to_member: engine.TracedSlot, member: *runtime.Instance, to_owner: engine.TracedSlot) error{OutOfMemory}!void {
    engine.traceChild(owner, member, to_member);
    engine.traceChild(member, owner, to_owner);
    if (!engine.hasWrapper(owner) or !engine.hasWrapper(member)) return error.OutOfMemory;
}

/// End both edges `traceBoth` drew (a reader released, a BYOB request
/// invalidated).
pub fn forgetBoth(owner: *runtime.Instance, to_member: engine.TracedSlot, member: *runtime.Instance, to_owner: engine.TracedSlot) void {
    engine.forgetTracedChild(owner, to_member);
    engine.forgetTracedChild(member, to_owner);
}

/// A counted keep on a streams object (engine.keepPlatformObjectAlive) for
/// work still pending that will touch it - a reaction, a pipe, a tee, an
/// async iterator, a network source: its wrapper is held whatever script
/// holds, so the collector leaves it and everything it traces alone. Exactly
/// one `give` per `take` (a counted keep: one owner's extra release would end
/// another's). Blink keeps pending work's objects through traced members of
/// the reactions themselves (pipe_to_engine.cc); a hold is the root form of
/// that, given back when the work ends.
///
/// A hold keeps its object from the collector, not from its realm's end
/// (lesson "a traced edge keeps an object from the collector, not from its
/// realm's end" holds for holds too): work in one realm on another realm's
/// stream asks `alive` before it touches it, and `give` never reaches a freed
/// one.
pub const Hold = struct {
    instance: *runtime.Instance,
    generation: u64,

    pub fn take(object: *runtime.Instance) Hold {
        engine.keepPlatformObjectAlive(object);
        return .{ .instance = object, .generation = runtime.SlabAllocator.generationOf(object) };
    }

    /// Still the object `take` held: its realm has not ended and freed it.
    pub fn alive(self: Hold) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }

    pub fn give(self: Hold) void {
        if (self.alive()) engine.releasePlatformObject(self.instance);
    }
};

/// Keep `value` - a JavaScript value a streams object runs or hands to
/// script, such as an underlying source's pull() - as a value traced from
/// `owner` (engine.traceValue), in slot `at`: it lives as long as `owner` does,
/// and a value that reaches back to `owner` (a source whose closure keeps its
/// controller) goes with it. `value` stays its holder's. A strong handle
/// instead kept the closure, and through it the whole stream, for the
/// realm's life.
pub fn keepTraced(owner: *runtime.Instance, at: engine.TracedSlot, value: Value) void {
    engine.traceValue(owner, value.value, at);
}

/// The value `keepTraced` keeps in `owner`'s slot `at`, as a Value of `realm`.
/// Owned (dispose it); null when the slot holds none.
pub fn readTraced(realm: Realm, owner: *runtime.Instance, at: engine.TracedSlot) ?Value {
    const held = engine.tracedValue(owner, at) orelse return null;
    return adopt(realm.ctx, held);
}

/// End `keepTraced`'s value in `owner`'s slot `at` (ClearAlgorithms).
pub fn forgetTraced(owner: *runtime.Instance, at: engine.TracedSlot) void {
    engine.forgetTracedChild(owner, at);
}

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

/// HTML "queue a microtask" running `callback(ctx)` - or, when it never runs,
/// `dropped(ctx)`, so that whatever `ctx` holds is let go either way. A realm
/// microtask (engine.queueRealmMicrotask): `dropped` runs when the realm ends
/// with it queued, or when the agent's queue is discarded under it (a
/// terminated checkpoint: a worker's termination, a script deadline).
///
/// `dropped` is required. This used engine.queueMicrotask, which has no
/// dropped end, and the data of every microtask that never ran leaked - lane
/// leaks1: fetch_body's read loop (the WPT runner's three empty-stack
/// reports, FileAPI/BlobURL/cross-partition.https.html) and the tees' chunk
/// steps (tests/v8/microtask_dropped_end_test.zig).
pub fn queueMicrotask(realm: Realm, comptime Ctx: type, ctx: *Ctx, comptime callback: fn (*Ctx) void, comptime dropped: fn (*Ctx) void) void {
    const Steps = struct {
        fn run(data: ?*anyopaque, _: runtime.JSValue) void {
            callback(@ptrCast(@alignCast(data.?)));
        }

        fn drop(data: ?*anyopaque) void {
            dropped(@ptrCast(@alignCast(data.?)));
        }

        const steps: engine.PromiseReactionSteps = .{ .fulfilled = run, .dropped = drop };
    };
    const queued: engine.Error!void = if (realm.ctx.agent != null) engine.queueRealmMicrotask(realm.ctx, &Steps.steps, ctx) else error.NotSupported;
    queued catch |err| switch (err) {
        // The realm's end is under way, or its agent is being stopped: the
        // steps would run in nothing.
        error.OperationFailed => dropped(ctx),
        // No microtask queue behind the realm (an engine without one; a
        // realm with no engine, a unit test's) or no memory: run the steps
        // now. Later than a microtask would be never happens, so the read
        // loop they continue does not stall; the cost is that they run inside
        // the caller's steps instead of after them.
        else => callback(ctx),
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
    float16,

    /// Element size from the typed array constructors table (1 for DataView).
    pub fn elementSize(self: ViewKind) usize {
        return switch (self) {
            .int8, .uint8, .uint8_clamped, .data_view => 1,
            .int16, .uint16, .float16 => 2,
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
            .float16 => .float16_array,
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
            .float16_array => .float16,
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
///
/// Settling also releases the capability: a settled Deferred never settles
/// again, so its resolver and the capability's promise - two of the three
/// handles a pending Deferred holds - are released then, and a settled one
/// keeps its own hold on the promise alone. Every copy carries the same
/// capability and reads the shared cell before touching it: settled means
/// released (resolve, reject and deinit leave it alone). The cell stays one
/// byte: a capability in it put every Deferred in a larger size class of the
/// allocator, whose buckets the streams' churn mapped and unmapped (lane
/// leakcheck1's gc_bench: +17-23% instructions per Response.text()). Streams
/// objects keep their promises for as long as they live (a reader's
/// [[closedPromise]], a writer's [[readyPromise]]), so the two counted per
/// settled promise per live stream
/// (tests/v8/streams_settled_promise_handles_test.zig).
pub const Deferred = struct {
    /// OWNED while the promise is pending; released by the settle that
    /// sets `settled` (or by deinit, if none did).
    capability: engine.PromiseCapability,
    /// Owned: the Deferred's own hold on the promise, which outlives the
    /// capability (`deinitResolverOnly` keeps it for the caller).
    promise: Value,
    /// Whether resolve or reject has run - and so released the capability.
    /// Allocated with `allocator`.
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
        self.settle(.resolve, value);
    }

    pub fn resolveUndefined(self: Deferred, realm: Realm) void {
        self.resolve(realm, .{ .value = .undefined, .realm = realm.ctx });
    }

    pub fn reject(self: Deferred, realm: Realm, reason: Value) void {
        _ = realm;
        self.settle(.reject, reason);
    }

    /// Resolve or reject the promise once, then release the capability.
    /// Settled is recorded BEFORE the engine settles it, as the resolving
    /// functions set alreadyResolved before anything else (ECMAScript
    /// CreateResolvingFunctions, 27.2.1.3): resolving with an object reads its
    /// `then`, which runs script, and a settle that script reaches is a
    /// no-op - never a second settle of a promise already resolved with a
    /// thenable, nor a second release of the capability. An engine failure
    /// (a terminating agent) leaves the promise pending and settleable.
    fn settle(self: Deferred, how: enum { resolve, reject }, value: Value) void {
        if (self.settled.*) return;
        self.settled.* = true;
        var capability = self.capability;
        const done = switch (how) {
            .resolve => engine.resolvePromise(&capability, value.value),
            .reject => engine.rejectPromise(&capability, value.value),
        };
        done catch {
            self.settled.* = false;
            return;
        };
        engine.releasePromiseCapability(&capability);
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

    /// Release the capability, if the promise is still pending, and the
    /// cell, keeping `promise` for the caller.
    pub fn deinitResolverOnly(self: Deferred) void {
        if (!self.settled.*) {
            var capability = self.capability;
            engine.releasePromiseCapability(&capability);
        }
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
