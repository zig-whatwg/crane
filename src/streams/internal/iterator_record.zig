//! ECMAScript IteratorRecord
//!
//! Spec: ES §27.1.1.2 The Iterator Record Specification Type
//! WHATWG Streams: Used in ReadableStreamFromIterable
//!
//! Stores iterator state and provides protocol operations.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const V8Resources = @import("v8_resources").V8Resources;

// V8 FFI types - placeholders for now
const V8Object = opaque {};
const V8Function = opaque {};
const V8Value = opaque {};
const V8Isolate = opaque {};
const V8Context = opaque {};
const V8Symbol = opaque {};
const V8String = opaque {};

/// Iterator Record - ECMAScript iterator state
///
/// Captures V8 iterator object and next method for async iteration
pub const IteratorRecord = struct {
    /// [[Iterator]] - The iterator object (V8 Global<Object>)
    iterator: *V8Object,

    /// [[NextMethod]] - The next() method (V8 Global<Function>)
    next_method: *V8Function,

    /// [[Done]] - Whether iteration is complete
    done: bool,

    /// V8 context for calls
    isolate: *V8Isolate,
    context: *V8Context,

    /// Resource tracking (for cleanup)
    resources: V8Resources,

    allocator: Allocator,

    /// Create IteratorRecord from async iterable
    /// Spec: GetIterator(obj, async)
    pub fn fromAsyncIterable(
        allocator: Allocator,
        ctx: runtime.Context,
        async_iterable: *const anyopaque,
    ) !*IteratorRecord {
        _ = allocator;
        _ = ctx;
        _ = async_iterable;

        // TODO: Implement when V8 FFI is available
        // This is a placeholder implementation
        return error.NotImplemented;
    }

    pub fn deinit(self: *IteratorRecord) void {
        self.resources.deinit();
        self.allocator.destroy(self);
    }

    /// IteratorNext - Call next() method
    /// Spec: ES §7.4.2 IteratorNext
    pub fn next(self: *IteratorRecord) !*V8Value {
        if (self.done) {
            return error.IteratorDone;
        }

        // TODO: Implement when V8 FFI is available
        return error.NotImplemented;
    }

    /// IteratorComplete - Get "done" property
    /// Spec: ES §7.4.3 IteratorComplete
    pub fn complete(iter_result: *V8Object, context: *V8Context) !bool {
        _ = iter_result;
        _ = context;

        // TODO: Implement when V8 FFI is available
        return error.NotImplemented;
    }

    /// IteratorValue - Get "value" property
    /// Spec: ES §7.4.4 IteratorValue
    pub fn value(iter_result: *V8Object, context: *V8Context) !*V8Value {
        _ = iter_result;
        _ = context;

        // TODO: Implement when V8 FFI is available
        return error.NotImplemented;
    }

    /// IteratorClose - Call return() method
    /// Spec: ES §7.4.6 IteratorClose
    pub fn close(self: *IteratorRecord, reason: *V8Value) !void {
        if (self.done) {
            return;
        }

        self.done = true;

        _ = reason;
        // TODO: Implement when V8 FFI is available
        return error.NotImplemented;
    }
};
