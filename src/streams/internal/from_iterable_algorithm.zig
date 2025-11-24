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

// V8 FFI placeholder
const V8Value = opaque {};

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
    _ = controller;
    _ = context_ptr;

    // TODO: Implement when V8 FFI and controller operations are available
    return error.NotImplemented;
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
    _ = controller;
    _ = context_ptr;

    // TODO: Implement when V8 FFI is available
    return error.NotImplemented;
}

/// Cancel algorithm implementation
/// Spec: ReadableStreamFromIterable, step 5 (cancelAlgorithm)
fn cancelInvokeWithArg(
    controller: *runtime.Instance,
    context_ptr: ?*anyopaque,
    reason: *const anyopaque,
) !*AsyncPromise(void) {
    _ = controller;
    _ = context_ptr;
    _ = reason;

    // TODO: Implement when V8 FFI is available
    return error.NotImplemented;
}

fn cancelDestroy(context_ptr: ?*anyopaque, allocator: Allocator) void {
    if (context_ptr) |ptr| {
        const context: *FromIterableContext = @ptrCast(@alignCast(ptr));
        context.deinit();
    }
    _ = allocator;
}
