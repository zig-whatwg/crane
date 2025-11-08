//! Write request record for pending write operations
//!
//! Used by WritableStreamDefaultWriter.write() to track pending writes.
//!
//! Spec: § 5.3.4 "Write request"
//! https://streams.spec.whatwg.org/#write-request

const std = @import("std");
const queue = @import("queue_with_sizes");

const Value = queue.Value;

/// Placeholder for Promise
/// In a real implementation, this would be webidl.Promise(void)
pub const Promise = struct {
    state: State = .pending,

    pub const State = enum {
        pending,
        fulfilled,
        rejected,
    };

    pub fn pending() Promise {
        return .{ .state = .pending };
    }

    pub fn fulfilled() Promise {
        return .{ .state = .fulfilled };
    }

    pub fn rejected() Promise {
        return .{ .state = .rejected };
    }

    pub fn fulfill(self: *Promise) void {
        self.state = .fulfilled;
    }

    pub fn reject(self: *Promise) void {
        self.state = .rejected;
    }
};

/// Write request record
///
/// A write request is a struct with two items:
/// - chunk: the JavaScript value being written
/// - promise: a promise that will be fulfilled/rejected when write completes
pub const WriteRequest = struct {
    allocator: std.mem.Allocator,

    /// chunk: The value being written
    chunk: Value,

    /// promise: Promise to resolve when write completes
    promise: Promise,

    /// Initialize a new write request
    pub fn init(
        allocator: std.mem.Allocator,
        chunk: Value,
    ) WriteRequest {
        return .{
            .allocator = allocator,
            .chunk = chunk,
            .promise = Promise.pending(),
        };
    }

    /// Fulfill the write promise
    pub fn fulfill(self: *WriteRequest) void {
        self.promise.fulfill();
    }

    /// Reject the write promise
    pub fn reject(self: *WriteRequest) void {
        self.promise.reject();
    }

    /// Check if promise is still pending
    pub fn isPending(self: *const WriteRequest) bool {
        return self.promise.state == .pending;
    }

    /// Check if promise is fulfilled
    pub fn isFulfilled(self: *const WriteRequest) bool {
        return self.promise.state == .fulfilled;
    }

    /// Check if promise is rejected
    pub fn isRejected(self: *const WriteRequest) bool {
        return self.promise.state == .rejected;
    }
};

// Tests

test "WriteRequest - basic creation" {
    const allocator = std.testing.allocator;

    const chunk = Value{ .number = 42.0 };
    const request = WriteRequest.init(allocator, chunk);

    try std.testing.expectEqual(Value{ .number = 42.0 }, request.chunk);
    try std.testing.expect(request.isPending());
    try std.testing.expect(!request.isFulfilled());
    try std.testing.expect(!request.isRejected());
}

test "WriteRequest - fulfill promise" {
    const allocator = std.testing.allocator;

    const chunk = Value{ .string = "test data" };
    var request = WriteRequest.init(allocator, chunk);

    try std.testing.expect(request.isPending());

    request.fulfill();

    try std.testing.expect(!request.isPending());
    try std.testing.expect(request.isFulfilled());
    try std.testing.expect(!request.isRejected());
}

test "WriteRequest - reject promise" {
    const allocator = std.testing.allocator;

    const chunk = Value{ .bytes = "bytes" };
    var request = WriteRequest.init(allocator, chunk);

    try std.testing.expect(request.isPending());

    request.reject();

    try std.testing.expect(!request.isPending());
    try std.testing.expect(!request.isFulfilled());
    try std.testing.expect(request.isRejected());
}

test "WriteRequest - multiple chunks" {
    const allocator = std.testing.allocator;

    const req1 = WriteRequest.init(allocator, .{ .number = 1.0 });
    const req2 = WriteRequest.init(allocator, .{ .number = 2.0 });
    const req3 = WriteRequest.init(allocator, .{ .number = 3.0 });

    try std.testing.expectEqual(Value{ .number = 1.0 }, req1.chunk);
    try std.testing.expectEqual(Value{ .number = 2.0 }, req2.chunk);
    try std.testing.expectEqual(Value{ .number = 3.0 }, req3.chunk);

    try std.testing.expect(req1.isPending());
    try std.testing.expect(req2.isPending());
    try std.testing.expect(req3.isPending());
}
