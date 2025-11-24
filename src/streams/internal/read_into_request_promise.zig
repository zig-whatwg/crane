//! Read-into request with Promise integration
//!
//! Provides promise-based BYOB read requests for ReadableStreamBYOBReader.
//!
//! Spec: § 4.5.4 "Read-into request"

const std = @import("std");
const AsyncPromise = @import("async_promise").AsyncPromise;
const event_loop = @import("event_loop");

/// Result returned from a BYOB read operation
///
/// Spec: ReadableStreamReadResult dictionary
pub const ReadIntoResult = struct {
    /// The view containing the read data
    view: *anyopaque, // ArrayBufferView
    /// Whether the stream is closed
    done: bool,
};

/// Read-into request with promise
///
/// This wraps an AsyncPromise and provides the three required callback steps.
pub const ReadIntoRequestWithPromise = struct {
    /// The promise to fulfill/reject
    promise: *AsyncPromise(ReadIntoResult),

    /// Allocator for cleanup
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        loop: event_loop.EventLoop,
    ) !*ReadIntoRequestWithPromise {
        const self = try allocator.create(ReadIntoRequestWithPromise);
        errdefer allocator.destroy(self);

        const promise = try AsyncPromise(ReadIntoResult).init(allocator, loop);

        self.* = .{
            .promise = promise,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *ReadIntoRequestWithPromise) void {
        self.promise.deinit();
        self.allocator.destroy(self);
    }

    /// Chunk steps: Called when bytes are read into the buffer
    ///
    /// Spec: Fulfill the promise with ReadIntoResult { view, done: false }
    pub fn chunkSteps(self: *ReadIntoRequestWithPromise, view: *anyopaque) void {
        const result = ReadIntoResult{
            .view = view,
            .done = false,
        };
        self.promise.fulfill(result);
    }

    /// Close steps: Called when stream closes before filling buffer
    ///
    /// Spec: Fulfill the promise with ReadIntoResult { view, done: true }
    pub fn closeSteps(self: *ReadIntoRequestWithPromise, view: *anyopaque) void {
        const result = ReadIntoResult{
            .view = view,
            .done = true,
        };
        self.promise.fulfill(result);
    }

    /// Error steps: Called when stream errors
    ///
    /// Spec: Reject the promise with error
    pub fn errorSteps(self: *ReadIntoRequestWithPromise, error_value: anyerror) void {
        // In a real implementation, this would convert the error to a proper JSValue
        // For now, just reject with the error
        _ = self;
        _ = error_value;
        // AsyncPromise expects the value type on rejection, not an error
        // So we need a different approach for error handling
        // TODO: Implement proper error rejection when JSValue integration is ready
    }

    /// Get the promise (for returning to caller)
    pub fn getPromise(self: *ReadIntoRequestWithPromise) *AsyncPromise(ReadIntoResult) {
        return self.promise;
    }
};

/// Callback-based read-into request (for use with existing code)
///
/// This creates ReadIntoRequest callbacks that fulfill/reject a promise.
pub const ReadIntoCallbacks = struct {
    /// Context struct that holds the promise
    pub const Context = struct {
        promise: *AsyncPromise(ReadIntoResult),
        view: *anyopaque, // Store the view for close steps
    };

    /// Chunk steps callback
    pub fn chunkStepsFn(ctx: ?*anyopaque, view: *anyopaque) void {
        const context: *Context = @ptrCast(@alignCast(ctx orelse return));
        const result = ReadIntoResult{
            .view = view,
            .done = false,
        };
        context.promise.fulfill(result);
    }

    /// Close steps callback
    pub fn closeStepsFn(ctx: ?*anyopaque) void {
        const context: *Context = @ptrCast(@alignCast(ctx orelse return));
        // Use the stored view
        const result = ReadIntoResult{
            .view = context.view,
            .done = true,
        };
        context.promise.fulfill(result);
    }

    /// Error steps callback
    pub fn errorStepsFn(ctx: ?*anyopaque, error_value: anyerror) void {
        _ = ctx;
        _ = error_value;
        // TODO: Implement proper error rejection
        // Need to reject the promise, but AsyncPromise doesn't have a reject API yet
        // This will be implemented when full JSValue integration is ready
    }

    /// Create a context for use with callbacks
    pub fn createContext(
        allocator: std.mem.Allocator,
        promise: *AsyncPromise(ReadIntoResult),
        view: *anyopaque,
    ) !*Context {
        const ctx = try allocator.create(Context);
        ctx.* = .{
            .promise = promise,
            .view = view,
        };
        return ctx;
    }
};

test "ReadIntoRequestWithPromise basic" {
    const testing = std.testing;
    const TestEventLoop = @import("test_event_loop").TestEventLoop;

    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const request = try ReadIntoRequestWithPromise.init(allocator, loop.eventLoop());
    defer request.deinit();

    // Simulate chunk steps
    var dummy_view: u32 = 42;
    request.chunkSteps(@ptrCast(&dummy_view));

    // Run microtasks
    loop.eventLoop().runMicrotasks();

    // Promise should be fulfilled
    const promise = request.getPromise();
    try testing.expect(promise.state == .fulfilled);
}

test "ReadIntoRequestWithPromise close steps" {
    const testing = std.testing;
    const TestEventLoop = @import("test_event_loop").TestEventLoop;

    const allocator = testing.allocator;
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    const request = try ReadIntoRequestWithPromise.init(allocator, loop.eventLoop());
    defer request.deinit();

    // Simulate close steps
    var dummy_view: u32 = 42;
    request.closeSteps(@ptrCast(&dummy_view));

    // Run microtasks
    loop.eventLoop().runMicrotasks();

    // Promise should be fulfilled with done=true
    const promise = request.getPromise();
    try testing.expect(promise.state == .fulfilled);
    // Note: We can't easily access the value without unwrapping the promise result
    // In a real scenario, the caller would use promise.then() to handle the result
}
