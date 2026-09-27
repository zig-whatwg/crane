//! ReadableStreamFromIterable(asyncIterable) - WHATWG Streams § 4.9.1.
//!
//! The iterator record is the engine's: GetIterator(asyncIterable, async)
//! (a sync iterable is read through CreateAsyncFromSyncIterator, a primitive
//! through ToObject), IteratorNext, IteratorComplete / IteratorValue and the
//! iterator's `return`. The steps that consume an abrupt completion instead of
//! propagating it - "if nextResult is an abrupt completion, return a promise
//! rejected with nextResult.[[Value]]" - run under engine.completionOf. The
//! stream itself is built with CreateReadableStream and driven from Zig.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");

const Value = js.Value;
const Realm = js.Realm;

/// An engine failure (not a completion: completionOf has caught those) as
/// streams_js's error.
fn streamsError(err: engine.Error) js.Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.ExceptionPending => error.ExceptionPending,
        else => error.V8Failure,
    };
}

/// A promise rejected with the value an abrupt completion threw. Takes it.
fn rejectedWith(realm: Realm, thrown: engine.Owned) js.Error!Value {
    defer thrown.release();
    const reason = try realm.fromRuntime(thrown.value);
    defer js.dispose(reason);
    return realm.promiseRejectedWith(reason);
}

/// Reject `deferred` with the value an abrupt completion threw. Takes it.
fn rejectDeferred(realm: Realm, deferred: js.Deferred, thrown: engine.Owned) void {
    defer thrown.release();
    const reason = realm.fromRuntime(thrown.value) catch return;
    defer js.dispose(reason);
    deferred.reject(realm, reason);
}

/// A promise resolved with `value` (an engine value; released).
fn resolvedWith(realm: Realm, value: engine.Owned) js.Error!Value {
    defer value.release();
    const resolution = try realm.fromRuntime(value.value);
    defer js.dispose(resolution);
    return realm.promiseResolvedWith(resolution);
}

const FromSource = struct {
    /// iteratorRecord. OWNED: engine.releaseIteratorRecord.
    record: *engine.IteratorRecord,
    /// The realm the stream was made in: the record's steps run in it.
    ctx: runtime.Context,

    /// Step 3: startAlgorithm, an algorithm that returns undefined.
    fn start(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!js.Completion {
        return .{ .normal = try realm.undefinedValue() };
    }

    /// IteratorNext(iteratorRecord), as steps for engine.completionOf.
    const NextStep = struct {
        source: *FromSource,
        result: ?engine.Owned = null,

        fn steps(data: ?*anyopaque) engine.Error!void {
            const self: *NextStep = @ptrCast(@alignCast(data.?));
            self.result = try engine.iteratorNext(self.source.ctx, self.source.record);
        }
    };

    /// Step 4: pullAlgorithm.
    fn pull(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value {
        const self: *FromSource = @ptrCast(@alignCast(ctx.?));
        // 1. Let nextResult be IteratorNext(iteratorRecord).
        var next = NextStep{ .source = self };
        const abrupt = engine.completionOf(self.ctx, NextStep.steps, &next) catch |err| return streamsError(err);
        // 2. If nextResult is an abrupt completion, return a promise rejected
        //    with nextResult.[[Value]].
        if (abrupt) |thrown| return rejectedWith(realm, thrown);
        // 3. Let nextPromise be a promise resolved with nextResult.[[Value]].
        const next_promise = try resolvedWith(realm, next.result.?);
        defer js.dispose(next_promise);
        // 4. Return the result of reacting to nextPromise with the fulfillment
        //    steps (PullStep.fulfilled).
        const allocator = controller.ctx.allocator;
        const step = try allocator.create(PullStep);
        errdefer allocator.destroy(step);
        step.* = .{ .deferred = try js.Deferred.init(realm), .controller = controller, .allocator = allocator, .realm = realm, .ctx = self.ctx };
        const result = js.clone(step.deferred.promise) catch |err| {
            step.deferred.deinit();
            return err;
        };
        realm.react(next_promise, PullStep, step, PullStep.fulfilled, PullStep.rejected) catch {
            step.deferred.resolveUndefined(realm);
            step.finish();
        };
        return result;
    }

    /// The iterator's `return` called with `reason`, as steps for
    /// engine.completionOf.
    const ReturnStep = struct {
        source: *FromSource,
        reason: runtime.JSValue,
        result: ?engine.Owned = null,

        fn steps(data: ?*anyopaque) engine.Error!void {
            const self: *ReturnStep = @ptrCast(@alignCast(data.?));
            self.result = try engine.iteratorReturn(self.source.ctx, self.source.record, self.reason);
        }
    };

    /// Step 5: cancelAlgorithm, given reason.
    fn cancelSource(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, reason: Value) js.Error!Value {
        const self: *FromSource = @ptrCast(@alignCast(ctx.?));
        // 1. Let iterator be iteratorRecord.[[Iterator]].
        // 2. Let returnMethod be GetMethod(iterator, "return").
        // 5. Let returnResult be Call(returnMethod.[[Value]], iterator,
        //    « reason »).
        var call = ReturnStep{ .source = self, .reason = js.toReturn(reason) };
        const abrupt = engine.completionOf(self.ctx, ReturnStep.steps, &call) catch |err| return streamsError(err);
        // 3, 6. If returnMethod or returnResult is an abrupt completion,
        //    return a promise rejected with its [[Value]].
        if (abrupt) |thrown| return rejectedWith(realm, thrown);
        // 4. If returnMethod.[[Value]] is undefined, return a promise
        //    resolved with undefined.
        const return_result = call.result orelse return realm.promiseResolvedWithUndefined();
        // 7. Let returnPromise be a promise resolved with
        //    returnResult.[[Value]].
        const return_promise = try resolvedWith(realm, return_result);
        defer js.dispose(return_promise);
        // 8. Return the result of reacting to returnPromise with the
        //    fulfillment steps (CancelStep.fulfilled).
        const allocator = controller.ctx.allocator;
        const step = try allocator.create(CancelStep);
        errdefer allocator.destroy(step);
        step.* = .{ .deferred = try js.Deferred.init(realm), .allocator = allocator, .realm = realm, .ctx = self.ctx };
        const result = js.clone(step.deferred.promise) catch |err| {
            step.deferred.deinit();
            return err;
        };
        realm.react(return_promise, CancelStep, step, CancelStep.fulfilled, CancelStep.rejected) catch {
            step.deferred.resolveUndefined(realm);
            step.finish();
        };
        return result;
    }

    fn deinitSource(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        const self: *FromSource = @ptrCast(@alignCast(ctx.?));
        engine.releaseIteratorRecord(self.record);
        allocator.destroy(self);
    }

    const vtable = srd.Source.VTable{ .start = start, .pull = pull, .cancel = cancelSource, .deinit = deinitSource };
};

/// IteratorComplete(iterResult) and IteratorValue(iterResult), as steps for
/// engine.completionOf; an iterResult that is not an Object is the TypeError
/// step 4.4.1 throws.
///
/// DEVIATION: engine.iteratorResult reads "value" whether or not "done" is
/// true, where step 4.4.3 closes without reading it - observable only
/// through a getter on the result's "value". The protocol has no
/// IteratorComplete on its own.
const ResultStep = struct {
    ctx: runtime.Context,
    iter_result: runtime.JSValue,
    result: ?engine.IteratorResult = null,

    fn steps(data: ?*anyopaque) engine.Error!void {
        const self: *ResultStep = @ptrCast(@alignCast(data.?));
        self.result = try engine.iteratorResult(self.ctx, self.iter_result);
    }
};

/// The pull algorithm's reaction (step 4.4). Settles the pull's promise.
const PullStep = struct {
    deferred: js.Deferred,
    controller: *runtime.Instance,
    allocator: std.mem.Allocator,
    realm: Realm,
    ctx: runtime.Context,

    fn finish(self: *PullStep) void {
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    /// Fulfillment steps, given iterResult. What they throw rejects the
    /// reaction's promise.
    fn fulfilled(self: *PullStep, iter_result: Value) void {
        defer self.finish();
        const realm = self.realm;
        // 1. If iterResult is not an Object, throw a TypeError.
        // 2. Let done be ? IteratorComplete(iterResult).
        // 4.1 Let value be ? IteratorValue(iterResult).
        var read = ResultStep{ .ctx = self.ctx, .iter_result = js.toReturn(iter_result) };
        const abrupt = engine.completionOf(self.ctx, ResultStep.steps, &read) catch
            return self.deferred.resolveUndefined(realm);
        if (abrupt) |thrown| return rejectDeferred(realm, self.deferred, thrown);
        const result = read.result.?;
        defer result.value.release();
        if (result.done) {
            // 3. If done is true: perform !
            //    ReadableStreamDefaultControllerClose(stream.[[controller]]).
            srd.defaultControllerClose(realm, self.controller);
        } else {
            // 4.2 Perform ! ReadableStreamDefaultControllerEnqueue(
            //     stream.[[controller]], value).
            const value = realm.fromRuntime(result.value.value) catch return self.deferred.resolveUndefined(realm);
            defer js.dispose(value);
            if (srd.defaultControllerEnqueueCompletion(realm, self.controller, value) catch null) |e| js.dispose(e);
        }
        self.deferred.resolveUndefined(realm);
    }

    fn rejected(self: *PullStep, reason: Value) void {
        self.deferred.reject(self.realm, reason);
        self.finish();
    }
};

/// The cancel algorithm's reaction (step 5.8). Settles the cancel's promise.
const CancelStep = struct {
    deferred: js.Deferred,
    allocator: std.mem.Allocator,
    realm: Realm,
    ctx: runtime.Context,

    fn finish(self: *CancelStep) void {
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    /// Fulfillment steps, given iterResult.
    fn fulfilled(self: *CancelStep, iter_result: Value) void {
        defer self.finish();
        const realm = self.realm;
        // 1. If iterResult is not an Object, throw a TypeError.
        if (engine.typeOf(self.ctx, js.toReturn(iter_result)) != .object) {
            const type_error = realm.typeError("The iterator's return() did not fulfill with an object") catch
                return self.deferred.resolveUndefined(realm);
            defer js.dispose(type_error);
            return self.deferred.reject(realm, type_error);
        }
        // 2. Return undefined.
        self.deferred.resolveUndefined(realm);
    }

    fn rejected(self: *CancelStep, reason: Value) void {
        self.deferred.reject(self.realm, reason);
        self.finish();
    }
};

/// ReadableStreamFromIterable(asyncIterable). `iterable` is borrowed.
pub fn fromIterable(realm: Realm, ctx: runtime.Context, iterable: runtime.JSValue) !*runtime.Instance {
    // 1. Let stream be undefined.
    // 2. Let iteratorRecord be ? GetIterator(asyncIterable, async).
    const record = try engine.getIterator(ctx, iterable, .async);
    const state = ctx.allocator.create(FromSource) catch |err| {
        engine.releaseIteratorRecord(record);
        return err;
    };
    state.* = .{ .record = record, .ctx = ctx };
    // 6. Set stream to ! CreateReadableStream(startAlgorithm, pullAlgorithm,
    //    cancelAlgorithm, 0).
    // 7. Return stream.
    // The source is the stream's from here: its controller releases it
    // (deinitSource), so nothing here frees it on a later failure.
    return srd.createReadableStream(realm, ctx, .{ .ctx = state, .vtable = &FromSource.vtable }, 0, .one);
}
