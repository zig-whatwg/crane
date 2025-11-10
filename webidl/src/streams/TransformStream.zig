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

        // Spec step 5-8: Extract high water marks and size algorithms
        // TODO: Use these for proper stream initialization
        _ = try dict_parsing.parseQueuingStrategy(allocator, readableStrategy);
        // const readable_hwm = readable_strategy_dict.high_water_mark orelse 0.0;

        _ = try dict_parsing.parseQueuingStrategy(allocator, writableStrategy);
        // const writable_hwm = writable_strategy_dict.high_water_mark orelse 1.0;

        // Spec step 9: Let startPromise be a new promise
        // (We'll use a simplified synchronous initialization for now)

        // Spec step 10-11: Initialize transform stream and set up controller
        // For now, we create a simple pass-through transform stream

        const readable_stream = try allocator.create(ReadableStream);
        errdefer allocator.destroy(readable_stream);
        readable_stream.* = try ReadableStream.init(allocator);

        const writable_stream = try allocator.create(WritableStream);
        errdefer allocator.destroy(writable_stream);
        writable_stream.* = try WritableStream.init(allocator);

        // Create controller with extracted algorithms
        const ctrl = try allocator.create(TransformStreamDefaultController);
        errdefer allocator.destroy(ctrl);

        // Use default algorithms for now
        // TODO: Extract transform/flush/cancel from transformer_dict
        ctrl.* = TransformStreamDefaultController.init(
            allocator,
            common.defaultTransformAlgorithm(),
            common.defaultFlushAlgorithm(),
            common.defaultCancelAlgorithm(),
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

        // Spec step 12-13: Call start() if it exists
        // TODO: Invoke transformer_dict.start with controller
        // TODO: Use readable_hwm and writable_hwm for stream initialization

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
