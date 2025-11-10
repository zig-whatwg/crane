//! WritableStreamDefaultController class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#ws-default-controller-class
//!
//! Controls a WritableStream's state and internal queue.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const QueueWithSizes = @import("queue_with_sizes").QueueWithSizes;
const eventLoop = @import("event_loop");
const AsyncPromise = @import("async_promise").AsyncPromise;

pub const WritableStreamDefaultController = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[abortAlgorithm]]: Promise-returning algorithm for abort
    abortAlgorithm: common.AbortAlgorithm,

    /// [[closeAlgorithm]]: Promise-returning algorithm for close
    closeAlgorithm: common.CloseAlgorithm,

    /// [[queue]]: Queue-with-sizes for internal chunk queue
    queue: QueueWithSizes,

    /// [[started]]: boolean - underlying sink has finished starting
    started: bool,

    /// [[strategyHWM]]: High water mark for backpressure
    strategyHwm: f64,

    /// [[strategySizeAlgorithm]]: Algorithm to calculate chunk size
    strategySizeAlgorithm: common.SizeAlgorithm,

    /// [[stream]]: The WritableStream instance controlled
    stream: ?*anyopaque,

    /// [[writeAlgorithm]]: Promise-returning algorithm for write
    writeAlgorithm: common.WriteAlgorithm,

    /// Event loop for async operations
    eventLoop: eventLoop.EventLoop,

    pub fn init(
        allocator: std.mem.Allocator,
        abortAlgorithm: common.AbortAlgorithm,
        closeAlgorithm: common.CloseAlgorithm,
        writeAlgorithm: common.WriteAlgorithm,
        strategyHwm: f64,
        strategySizeAlgorithm: common.SizeAlgorithm,
        loop: eventLoop.EventLoop,
    ) WritableStreamDefaultController {
        return .{
            .allocator = allocator,
            .abortAlgorithm = abortAlgorithm,
            .closeAlgorithm = closeAlgorithm,
            .queue = QueueWithSizes.init(allocator),
            .started = false,
            .strategyHwm = strategyHwm,
            .strategySizeAlgorithm = strategySizeAlgorithm,
            .stream = null,
            .writeAlgorithm = writeAlgorithm,
            .eventLoop = loop,
        };
    }

    pub fn deinit(self: *WritableStreamDefaultController) void {
        self.queue.deinit();
    }

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn errorStream(self: *WritableStreamDefaultController, e: ?webidl.JSValue) void {
        const error_value = if (e) |err| common.JSValue.fromWebIDL(err) else common.JSValue.undefined_value();
        self.errorInternal(error_value);
    }

    // ============================================================================
    // Internal Algorithms
    // ============================================================================

    fn errorInternal(self: *WritableStreamDefaultController, error_value: common.JSValue) void {
        _ = error_value;
        self.clearAlgorithms();
    }

    fn clearAlgorithms(self: *WritableStreamDefaultController) void {
        self.abortAlgorithm = common.defaultAbortAlgorithm();
        self.closeAlgorithm = common.defaultCloseAlgorithm();
        self.writeAlgorithm = common.defaultWriteAlgorithm();
        self.strategySizeAlgorithm = common.defaultSizeAlgorithm();
    }

    pub fn abortSteps(self: *WritableStreamDefaultController, reason: ?common.JSValue) !*AsyncPromise(void) {
        const result = self.abortAlgorithm.call(reason);
        self.clearAlgorithms();

        const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
        if (result.isFulfilled()) {
            promise.fulfill({});
        } else if (result.isRejected()) {
            promise.reject(result.error_value orelse common.JSValue{ .string = "Abort failed" });
        }
        return promise;
    }

    pub fn calculateDesiredSize(self: *const WritableStreamDefaultController) ?f64 {
        return self.strategyHwm - self.queue.queue_total_size;
    }
}, .{
    .exposed = &.{.all},
});
