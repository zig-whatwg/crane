//! WritableStreamDefaultController Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#ws-default-controller-class
//!
//! Controller that allows control of a WritableStream's state and queue.

const std = @import("std");
const runtime = @import("runtime");
const v8_engine = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WritableStreamDefaultController = interfaces.WritableStreamDefaultController;

// Import streams infrastructure
const queue_with_sizes = @import("streams_queue");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

pub const State = WritableStreamDefaultController.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
    InvalidState,
};

/// Queue value type - can be a chunk or the close sentinel
///
/// Spec: § 9.2.1 "Value container" - stores value with its calculated size
pub const QueueValue = union(enum) {
    /// A chunk with its calculated size (from strategy.size algorithm)
    chunk: struct {
        value: *anyopaque,
        size: f64,
    },
    close_sentinel: void,
};

/// Internal state for WritableStreamDefaultController
///
/// This mirrors the internal slots defined in WHATWG Streams spec § 4.5.4
///
/// ## V8 Handle Lifetime
///
/// Callbacks (write, close, abort, start, size) are stored as V8 Global handles
/// to survive HandleScope destruction. When JavaScript code like
/// `new WritableStream({ start: fn, write: fn })` executes, the callbacks are
/// extracted as Local<Value> handles. Without Global handles, these become
/// dangling pointers when the constructor's HandleScope ends.
///
/// See: src/runtime/engines/v8/global_handles.zig for implementation details.
pub const InternalState = struct {
    /// [[stream]]: WritableStream instance this controller controls
    stream: ?*runtime.Instance,

    /// [[writeAlgorithm]]: Underlying sink write callback (V8 Global handle)
    write_algorithm: v8_engine.OptionalGlobalHandle,

    /// [[closeAlgorithm]]: Underlying sink close callback (V8 Global handle)
    close_algorithm: v8_engine.OptionalGlobalHandle,

    /// [[abortAlgorithm]]: Underlying sink abort callback (V8 Global handle)
    abort_algorithm: v8_engine.OptionalGlobalHandle,

    /// [[startAlgorithm]]: Underlying sink start callback (V8 Global handle)
    /// Stored for deferred invocation. Set to null after invocation.
    start_algorithm: v8_engine.OptionalGlobalHandle,

    /// [[strategyHWM]]: High water mark for backpressure
    strategy_hwm: f64,

    /// [[strategySizeAlgorithm]]: Function to compute chunk size (V8 Global handle)
    strategy_size_algorithm: v8_engine.OptionalGlobalHandle,

    /// V8 isolate (if running in V8 context) - for invoking callbacks
    isolate: ?*v8_engine.ffi.Isolate,

    /// V8 context (if running in V8 context) - for invoking callbacks
    v8_context: ?*anyopaque,

    /// [[started]]: Whether start algorithm has completed
    started: bool,

    /// [[queue]]: Internal queue of chunks (list of QueueValue)
    queue: std.ArrayList(QueueValue),

    /// [[queueTotalSize]]: Total size of all chunks in queue
    queue_total_size: f64,

    /// [[abortController]]: AbortController for canceling operations
    /// Future: Create proper AbortController instance
    abort_controller: ?*runtime.Instance,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Dispose V8 Global handles to prevent memory leaks
        v8_engine.disposeOptionalGlobalHandle(&self.write_algorithm);
        v8_engine.disposeOptionalGlobalHandle(&self.close_algorithm);
        v8_engine.disposeOptionalGlobalHandle(&self.abort_algorithm);
        v8_engine.disposeOptionalGlobalHandle(&self.start_algorithm);
        v8_engine.disposeOptionalGlobalHandle(&self.strategy_size_algorithm);

        // Clean up queue
        self.queue.deinit(allocator);
        allocator.destroy(self);
    }
};

// ============================================================================
// Promise Callback Context and Handlers
// ============================================================================

/// Context for write promise callbacks
///
/// Stores references needed by the V8 callback to complete the write operation.
const WriteCallbackContext = struct {
    controller: *runtime.Instance,
    stream: *runtime.Instance,
    allocator: std.mem.Allocator,
};

/// Context for close promise callbacks
const CloseCallbackContext = struct {
    stream: *runtime.Instance,
    allocator: std.mem.Allocator,
};

/// Callback invoked when write promise is fulfilled
///
/// V8 calls this when the underlying sink's write() promise resolves.
fn onWriteFulfilled(ctx_ptr: *anyopaque) void {
    const ctx: *WriteCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    writableStreamDefaultControllerFinishWrite(ctx.controller, ctx.stream);
    // Clean up context
    ctx.allocator.destroy(ctx);
}

/// Callback invoked when write promise is rejected
///
/// V8 calls this when the underlying sink's write() promise rejects.
fn onWriteRejected(ctx_ptr: *anyopaque, _: *v8_engine.ffi.Value) void {
    const ctx: *WriteCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    writableStreamDefaultControllerError(ctx.controller, ctx.stream);
    // Clean up context
    ctx.allocator.destroy(ctx);
}

/// Callback invoked when close promise is fulfilled
fn onCloseFulfilled(ctx_ptr: *anyopaque) void {
    const ctx: *CloseCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    writableStreamDefaultControllerFinishClose(ctx.stream);
    // Clean up context
    ctx.allocator.destroy(ctx);
}

/// Callback invoked when close promise is rejected
fn onCloseRejected(ctx_ptr: *anyopaque, _: *v8_engine.ffi.Value) void {
    const ctx: *CloseCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    // On close rejection, error the stream
    const stream_state = ctx.stream.getState(interfaces.WritableStream.State);
    if (stream_state.own._internal) |stream_internal| {
        // Mark close request as rejected
        if (stream_internal.in_flight_close_request) |close_req| {
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = "Close algorithm rejected",
                },
            };
            close_req.reject(exception);
        }
        stream_internal.in_flight_close_request = null;
        stream_internal.state = .errored;
    }
    // Clean up context
    ctx.allocator.destroy(ctx);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // InternalState is set up by SetUpWritableStreamDefaultController
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for signal
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-signal
/// Returns: An AbortSignal that can be used to abort pending write/close operations
///
/// NOTE: This returns the AbortSignal associated with the controller's AbortController.
/// Per spec, the signal should be created when the controller is set up.
pub fn get_signal(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Return the AbortSignal from the AbortController
    // Per spec, the controller's [[abortController]] should always exist
    // and we return abortController.[[signal]] (use interface per Golden Rule #13)
    if (internal.abort_controller) |abort_controller| {
        // Get the signal from the AbortController
        return interfaces.AbortController.get_signal(abort_controller);
    }

    // If no abort controller is set, this is an implementation error
    // The abort controller should be created during controller setup
    return error.InvalidState;
}

/// Operation: error
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-error
/// Arguments:
///   e: Error to error the stream with (optional, defaults to undefined)
///
/// Steps:
/// 1. Let state = this.[[stream]].[[state]]
/// 2. If state is not "writable", return
/// 3. Perform WritableStreamDefaultControllerError(this, e)
pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(runtime.JSValue)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Get the stream
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // 1. Let state = this.[[stream]].[[state]]
    const current_state = stream_internal.state;

    // 2. If state is not "writable", return
    if (current_state != .writable) {
        return;
    }

    // 3. Perform WritableStreamDefaultControllerError(this, e)
    // Unwrap the Opt - use a default error value if not passed
    const default_error: u8 = 0;
    const error_ptr: *const anyopaque = if (e.was_passed) e.value else @ptrCast(&default_error);
    writableStreamDefaultControllerError(instance, error_ptr);
}

// ============================================================================
// Abstract Operations
// ============================================================================

/// WritableStreamDefaultControllerError
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-error
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   error_value: Error to error the stream with
///
/// Steps per spec - simplified for now
fn writableStreamDefaultControllerError(controller: *runtime.Instance, error_value: *const anyopaque) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    // Get the stream
    const stream = internal.stream orelse return;

    // For now, just mark stream as errored
    // Future: Implement full WritableStreamStartErroring algorithm
    const stream_state = stream.getState(interfaces.WritableStream.State);
    if (stream_state.own._internal) |stream_internal| {
        stream_internal.state = .errored;
        stream_internal.stored_error.storeRawPtr(@constCast(error_value));
    }
}

/// ResetQueue - Clear the controller's queue
///
/// Spec: https://streams.spec.whatwg.org/#reset-queue
fn resetQueue(controller: *runtime.Instance) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    internal.queue.clearRetainingCapacity();
    internal.queue_total_size = 0.0;
}

// ============================================================================
// Internal Methods (called by WritableStream)
// ============================================================================

/// WritableStreamDefaultControllerWrite - Queue a write operation
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-write
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   chunk: The chunk to write
///   chunk_size: Size of the chunk
/// Returns: Promise that resolves when write completes
///
/// Steps:
/// 1. Let writeAlgorithm be this.[[writeAlgorithm]]
/// 2. Let writeRecord be a new write record with chunk and a new promise
/// 3. Enqueue writeRecord to this.[[queue]]
/// 4. Let stream be this.[[stream]]
/// 5. If WritableStreamCloseQueuedOrInFlight(stream) is false and stream.[[state]] is "writable",
///    perform WritableStreamDefaultControllerAdvanceQueueIfNeeded(this)
/// 6. Return writeRecord's promise
pub fn write(controller: *runtime.Instance, chunk: *const anyopaque, chunk_size_param: f64) !*AsyncPromise(void) {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Import modules
    const write_request = @import("streams_write_request");
    const common = @import("streams_common");

    // 1. Get stream to access event loop
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // 2. Calculate actual chunk size using strategy size algorithm
    const chunk_size = if (internal.strategy_size_algorithm) |size_global| blk: {
        // Check if we have V8 context (runtime mode)
        if (internal.isolate) |isolate| {
            // Get Local from Global handle for this invocation
            const size_value = size_global.get(isolate) orelse break :blk chunk_size_param;

            // Verify it's a function
            if (!v8_engine.ffi.v8_Value_IsFunction(size_value)) {
                break :blk chunk_size_param;
            }
            const size_function: *v8_engine.ffi.Function = @ptrCast(size_value);

            const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(internal.v8_context.?));

            // Convert chunk to V8 Value
            const chunk_v8 = v8_engine.conversions.chunkToV8Value(
                chunk,
                isolate,
                v8_context,
            ) catch break :blk chunk_size_param;

            // Invoke size_algorithm(chunk) → number
            const size_result = v8_engine.streams_callbacks.invokeSizeAlgorithm(
                isolate,
                v8_context,
                size_function,
                chunk_v8,
            ) catch break :blk chunk_size_param; // Fallback on error

            break :blk size_result;
        } else {
            break :blk chunk_size_param; // No V8 context - use provided size
        }
    } else chunk_size_param; // No size algorithm - use provided size

    // 3. Wrap chunk in JSValue (simplified - treat as opaque object for now)
    const js_chunk = common.JSValue{ .object = {} };

    // 4. Create write request with chunk and promise
    const request = try write_request.WriteRequest.init(
        allocator,
        stream_internal.event_loop,
        js_chunk,
    );
    errdefer request.deinit();

    // 5. Enqueue to controller's queue (using QueueValue wrapper from this module)
    // Store both the chunk and its calculated size per spec § 9.2.1
    const value = QueueValue{ .chunk = .{
        .value = @constCast(chunk),
        .size = chunk_size,
    } };
    try internal.queue.append(allocator, value);
    internal.queue_total_size += chunk_size;

    // 6. Store WriteRequest in stream's write_requests queue
    try stream_internal.write_requests.append(allocator, request);

    // 7. Update backpressure after adding to queue
    writableStreamDefaultControllerUpdateBackpressure(controller);

    // 8. If stream is writable and no close pending, advance the queue
    const close_pending = stream_internal.close_request != null or stream_internal.in_flight_close_request != null;
    if (stream_internal.state == .writable and !close_pending) {
        writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
    }

    // 9. Return the write request's promise
    return request.promise;
}

/// WritableStreamDefaultControllerAdvanceQueueIfNeeded - Process write queue
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-advance-queue-if-needed
/// Arguments:
///   controller: WritableStreamDefaultController instance
///
/// Steps:
/// 1. Let controller be this
/// 2. If controller.[[started]] is false, return
/// 3. Let stream be controller.[[stream]]
/// 4. If stream.[[inFlightWriteRequest]] is not undefined, return
/// 5. Let state be stream.[[state]]
/// 6. Assert: state is not "closed" or "errored"
/// 7. If state is "erroring", perform WritableStreamFinishErroring(stream) and return
/// 8. If controller.[[queue]] is empty, return
/// 9. Let value be PeekQueueValue(controller)
/// 10. If value is close sentinel, perform WritableStreamDefaultControllerProcessClose(controller)
/// 11. Otherwise, perform WritableStreamDefaultControllerProcessWrite(controller, value)
fn writableStreamDefaultControllerAdvanceQueueIfNeeded(controller: *runtime.Instance) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    // 1-2. If controller not started, return
    if (!internal.started) {
        return;
    }

    // 3. Get stream
    const stream = internal.stream orelse return;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // 4. If there's an in-flight write, return
    if (stream_internal.in_flight_write_request != null) {
        return;
    }

    // 5-6. Check stream state
    const current_state = stream_internal.state;
    if (current_state == .closed or current_state == .errored) {
        return; // Assert violation in spec, but we handle gracefully
    }

    // 7. If erroring, finish erroring
    if (current_state == .erroring) {
        const WritableStreamImpl = @import("WritableStream.zig");
        WritableStreamImpl.writableStreamFinishErroring(stream, stream_internal);
        return;
    }

    // 8. If queue is empty, return
    if (internal.queue.items.len == 0) {
        return;
    }

    // 9. Peek at next value
    const value = internal.queue.items[0];

    // 10-11. Process close or write
    switch (value) {
        .close_sentinel => {
            writableStreamDefaultControllerProcessClose(controller);
        },
        .chunk => |chunk_container| {
            // Extract the actual chunk value from the container
            writableStreamDefaultControllerProcessWrite(controller, chunk_container.value);
        },
    }
}

/// WritableStreamDefaultControllerProcessWrite - Execute underlying sink write
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-process-write
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   chunk: The chunk to write
///
/// Steps:
/// 1. Let stream be controller.[[stream]]
/// 2. Assert: stream.[[state]] is "writable"
/// 3. Dequeue writeRecord from stream.[[writeRequests]]
/// 4. Set stream.[[inFlightWriteRequest]] to writeRecord
/// 5. Let sink be controller.[[writeAlgorithm]]
/// 6. Upon fulfillment of sink(chunk, controller):
///    - Resolve writeRecord's promise
///    - Set stream.[[inFlightWriteRequest]] to undefined
///    - Update backpressure and advance queue
/// 7. Upon rejection: handle error
fn writableStreamDefaultControllerProcessWrite(controller: *runtime.Instance, chunk: *const anyopaque) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    // 1-2. Get stream and verify state
    const stream = internal.stream orelse return;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    if (stream_internal.state != .writable) {
        return; // Assert violation
    }

    // 3. Dequeue the write request from stream's write_requests
    if (stream_internal.write_requests.items.len == 0) {
        return; // No write requests
    }
    const write_request = stream_internal.write_requests.orderedRemove(0);

    // Also dequeue from controller's internal queue
    const value = internal.queue.orderedRemove(0);

    // Get size from the stored value container (per spec § 9.2.1)
    const chunk_size = switch (value) {
        .chunk => |c| c.size,
        .close_sentinel => 0.0,
    };
    internal.queue_total_size -= chunk_size;

    // 4. Mark as in-flight
    stream_internal.in_flight_write_request = write_request;

    // 5. Invoke underlying sink write algorithm
    if (internal.write_algorithm) |write_global| {
        // Check if we have V8 context (runtime mode)
        if (internal.isolate) |isolate| {
            // Get Local from Global handle for this invocation
            const write_value = write_global.get(isolate) orelse {
                writableStreamDefaultControllerError(controller, stream);
                return;
            };

            // Verify it's a function
            if (!v8_engine.ffi.v8_Value_IsFunction(write_value)) {
                writableStreamDefaultControllerError(controller, stream);
                return;
            }
            const write_function: *v8_engine.ffi.Function = @ptrCast(write_value);
            const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(internal.v8_context.?));

            // Convert chunk to V8 Value
            const chunk_v8 = v8_engine.conversions.chunkToV8Value(
                chunk,
                isolate,
                v8_context,
            ) catch {
                writableStreamDefaultControllerError(controller, stream);
                return;
            };

            // Convert controller to V8 Object
            const controller_v8 = v8_engine.conversions.instanceToV8Object(
                controller,
                isolate,
                v8_context,
            ) catch {
                writableStreamDefaultControllerError(controller, stream);
                return;
            };
            defer v8_engine.ffi.v8_Object_Dispose(controller_v8);

            // Invoke write_algorithm(chunk, controller) → Promise<void>
            var write_promise = v8_engine.streams_callbacks.invokeWriteAlgorithm(
                isolate,
                v8_context,
                write_function,
                chunk_v8,
                controller_v8,
            ) catch {
                writableStreamDefaultControllerError(controller, stream);
                return;
            };
            defer write_promise.deinit();

            // Create callback context for promise handlers
            const write_ctx = internal.allocator.create(WriteCallbackContext) catch {
                writableStreamDefaultControllerError(controller, stream);
                return;
            };
            write_ctx.* = .{
                .controller = controller,
                .stream = stream,
                .allocator = internal.allocator,
            };

            // Create V8 callbacks for Promise handlers
            // These wrap the Zig functions and pass context so Promise.then() can call them
            const onFulfilled = v8_engine.zig_callbacks.createContextCallback(
                internal.allocator,
                isolate,
                v8_context,
                onWriteFulfilled,
                write_ctx,
            ) catch {
                internal.allocator.destroy(write_ctx);
                writableStreamDefaultControllerError(controller, stream);
                return;
            };
            defer v8_engine.ffi.v8_Function_Dispose(onFulfilled);

            const onRejected = v8_engine.zig_callbacks.createContextCallbackWithArg(
                internal.allocator,
                isolate,
                v8_context,
                onWriteRejected,
                write_ctx,
            ) catch {
                internal.allocator.destroy(write_ctx);
                writableStreamDefaultControllerError(controller, stream);
                return;
            };
            defer v8_engine.ffi.v8_Function_Dispose(onRejected);

            // Chain Promise handlers
            // When write Promise settles, onFulfilled/onRejected will be called
            _ = write_promise.then(onFulfilled, onRejected) catch {
                internal.allocator.destroy(write_ctx);
                writableStreamDefaultControllerError(controller, stream);
                return;
            };

            // Promise will settle asynchronously - callbacks will handle completion
            return;
        }
    }

    // Fallback: No write algorithm or no V8 context (testing mode)
    // Immediately fulfill the write
    writableStreamDefaultControllerFinishWrite(controller, stream);
}

/// WritableStreamDefaultControllerFinishWrite - Complete a write operation
///
/// Called when underlying sink write succeeds
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   stream: WritableStream instance
fn writableStreamDefaultControllerFinishWrite(controller: *runtime.Instance, stream: *runtime.Instance) void {
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Fulfill the write request's promise
    if (stream_internal.in_flight_write_request) |request| {
        request.fulfill();
    }

    // Clear in-flight write request
    stream_internal.in_flight_write_request = null;

    // Update backpressure
    writableStreamDefaultControllerUpdateBackpressure(controller);

    // Advance the queue to process next write
    writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
}

/// WritableStreamDefaultControllerProcessClose - Execute underlying sink close
///
/// Spec: § 5.7.6 "Process a close request"
/// Arguments:
///   controller: WritableStreamDefaultController instance
fn writableStreamDefaultControllerProcessClose(controller: *runtime.Instance) void {
    const controller_state = controller.getState(State);
    const controller_internal = controller_state.own._internal orelse return;

    // Get stream
    const stream = controller_internal.stream orelse return;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Remove close sentinel from queue
    if (controller_internal.queue.items.len > 0) {
        _ = controller_internal.queue.orderedRemove(0);
    }

    // Set in_flight_close_request from close_request
    if (stream_internal.close_request) |close_req| {
        stream_internal.in_flight_close_request = close_req;
        stream_internal.close_request = null;
    }

    // Invoke underlying sink close algorithm
    if (controller_internal.close_algorithm) |close_global| {
        // Check if we have V8 context (runtime mode)
        if (controller_internal.isolate) |isolate| {
            if (controller_internal.v8_context) |v8_ctx| {
                // Get Local from Global handle for this invocation
                const close_value = close_global.get(isolate) orelse {
                    writableStreamDefaultControllerFinishClose(stream);
                    return;
                };

                // Verify it's a function
                if (!v8_engine.ffi.v8_Value_IsFunction(close_value)) {
                    writableStreamDefaultControllerFinishClose(stream);
                    return;
                }
                const close_function: *v8_engine.ffi.Function = @ptrCast(close_value);
                const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(v8_ctx));

                // Invoke close_algorithm() → Promise<void>
                var close_promise = v8_engine.streams_callbacks.invokeCloseAlgorithm(
                    isolate,
                    v8_context,
                    close_function,
                ) catch {
                    // Invocation failed - just finish close anyway
                    writableStreamDefaultControllerFinishClose(stream);
                    return;
                };
                defer close_promise.deinit();

                // Create callback context for promise handlers
                const close_ctx = controller_internal.allocator.create(CloseCallbackContext) catch {
                    writableStreamDefaultControllerFinishClose(stream);
                    return;
                };
                close_ctx.* = .{
                    .stream = stream,
                    .allocator = controller_internal.allocator,
                };

                // Create V8 callbacks for Promise handlers with context
                const onFulfilled = v8_engine.zig_callbacks.createContextCallback(
                    controller_internal.allocator,
                    isolate,
                    v8_context,
                    onCloseFulfilled,
                    close_ctx,
                ) catch {
                    controller_internal.allocator.destroy(close_ctx);
                    writableStreamDefaultControllerFinishClose(stream);
                    return;
                };
                defer v8_engine.ffi.v8_Function_Dispose(onFulfilled);

                const onRejected = v8_engine.zig_callbacks.createContextCallbackWithArg(
                    controller_internal.allocator,
                    isolate,
                    v8_context,
                    onCloseRejected,
                    close_ctx,
                ) catch {
                    controller_internal.allocator.destroy(close_ctx);
                    writableStreamDefaultControllerFinishClose(stream);
                    return;
                };
                defer v8_engine.ffi.v8_Function_Dispose(onRejected);

                // Chain Promise handlers
                _ = close_promise.then(onFulfilled, onRejected) catch {
                    controller_internal.allocator.destroy(close_ctx);
                    writableStreamDefaultControllerFinishClose(stream);
                    return;
                };

                // Promise will settle asynchronously - callbacks will handle completion
                return;
            }
        }
    }

    // Fallback: No close algorithm or no V8 context (testing mode)
    // Immediately succeed
    writableStreamDefaultControllerFinishClose(stream);
}

/// WritableStreamDefaultControllerFinishClose - Complete close operation
///
/// Called when underlying sink close succeeds
/// Arguments:
///   stream: WritableStream instance
fn writableStreamDefaultControllerFinishClose(stream: *runtime.Instance) void {
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Fulfill the in-flight close request
    if (stream_internal.in_flight_close_request) |close_req| {
        close_req.fulfill({});
    }

    // Clear in-flight close request
    stream_internal.in_flight_close_request = null;

    // Set stream state to closed
    stream_internal.state = .closed;

    // Fulfill writer's closed promise if writer exists
    if (stream_internal.writer != .none) {
        const writer = switch (stream_internal.writer) {
            .default => |w| w,
            .none => return,
        };

        const writer_state = writer.getState(interfaces.WritableStreamDefaultWriter.State);
        if (writer_state.own._internal) |writer_internal| {
            if (writer_internal.closed_promise) |closed| {
                closed.fulfill({});
            }
        }
    }
}

/// WritableStreamDefaultControllerUpdateBackpressure - Update backpressure signal
///
/// Spec: Not explicitly named in spec, but combines several backpressure algorithms
/// Arguments:
///   controller: WritableStreamDefaultController instance
///
/// This implements the logic from:
/// - WritableStreamDefaultControllerGetDesiredSize
/// - WritableStreamUpdateBackpressure
fn writableStreamDefaultControllerUpdateBackpressure(controller: *runtime.Instance) void {
    const controller_state = controller.getState(State);
    const controller_internal = controller_state.own._internal orelse return;

    // Get stream
    const stream = controller_internal.stream orelse return;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Calculate desired size = highWaterMark - queueTotalSize
    const desired_size = controller_internal.strategy_hwm - controller_internal.queue_total_size;

    // Backpressure is true if desired size <= 0
    const new_backpressure = desired_size <= 0.0;

    // If backpressure changed, update ready promise
    if (new_backpressure != stream_internal.backpressure) {
        stream_internal.backpressure = new_backpressure;

        // Update writer's ready promise if writer exists
        if (stream_internal.writer != .none) {
            const writer = switch (stream_internal.writer) {
                .default => |w| w,
                .none => return,
            };

            const writer_state = writer.getState(interfaces.WritableStreamDefaultWriter.State);
            const writer_internal = writer_state.own._internal orelse return;

            if (writer_internal.ready_promise) |ready_promise| {
                if (new_backpressure) {
                    // Backpressure applied: ready promise should be pending
                    // If the promise is already fulfilled, we need a new pending promise
                    if (ready_promise.isFulfilled()) {
                        // Clean up old promise
                        ready_promise.deinit();

                        // Create new pending promise
                        const new_ready = AsyncPromise(void).init(
                            writer_internal.allocator,
                            stream_internal.event_loop,
                        ) catch return; // Graceful handling

                        writer_internal.ready_promise = new_ready;
                    }
                } else {
                    // Backpressure released: fulfill ready promise
                    ready_promise.fulfill({});
                }
            }
        }
    }
}

/// [[AbortSteps]] - Handle abort request
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-internal-abort
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   reason: Abort reason
/// Returns: Promise<undefined> from abort algorithm
///
/// Steps:
/// 1. Let result = perform this.[[abortAlgorithm]], passing reason
/// 2. Perform WritableStreamDefaultControllerClearAlgorithms(this)
/// 3. Return result
pub fn abortSteps(controller: *runtime.Instance, reason: *const anyopaque) !*AsyncPromise(void) {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Get event loop from stream
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;
    const event_loop = stream_internal.event_loop;

    // 1. Perform abort algorithm with reason
    if (internal.abort_algorithm) |abort_global| {
        // Check if we have V8 context (runtime mode)
        if (internal.isolate) |isolate| {
            // Get Local from Global handle for this invocation
            const abort_value = abort_global.get(isolate) orelse {
                // Handle null - return rejected promise
                const promise = try AsyncPromise(void).init(allocator, event_loop);
                const exception = try webidl.errors.Exception.typeError(allocator, "Abort algorithm handle is invalid");
                promise.reject(exception);
                writableStreamDefaultControllerClearAlgorithms(controller);
                return promise;
            };

            // Verify it's a function
            if (!v8_engine.ffi.v8_Value_IsFunction(abort_value)) {
                const promise = try AsyncPromise(void).init(allocator, event_loop);
                const exception = try webidl.errors.Exception.typeError(allocator, "Abort algorithm is not a function");
                promise.reject(exception);
                writableStreamDefaultControllerClearAlgorithms(controller);
                return promise;
            }
            const abort_function: *v8_engine.ffi.Function = @ptrCast(abort_value);
            const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(internal.v8_context.?));

            // Convert reason to V8 Value - untag the pointer first
            const pointer_tag = @import("v8").pointer_tag;
            const untagged_reason = pointer_tag.untagPointer(reason);

            // If it's a runtime instance, we can't use it directly as a V8 value
            // In this case, we should convert it or error
            if (untagged_reason.tag == .runtime_instance) {
                const promise = try AsyncPromise(void).init(allocator, event_loop);
                const exception = try webidl.errors.Exception.typeError(allocator, "Invalid abort reason: expected V8 value");
                promise.reject(exception);
                writableStreamDefaultControllerClearAlgorithms(controller);
                return promise;
            }

            const reason_v8: *v8_engine.ffi.Value = @ptrCast(untagged_reason.ptr);

            // Invoke abort_algorithm(reason) → Promise<void>
            var abort_promise = v8_engine.streams_callbacks.invokeAbortAlgorithm(
                isolate,
                v8_context,
                abort_function,
                reason_v8,
            ) catch {
                // On error, return rejected promise
                const promise = try AsyncPromise(void).init(allocator, event_loop);
                const exception = try webidl.errors.Exception.typeError(allocator, "Abort algorithm invocation failed");
                promise.reject(exception);
                writableStreamDefaultControllerClearAlgorithms(controller);
                return promise;
            };
            defer abort_promise.deinit();

            // Create AsyncPromise to track result
            const result_promise = try AsyncPromise(void).init(allocator, event_loop);

            // Create callback context
            const abort_ctx = try allocator.create(AbortCallbackContext);
            abort_ctx.* = .{
                .controller = controller,
                .result_promise = result_promise,
                .allocator = allocator,
            };

            // Create V8 callbacks for Promise handlers
            const onFulfilled = v8_engine.zig_callbacks.createContextCallback(
                allocator,
                isolate,
                v8_context,
                onAbortFulfilled,
                abort_ctx,
            ) catch {
                allocator.destroy(abort_ctx);
                result_promise.fulfill({});
                writableStreamDefaultControllerClearAlgorithms(controller);
                return result_promise;
            };
            defer v8_engine.ffi.v8_Function_Dispose(onFulfilled);

            const onRejected = v8_engine.zig_callbacks.createContextCallbackWithArg(
                allocator,
                isolate,
                v8_context,
                onAbortRejected,
                abort_ctx,
            ) catch {
                allocator.destroy(abort_ctx);
                result_promise.fulfill({});
                writableStreamDefaultControllerClearAlgorithms(controller);
                return result_promise;
            };
            defer v8_engine.ffi.v8_Function_Dispose(onRejected);

            // Chain Promise handlers
            _ = abort_promise.then(onFulfilled, onRejected) catch {
                allocator.destroy(abort_ctx);
                result_promise.fulfill({});
                writableStreamDefaultControllerClearAlgorithms(controller);
                return result_promise;
            };

            // Note: Don't clear algorithms here - let the callback do it after promise settles
            return result_promise;
        }
    }

    // 2. Clear algorithms (no abort callback or no V8 context)
    writableStreamDefaultControllerClearAlgorithms(controller);

    // 3. Return fulfilled promise (fallback/testing mode)
    const promise = try AsyncPromise(void).init(allocator, event_loop);
    promise.fulfill({});
    return promise;
}

/// Context for abort callback
const AbortCallbackContext = struct {
    controller: *runtime.Instance,
    result_promise: *AsyncPromise(void),
    allocator: std.mem.Allocator,
};

/// Callback for abort promise fulfillment
fn onAbortFulfilled(ctx_ptr: *anyopaque) void {
    const ctx: *AbortCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    defer ctx.allocator.destroy(ctx);

    // Clear algorithms after abort completes
    writableStreamDefaultControllerClearAlgorithms(ctx.controller);

    // Fulfill the result promise
    ctx.result_promise.fulfill({});
}

/// Callback for abort promise rejection
fn onAbortRejected(ctx_ptr: *anyopaque, _: *v8_engine.ffi.Value) void {
    const ctx: *AbortCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    defer ctx.allocator.destroy(ctx);

    // Clear algorithms after abort completes
    writableStreamDefaultControllerClearAlgorithms(ctx.controller);

    // Reject the result promise
    const exception = webidl.errors.Exception.typeError(ctx.allocator, "Abort algorithm rejected") catch {
        ctx.result_promise.fulfill({});
        return;
    };
    ctx.result_promise.reject(exception);
}

/// [[ErrorSteps]] - Handle error state
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-internal-error
/// Steps:
/// 1. Perform ResetQueue(this)
pub fn errorSteps(controller: *runtime.Instance) void {
    resetQueue(controller);
}

/// WritableStreamDefaultControllerClearAlgorithms
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-clear-algorithms
/// Steps:
/// 1. Set this.[[writeAlgorithm]] to undefined
/// 2. Set this.[[closeAlgorithm]] to undefined
/// 3. Set this.[[abortAlgorithm]] to undefined
/// 4. Set this.[[strategySizeAlgorithm]] to undefined
fn writableStreamDefaultControllerClearAlgorithms(controller: *runtime.Instance) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    internal.write_algorithm = null;
    internal.close_algorithm = null;
    internal.abort_algorithm = null;
    internal.strategy_size_algorithm = null;
}
