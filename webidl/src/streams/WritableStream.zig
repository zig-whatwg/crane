//! WritableStream class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#ws-class
//!
//! Represents a destination for streaming data that can be written incrementally.

const std = @import("std");
const webidl = @import("webidl");

// Import stream infrastructure
const common = @import("common");
const dict_parsing = @import("dict_parsing");
const eventLoop = @import("eventLoop");
const AsyncPromise = @import("async_promise").AsyncPromise;
const TestEventLoop = @import("test_eventLoop").TestEventLoop;

// Import related types
const WritableStreamDefaultController = @import("WritableStreamDefaultController").WritableStreamDefaultController;
const WritableStreamDefaultWriter = @import("WritableStreamDefaultWriter").WritableStreamDefaultWriter;

/// Stream state enumeration
///
/// Spec: § 5.1 "Internal slots" - [[state]]
pub const StreamState = enum {
    writable,
    closed,
    erroring,
    errored,
};

/// Writer type for a writable stream (optional)
pub const Writer = union(enum) {
    none: void,
    default: *WritableStreamDefaultWriter,
};

pub const WritableStream = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[backpressure]]: boolean - whether backpressure is being applied
    backpressure: bool,

    /// [[closeRequest]]: undefined or promise
    closeRequest: ?*AsyncPromise(void),

    /// [[controller]]: WritableStreamDefaultController
    controller: *WritableStreamDefaultController,

    /// [[detached]]: boolean - stream has been transferred via postMessage
    detached: bool,

    /// [[inFlightWriteRequest]]: undefined or promise
    inFlightWriteRequest: ?*AsyncPromise(void),

    /// [[inFlightCloseRequest]]: undefined or promise
    inFlightCloseRequest: ?*AsyncPromise(void),

    /// [[pendingAbortRequest]]: undefined or abort request record
    pendingAbortRequest: ?AbortRequest,

    /// [[state]]: "writable", "closed", "erroring", or "errored"
    state: StreamState,

    /// [[storedError]]: JavaScript value (if state is "erroring" or "errored")
    storedError: ?common.JSValue,

    /// [[writer]]: WritableStreamDefaultWriter or undefined
    writer: Writer,

    /// [[writeRequests]]: list of async promises
    writeRequests: std.ArrayList(*AsyncPromise(void)),

    /// Event loop for async operations (borrowed reference)
    eventLoop: eventLoop.EventLoop,

    /// Optional owned event loop for backward compatibility
    eventLoop_storage: ?*TestEventLoop,

    /// Initialize a new WritableStream (backward compatibility)
    pub fn init(allocator: std.mem.Allocator) !WritableStream {
        const loop_ptr = try allocator.create(TestEventLoop);
        errdefer allocator.destroy(loop_ptr);

        loop_ptr.* = TestEventLoop.init(allocator);

        var stream = try initWithSink(allocator, loop_ptr.eventLoop(), null, null);
        stream.eventLoop_storage = loop_ptr;

        return stream;
    }

    pub fn deinit(self: *WritableStream) void {
        self.controller.deinit();
        self.allocator.destroy(self.controller);

        self.writeRequests.deinit();

        switch (self.writer) {
            .default => |w| {
                w.deinit();
                self.allocator.destroy(w);
            },
            .none => {},
        }

        if (self.eventLoop_storage) |loop_ptr| {
            loop_ptr.deinit();
            self.allocator.destroy(loop_ptr);
        }
    }

    /// Initialize with underlying sink and strategy
    ///
    /// Spec: § 5.1.3 "new WritableStream(underlyingSink, strategy)"
    pub fn initWithSink(
        allocator: std.mem.Allocator,
        loop: eventLoop.EventLoop,
        underlyingSink: ?webidl.JSValue,
        strategy: ?webidl.JSValue,
    ) !WritableStream {
        const sink_dict = try dict_parsing.parseUnderlyingSink(allocator, underlyingSink);
        const strategy_dict = try dict_parsing.parseQueuingStrategy(allocator, strategy);

        const highWaterMark = strategy_dict.highWaterMark orelse 1.0;
        const size_algorithm = if (strategy_dict.size) |size_fn|
            common.wrapGenericSizeCallback(size_fn)
        else
            common.defaultSizeAlgorithm();

        const abortAlgorithm = if (sink_dict.abort) |abort_fn|
            common.wrapGenericAbortCallback(abort_fn)
        else
            common.defaultAbortAlgorithm();

        const closeAlgorithm = if (sink_dict.close) |close_fn|
            common.wrapGenericCloseCallback(close_fn)
        else
            common.defaultCloseAlgorithm();

        const writeAlgorithm = if (sink_dict.write) |write_fn|
            common.wrapGenericWriteCallback(write_fn)
        else
            common.defaultWriteAlgorithm();

        const controller = try allocator.create(WritableStreamDefaultController);
        errdefer allocator.destroy(controller);

        controller.* = WritableStreamDefaultController.init(
            allocator,
            abortAlgorithm,
            closeAlgorithm,
            writeAlgorithm,
            highWaterMark,
            size_algorithm,
            loop,
        );

        var stream = WritableStream{
            .allocator = allocator,
            .backpressure = false,
            .closeRequest = null,
            .controller = controller,
            .detached = false,
            .inFlightWriteRequest = null,
            .inFlightCloseRequest = null,
            .pendingAbortRequest = null,
            .state = .writable,
            .storedError = null,
            .writer = .none,
            .writeRequests = std.ArrayList(*AsyncPromise(void)).init(allocator),
            .eventLoop = loop,
            .eventLoop_storage = null,
        };

        stream.controller.stream = @ptrCast(&stream);
        stream.controller.started = true;

        return stream;
    }

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    /// locked attribute getter
    pub fn locked(self: *const WritableStream) bool {
        return self.isLocked();
    }

    /// abort(reason) method
    pub fn abort(self: *WritableStream, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        if (self.isLocked()) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Stream is locked" });
            return promise;
        }

        const reason_value = if (reason) |r| common.JSValue.fromWebIDL(r) else null;
        return self.abortInternal(reason_value);
    }

    /// close() method
    pub fn close(self: *WritableStream) !*AsyncPromise(void) {
        if (self.isLocked()) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Stream is locked" });
            return promise;
        }

        if (self.state == .closed or self.state == .errored) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Stream is already closed or errored" });
            return promise;
        }

        return self.closeInternal();
    }

    /// getWriter() method
    pub fn getWriter(self: *WritableStream) !*WritableStreamDefaultWriter {
        return self.acquireDefaultWriter(self.eventLoop);
    }

    // ============================================================================
    // Internal Algorithms
    // ============================================================================

    fn isLocked(self: *const WritableStream) bool {
        return self.writer != .none;
    }

    fn abortInternal(self: *WritableStream, reason: ?common.JSValue) !*AsyncPromise(void) {
        if (self.state == .closed or self.state == .errored) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.fulfill({});
            return promise;
        }

        // Signal abort to controller
        _ = reason;
        const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
        promise.fulfill({});
        return promise;
    }

    fn closeInternal(self: *WritableStream) !*AsyncPromise(void) {
        self.state = .closed;
        const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
        promise.fulfill({});
        return promise;
    }

    fn acquireDefaultWriter(self: *WritableStream, loop: eventLoop.EventLoop) !*WritableStreamDefaultWriter {
        const writer = try self.allocator.create(WritableStreamDefaultWriter);
        errdefer self.allocator.destroy(writer);

        writer.* = try WritableStreamDefaultWriter.init(self.allocator, self, loop);
        self.writer = .{ .default = writer };

        return writer;
    }

    pub fn errorInternal(self: *WritableStream, e: common.JSValue) void {
        if (self.state == .closed or self.state == .errored) {
            return;
        }
        self.state = .errored;
        self.storedError = e;
    }
});

const AbortRequest = struct {
    reason: ?common.JSValue,
    wasAlreadyErroring: bool,
};
