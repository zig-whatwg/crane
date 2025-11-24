//! Async Iterator Protocol (ES2018+)
//!
//! Implements the ES async iterator protocol for use with ReadableStream.from()
//! Spec: ECMAScript Language Specification §27.1 (Iteration)
//! Spec: WHATWG Streams §4.2.1 ReadableStreamFromIterable
//!
//! This module provides the public interface for async iteration.
//! The actual V8 FFI implementation is in iterator_record.zig.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const common = @import("common");
const JSValue = common.JSValue;
const Promise = common.Promise;

// Import the V8-backed IteratorRecord implementation
const iterator_record = @import("iterator_record");
pub const V8IteratorRecord = iterator_record.IteratorRecord;

/// IteratorRecord - lightweight wrapper for internal use
/// For V8-backed iteration, use V8IteratorRecord directly
pub const IteratorRecord = struct {
    /// [[Iterator]] - The iterator object
    iterator: JSValue,

    /// [[NextMethod]] - The next method of the iterator
    next_method: JSValue,

    /// [[Done]] - Whether the iterator has been closed
    done: bool,

    /// Allocator for temporary allocations during iteration
    allocator: Allocator,

    pub fn init(allocator: Allocator, iterator: JSValue, next_method: JSValue) IteratorRecord {
        return .{
            .iterator = iterator,
            .next_method = next_method,
            .done = false,
            .allocator = allocator,
        };
    }
};

/// GetIterator(obj, hint) - Create iterator from object
///
/// For real V8 integration, use V8IteratorRecord.fromAsyncIterable instead.
/// This function is for internal Zig-only iteration (testing/mocks).
///
/// Spec: ES §7.4.1 GetIterator
pub fn getIterator(allocator: Allocator, obj: JSValue, hint: enum { sync, async_hint }) !IteratorRecord {
    _ = hint;

    switch (obj) {
        .object => {
            return IteratorRecord.init(
                allocator,
                obj,
                JSValue.undefined_value(),
            );
        },
        else => return error.TypeError,
    }
}

/// IteratorNext(iteratorRecord) - Call next() on iterator
///
/// For real V8 integration, use V8IteratorRecord.next() instead.
///
/// Spec: ES §7.4.2 IteratorNext
pub fn iteratorNext(record: *IteratorRecord) !Promise(JSValue) {
    if (record.done) {
        return Promise(JSValue).fulfilled(JSValue.undefined_value());
    }

    // For Zig-only iteration, return pending promise
    // Real iteration uses V8IteratorRecord.next()
    return Promise(JSValue).pending();
}

/// IteratorComplete(iterResult) - Get "done" property
///
/// For real V8 integration, use V8IteratorRecord.complete() instead.
///
/// Spec: ES §7.4.3 IteratorComplete
pub fn iteratorComplete(iter_result: JSValue) !bool {
    if (iter_result != .object) {
        return error.TypeError;
    }

    // Placeholder - real implementation uses V8 property access
    return false;
}

/// IteratorValue(iterResult) - Get "value" property
///
/// For real V8 integration, use V8IteratorRecord.value() instead.
///
/// Spec: ES §7.4.4 IteratorValue
pub fn iteratorValue(iter_result: JSValue) !JSValue {
    if (iter_result != .object) {
        return error.TypeError;
    }

    // Placeholder - real implementation uses V8 property access
    return JSValue.undefined_value();
}

/// GetMethod(V, P) - Get method from object by property key
///
/// For real V8 integration, use v8_Object_Get FFI directly.
///
/// Spec: ES §7.3.9 GetMethod
pub fn getMethod(v: JSValue, property: []const u8) !?JSValue {
    _ = property;

    switch (v) {
        .object => return null, // V8 implementation uses property access
        .undefined, .null => return null,
        else => return error.TypeError,
    }
}

/// Call(F, V, argumentsList) - Call function with this binding
///
/// For real V8 integration, use v8_Function_CallWithReceiver FFI directly.
///
/// Spec: ES §7.3.12 Call
pub fn call(f: JSValue, v: JSValue, args: []const JSValue) !JSValue {
    _ = f;
    _ = v;
    _ = args;

    // Placeholder - real implementation uses V8 Function::Call
    return JSValue.undefined_value();
}

/// IteratorClose(iteratorRecord, completion) - Close iterator
///
/// For real V8 integration, use V8IteratorRecord.close() instead.
///
/// Spec: ES §7.4.6 IteratorClose
pub fn iteratorClose(record: *IteratorRecord, reason: JSValue) !void {
    if (record.done) {
        return;
    }

    const return_method = try getMethod(record.iterator, "return");

    if (return_method == null) {
        record.done = true;
        return;
    }

    _ = try call(return_method.?, record.iterator, &[_]JSValue{reason});

    record.done = true;
}

// ============================================================================
// Mock Async Iterator for Testing
// ============================================================================

/// MockAsyncIterator - Test helper that provides a simple async iterator
pub const MockAsyncIterator = struct {
    values: []const JSValue,
    index: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, values: []const JSValue) !*MockAsyncIterator {
        const iter = try allocator.create(MockAsyncIterator);
        iter.* = .{
            .values = values,
            .index = 0,
            .allocator = allocator,
        };
        return iter;
    }

    pub fn deinit(self: *MockAsyncIterator) void {
        self.allocator.destroy(self);
    }

    pub fn next(self: *MockAsyncIterator) IteratorResult {
        if (self.index >= self.values.len) {
            return .{ .done = true, .value = JSValue.undefined_value() };
        }

        const value = self.values[self.index];
        self.index += 1;

        return .{ .done = false, .value = value };
    }

    pub fn returnMethod(self: *MockAsyncIterator, reason: JSValue) IteratorResult {
        _ = reason;
        self.index = self.values.len;
        return .{ .done = true, .value = JSValue.undefined_value() };
    }
};

/// IteratorResult - The result of calling next() on an iterator
pub const IteratorResult = struct {
    done: bool,
    value: JSValue,
};
