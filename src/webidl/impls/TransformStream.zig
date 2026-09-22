//! TransformStream Implementation
//!
//! WHATWG Streams Standard § 6.2: https://streams.spec.whatwg.org/#ts-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_transform.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const js = @import("streams_js.zig");
const sw = @import("streams_writable.zig");
const st = @import("streams_transform.zig");

pub const State = interfaces.TransformStream.State;
pub const InternalState = st.Stream;

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |slots| {
        state.own._internal = null;
        slots.deinit();
    }
}

/// `new TransformStream(transformer, writableStrategy, readableStrategy)` - § 6.2.4.
pub fn call_constructor(ctx: runtime.Context, transformer: webidl.Opt(runtime.JSValue), writableStrategy: webidl.Opt(dictionaries.QueuingStrategy), readableStrategy: webidl.Opt(dictionaries.QueuingStrategy)) !*runtime.Instance {
    const realm = try js.Realm.ofContext(ctx);
    const writable_strategy = if (writableStrategy.was_passed) writableStrategy.value else dictionaries.QueuingStrategy{};
    const readable_strategy = if (readableStrategy.was_passed) readableStrategy.value else dictionaries.QueuingStrategy{};

    // Step 1: If transformer is missing, set it to null. It is typed
    // `object`: undefined is "missing", any other non-object throws.
    var transformer_object: ?js.Value = null;
    defer js.disposeOptional(&transformer_object);
    if (transformer.was_passed) switch (transformer.value) {
        .undefined => {},
        .handle => {
            const value = try realm.fromRuntime(transformer.value);
            if (!js.isObject(value)) {
                js.dispose(value);
                return error.TypeError;
            }
            transformer_object = value;
        },
        else => return error.TypeError,
    };

    // Steps 2-4: convert; readableType or writableType is a RangeError.
    const dict = try st.convertTransformer(realm, ctx.allocator, transformer_object);
    var owned_dict: ?*st.JsTransformer = dict;
    errdefer if (owned_dict) |d| st.JsTransformer.vtable.deinit(d, ctx.allocator);

    // Steps 5-8: the two strategies.
    const readable_hwm = try sw.extractHighWaterMark(readable_strategy, 0);
    var readable_size = try sw.extractSizeAlgorithm(readable_strategy);
    errdefer if (readable_size == .callback) js.dispose(readable_size.callback);
    const writable_hwm = try sw.extractHighWaterMark(writable_strategy, 1);
    var writable_size = try sw.extractSizeAlgorithm(writable_strategy);
    errdefer if (writable_size == .callback) js.dispose(writable_size.callback);

    // Step 9: Let startPromise be a new promise.
    const start_promise = try js.Deferred.init(realm);
    const start_handle = try js.clone(start_promise.promise);
    defer js.dispose(start_handle);

    // Step 10: Perform ! InitializeTransformStream(this, startPromise, ...).
    const instance = try st.newStream(ctx);
    const sizes_taken = .{ writable_size, readable_size };
    writable_size = .one;
    readable_size = .one;
    try st.initialize(realm, instance, start_promise, writable_hwm, sizes_taken[0], readable_hwm, sizes_taken[1]);

    // Step 11: Perform ? SetUpTransformStreamDefaultControllerFromTransformer(this, transformer, transformerDict).
    const controller = try st.newController(ctx, instance, .{ .ctx = dict, .vtable = &st.JsTransformer.vtable });
    owned_dict = null;
    try st.setUpController(realm, instance, controller);

    // Steps 12-13: resolve startPromise with the result of start(), or undefined.
    const slots = st.streamOf(instance).?;
    if (dict.start) |start_fn| {
        switch (try realm.call(start_fn, dict.this, &.{try realm.wrap(controller)})) {
            .normal => |v| {
                defer js.dispose(v);
                slots.start_promise.?.resolve(realm, v);
            },
            .thrown => |e| {
                defer js.dispose(e);
                return realm.throwValue(e);
            },
        }
    } else {
        slots.start_promise.?.resolveUndefined(realm);
    }
    return instance;
}

/// `readable` - § 6.2.4: Return this.[[readable]].
pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const stream = st.streamOf(instance) orelse return error.TypeError;
    return stream.readable orelse error.InvalidStateError;
}

/// `writable` - § 6.2.4: Return this.[[writable]].
pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const stream = st.streamOf(instance) orelse return error.TypeError;
    return stream.writable orelse error.InvalidStateError;
}
