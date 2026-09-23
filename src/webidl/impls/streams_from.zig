//! ReadableStreamFromIterable(asyncIterable) - WHATWG Streams § 4.9.1.
//!
//! GetIterator(asyncIterable, async) and CreateAsyncFromSyncIterator are
//! ECMAScript operations with no V8 API: they need GetV on primitives (a
//! string is iterable) and must turn a throwing getter into an abrupt
//! completion. A small script does exactly those two operations and hands
//! back `next()` / `cancel(reason)` promise functions; the stream itself is
//! built with CreateReadableStream and driven from Zig, step by step.

const std = @import("std");
const runtime = @import("runtime");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");

const Value = js.Value;
const Realm = js.Realm;
const ffi = @import("v8").ffi;

/// Step 2's GetIterator(asyncIterable, async), plus the two ways the pull and
/// cancel algorithms (steps 4-5) use the record. next() resolves to
/// [done, value]; cancel(reason) resolves when return() has.
const helper_source =
    \\(function (asyncIterable) {
    \\  "use strict";
    \\  const GetMethod = (V, P) => {
    \\    const func = V[P];
    \\    if (func === undefined || func === null) return undefined;
    \\    if (typeof func !== "function") throw new TypeError("iterator method is not callable");
    \\    return func;
    \\  };
    \\  let iterator;
    \\  let sync = false;
    \\  const asyncMethod = GetMethod(asyncIterable, Symbol.asyncIterator);
    \\  if (asyncMethod !== undefined) {
    \\    iterator = Reflect.apply(asyncMethod, asyncIterable, []);
    \\  } else {
    \\    const syncMethod = GetMethod(asyncIterable, Symbol.iterator);
    \\    if (syncMethod === undefined) throw new TypeError("value is not iterable");
    \\    iterator = Reflect.apply(syncMethod, asyncIterable, []);
    \\    sync = true;
    \\  }
    \\  if (Object(iterator) !== iterator) throw new TypeError("iterator is not an object");
    \\  const nextMethod = iterator.next;
    \\  const unpack = (r) => {
    \\    if (Object(r) !== r) throw new TypeError("iterator result is not an object");
    \\    return [!!r.done, r.value];
    \\  };
    \\  return {
    \\    async next() {
    \\      const result = Reflect.apply(nextMethod, iterator, []);
    \\      if (sync) {
    \\        const [done, value] = unpack(result);
    \\        return [done, await value];
    \\      }
    \\      return unpack(await result);
    \\    },
    \\    async cancel(reason) {
    \\      const returnMethod = GetMethod(iterator, "return");
    \\      if (returnMethod === undefined) return;
    \\      const returnResult = Reflect.apply(returnMethod, iterator, [reason]);
    \\      const r = sync ? returnResult : await returnResult;
    \\      if (Object(r) !== r) throw new TypeError("iterator result is not an object");
    \\    }
    \\  };
    \\})
;

const FromSource = struct {
    /// The helper's record object and its two methods, owned.
    record: Value,
    next: Value,
    cancel: Value,

    fn start(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!js.Completion {
        // Step 3: an algorithm that returns undefined.
        return .{ .normal = try realm.undefinedValue() };
    }

    /// Step 4: pullAlgorithm.
    fn pull(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value {
        const self: *FromSource = @ptrCast(@alignCast(ctx.?));
        // 4.1-4.3: next() as a promise (an abrupt completion rejects it).
        const next_promise = try realm.promiseCall(self.next, self.record, &.{});
        defer js.dispose(next_promise);
        // 4.4: react to it; the pull settles when the chunk is placed.
        const step = try controller.ctx.allocator.create(PullStep);
        step.* = .{ .deferred = try js.Deferred.init(realm), .controller = controller, .allocator = controller.ctx.allocator, .realm = realm };
        const result = try js.clone(step.deferred.promise);
        realm.react(next_promise, PullStep, step, PullStep.fulfilled, PullStep.rejected) catch {
            step.deferred.resolveUndefined(realm);
            step.finish();
        };
        return result;
    }

    /// Step 5: cancelAlgorithm.
    fn cancelSource(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, reason: Value) js.Error!Value {
        const self: *FromSource = @ptrCast(@alignCast(ctx.?));
        return realm.promiseCall(self.cancel, self.record, &.{reason});
    }

    fn deinitSource(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        const self: *FromSource = @ptrCast(@alignCast(ctx.?));
        js.dispose(self.record);
        js.dispose(self.next);
        js.dispose(self.cancel);
        allocator.destroy(self);
    }

    const vtable = srd.Source.VTable{ .start = start, .pull = pull, .cancel = cancelSource, .deinit = deinitSource };
};

const PullStep = struct {
    deferred: js.Deferred,
    controller: *runtime.Instance,
    allocator: std.mem.Allocator,
    realm: Realm,

    fn finish(self: *PullStep) void {
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    /// 4.4 fulfillment steps, given [done, value].
    fn fulfilled(self: *PullStep, pair: Value) void {
        defer self.finish();
        const realm = self.realm;
        const arr: *ffi.Array = @ptrCast(pair);
        const done_value = ffi.v8_Array_Get(realm.context, arr, 0) orelse return self.deferred.resolveUndefined(realm);
        defer js.dispose(done_value);
        const value = ffi.v8_Array_Get(realm.context, arr, 1) orelse return self.deferred.resolveUndefined(realm);
        defer js.dispose(value);
        if (ffi.v8_Value_BooleanValue(done_value, realm.isolate)) {
            // 4.4.3 done: close.
            srd.defaultControllerClose(realm, self.controller);
        } else {
            // 4.4.4 otherwise enqueue the value.
            if (srd.defaultControllerEnqueueCompletion(realm, self.controller, value) catch null) |e| js.dispose(e);
        }
        self.deferred.resolveUndefined(realm);
    }

    fn rejected(self: *PullStep, reason: Value) void {
        self.deferred.reject(self.realm, reason);
        self.finish();
    }
};

/// ReadableStreamFromIterable(asyncIterable). `iterable` is borrowed.
pub fn fromIterable(realm: Realm, ctx: runtime.Context, iterable: Value) !*runtime.Instance {
    // Step 2: Let iteratorRecord be ? GetIterator(asyncIterable, async).
    const source_str = ffi.v8_String_NewFromUtf8(realm.isolate, helper_source.ptr, @intCast(helper_source.len)) orelse return error.OutOfMemory;
    defer ffi.v8_String_Dispose(source_str);
    const script = ffi.v8_Script_Compile(realm.context, source_str) orelse return error.OutOfMemory;
    defer ffi.v8_Script_Dispose(script);
    const helper = ffi.v8_Script_Run(realm.context, script) orelse return error.OutOfMemory;
    defer js.dispose(helper);
    const record = switch (try realm.call(helper, null, &.{iterable})) {
        .normal => |v| v,
        .thrown => |e| {
            defer js.dispose(e);
            return realm.throwValue(e);
        },
    };
    errdefer js.dispose(record);
    const next = (try js.getMember(realm, record, "next")) orelse return error.TypeError;
    errdefer js.dispose(next);
    const cancel = (try js.getMember(realm, record, "cancel")) orelse return error.TypeError;
    errdefer js.dispose(cancel);
    const state = try ctx.allocator.create(FromSource);
    state.* = .{ .record = record, .next = next, .cancel = cancel };
    // Step 6: Set stream to ! CreateReadableStream(startAlgorithm, pullAlgorithm, cancelAlgorithm, 0).
    return srd.createReadableStream(realm, ctx, .{ .ctx = state, .vtable = &FromSource.vtable }, 0, .one);
}
