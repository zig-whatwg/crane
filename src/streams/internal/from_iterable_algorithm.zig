//! Pull Algorithm for ReadableStream.from()
//!
//! Implements the pullAlgorithm from ReadableStreamFromIterable
//! Spec: WHATWG Streams §4.2.1

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const Algorithm = @import("algorithm").Algorithm;
const IteratorRecord = @import("iterator_record").IteratorRecord;
const AsyncPromise = @import("async_promise").AsyncPromise;
const v8_mod = @import("v8");
const v8 = v8_mod.ffi; // Use FFI functions directly
const v8_engine = v8_mod.engine; // V8 engine helpers
const webidl = @import("webidl");
const impls = @import("impls");

// Controller implementation functions
const ReadableStreamDefaultControllerImpl = impls.ReadableStreamDefaultController;

/// Context for from() pull algorithm
/// Captured state: iterator record + stream reference
pub const FromIterableContext = struct {
    iterator_record: *IteratorRecord,
    allocator: Allocator,

    pub fn deinit(self: *FromIterableContext) void {
        self.iterator_record.deinit();
        self.allocator.destroy(self);
    }
};

/// Create pull algorithm for ReadableStream.from()
pub fn createPullAlgorithm(
    allocator: Allocator,
    iterator_record: *IteratorRecord,
) !*Algorithm {
    const context = try allocator.create(FromIterableContext);
    context.* = .{
        .iterator_record = iterator_record,
        .allocator = allocator,
    };

    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = context,
        .vtable = &pull_vtable,
        .allocator = allocator,
    };

    return algo;
}

const pull_vtable = Algorithm.VTable{
    .invoke = pullInvoke,
    .invoke_with_arg = pullInvokeWithArg,
    .destroy = pullDestroy,
};

/// Pull algorithm implementation
/// Spec: ReadableStreamFromIterable, step 4 (pullAlgorithm)
fn pullInvoke(
    controller: *runtime.Instance,
    context_ptr: ?*anyopaque,
) !*AsyncPromise(void) {
    const context: *FromIterableContext = @ptrCast(@alignCast(context_ptr orelse return error.InvalidContext));
    const iter_record = context.iterator_record;

    // Create promise for this pull operation
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    errdefer promise.deinit();

    // Step 4.1: Let nextResult = IteratorNext(iteratorRecord)
    const next_result = iter_record.next() catch |err| {
        // Step 4.2: If nextResult is abrupt, error the controller
        const err_ptr: *const anyopaque = @ptrCast(&err);
        ReadableStreamDefaultControllerImpl.call_error(controller, err_ptr) catch {};
        promise.fulfill({});
        return promise;
    };
    defer v8.v8_Value_Dispose(next_result);

    const result_obj: *v8.Object = @ptrCast(next_result);

    // Step 4.4.1: If iterResult is not Object, throw TypeError
    if (!v8.v8_Value_IsObject(next_result)) {
        const err = error.TypeError;
        const err_ptr: *const anyopaque = @ptrCast(&err);
        ReadableStreamDefaultControllerImpl.call_error(controller, err_ptr) catch {};
        promise.fulfill({});
        return promise;
    }

    // Step 4.4.2: Let done = IteratorComplete(iterResult)
    const done = IteratorRecord.complete(
        result_obj,
        iter_record.context,
        iter_record.isolate,
    ) catch |err| {
        const err_ptr: *const anyopaque = @ptrCast(&err);
        ReadableStreamDefaultControllerImpl.call_error(controller, err_ptr) catch {};
        promise.fulfill({});
        return promise;
    };

    if (done) {
        // Step 4.4.3: If done is true, close the stream
        ReadableStreamDefaultControllerImpl.call_close(controller) catch |err| {
            const err_ptr: *const anyopaque = @ptrCast(&err);
            ReadableStreamDefaultControllerImpl.call_error(controller, err_ptr) catch {};
        };
        promise.fulfill({});
        return promise;
    }

    // Step 4.4.4: Let value = IteratorValue(iterResult)
    const iter_value = IteratorRecord.value(
        result_obj,
        iter_record.context,
        iter_record.isolate,
    ) catch |err| {
        const err_ptr: *const anyopaque = @ptrCast(&err);
        ReadableStreamDefaultControllerImpl.call_error(controller, err_ptr) catch {};
        promise.fulfill({});
        return promise;
    };
    // Keep value alive - will be enqueued

    // Step 4.4.4.2: Enqueue value
    ReadableStreamDefaultControllerImpl.call_enqueue(controller, iter_value) catch |err| {
        v8.v8_Value_Dispose(iter_value);
        const err_ptr: *const anyopaque = @ptrCast(&err);
        ReadableStreamDefaultControllerImpl.call_error(controller, err_ptr) catch {};
        promise.fulfill({});
        return promise;
    };

    promise.fulfill({});
    return promise;
}

fn pullInvokeWithArg(
    controller: *runtime.Instance,
    context: ?*anyopaque,
    _: *const anyopaque,
) !*AsyncPromise(void) {
    // Pull doesn't take arguments
    return pullInvoke(controller, context);
}

fn pullDestroy(context_ptr: ?*anyopaque, allocator: Allocator) void {
    if (context_ptr) |ptr| {
        const context: *FromIterableContext = @ptrCast(@alignCast(ptr));
        context.deinit();
    }
    _ = allocator;
}

/// Create cancel algorithm for ReadableStream.from()
pub fn createCancelAlgorithm(
    allocator: Allocator,
    iterator_record: *IteratorRecord,
) !*Algorithm {
    // Reuse same context structure
    const context = try allocator.create(FromIterableContext);
    context.* = .{
        .iterator_record = iterator_record,
        .allocator = allocator,
    };

    const algo = try allocator.create(Algorithm);
    algo.* = .{
        .context = context,
        .vtable = &cancel_vtable,
        .allocator = allocator,
    };

    return algo;
}

const cancel_vtable = Algorithm.VTable{
    .invoke = cancelInvoke,
    .invoke_with_arg = cancelInvokeWithArg,
    .destroy = cancelDestroy,
};

fn cancelInvoke(
    controller: *runtime.Instance,
    context_ptr: ?*anyopaque,
) !*AsyncPromise(void) {
    // Cancel without reason (use undefined)
    const isolate = v8_engine.getIsolate(controller.ctx) orelse return error.NoV8Engine;
    const undef = v8.v8_Undefined(isolate) orelse return error.V8Error;
    defer v8.v8_Value_Dispose(undef);

    return cancelInvokeWithArg(controller, context_ptr, undef);
}

/// Cancel algorithm implementation
/// Spec: ReadableStreamFromIterable, step 5 (cancelAlgorithm)
fn cancelInvokeWithArg(
    controller: *runtime.Instance,
    context_ptr: ?*anyopaque,
    reason: *const anyopaque,
) !*AsyncPromise(void) {
    const context: *FromIterableContext = @ptrCast(@alignCast(context_ptr orelse return error.InvalidContext));
    const iter_record = context.iterator_record;

    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();
    const promise = try AsyncPromise(void).init(allocator, event_loop);

    // Cast reason to V8 Value
    const reason_value: *v8.Value = @ptrCast(@alignCast(@constCast(reason)));

    // Call iterator.return(reason)
    // If close fails, just fulfill anyway (stream is canceling)
    iter_record.close(reason_value) catch {};

    promise.fulfill({});
    return promise;
}

fn cancelDestroy(context_ptr: ?*anyopaque, allocator: Allocator) void {
    if (context_ptr) |ptr| {
        const context: *FromIterableContext = @ptrCast(@alignCast(ptr));
        context.deinit();
    }
    _ = allocator;
}
