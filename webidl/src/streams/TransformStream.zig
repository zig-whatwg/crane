//! TransformStream class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#ts-class
//!
//! Represents a transformation that consists of a pair of streams.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const dict_parsing = @import("dict_parsing");
const eventLoop = @import("event_loop");
const ReadableStream = @import("readable_stream").ReadableStream;
const WritableStream = @import("writable_stream").WritableStream;
const TransformStreamDefaultController = @import("transform_stream_default_controller").TransformStreamDefaultController;

pub const TransformStream = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[backpressure]]: boolean - whether backpressure signal has been sent
    backpressure: bool,

    /// [[backpressureChangePromise]]: Promise that resolves when backpressure changes
    /// Spec: § 6.1.2 Internal slots
    backpressureChangePromise: ?common.Promise(void),

    /// [[readable]]: ReadableStream representing the readable side
    readableStream: *ReadableStream,

    /// [[writable]]: WritableStream representing the writable side
    writableStream: *WritableStream,

    /// [[controller]]: TransformStreamDefaultController
    controller: *TransformStreamDefaultController,

    pub fn init(allocator: std.mem.Allocator) !TransformStream {
        return initWithTransformer(allocator, null, null, null);
    }

    pub fn deinit(self: *TransformStream) void {
        self.readableStream.deinit();
        self.allocator.destroy(self.readableStream);
        self.writableStream.deinit();
        self.allocator.destroy(self.writableStream);
        self.controller.deinit();
        self.allocator.destroy(self.controller);
    }

    /// new TransformStream(transformer, writableStrategy, readableStrategy)
    ///
    /// Spec: § 6.1.3 "Constructor steps"
    pub fn initWithTransformer(
        allocator: std.mem.Allocator,
        transformer: ?webidl.JSValue,
        writableStrategy: ?webidl.JSValue,
        readableStrategy: ?webidl.JSValue,
    ) !TransformStream {
        // Spec step 1-2: If transformer is missing, set it to null; convert to Transformer dict
        const transformer_dict = try dict_parsing.parseTransformer(allocator, transformer);

        // Spec step 3: If transformerDict["readableType"] exists, throw RangeError
        if (transformer_dict.readable_type) |_| {
            return error.RangeError;
        }

        // Spec step 4: If transformerDict["writableType"] exists, throw RangeError
        if (transformer_dict.writable_type) |_| {
            return error.RangeError;
        }

        // Spec step 5-6: Extract readable high water mark and size algorithm
        const readable_strategy_dict = try dict_parsing.parseQueuingStrategy(allocator, readableStrategy);
        const readable_hwm = readable_strategy_dict.high_water_mark orelse 0.0;
        // Readable side default size algorithm (returns 1)
        // TODO: Extract and use readable_strategy_dict.size when available

        // Spec step 7-8: Extract writable high water mark and size algorithm
        const writable_strategy_dict = try dict_parsing.parseQueuingStrategy(allocator, writableStrategy);
        const writable_hwm = writable_strategy_dict.high_water_mark orelse 1.0;
        // Writable side default size algorithm (returns 1)
        // TODO: Extract and use writable_strategy_dict.size when available

        // Spec step 9: Let startPromise be a new promise
        // (We'll use a simplified synchronous initialization for now)

        // Spec step 10-11: Initialize transform stream and set up controller
        // Note: We use simplified initialization here. Full spec requires InitializeTransformStream
        // which creates streams with proper write/pull/close/abort algorithms linked to the controller

        const readable_stream = try allocator.create(ReadableStream);
        errdefer allocator.destroy(readable_stream);
        readable_stream.* = try ReadableStream.init(allocator);

        const writable_stream = try allocator.create(WritableStream);
        errdefer allocator.destroy(writable_stream);
        writable_stream.* = try WritableStream.init(allocator);

        // Create controller with extracted algorithms
        const ctrl = try allocator.create(TransformStreamDefaultController);
        errdefer allocator.destroy(ctrl);

        // Spec: Extract transform, flush, and cancel algorithms from transformer
        // If callbacks are provided, wrap them; otherwise use defaults
        const transform_alg = if (transformer_dict.transform) |cb|
            common.wrapGenericTransformCallback(cb)
        else
            common.defaultTransformAlgorithm();

        const flush_alg = if (transformer_dict.flush) |cb|
            common.wrapGenericFlushCallback(cb)
        else
            common.defaultFlushAlgorithm();

        const cancel_alg = if (transformer_dict.cancel) |cb|
            common.wrapGenericCancelCallback(cb)
        else
            common.defaultCancelAlgorithm();

        ctrl.* = TransformStreamDefaultController.init(
            allocator,
            transform_alg,
            flush_alg,
            cancel_alg,
        );

        var stream = TransformStream{
            .allocator = allocator,
            .backpressure = false,
            .backpressureChangePromise = null,
            .readableStream = readable_stream,
            .writableStream = writable_stream,
            .controller = ctrl,
        };

        ctrl.stream = @ptrCast(&stream);
        readable_stream.controller.stream = @ptrCast(readable_stream);
        writable_stream.controller.stream = @ptrCast(writable_stream);

        // Wire up TransformStream: set transformController on writable controller
        // This routes writes through the transform controller to the readable side
        // Spec: § 6.3.4 "TransformStreamDefaultSinkWriteAlgorithm"
        writable_stream.controller.transformController = ctrl;

        // Spec step 12-13: If transformerDict["start"] exists, invoke it with controller
        if (transformer_dict.start) |start_callback| {
            // TODO: Invoke start_callback with controller argument when zig-js-runtime is available
            // For now, we skip invocation since we can't call JavaScript callbacks yet
            _ = start_callback;
        }
        // Otherwise, startPromise is resolved with undefined (no-op)

        // Note: readable_hwm and writable_hwm are extracted but not yet applied
        // TODO: Use these for stream initialization via CreateReadableStream/CreateWritableStream
        // when InitializeTransformStream is fully implemented
        _ = readable_hwm;
        _ = writable_hwm;

        return stream;
    }

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn get_readable(self: *const TransformStream) *ReadableStream {
        return self.readableStream;
    }

    pub fn get_writable(self: *const TransformStream) *WritableStream {
        return self.writableStream;
    }

    // ============================================================================
    // Internal Helper Methods
    // ============================================================================

    /// TransformStreamError(stream, e)
    ///
    /// Spec: § 6.3.1 "Error both sides of the transform stream"
    pub fn errorStream(self: *TransformStream, e: common.JSValue) void {
        // Spec step 1: Perform ! ReadableStreamDefaultControllerError(stream.[[readable]].[[controller]], e)
        self.readableStream.controller.errorInternal(e.toWebIDL());

        // Spec step 2: Perform ! TransformStreamErrorWritableAndUnblockWrite(stream, e)
        self.errorWritableAndUnblockWrite(e);
    }

    /// TransformStreamErrorWritableAndUnblockWrite(stream, e)
    ///
    /// Spec: § 6.3.1 "Error writable side and unblock write"
    pub fn errorWritableAndUnblockWrite(self: *TransformStream, e: common.JSValue) void {
        // Spec step 1: Perform ! TransformStreamDefaultControllerClearAlgorithms(stream.[[controller]])
        self.controller.clearAlgorithms();

        // Spec step 2: Perform ! WritableStreamDefaultControllerErrorIfNeeded(stream.[[writable]].[[controller]], e)
        // Note: errorInternal checks if already errored
        self.writableStream.errorInternal(e);

        // Spec step 3: Perform ! TransformStreamUnblockWrite(stream)
        self.unblockWrite();
    }

    /// TransformStreamSetBackpressure(stream, backpressure)
    ///
    /// Spec: § 6.3.1 "Set backpressure signal"
    pub fn setBackpressure(self: *TransformStream, backpressure: bool) void {
        // Spec step 1: Assert: stream.[[backpressure]] is not backpressure
        std.debug.assert(self.backpressure != backpressure);

        // Spec step 2: If stream.[[backpressureChangePromise]] is not undefined,
        //              resolve stream.[[backpressureChangePromise]] with undefined
        if (self.backpressureChangePromise) |*promise| {
            if (promise.isPending()) {
                promise.fulfill({});
            }
        }

        // Spec step 3: Set stream.[[backpressureChangePromise]] to a new promise
        self.backpressureChangePromise = common.Promise(void).pending();

        // Spec step 4: Set stream.[[backpressure]] to backpressure
        self.backpressure = backpressure;
    }

    /// TransformStreamUnblockWrite(stream)
    ///
    /// Spec: § 6.3.1 "Unblock write if backpressure is true"
    pub fn unblockWrite(self: *TransformStream) void {
        // Spec step 1: If stream.[[backpressure]] is true, perform ! TransformStreamSetBackpressure(stream, false)
        if (self.backpressure) {
            self.setBackpressure(false);
        }
    }

    // ============================================================================
    // Default Sink Algorithms (Writable Side)
    // ============================================================================

    /// TransformStreamDefaultSinkWriteAlgorithm(stream, chunk)
    ///
    /// Spec: § 6.3.4 "Default sink write algorithm"
    pub fn defaultSinkWriteAlgorithm(self: *TransformStream, chunk: common.JSValue) common.Promise(void) {
        // Spec step 1: Assert: stream.[[writable]].[[state]] is "writable"
        // (Assertion - caller ensures this)

        // Spec step 2: Let controller be stream.[[controller]]
        const controller = self.controller;

        // Spec step 3: If stream.[[backpressure]] is true
        if (self.backpressure) {
            // Spec step 3.1: Let backpressureChangePromise be stream.[[backpressureChangePromise]]
            // Spec step 3.2: Assert: backpressureChangePromise is not undefined
            const backpressure_promise = self.backpressureChangePromise orelse {
                // Shouldn't happen per spec, but handle gracefully
                return controller.performTransform(chunk);
            };

            // Spec step 3.3: Return the result of reacting to backpressureChangePromise with fulfillment steps
            // Simplified: If promise is already fulfilled, proceed; otherwise return pending
            if (backpressure_promise.isFulfilled()) {
                // Spec step 3.3.1-3.3.5: Check state and perform transform
                // Simplified: directly perform transform
                return controller.performTransform(chunk);
            } else {
                // In full implementation, would chain promises
                // For now, return pending promise (simplified)
                return common.Promise(void).pending();
            }
        }

        // Spec step 4: Return ! TransformStreamDefaultControllerPerformTransform(controller, chunk)
        return controller.performTransform(chunk);
    }

    /// TransformStreamDefaultSinkAbortAlgorithm(stream, reason)
    ///
    /// Spec: § 6.3.4 "Default sink abort algorithm"
    pub fn defaultSinkAbortAlgorithm(self: *TransformStream, reason: ?common.JSValue) common.Promise(void) {
        // Spec step 1: Let controller be stream.[[controller]]
        const controller = self.controller;

        // Spec step 2: If controller.[[finishPromise]] is not undefined, return controller.[[finishPromise]]
        if (controller.finishPromise) |finish_promise| {
            return finish_promise;
        }

        // Spec step 3: Let readable be stream.[[readable]]
        const readable = self.readableStream;

        // Spec step 4: Set controller.[[finishPromise]] to a new promise
        controller.finishPromise = common.Promise(void).pending();

        // Spec step 5: Let cancelPromise be the result of performing controller.[[cancelAlgorithm]], passing reason
        const reason_val = reason orelse common.JSValue.undefined_value();
        const cancel_promise = controller.cancelAlgorithm.call(reason_val);

        // Spec step 6: Perform ! TransformStreamDefaultControllerClearAlgorithms(controller)
        controller.clearAlgorithms();

        // Spec step 7: React to cancelPromise (simplified)
        // In full implementation, would chain promises and handle readable state
        if (cancel_promise.isFulfilled()) {
            // Spec step 7.1: If readable.[[state]] is "errored", reject finishPromise
            if (readable.state == .errored) {
                if (controller.finishPromise) |*fp| {
                    fp.reject(webidl.errors.Exception.typeError(self.allocator, "Readable errored") catch return);
                }
            } else {
                // Spec step 7.2: Otherwise, error readable and resolve finishPromise
                readable.controller.errorInternal(reason_val.toWebIDL());
                if (controller.finishPromise) |*fp| {
                    fp.fulfill({});
                }
            }
        } else if (cancel_promise.isRejected()) {
            // Spec step 7.2: Handle rejection
            const err_exception = cancel_promise.error_value orelse webidl.errors.Exception.typeError(self.allocator, "Cancel failed") catch return controller.finishPromise orelse common.Promise(void).fulfilled({});
            const err_jsvalue = common.JSValue{ .string = err_exception.toString() };
            readable.controller.errorInternal(err_jsvalue.toWebIDL());
            if (controller.finishPromise) |*fp| {
                fp.reject(err_exception);
            }
        }

        // Spec step 8: Return controller.[[finishPromise]]
        return controller.finishPromise orelse common.Promise(void).fulfilled({});
    }

    /// TransformStreamDefaultSinkCloseAlgorithm(stream)
    ///
    /// Spec: § 6.3.4 "Default sink close algorithm"
    pub fn defaultSinkCloseAlgorithm(self: *TransformStream) common.Promise(void) {
        // Spec step 1: Let controller be stream.[[controller]]
        const controller = self.controller;

        // Spec step 2: If controller.[[finishPromise]] is not undefined, return controller.[[finishPromise]]
        if (controller.finishPromise) |finish_promise| {
            return finish_promise;
        }

        // Spec step 3: Let readable be stream.[[readable]]
        const readable = self.readableStream;

        // Spec step 4: Set controller.[[finishPromise]] to a new promise
        controller.finishPromise = common.Promise(void).pending();

        // Spec step 5: Let flushPromise be the result of performing controller.[[flushAlgorithm]]
        const flush_promise = controller.flushAlgorithm.call();

        // Spec step 6: Perform ! TransformStreamDefaultControllerClearAlgorithms(controller)
        controller.clearAlgorithms();

        // Spec step 7: React to flushPromise
        if (flush_promise.isFulfilled()) {
            // Spec step 7.1: If readable.[[state]] is "errored", reject finishPromise
            if (readable.state == .errored) {
                if (controller.finishPromise) |*fp| {
                    fp.reject(webidl.errors.Exception.typeError(self.allocator, "Readable errored") catch return);
                }
            } else {
                // Spec step 7.2: Otherwise, close readable and resolve finishPromise
                readable.controller.closeInternal();
                if (controller.finishPromise) |*fp| {
                    fp.fulfill({});
                }
            }
        } else if (flush_promise.isRejected()) {
            // Spec step 7.2: Handle rejection
            const err = flush_promise.error_value orelse common.JSValue{ .string = "Flush failed" };
            readable.controller.errorInternal(err.toWebIDL());
            if (controller.finishPromise) |*fp| {
                fp.reject(err);
            }
        }

        // Spec step 8: Return controller.[[finishPromise]]
        return controller.finishPromise orelse common.Promise(void).fulfilled({});
    }

    // ============================================================================
    // Default Source Algorithms (Readable Side)
    // ============================================================================

    /// TransformStreamDefaultSourcePullAlgorithm(stream)
    ///
    /// Spec: § 6.3.5 "Default source pull algorithm"
    pub fn defaultSourcePullAlgorithm(self: *TransformStream) common.Promise(void) {
        // Spec step 1: Assert: stream.[[backpressure]] is true
        std.debug.assert(self.backpressure);

        // Spec step 2: Assert: stream.[[backpressureChangePromise]] is not undefined
        // (Simplified - we don't track backpressureChangePromise yet)

        // Spec step 3: Perform ! TransformStreamSetBackpressure(stream, false)
        self.setBackpressure(false);

        // Spec step 4: Return stream.[[backpressureChangePromise]]
        // For now, return fulfilled promise (simplified)
        return common.Promise(void).fulfilled({});
    }

    /// TransformStreamDefaultSourceCancelAlgorithm(stream, reason)
    ///
    /// Spec: § 6.3.5 "Default source cancel algorithm"
    pub fn defaultSourceCancelAlgorithm(self: *TransformStream, reason: ?common.JSValue) common.Promise(void) {
        // Spec step 1: Let controller be stream.[[controller]]
        const controller = self.controller;

        // Spec step 2: If controller.[[finishPromise]] is not undefined, return controller.[[finishPromise]]
        if (controller.finishPromise) |finish_promise| {
            return finish_promise;
        }

        // Spec step 3: Let writable be stream.[[writable]]
        const writable = self.writableStream;

        // Spec step 4: Set controller.[[finishPromise]] to a new promise
        controller.finishPromise = common.Promise(void).pending();

        // Spec step 5: Let cancelPromise be the result of performing controller.[[cancelAlgorithm]], passing reason
        const reason_val = reason orelse common.JSValue.undefined_value();
        const cancel_promise = controller.cancelAlgorithm.call(reason_val);

        // Spec step 6: Perform ! TransformStreamDefaultControllerClearAlgorithms(controller)
        controller.clearAlgorithms();

        // Spec step 7: React to cancelPromise
        if (cancel_promise.isFulfilled()) {
            // Spec step 7.1: If writable.[[state]] is "errored", reject finishPromise
            if (writable.state == .errored) {
                if (controller.finishPromise) |*fp| {
                    fp.reject(webidl.errors.Exception.typeError(self.allocator, "Writable errored") catch return);
                }
            } else {
                // Spec step 7.2: Otherwise, error writable, unblock, and resolve finishPromise
                writable.controller.errorIfNeeded(reason_val);
                self.unblockWrite();
                if (controller.finishPromise) |*fp| {
                    fp.fulfill({});
                }
            }
        } else if (cancel_promise.isRejected()) {
            // Spec step 7.2: Handle rejection
            const err_exception = cancel_promise.error_value orelse webidl.errors.Exception.typeError(self.allocator, "Cancel failed") catch return controller.finishPromise orelse common.Promise(void).fulfilled({});
            const err_jsvalue = common.JSValue{ .string = err_exception.toString() };
            writable.controller.errorIfNeeded(err_jsvalue);
            self.unblockWrite();
            if (controller.finishPromise) |*fp| {
                fp.reject(err_exception);
            }
        }

        // Spec step 8: Return controller.[[finishPromise]]
        return controller.finishPromise orelse common.Promise(void).fulfilled({});
    }
}, .{
    .exposed = &.{.global},
    .transferable = true,
});
