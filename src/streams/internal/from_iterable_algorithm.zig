//! Pull Algorithm for ReadableStream.from()
//!
//! Implements the pullAlgorithm from ReadableStreamFromIterable
//! Spec: WHATWG Streams §4.2.1
//!
//! This module uses the typed algorithm pattern from algorithm.zig:
//! - FromIterableContext is the typed context struct
//! - Typed callback functions receive *FromIterableContext directly
//! - createTypedAlgorithm() wraps these into the type-erased Algorithm

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const algorithm_mod = @import("algorithm");
const Algorithm = algorithm_mod.Algorithm;
const createTypedAlgorithm = algorithm_mod.createTypedAlgorithm;
const IteratorRecord = @import("iterator_record").IteratorRecord;
const AsyncPromise = @import("async_promise").AsyncPromise;
const v8_mod = @import("v8");
const v8 = v8_mod.ffi; // Use FFI functions directly
const v8_engine = v8_mod.engine; // V8 engine helpers
const pointer_tag = v8_mod.pointer_tag; // Pointer untagging for V8 tagged pointers
const webidl = @import("webidl");

// Use interfaces instead of impls (per Golden Rule #12)
const interfaces = @import("interfaces");
const ReadableStreamDefaultController = interfaces.ReadableStreamDefaultController;

/// Context for from() pull algorithm
/// Captured state: iterator record + stream reference
///
/// This is a typed context struct used with TypedAlgorithm/createTypedAlgorithm.
/// The callback functions below receive *FromIterableContext directly without
/// any anyopaque casts, providing compile-time type safety.
pub const FromIterableContext = struct {
    iterator_record: *IteratorRecord,
    allocator: Allocator,

    pub fn deinit(self: *FromIterableContext) void {
        self.iterator_record.deinit();
        self.allocator.destroy(self);
    }
};

/// Create pull algorithm for ReadableStream.from()
///
/// Uses createTypedAlgorithm to create a type-safe algorithm that
/// wraps FromIterableContext with proper typed callbacks.
pub fn createPullAlgorithm(
    allocator: Allocator,
    iterator_record: *IteratorRecord,
) !*Algorithm {
    const context = try allocator.create(FromIterableContext);
    context.* = .{
        .iterator_record = iterator_record,
        .allocator = allocator,
    };

    // Use typed algorithm creation for type safety
    return createTypedAlgorithm(
        FromIterableContext,
        allocator,
        context,
        pullInvokeTyped,
        pullInvokeWithArgTyped,
        pullDestroyTyped,
    );
}

// ============================================================================
// Typed Pull Algorithm Callbacks
// ============================================================================
//
// These callbacks receive *FromIterableContext directly, providing type safety.
// They are wrapped by createTypedAlgorithm into the type-erased Algorithm.

/// Pull algorithm implementation (typed version)
/// Receives *FromIterableContext directly - no anyopaque casting needed.
///
/// Spec: ReadableStreamFromIterable, step 4 (pullAlgorithm)
fn pullInvokeTyped(
    controller: *runtime.Instance,
    context: *FromIterableContext,
) anyerror!*AsyncPromise(void) {
    const iter_record = context.iterator_record;

    // Create promise for this pull operation
    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    errdefer promise.deinit();

    // Step 4.1: Let nextResult = IteratorNext(iteratorRecord)
    const next_result = iter_record.next() catch |err| {
        // Step 4.2: If nextResult is abrupt, error the controller
        // Create a proper JS error value from the Zig error name
        const error_value = runtime.JSValue.fromStringRef(@errorName(err));
        ReadableStreamDefaultController.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_value)) catch {};
        promise.fulfill({});
        return promise;
    };
    defer v8.v8_Value_Dispose(next_result);

    const result_obj: *v8.Object = @ptrCast(next_result);

    // Step 4.4.1: If iterResult is not Object, throw TypeError
    if (!v8.v8_Value_IsObject(next_result)) {
        // Create a proper JS TypeError from the error message
        const error_value = runtime.JSValue.fromStringRef("TypeError: Iterator result is not an object");
        ReadableStreamDefaultController.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_value)) catch {};
        promise.fulfill({});
        return promise;
    }

    // Step 4.4.2: Let done = IteratorComplete(iterResult)
    const done = IteratorRecord.complete(
        result_obj,
        iter_record.context,
        iter_record.isolate,
    ) catch |err| {
        // Create a proper JS error value from the Zig error name
        const error_value = runtime.JSValue.fromStringRef(@errorName(err));
        ReadableStreamDefaultController.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_value)) catch {};
        promise.fulfill({});
        return promise;
    };

    if (done) {
        // Step 4.4.3: If done is true, close the stream
        ReadableStreamDefaultController.call_close(controller) catch |err| {
            // Create a proper JS error value from the Zig error name
            const error_value = runtime.JSValue.fromStringRef(@errorName(err));
            ReadableStreamDefaultController.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_value)) catch {};
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
        // Create a proper JS error value from the Zig error name
        const error_value = runtime.JSValue.fromStringRef(@errorName(err));
        ReadableStreamDefaultController.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_value)) catch {};
        promise.fulfill({});
        return promise;
    };
    // Keep value alive - will be enqueued

    // Step 4.4.4.2: Enqueue value - wrap in Opt since call_enqueue expects webidl.Opt(runtime.JSValue)
    // Convert the V8 value pointer to a runtime.JSValue handle
    const chunk_js_value = runtime.JSValue.fromHandle(@ptrCast(iter_value));
    ReadableStreamDefaultController.call_enqueue(controller, webidl.Opt(runtime.JSValue).passed(chunk_js_value)) catch |err| {
        v8.v8_Value_Dispose(iter_value);
        // Create a proper JS error value from the Zig error name
        const error_value = runtime.JSValue.fromStringRef(@errorName(err));
        ReadableStreamDefaultController.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_value)) catch {};
        promise.fulfill({});
        return promise;
    };

    promise.fulfill({});
    return promise;
}

/// Pull with argument (typed version)
/// Pull doesn't use the argument, so this delegates to pullInvokeTyped.
fn pullInvokeWithArgTyped(
    controller: *runtime.Instance,
    context: *FromIterableContext,
    _: *const anyopaque,
) anyerror!*AsyncPromise(void) {
    // Pull doesn't take arguments
    return pullInvokeTyped(controller, context);
}

/// Destroy callback (typed version)
/// Cleans up the FromIterableContext.
fn pullDestroyTyped(context: *FromIterableContext, allocator: Allocator) void {
    context.deinit();
    _ = allocator;
}

// ============================================================================
// Typed Cancel Algorithm
// ============================================================================

/// Create cancel algorithm for ReadableStream.from()
///
/// Uses createTypedAlgorithm to create a type-safe algorithm that
/// wraps FromIterableContext with proper typed callbacks.
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

    // Use typed algorithm creation for type safety
    return createTypedAlgorithm(
        FromIterableContext,
        allocator,
        context,
        cancelInvokeTyped,
        cancelInvokeWithArgTyped,
        cancelDestroyTyped,
    );
}

// ============================================================================
// Typed Cancel Algorithm Callbacks
// ============================================================================

/// Cancel algorithm invoke (typed version)
/// Cancel without reason - uses undefined.
fn cancelInvokeTyped(
    controller: *runtime.Instance,
    context: *FromIterableContext,
) anyerror!*AsyncPromise(void) {
    // Cancel without reason (use undefined)
    const isolate = v8_engine.getIsolate(controller.ctx) orelse return error.NoV8Engine;
    const undef = v8.v8_Undefined(isolate) orelse return error.V8Error;
    defer v8.v8_Value_Dispose(undef);

    return cancelInvokeWithArgTypedImpl(controller, context, undef);
}

/// Cancel algorithm implementation (typed version)
/// Receives *FromIterableContext directly - no anyopaque casting needed.
///
/// Spec: ReadableStreamFromIterable, step 5 (cancelAlgorithm)
fn cancelInvokeWithArgTyped(
    controller: *runtime.Instance,
    context: *FromIterableContext,
    reason: *const anyopaque,
) anyerror!*AsyncPromise(void) {
    // Cast reason to V8 Value - use pointer untagging for V8 tagged pointers
    const untagged = pointer_tag.untagPointer(reason);
    const reason_value: *v8.Value = @ptrCast(untagged.ptr);

    return cancelInvokeWithArgTypedImpl(controller, context, reason_value);
}

/// Internal implementation for cancel with typed context and V8 value
fn cancelInvokeWithArgTypedImpl(
    controller: *runtime.Instance,
    context: *FromIterableContext,
    reason_value: *v8.Value,
) anyerror!*AsyncPromise(void) {
    const iter_record = context.iterator_record;

    const allocator = controller.ctx.getAllocator();
    const event_loop = try controller.ctx.getEventLoop();
    const promise = try AsyncPromise(void).init(allocator, event_loop);

    // Call iterator.return(reason)
    // If close fails, just fulfill anyway (stream is canceling)
    iter_record.close(reason_value) catch {};

    promise.fulfill({});
    return promise;
}

/// Destroy callback for cancel algorithm (typed version)
fn cancelDestroyTyped(context: *FromIterableContext, allocator: Allocator) void {
    context.deinit();
    _ = allocator;
}
