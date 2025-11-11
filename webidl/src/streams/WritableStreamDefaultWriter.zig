//! WritableStreamDefaultWriter class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#default-writer-class
//!
//! Allows writing chunks to a WritableStream.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const eventLoop = @import("event_loop");
const AsyncPromise = @import("async_promise").AsyncPromise;

const WritableStream = @import("writable_stream").WritableStream;

pub const WritableStreamDefaultWriter = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[closedPromise]]: Promise that fulfills when stream closes
    closedPromise: *AsyncPromise(void),

    /// [[readyPromise]]: Promise that fulfills when stream is ready for writes
    readyPromise: ?*AsyncPromise(void),

    /// [[stream]]: The WritableStream being written to (or undefined if released)
    stream: ?*WritableStream,

    /// Event loop for async operations
    eventLoop: eventLoop.EventLoop,

    pub fn init(
        allocator: std.mem.Allocator,
        stream: *WritableStream,
        loop: eventLoop.EventLoop,
    ) !WritableStreamDefaultWriter {
        const closedPromise = try AsyncPromise(void).init(allocator, loop);
        const readyPromise = try AsyncPromise(void).init(allocator, loop);

        if (!stream.backpressure) {
            readyPromise.fulfill({});
        }

        return .{
            .allocator = allocator,
            .closedPromise = closedPromise,
            .readyPromise = readyPromise,
            .stream = stream,
            .eventLoop = loop,
        };
    }

    pub fn deinit(_: *WritableStreamDefaultWriter) void {}

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn closed(self: *const WritableStreamDefaultWriter) webidl.Promise(void) {
        if (self.closedPromise.isFulfilled()) {
            return webidl.Promise(void).fulfilled({});
        } else if (self.closedPromise.isRejected()) {
            const err_str = switch (self.closedPromise.state.rejected) {
                .string => |s| s,
                else => "Unknown error",
            };
            return webidl.Promise(void).rejected(err_str);
        } else {
            return webidl.Promise(void).pending();
        }
    }

    pub fn call_desiredSize(self: *const WritableStreamDefaultWriter) ?f64 {
        if (self.stream == null) {
            return null;
        }
        return self.getDesiredSizeInternal();
    }

    /// Alias for generated code compatibility
    pub fn desiredSize(self: *const WritableStreamDefaultWriter) ?f64 {
        return self.call_desiredSize();
    }

    pub fn ready(self: *const WritableStreamDefaultWriter) webidl.Promise(void) {
        if (self.readyPromise) |promise| {
            if (promise.isFulfilled()) {
                return webidl.Promise(void).fulfilled({});
            } else if (promise.isRejected()) {
                const err_str = switch (promise.state.rejected) {
                    .string => |s| s,
                    else => "Unknown error",
                };
                return webidl.Promise(void).rejected(err_str);
            } else {
                return webidl.Promise(void).pending();
            }
        }
        return webidl.Promise(void).fulfilled({});
    }

    pub fn abort(self: *WritableStreamDefaultWriter, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        if (self.stream == null) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Writer released" });
            return promise;
        }

        const reason_value = if (reason) |r| common.JSValue.fromWebIDL(r) else null;
        return self.abortInternal(reason_value);
    }

    pub fn close(self: *WritableStreamDefaultWriter) !*AsyncPromise(void) {
        if (self.stream == null) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Writer released" });
            return promise;
        }

        return self.closeInternal();
    }

    pub fn call_releaseLock(self: *WritableStreamDefaultWriter) void {
        if (self.stream == null) {
            return;
        }
        self.releaseInternal();
    }

    /// Alias for generated code compatibility
    pub fn releaseLock(self: *WritableStreamDefaultWriter) void {
        self.call_releaseLock();
    }

    pub fn write(self: *WritableStreamDefaultWriter, chunk: ?webidl.JSValue) !*AsyncPromise(void) {
        if (self.stream == null) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Writer released" });
            return promise;
        }

        const chunkValue = if (chunk) |c| c else webidl.JSValue{ .undefined = {} };
        return self.writeInternal(common.JSValue.fromWebIDL(chunkValue));
    }

    // ============================================================================
    // Internal Algorithms
    // ============================================================================

    fn getDesiredSizeInternal(self: *const WritableStreamDefaultWriter) ?f64 {
        _ = self;
        return 1.0; // Placeholder
    }

    fn abortInternal(self: *WritableStreamDefaultWriter, reason: ?common.JSValue) !*AsyncPromise(void) {
        _ = reason;
        const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
        promise.fulfill({});
        return promise;
    }

    fn closeInternal(self: *WritableStreamDefaultWriter) !*AsyncPromise(void) {
        const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
        promise.fulfill({});
        return promise;
    }

    pub fn writeInternal(self: *WritableStreamDefaultWriter, chunk: common.JSValue) !*AsyncPromise(void) {
        _ = chunk;
        const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
        promise.fulfill({});
        return promise;
    }

    fn releaseInternal(self: *WritableStreamDefaultWriter) void {
        if (self.stream) |stream| {
            stream.writer = .none;
            self.stream = null;
        }
    }
}, .{
    .exposed = &.{.global},
});
