//! WHATWG Fetch Standard - Fetch Params
//!
//! Fetch params is bookkeeping for the fetch algorithm.
//!
//! Spec: https://fetch.spec.whatwg.org/#fetch-params

const std = @import("std");
const Allocator = std.mem.Allocator;
const fetch_timing = @import("fetch_timing.zig");
const FetchTimingInfo = fetch_timing.FetchTimingInfo;
const fetch_controller = @import("fetch_controller.zig");
const FetchController = fetch_controller.FetchController;
const request_mod = @import("request.zig");
const InternalRequest = request_mod.InternalRequest;
const response_mod = @import("response.zig");
const InternalResponse = response_mod.InternalResponse;
const networkError = response_mod.networkError;
const abortedNetworkError = response_mod.abortedNetworkError;

// =============================================================================
// Task Destination
// =============================================================================

/// Parallel queue for task execution.
/// Note: This is a simplified stub. Real implementation would use thread pool.
pub const ParallelQueue = struct {
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) !*Self {
        const queue = try allocator.create(Self);
        queue.* = .{ .allocator = allocator };
        return queue;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    /// Enqueue a task for execution.
    pub fn enqueue(self: *Self, task: *const fn () void) void {
        _ = self;
        // In a real implementation, this would queue the task
        // For now, execute immediately (synchronous)
        task();
    }
};

/// Task destination for queuing fetch tasks.
///
/// Spec: "A task destination is either null, a global object, or a parallel queue."
pub const TaskDestination = union(enum) {
    /// No destination (null).
    none,
    /// A global object (for task queuing in event loop).
    global_object: *anyopaque,
    /// A parallel queue (for parallel execution).
    parallel_queue: *ParallelQueue,
};

/// Queue a fetch task to the given task destination.
///
/// Spec: "To queue a fetch task, given an algorithm algorithm and a task destination
/// taskDestination, queue a task on the networking task source to run algorithm,
/// with the task's document equal to taskDestination if it is a global object."
pub fn queueFetchTask(
    algorithm: *const fn () void,
    task_destination: TaskDestination,
) void {
    switch (task_destination) {
        .none => {
            // No destination - execute immediately
            algorithm();
        },
        .global_object => {
            // In a real implementation, queue to event loop
            // For now, execute immediately
            algorithm();
        },
        .parallel_queue => |queue| {
            queue.enqueue(algorithm);
        },
    }
}

// =============================================================================
// Fetch Params
// =============================================================================

/// Fetch params is bookkeeping for the fetch algorithm.
///
/// Spec: https://fetch.spec.whatwg.org/#fetch-params
pub const FetchParams = struct {
    allocator: Allocator,

    /// The request being fetched.
    /// Spec: "A fetch params has an associated request (a request)."
    request: *InternalRequest,

    /// Callback: process request body chunk length.
    /// Spec: "A fetch params has an associated process request body chunk length
    /// (default null), which is null or an algorithm accepting a bytesLength."
    process_request_body_chunk_length: ?ProcessRequestBodyChunkLengthFn = null,

    /// Callback: process request end-of-body.
    /// Spec: "A fetch params has an associated process request end-of-body
    /// (default null), which is null or an algorithm accepting nothing."
    process_request_end_of_body: ?ProcessRequestEndOfBodyFn = null,

    /// Callback: process early hints response (103).
    /// Spec: "A fetch params has an associated process early hints response
    /// (default null), which is null or an algorithm accepting a response."
    process_early_hints_response: ?ProcessEarlyHintsResponseFn = null,

    /// Callback: process response.
    /// Spec: "A fetch params has an associated process response (default null),
    /// which is null or an algorithm accepting a response."
    process_response: ?ProcessResponseFn = null,

    /// Callback: process response end-of-body.
    /// Spec: "A fetch params has an associated process response end-of-body
    /// (default null), which is null or an algorithm accepting a response."
    process_response_end_of_body: ?ProcessResponseEndOfBodyFn = null,

    /// Callback: process response consume body.
    /// Spec: "A fetch params has an associated process response consume body
    /// (default null), which is null or an algorithm accepting a response
    /// and null, failure, or a byte sequence."
    process_response_consume_body: ?ProcessResponseConsumeBodyFn = null,

    /// Callback: process response body chunk (for streaming/progress).
    /// Extension for XHR: Called when a chunk of the response body is received.
    /// This enables progress events during download.
    process_response_body_chunk: ?ProcessResponseBodyChunkFn = null,

    /// Task destination.
    /// Spec: "A fetch params has an associated task destination (default null),
    /// which is null, a global object, or a parallel queue."
    task_destination: TaskDestination = .none,

    /// Cross-origin isolated capability.
    /// Spec: "A fetch params has an associated cross-origin isolated capability
    /// (default false), which is a boolean."
    cross_origin_isolated_capability: bool = false,

    /// Fetch controller.
    /// Spec: "A fetch params has an associated controller (a fetch controller)."
    controller: *FetchController,

    /// Timing info.
    /// Spec: "A fetch params has an associated timing info (a fetch timing info)."
    timing_info: *FetchTimingInfo,

    /// Preloaded response candidate.
    /// Spec: "A fetch params has an associated preloaded response candidate
    /// (default null), which is null, 'pending', or a response."
    preloaded_response_candidate: PreloadedResponseCandidate = .none,

    const Self = @This();

    // === Callback Types ===

    /// Process request body chunk length callback.
    pub const ProcessRequestBodyChunkLengthFn = *const fn (bytes_length: u64) void;

    /// Process request end-of-body callback.
    pub const ProcessRequestEndOfBodyFn = *const fn () void;

    /// Process early hints response callback.
    pub const ProcessEarlyHintsResponseFn = *const fn (response: *InternalResponse) void;

    /// Process response callback.
    pub const ProcessResponseFn = *const fn (response: *InternalResponse) void;

    /// Process response end-of-body callback.
    pub const ProcessResponseEndOfBodyFn = *const fn (response: *InternalResponse) void;

    /// Process response consume body callback.
    /// The body_result is null (no body), failure marker, or body bytes.
    pub const ProcessResponseConsumeBodyFn = *const fn (response: *InternalResponse, body_result: ?BodyResult) void;

    /// Process response body chunk callback (for streaming/progress).
    /// Extension for XHR: Called when a chunk of response body bytes is received.
    pub const ProcessResponseBodyChunkFn = *const fn (chunk: []const u8) void;

    /// Body result for consume body callback.
    pub const BodyResult = union(enum) {
        /// Successfully consumed body bytes.
        bytes: []const u8,
        /// Body consumption failed.
        failure,
    };

    /// Preloaded response candidate.
    pub const PreloadedResponseCandidate = union(enum) {
        /// No preloaded response.
        none,
        /// Preload is pending.
        pending,
        /// Preloaded response is available.
        response: *InternalResponse,
    };

    // === Initialization ===

    /// Initialize new fetch params.
    pub fn init(
        allocator: Allocator,
        request: *InternalRequest,
        controller: *FetchController,
        timing_info: *FetchTimingInfo,
    ) !*Self {
        const params = try allocator.create(Self);
        params.* = .{
            .allocator = allocator,
            .request = request,
            .controller = controller,
            .timing_info = timing_info,
        };
        return params;
    }

    /// Deinitialize fetch params.
    /// Note: Does NOT free the request, controller, or timing_info as they may be shared.
    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    // === State Checks ===

    /// Check if fetch params is aborted.
    ///
    /// Spec: "A fetch params is aborted if its controller's state is 'aborted'."
    pub fn isAborted(self: *const Self) bool {
        return self.controller.isAborted();
    }

    /// Check if fetch params is canceled.
    ///
    /// Spec: "A fetch params is canceled if its controller's state is
    /// 'aborted' or 'terminated'."
    pub fn isCanceled(self: *const Self) bool {
        return self.controller.isCanceled();
    }

    // === Callback Invocation ===

    /// Invoke process request body chunk length callback if set.
    pub fn processRequestBodyChunkLength(self: *Self, bytes_length: u64) void {
        if (self.process_request_body_chunk_length) |callback| {
            callback(bytes_length);
        }
    }

    /// Invoke process request end-of-body callback if set.
    pub fn processRequestEndOfBody(self: *Self) void {
        if (self.process_request_end_of_body) |callback| {
            callback();
        }
    }

    /// Invoke process early hints response callback if set.
    pub fn processEarlyHintsResponse(self: *Self, response: *InternalResponse) void {
        if (self.process_early_hints_response) |callback| {
            callback(response);
        }
    }

    /// Invoke process response callback if set.
    pub fn processResponse(self: *Self, response: *InternalResponse) void {
        if (self.process_response) |callback| {
            callback(response);
        }
    }

    /// Invoke process response end-of-body callback if set.
    pub fn processResponseEndOfBody(self: *Self, response: *InternalResponse) void {
        if (self.process_response_end_of_body) |callback| {
            callback(response);
        }
    }

    /// Invoke process response consume body callback if set.
    pub fn processResponseConsumeBody(self: *Self, response: *InternalResponse, body_result: ?BodyResult) void {
        if (self.process_response_consume_body) |callback| {
            callback(response, body_result);
        }
    }

    /// Invoke process response body chunk callback if set.
    pub fn processResponseBodyChunk(self: *Self, chunk: []const u8) void {
        if (self.process_response_body_chunk) |callback| {
            callback(chunk);
        }
    }
};

// =============================================================================
// Tests
// =============================================================================
// Create Appropriate Network Error
// =============================================================================

/// Create the appropriate network error given fetch params.
///
/// Spec: To create the appropriate network error given fetch params fetchParams:
/// 1. Assert: fetchParams is canceled.
/// 2. Return an aborted network error if fetchParams is aborted; otherwise a network error.
pub fn createAppropriateNetworkError(
    allocator: Allocator,
    fetch_params: *FetchParams,
) !*InternalResponse {
    // 1. Assert fetchParams is canceled
    std.debug.assert(fetch_params.isCanceled());

    // 2. Return appropriate error type
    if (fetch_params.isAborted()) {
        return try abortedNetworkError(allocator);
    } else {
        return try networkError(allocator);
    }
}

// =============================================================================
// Tests
// =============================================================================

test "FetchParams.init creates params" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();

    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    try std.testing.expectEqual(request, params.request);
    try std.testing.expectEqual(controller, params.controller);
    try std.testing.expectEqual(&timing, params.timing_info);
    try std.testing.expectEqual(false, params.cross_origin_isolated_capability);
}

test "FetchParams.isAborted checks controller" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();

    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    try std.testing.expect(!params.isAborted());
    try std.testing.expect(!params.isCanceled());

    try controller.abort(null);

    try std.testing.expect(params.isAborted());
    try std.testing.expect(params.isCanceled());
}

test "FetchParams.isCanceled for terminated" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();

    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    controller.terminate();

    try std.testing.expect(!params.isAborted());
    try std.testing.expect(params.isCanceled());
}

var chunk_length_received: u64 = 0;

fn testProcessChunkLength(bytes_length: u64) void {
    chunk_length_received = bytes_length;
}

test "FetchParams.processRequestBodyChunkLength callback" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();

    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    chunk_length_received = 0;
    params.process_request_body_chunk_length = testProcessChunkLength;
    params.processRequestBodyChunkLength(42);

    try std.testing.expectEqual(@as(u64, 42), chunk_length_received);
}

test "createAppropriateNetworkError for aborted" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();

    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    try controller.abort(null);

    const err = try createAppropriateNetworkError(allocator, params);
    defer err.deinit();

    try std.testing.expect(err.aborted);
    try std.testing.expectEqual(response_mod.ResponseType.@"error", err.response_type);
}

test "createAppropriateNetworkError for terminated" {
    const allocator = std.testing.allocator;

    const request = try InternalRequest.init(allocator, "https://example.com");
    defer request.deinit();

    const controller = try FetchController.init(allocator);
    defer controller.deinit();

    var timing = FetchTimingInfo.init(allocator);
    defer timing.deinit();

    const params = try FetchParams.init(allocator, request, controller, &timing);
    defer params.deinit();

    controller.terminate();

    const err = try createAppropriateNetworkError(allocator, params);
    defer err.deinit();

    try std.testing.expect(!err.aborted);
    try std.testing.expectEqual(response_mod.ResponseType.@"error", err.response_type);
}

var queue_task_executed = false;

fn testQueueCallback() void {
    queue_task_executed = true;
}

test "queueFetchTask with none destination" {
    queue_task_executed = false;
    queueFetchTask(testQueueCallback, .none);
    try std.testing.expect(queue_task_executed);
}

test "ParallelQueue.init and deinit" {
    const allocator = std.testing.allocator;

    const queue = try ParallelQueue.init(allocator);
    defer queue.deinit();

    // Verify queue was created
    try std.testing.expect(queue.allocator.ptr == allocator.ptr);
}

test "TaskDestination union" {
    const allocator = std.testing.allocator;

    // Test none
    const dest_none: TaskDestination = .none;
    try std.testing.expectEqual(TaskDestination.none, dest_none);

    // Test global_object
    var dummy: u8 = 0;
    const dest_global = TaskDestination{ .global_object = &dummy };
    switch (dest_global) {
        .global_object => |ptr| try std.testing.expectEqual(&dummy, @as(*u8, @ptrCast(@alignCast(ptr)))),
        else => return error.UnexpectedValue,
    }

    // Test parallel_queue
    const queue = try ParallelQueue.init(allocator);
    defer queue.deinit();

    const dest_queue = TaskDestination{ .parallel_queue = queue };
    switch (dest_queue) {
        .parallel_queue => |q| try std.testing.expectEqual(queue, q),
        else => return error.UnexpectedValue,
    }
}
