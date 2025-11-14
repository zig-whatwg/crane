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




