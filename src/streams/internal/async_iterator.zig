//! Async Iterator Protocol (ES2018+)
//!
//! Implements the ES async iterator protocol for use with ReadableStream.from()
//! Spec: ECMAScript Language Specification §27.1 (Iteration)
//! Spec: WHATWG Streams §4.2.1 ReadableStreamFromIterable

const std = @import("std");
const Allocator = std.mem.Allocator;
const common = @import("common");
const JSValue = common.JSValue;
const Promise = common.Promise;

/// IteratorRecord
/// Spec: ES §27.1.1.2 The Iterator Record Specification Type
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

/// GetIterator(obj, hint)
/// Spec: ES §7.4.1 GetIterator
///
/// Gets an iterator from an object using either @@iterator or @@asyncIterator
/// NOTE: Simplified implementation - full iterator protocol requires JS runtime
pub fn getIterator(allocator: Allocator, obj: JSValue, hint: enum { sync, async_hint }) !IteratorRecord {
    _ = hint; // Hint determines Symbol.asyncIterator vs Symbol.iterator

    // Simplified implementation assumes obj is already an iterator-like object
    // Full implementation requires:
    // 1. Get @@asyncIterator or @@iterator method from obj
    // 2. Call the method to get iterator
    // 3. Get the "next" method from iterator
    // 4. Return IteratorRecord

    switch (obj) {
        .object => {
            // Return a dummy iterator record that will be filled in by calling code
            return IteratorRecord.init(
                allocator,
                obj,
                JSValue.undefined_value(), // next method placeholder
            );
        },
        else => return error.TypeError,
    }
}

/// IteratorNext(iteratorRecord)
/// Spec: ES §7.4.2 IteratorNext
///
/// Calls the next() method on an iterator and returns the result
pub fn iteratorNext(record: *IteratorRecord) !Promise(JSValue) {
    if (record.done) {
        // Iterator already closed
        return Promise(JSValue).fulfilled(JSValue.undefined_value());
    }

    // Call iteratorRecord.[[NextMethod]].call(iteratorRecord.[[Iterator]])
    // This would be: result = record.next_method.call(record.iterator)

    // For now, return a placeholder promise
    // In production, this needs proper method invocation
    return Promise(JSValue).pending();
}

/// IteratorComplete(iterResult)
/// Spec: ES §7.4.3 IteratorComplete
///
/// Returns the value of the "done" property of an iterator result object
pub fn iteratorComplete(iter_result: JSValue) !bool {
    // iterResult must be an Object
    if (iter_result != .object) {
        return error.TypeError;
    }

    // Return ToBoolean(? Get(iterResult, "done"))
    // For now, this is a placeholder
    // In production, this needs proper property access

    // Placeholder: return false to continue iteration
    return false;
}

/// IteratorValue(iterResult)
/// Spec: ES §7.4.4 IteratorValue
///
/// Returns the value of the "value" property of an iterator result object
pub fn iteratorValue(iter_result: JSValue) !JSValue {
    // iterResult must be an Object
    if (iter_result != .object) {
        return error.TypeError;
    }

    // Return ? Get(iterResult, "value")
    // For now, this is a placeholder
    // In production, this needs proper property access

    // Placeholder: return undefined
    return JSValue.undefined_value();
}

/// GetMethod(V, P)
/// Spec: ES §7.3.9 GetMethod
///
/// Gets a method from an object by property key
pub fn getMethod(v: JSValue, property: []const u8) !?JSValue {
    _ = property;

    // Get the property from V
    // If it's undefined or null, return null
    // If it's callable, return it
    // Otherwise, throw TypeError

    switch (v) {
        .object => {
            // NOTE: Proper property lookup requires JS runtime
            return null;
        },
        .undefined, .null => return null,
        else => return error.TypeError,
    }
}

/// Call(F, V, argumentsList)
/// Spec: ES §7.3.12 Call
///
/// Calls a function with a given this value and arguments
pub fn call(f: JSValue, v: JSValue, args: []const JSValue) !JSValue {
    _ = f;
    _ = v;
    _ = args;

    // Call F with this=V and arguments=argumentsList
    // For now, return undefined placeholder
    // In production, this needs proper function invocation

    return JSValue.undefined_value();
}

/// IteratorClose(iteratorRecord, completion)
/// Spec: ES §7.4.6 IteratorClose
///
/// Closes an iterator by calling its return() method
pub fn iteratorClose(record: *IteratorRecord, reason: JSValue) !void {
    if (record.done) {
        return; // Already closed
    }

    // Get return method
    const return_method = try getMethod(record.iterator, "return");

    if (return_method == null) {
        // No return method, just mark as done
        record.done = true;
        return;
    }

    // Call return method
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
        self.index = self.values.len; // Mark as done
        return .{ .done = true, .value = JSValue.undefined_value() };
    }
};

/// IteratorResult - The result of calling next() on an iterator
pub const IteratorResult = struct {
    done: bool,
    value: JSValue,
};

// ============================================================================
// Tests
// ============================================================================

test "IteratorRecord init" {
    const allocator = std.testing.allocator;

    const iter_obj = JSValue{ .object = {} };
    const next_method = JSValue{ .object = {} };

    const record = IteratorRecord.init(allocator, iter_obj, next_method);

    try std.testing.expectEqual(false, record.done);
    try std.testing.expectEqual(iter_obj, record.iterator);
    try std.testing.expectEqual(next_method, record.next_method);
}

test "iteratorComplete - non-object throws" {
    const result = JSValue{ .number = 42 };
    try std.testing.expectError(error.TypeError, iteratorComplete(result));
}

test "iteratorValue - non-object throws" {
    const result = JSValue{ .string = "not an object" };
    try std.testing.expectError(error.TypeError, iteratorValue(result));
}

test "getMethod - undefined returns null" {
    const result = try getMethod(JSValue.undefined_value(), "return");
    try std.testing.expectEqual(@as(?JSValue, null), result);
}

test "getMethod - null returns null" {
    const result = try getMethod(JSValue.null_value(), "return");
    try std.testing.expectEqual(@as(?JSValue, null), result);
}

test "MockAsyncIterator - basic iteration" {
    const allocator = std.testing.allocator;

    const values = [_]JSValue{
        JSValue{ .number = 1 },
        JSValue{ .number = 2 },
        JSValue{ .number = 3 },
    };

    var iter = try MockAsyncIterator.init(allocator, &values);
    defer iter.deinit();

    // First value
    var result = iter.next();
    try std.testing.expectEqual(false, result.done);
    try std.testing.expectEqual(JSValue{ .number = 1 }, result.value);

    // Second value
    result = iter.next();
    try std.testing.expectEqual(false, result.done);
    try std.testing.expectEqual(JSValue{ .number = 2 }, result.value);

    // Third value
    result = iter.next();
    try std.testing.expectEqual(false, result.done);
    try std.testing.expectEqual(JSValue{ .number = 3 }, result.value);

    // Done
    result = iter.next();
    try std.testing.expectEqual(true, result.done);
}

test "MockAsyncIterator - empty iterator" {
    const allocator = std.testing.allocator;

    const values = [_]JSValue{};

    var iter = try MockAsyncIterator.init(allocator, &values);
    defer iter.deinit();

    const result = iter.next();
    try std.testing.expectEqual(true, result.done);
}

test "MockAsyncIterator - return method" {
    const allocator = std.testing.allocator;

    const values = [_]JSValue{
        JSValue{ .number = 1 },
        JSValue{ .number = 2 },
        JSValue{ .number = 3 },
    };

    var iter = try MockAsyncIterator.init(allocator, &values);
    defer iter.deinit();

    // Get first value
    var result = iter.next();
    try std.testing.expectEqual(false, result.done);

    // Call return (simulates cancel)
    result = iter.returnMethod(JSValue.undefined_value());
    try std.testing.expectEqual(true, result.done);

    // Further calls should return done
    result = iter.next();
    try std.testing.expectEqual(true, result.done);
}
