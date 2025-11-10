//! TransformStream class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#ts-class
//!
//! Represents a transformation that consists of a pair of streams.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const dict_parsing = @import("dict_parsing");
const ReadableStream = @import("readable_stream").ReadableStream;
const WritableStream = @import("writable_stream").WritableStream;
const TransformStreamDefaultController = @import("transform_stream_default_controller").TransformStreamDefaultController;

pub const TransformStream = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[backpressure]]: boolean - whether backpressure signal has been sent
    backpressure: bool,

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
            .readableStream = readable_stream,
            .writableStream = writable_stream,
            .controller = ctrl,
        };

        ctrl.stream = @ptrCast(&stream);
        readable_stream.controller.stream = @ptrCast(readable_stream);
        writable_stream.controller.stream = @ptrCast(writable_stream);

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
        self.readableStream.controller.errorInternal(e);

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
        // (We allow setting to same value for simplicity)

        // Spec step 4: Set stream.[[backpressure]] to backpressure
        self.backpressure = backpressure;

        // Note: Full implementation would handle backpressureChangePromise
        // For now, we just set the flag
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
}, .{
    .exposed = &.{.global},
    .transferable = true,
});
