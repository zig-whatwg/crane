//! ReadableByteStreamController class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#rbs-controller-class
//!
//! Controls a readable byte stream for zero-copy operations.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const eventLoop = @import("eventLoop");
const QueueWithSizes = @import("queue_with_sizes").QueueWithSizes;

pub const ReadableByteStreamController = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[cancelAlgorithm]]: Algorithm for cancelation
    cancelAlgorithm: common.CancelAlgorithm,

    /// [[closeRequested]]: boolean
    closeRequested: bool,

    /// [[pullAlgorithm]]: Algorithm for pulling data
    pullAlgorithm: common.PullAlgorithm,

    /// [[pulling]]: boolean
    pulling: bool,

    /// [[queue]]: Queue-with-sizes
    queue: QueueWithSizes,

    /// [[started]]: boolean
    started: bool,

    /// [[strategyHWM]]: High water mark
    strategyHwm: f64,

    /// [[stream]]: The ReadableStream
    stream: ?*anyopaque,

    /// Event loop
    eventLoop: eventLoop.EventLoop,

    pub fn init(
        allocator: std.mem.Allocator,
        cancelAlgorithm: common.CancelAlgorithm,
        pullAlgorithm: common.PullAlgorithm,
        strategyHwm: f64,
        loop: eventLoop.EventLoop,
    ) ReadableByteStreamController {
        return .{
            .allocator = allocator,
            .cancelAlgorithm = cancelAlgorithm,
            .closeRequested = false,
            .pullAlgorithm = pullAlgorithm,
            .pulling = false,
            .queue = QueueWithSizes.init(allocator),
            .started = false,
            .strategyHwm = strategyHwm,
            .stream = null,
            .eventLoop = loop,
        };
    }

    pub fn deinit(self: *ReadableByteStreamController) void {
        self.queue.deinit();
    }

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn desiredSize(self: *const ReadableByteStreamController) ?f64 {
        return self.strategyHwm - self.queue.queueTotalSize;
    }

    pub fn close(self: *ReadableByteStreamController) !void {
        if (self.closeRequested) {
            return error.AlreadyClosing;
        }
        self.closeRequested = true;
    }

    pub fn enqueue(self: *ReadableByteStreamController, chunk: ?webidl.JSValue) !void {
        _ = self;
        _ = chunk;
        // Enqueue byte chunk
    }

    pub fn errorStream(self: *ReadableByteStreamController, e: ?webidl.JSValue) void {
        _ = self;
        _ = e;
        // Error the stream
    }
});
