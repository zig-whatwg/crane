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
const v8 = @import("v8");
const webidl = @import("webidl");

// Import controller functions
const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController");

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
    const promise = try AsyncPromise(void).init(
        controller.allocator,
        controller.ctx.getEventLoop(),
    );
    errdefer promise.deinit();

    // Step 4.1: Let nextResult = IteratorNext(iteratorRecord)
    const next_result = iter_record.next() catch |err| {
        // Step 4.2: If nextResult is abrupt, reject promise
        promise.reject(@ptrFromInt(@intFromError(err)));
        return promise;
    };
    defer v8.v8_Value_Dispose(next_result);

    const result_obj: *v8.Object = @ptrCast(next_result);

    // Step 4.4.1: If iterResult is not Object, throw TypeError
    if (!v8.v8_Value_IsObject(next_result)) {
        promise.reject(@ptrFromInt(@intFromError(error.TypeError)));
        return promise;
    }

    // Step 4.4.2: Let done = IteratorComplete(iterResult)
    const done = IteratorRecord.complete(
        result_obj,
        iter_record.context,
        iter_record.isolate,
    ) catch |err| {
        promise.reject(@ptrFromInt(@intFromError(err)));
        return promise;
    };

    if (done) {
        // Step 4.4.3: If done is true, close the stream
        ReadableStreamDefaultControllerImpl.call_close(controller) catch |err| {
            promise.reject(@ptrFromInt(@intFromError(err)));
            return promise;
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
        promise.reject(@ptrFromInt(@intFromError(err)));
        return promise;
    };
    // Keep value alive - will be enqueued

    // Step 4.4.4.2: Enqueue value
    ReadableStreamDefaultControllerImpl.call_enqueue(controller, iter_value) catch |err| {
        v8.v8_Value_Dispose(iter_value);
        promise.reject(@ptrFromInt(@intFromError(err)));
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
    const isolate = runtime.getIsolate(controller.ctx);
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

    const promise = try AsyncPromise(void).init(
        controller.allocator,
        controller.ctx.getEventLoop(),
    );

    // Cast reason to V8 Value
    const reason_value: *v8.Value = @ptrCast(@alignCast(@constCast(reason)));

    // Call iterator.return(reason)
    iter_record.close(reason_value) catch |err| {
        promise.reject(@ptrFromInt(@intFromError(err)));
        return promise;
    };

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
