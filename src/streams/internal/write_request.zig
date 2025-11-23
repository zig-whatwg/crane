//! Write request record for pending write operations
//!
//! Used by WritableStreamDefaultWriter.write() to track pending writes.
//!
//! Spec: § 5.3.4 "Write request"
//! https://streams.spec.whatwg.org/#write-request

const std = @import("std");
const queue = @import("queue_with_sizes");
const AsyncPromise = @import("async_promise").AsyncPromise;
const event_loop = @import("event_loop");
const webidl = @import("webidl");

const Value = queue.Value;

/// Write request record
///
/// A write request is a struct with two items:
/// - chunk: the JavaScript value being written
/// - promise: a promise that will be fulfilled/rejected when write completes
///
/// Per WHATWG Streams spec § 5.3.4:
/// "A write request is a struct with two items:
///  - chunk (a JavaScript value)
///  - promise (a promise)"
pub const WriteRequest = struct {
    allocator: std.mem.Allocator,

    /// chunk: The value being written
    chunk: Value,

    /// promise: AsyncPromise<void> to resolve when write completes
    promise: *AsyncPromise(void),

    /// Initialize a new write request
    pub fn init(
        allocator: std.mem.Allocator,
        loop: event_loop.EventLoop,
        chunk: Value,
    ) !*WriteRequest {
        const request = try allocator.create(WriteRequest);
        errdefer allocator.destroy(request);

        const promise = try AsyncPromise(void).init(allocator, loop);
        errdefer promise.deinit();

        request.* = .{
            .allocator = allocator,
            .chunk = chunk,
            .promise = promise,
        };
        return request;
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *WriteRequest) void {
        self.promise.deinit();
        self.allocator.destroy(self);
    }

    /// Fulfill the write promise
    pub fn fulfill(self: *WriteRequest) void {
        self.promise.fulfill({});
    }

    /// Reject the write promise
    pub fn reject(self: *WriteRequest, err: webidl.errors.Exception) void {
        self.promise.reject(err);
    }

    /// Check if promise is still pending
    pub fn isPending(self: *const WriteRequest) bool {
        return self.promise.isPending();
    }

    /// Check if promise is fulfilled
    pub fn isFulfilled(self: *const WriteRequest) bool {
        return self.promise.isFulfilled();
    }

    /// Check if promise is rejected
    pub fn isRejected(self: *const WriteRequest) bool {
        return self.promise.isRejected();
    }
};

// Tests
