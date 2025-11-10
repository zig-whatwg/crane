//! ReadableStreamDefaultController class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#rs-default-controller-class
//!
//! Controls a ReadableStream's state and internal queue.
//!
//! This implementation follows the reference implementation pattern from
//! webidl/generated-back/streams/ but uses PascalCase naming for interfaces.

const std = @import("std");
const webidl = @import("webidl");

// Import stream infrastructure
const QueueWithSizes = @import("queue_with_sizes").QueueWithSizes;
const Value = @import("queue_with_sizes").Value;
const common = @import("common");
const eventLoop = @import("event_loop");
const AsyncPromise = @import("async_promise").AsyncPromise;

// Import ReadableStream (will be defined elsewhere to avoid circular dependency)
// We use *anyopaque for the stream reference and cast when needed
const ReadableStream = @import("readable_stream").ReadableStream;
const ReadableStreamDefaultReader = @import("readable_stream_default_reader").ReadableStreamDefaultReader;

/// ReadableStreamDefaultController WebIDL interface
///
/// IDL:
/// ```webidl
/// [Exposed=*]
/// interface ReadableStreamDefaultController {
///   readonly attribute unrestricted double? desiredSize;
///
///   undefined close();
///   undefined enqueue(optional any chunk);
///   undefined error(optional any e);
/// };
/// ```
pub const ReadableStreamDefaultController = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[cancelAlgorithm]]: Promise-returning algorithm for cancelation
    ///
    /// Spec: § 4.6.2 Internal slot [[cancelAlgorithm]]
    cancelAlgorithm: common.CancelAlgorithm,

    /// [[closeRequested]]: boolean - stream closed by source but has queued chunks
    ///
    /// Spec: § 4.6.2 Internal slot [[closeRequested]]
    closeRequested: bool,

    /// [[pullAgain]]: boolean - pull requested but previous pull still executing
    ///
    /// Spec: § 4.6.2 Internal slot [[pullAgain]]
    pullAgain: bool,

    /// [[pullAlgorithm]]: Promise-returning algorithm for pulling data
    ///
    /// Spec: § 4.6.2 Internal slot [[pullAlgorithm]]
    pullAlgorithm: common.PullAlgorithm,

    /// [[pulling]]: boolean - pull algorithm currently executing
    ///
    /// Spec: § 4.6.2 Internal slot [[pulling]]
    pulling: bool,

    /// [[queue]]: Queue-with-sizes for internal chunk queue
    ///
    /// Spec: § 4.6.2 Internal slot [[queue]]
    queue: QueueWithSizes,

    /// [[started]]: boolean - underlying source has finished starting
    ///
    /// Spec: § 4.6.2 Internal slot [[started]]
    started: bool,

    /// [[strategyHWM]]: High water mark for backpressure
    ///
    /// Spec: § 4.6.2 Internal slot [[strategyHWM]]
    strategyHwm: f64,

    /// [[strategySizeAlgorithm]]: Algorithm to calculate chunk size
    ///
    /// Spec: § 4.6.2 Internal slot [[strategySizeAlgorithm]]
    strategySizeAlgorithm: common.SizeAlgorithm,

    /// [[stream]]: The ReadableStream instance controlled
    ///
    /// Spec: § 4.6.2 Internal slot [[stream]]
    /// Using *anyopaque to avoid circular dependency
    stream: ?*anyopaque,

    /// Event loop for async operations
    eventLoop: eventLoop.EventLoop,

    /// Initialize a new controller (internal - not exposed via WebIDL)
    ///
    /// Spec: § 4.6.4 "SetUpReadableStreamDefaultController"
    pub fn init(
        allocator: std.mem.Allocator,
        cancelAlgorithm: common.CancelAlgorithm,
        pullAlgorithm: common.PullAlgorithm,
        strategyHwm: f64,
        strategySizeAlgorithm: common.SizeAlgorithm,
        loop: eventLoop.EventLoop,
    ) ReadableStreamDefaultController {
        return .{
            .allocator = allocator,
            .cancelAlgorithm = cancelAlgorithm,
            .closeRequested = false,
            .pullAgain = false,
            .pullAlgorithm = pullAlgorithm,
            .pulling = false,
            .queue = QueueWithSizes.init(allocator),
            .started = false,
            .strategyHwm = strategyHwm,
            .strategySizeAlgorithm = strategySizeAlgorithm,
            .stream = null,
            .eventLoop = loop,
        };
    }

    /// Deinitialize the controller
    ///
    /// Spec: Cleanup internal queue
    pub fn deinit(self: *ReadableStreamDefaultController) void {
        self.queue.deinit();
    }

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    /// desiredSize attribute getter
    ///
    /// IDL: readonly attribute unrestricted double? desiredSize;
    ///
    /// Spec: § 4.6.3 "The desiredSize getter steps are:"
    /// Returns the desired size to fill the stream's internal queue.
    pub fn call_desiredSize(self: *const ReadableStreamDefaultController) ?f64 {
        // Step 1: Return ! ReadableStreamDefaultControllerGetDesiredSize(this).
        return self.calculateDesiredSize();
    }

    /// close() method
    ///
    /// IDL: undefined close();
    ///
    /// Spec: § 4.6.3 "The close() method steps are:"
    /// Closes the controlled readable stream.
    pub fn close(self: *ReadableStreamDefaultController) !void {
        // Step 1: If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(this) is false,
        // throw a TypeError exception.
        if (!self.canCloseOrEnqueue()) {
            return error.TypeError;
        }

        // Step 2: Perform ! ReadableStreamDefaultControllerClose(this).
        self.closeInternal();
    }

    /// enqueue(chunk) method
    ///
    /// IDL: undefined enqueue(optional any chunk);
    ///
    /// Spec: § 4.6.3 "The enqueue(chunk) method steps are:"
    /// Enqueues the given chunk in the controlled readable stream.
    pub fn call_enqueue(self: *ReadableStreamDefaultController, chunk: ?webidl.JSValue) !void {
        // Step 1: If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(this) is false,
        // throw a TypeError exception.
        if (!self.canCloseOrEnqueue()) {
            return error.TypeError;
        }

        const chunkValue = if (chunk) |c| c else webidl.JSValue{ .undefined = {} };

        // Step 2: Perform ? ReadableStreamDefaultControllerEnqueue(this, chunk).
        try self.enqueueInternal(chunkValue);
    }

    /// error(e) method (exposed as errorStream to avoid keyword conflict)
    ///
    /// IDL: undefined error(optional any e);
    ///
    /// Spec: § 4.6.3 "The error(e) method steps are:"
    /// Errors the controlled readable stream.
    ///
    /// Note: Named `errorStream` in Zig to avoid conflict with `error` keyword
    pub fn errorStream(self: *ReadableStreamDefaultController, e: ?webidl.JSValue) void {
        // Step 1: Perform ! ReadableStreamDefaultControllerError(this, e).
        const error_value = if (e) |err| err else webidl.JSValue{ .undefined = {} };
        self.errorInternal(error_value);
    }

    // ============================================================================
    // Internal Algorithms (Abstract Operations)
    // ============================================================================

    /// ReadableStreamDefaultControllerGetDesiredSize(controller)
    ///
    /// Spec: § 4.6.4 "Calculate desired size for backpressure"
    pub fn calculateDesiredSize(self: *const ReadableStreamDefaultController) ?f64 {
        // If stream is closed, return 0
        if (self.closeRequested and self.queue.isEmpty()) {
            return 0.0;
        }

        // Return highWaterMark - queueTotalSize
        return self.strategyHwm - self.queue.queue_total_size;
    }

    /// ReadableStreamDefaultControllerCanCloseOrEnqueue(controller)
    ///
    /// Spec: § 4.6.4 "Check if controller can close or enqueue"
    fn canCloseOrEnqueue(self: *const ReadableStreamDefaultController) bool {
        // Cannot close or enqueue if already close requested
        return !self.closeRequested;
    }

    /// ReadableStreamDefaultControllerClose(controller)
    ///
    /// Spec: § 4.6.4 "Close the controller"
    fn closeInternal(self: *ReadableStreamDefaultController) void {
        // Step 1: If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(controller) is false, return.
        if (!self.canCloseOrEnqueue()) {
            return;
        }

        // Step 2: Set controller.[[closeRequested]] to true.
        self.closeRequested = true;

        // Step 3: If controller.[[queue]] is empty,
        if (self.queue.isEmpty()) {
            // Step 3.1: Perform ! ReadableStreamDefaultControllerClearAlgorithms(controller).
            self.clearAlgorithms();

            // Step 3.2: Perform ! ReadableStreamClose(stream).
            if (self.stream) |stream_ptr| {
                const stream: *ReadableStream = @ptrCast(@alignCast(stream_ptr));

                // Fulfill all pending read requests with done=true
                switch (stream.reader) {
                    .none => {},
                    .default => |reader| {
                        while (reader.readRequests.items.len > 0) {
                            const promise = reader.readRequests.orderedRemove(0);
                            promise.fulfill(.{
                                .value = null,
                                .done = true,
                            });
                        }
                    },
                    .byob => {}, // TODO: BYOB reader fulfillment (Phase 7)
                }

                stream.closeInternal();
            }
        }
    }

    /// ReadableStreamDefaultControllerEnqueue(controller, chunk)
    ///
    /// Spec: § 4.6.4 "Enqueue a chunk"
    pub fn enqueueInternal(self: *ReadableStreamDefaultController, chunk: webidl.JSValue) !void {
        // Step 1: If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(controller) is false, return.
        if (!self.canCloseOrEnqueue()) {
            return;
        }

        // Step 2: Let stream be controller.[[stream]].
        // Step 3: If ! IsReadableStreamLocked(stream) is true and
        //         ! ReadableStreamGetNumReadRequests(stream) > 0,
        //         perform ! ReadableStreamFulfillReadRequest(stream, chunk, false).
        if (self.stream) |stream_ptr| {
            const stream: *ReadableStream = @ptrCast(@alignCast(stream_ptr));

            // Check if stream has a reader with pending read requests
            if (stream.isLocked()) {
                const num_requests = stream.getNumReadRequests();
                if (num_requests > 0) {
                    // Fulfill the first pending read request immediately
                    stream.fulfillReadRequest(common.JSValue.fromWebIDL(chunk), false);
                    return;
                }
            }
        }

        // Step 4: Otherwise, enqueue the chunk
        // Step 4.1: Let result be the result of performing controller.[[strategySizeAlgorithm]]
        const chunkValue = common.JSValue.fromWebIDL(chunk);
        const chunkSize = self.strategySizeAlgorithm.call(chunkValue);

        // Convert common.JSValue to queue Value for storage
        const queue_value: Value = switch (chunkValue) {
            .undefined => .undefined,
            .null => .null,
            .boolean => |b| .{ .number = if (b) 1.0 else 0.0 },
            .number => |n| .{ .number = n },
            .string => |s| .{ .string = s },
            .bytes => |b| .{ .bytes = b },
            .object => .undefined,
            .close_sentinel => .close_sentinel,
        };

        // Step 4.4: Let enqueueResult be EnqueueValueWithSize(controller, chunk, chunkSize).
        self.queue.enqueueValueWithSize(queue_value, chunkSize) catch {
            // Step 4.5: If enqueueResult is an abrupt completion,
            self.errorInternal(webidl.JSValue{ .string = "Enqueue failed" });
            return error.EnqueueFailed;
        };

        // Step 5: Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller).
        self.callPullIfNeeded();
    }

    /// ReadableStreamDefaultControllerError(controller, e)
    ///
    /// Spec: § 4.6.4 "Error the controller"
    fn errorInternal(self: *ReadableStreamDefaultController, e: webidl.JSValue) void {
        // Convert to internal JSValue
        const error_value = common.JSValue.fromWebIDL(e);

        // Step 1: Let stream be controller.[[stream]].
        if (self.stream) |stream_ptr| {
            const stream: *ReadableStream = @ptrCast(@alignCast(stream_ptr));

            // Step 2: If stream.[[state]] is not "readable", return.
            if (stream.state != .readable) {
                return;
            }

            // Step 3: Perform ! ReadableStreamDefaultControllerClearAlgorithms(controller).
            self.clearAlgorithms();

            // Step 4: Perform ! ReadableStreamError(stream, e).
            stream.errorInternal(error_value);
        }
    }

    /// ReadableStreamDefaultControllerClearAlgorithms(controller)
    ///
    /// Spec: § 4.6.4 "Clear algorithms to enable garbage collection"
    fn clearAlgorithms(self: *ReadableStreamDefaultController) void {
        // In Zig, we don't need explicit clearing since algorithms use VTable pattern
        // The algorithms will be freed when the controller is deinitialized
        _ = self;
    }

    /// ReadableStreamDefaultControllerCallPullIfNeeded(controller)
    ///
    /// Spec: § 4.6.4 "Call pull algorithm if backpressure allows"
    fn callPullIfNeeded(self: *ReadableStreamDefaultController) void {
        // Step 1: Let shouldPull be ! ReadableStreamDefaultControllerShouldCallPull(controller).
        if (!self.shouldCallPull()) {
            return;
        }

        // Step 2: If controller.[[pulling]] is true,
        if (self.pulling) {
            // Step 2.1: Set controller.[[pullAgain]] to true.
            self.pullAgain = true;
            return;
        }

        // Step 3: Assert: controller.[[pullAgain]] is false.
        std.debug.assert(!self.pullAgain);

        // Step 4: Set controller.[[pulling]] to true.
        self.pulling = true;

        // Step 5: Let pullPromise be the result of performing controller.[[pullAlgorithm]].
        const pullPromise = self.pullAlgorithm.call();

        // TODO: Implement promise handling when pull completes
        // For now, we just mark pulling as complete
        _ = pullPromise;
        self.pulling = false;

        // Check if we need to pull again
        if (self.pullAgain) {
            self.pullAgain = false;
            self.callPullIfNeeded();
        }
    }

    /// ReadableStreamDefaultControllerShouldCallPull(controller)
    ///
    /// Spec: § 4.6.4 "Determine if pull should be called"
    fn shouldCallPull(self: *ReadableStreamDefaultController) bool {
        // Step 1: Let stream be controller.[[stream]].
        if (self.stream) |stream_ptr| {
            const stream: *ReadableStream = @ptrCast(@alignCast(stream_ptr));

            // Step 2: If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(controller) is false, return false.
            if (!self.canCloseOrEnqueue()) {
                return false;
            }

            // Step 3: If controller.[[started]] is false, return false.
            if (!self.started) {
                return false;
            }

            // Step 4: If ! IsReadableStreamLocked(stream) is true and
            //         ! ReadableStreamGetNumReadRequests(stream) > 0, return true.
            if (stream.isLocked() and stream.getNumReadRequests() > 0) {
                return true;
            }

            // Step 5: Let desiredSize be ! ReadableStreamDefaultControllerGetDesiredSize(controller).
            const desired_size = self.calculateDesiredSize();

            // Step 6: Assert: desiredSize is not null.
            // Step 7: If desiredSize > 0, return true.
            if (desired_size) |size| {
                return size > 0;
            }
        }

        // Step 8: Return false.
        return false;
    }

    /// [[PullSteps]](reader) - Internal operation called by reader.read()
    ///
    /// Spec: § 4.6.5 "Pull steps for default controller"
    pub fn pullSteps(self: *ReadableStreamDefaultController, reader: *ReadableStreamDefaultReader) !*AsyncPromise(common.ReadResult) {
        // Step 1: Let stream be controller.[[stream]].
        if (self.stream) |stream_ptr| {
            const stream: *ReadableStream = @ptrCast(@alignCast(stream_ptr));

            // Step 2: If controller.[[queue]] is not empty,
            if (!self.queue.isEmpty()) {
                // Step 2.1: Let chunk be ! DequeueValue(controller).
                const chunk = self.queue.dequeueValue();

                // Step 2.2: If controller.[[closeRequested]] is true and controller.[[queue]] is empty,
                if (self.closeRequested and self.queue.isEmpty()) {
                    // Step 2.2.1: Perform ! ReadableStreamDefaultControllerClearAlgorithms(controller).
                    self.clearAlgorithms();
                    // Step 2.2.2: Perform ! ReadableStreamClose(stream).
                    stream.closeInternal();
                }
                // Step 2.3: Otherwise, perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller).
                else {
                    self.callPullIfNeeded();
                }

                // Step 2.4: Return a promise fulfilled with ! ReadableStreamCreateReadResult(chunk, false, forAuthorCode).
                const promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);
                promise.fulfill(.{
                    .value = chunk,
                    .done = false,
                });
                return promise;
            }

            // Step 3: Let pendingPromise be ! ReadableStreamAddReadRequest(stream).
            const pendingPromise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);
            try reader.readRequests.append(pendingPromise);

            // Step 4: Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller).
            self.callPullIfNeeded();

            // Step 5: Return pendingPromise.
            return pendingPromise;
        }

        // Shouldn't reach here if stream is set correctly
        const promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);
        promise.reject(common.JSValue{ .string = "Stream not initialized" });
        return promise;
    }

    /// [[CancelSteps]](reason) - Internal operation called by stream.cancel()
    ///
    /// Spec: § 4.6.5 "Cancel steps for default controller"
    pub fn cancelInternal(self: *ReadableStreamDefaultController, reason: ?common.JSValue) !*AsyncPromise(void) {
        // Step 1: Perform ! ResetQueue(controller).
        self.queue.resetQueue();

        // Step 2: Let result be the result of performing controller.[[cancelAlgorithm]], passing reason.
        _ = reason;
        const result = self.cancelAlgorithm.call();

        // Step 3: Perform ! ReadableStreamDefaultControllerClearAlgorithms(controller).
        self.clearAlgorithms();

        // Step 4: Return result.
        return result;
    }

    /// [[ReleaseSteps]]() - Internal operation called when reader is released
    ///
    /// Spec: § 4.6.5 "Release steps for default controller"
    pub fn releaseSteps(self: *ReadableStreamDefaultController) void {
        // For default controller, release steps are a no-op
        _ = self;
    }
}, .{
    .exposed = &.{.global},
});
