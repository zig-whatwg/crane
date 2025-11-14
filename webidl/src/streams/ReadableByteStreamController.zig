//! ReadableByteStreamController class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#rbs-controller-class
//!
//! Controls a readable byte stream for zero-copy operations.

const std = @import("std");
const infra = @import("infra");
const webidl = @import("webidl");

const common = @import("common");
const eventLoop = @import("event_loop");
const QueueWithSizes = @import("queue_with_sizes").QueueWithSizes;
const AbortController = @import("dom").AbortController;

// BYOB infrastructure imports
const PullIntoDescriptorModule = @import("pull_into_descriptor");
const PullIntoDescriptor = PullIntoDescriptorModule.PullIntoDescriptor;
const ArrayBuffer = PullIntoDescriptorModule.ArrayBuffer;
const ViewConstructor = PullIntoDescriptorModule.ViewConstructor;
const ReaderType = PullIntoDescriptorModule.ReaderType;

const ReadIntoRequestModule = @import("read_into_request");
const ReadIntoRequest = ReadIntoRequestModule.ReadIntoRequest;

const ViewConstruction = @import("view_construction");

const AsyncPromise = @import("async_promise").AsyncPromise;
const ReadableStreamBYOBRequest = @import("readable_stream_byob_request").ReadableStreamBYOBRequest;

/// Byte stream queue entry per WHATWG Streams Standard § 4.7.2
///
/// Represents a queued chunk in a byte stream with its buffer and byte range.
const ByteStreamQueueEntry = struct {
    /// The ArrayBuffer containing the queued bytes
    buffer: *ArrayBuffer,
    /// Byte offset into the buffer where this chunk starts
    byteOffset: u64,
    /// Length in bytes of this chunk
    byteLength: u64,
};

pub const ReadableByteStreamController = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[abortController]]: AbortController for signaling abort
    /// Spec: https://streams.spec.whatwg.org/#readablebytestreamcontroller-abortcontroller
    abortController: AbortController,

    /// [[autoAllocateChunkSize]]: Size for auto-allocated buffers
    autoAllocateChunkSize: ?u64,

    /// [[byobRequest]]: Current BYOB request (or null)
    byobRequest: ?*ReadableStreamBYOBRequest,

    /// [[cancelAlgorithm]]: Algorithm for cancelation
    cancelAlgorithm: common.CancelAlgorithm,

    /// [[closeRequested]]: boolean - stream closed by source but has queued chunks
    closeRequested: bool,

    /// [[pullAgain]]: boolean - pull requested but previous pull still executing
    pullAgain: bool,

    /// [[pullAlgorithm]]: Algorithm for pulling data
    pullAlgorithm: common.PullAlgorithm,

    /// [[pulling]]: boolean - pull algorithm currently executing
    pulling: bool,

    /// [[pendingPullIntos]]: List of pending pull-into descriptors
    pendingPullIntos: infra.List(*PullIntoDescriptor),

    /// [[queue]]: List of byte stream queue entries
    byteQueue: infra.List(ByteStreamQueueEntry),

    /// [[queueTotalSize]]: Total size of all byte chunks in queue
    queueTotalSize: f64,

    /// [[started]]: boolean - underlying source has finished starting
    started: bool,

    /// [[strategyHWM]]: High water mark for backpressure
    strategyHwm: f64,

    /// [[stream]]: The ReadableStream instance controlled
    stream: ?*anyopaque,

    /// Event loop for async operations
    eventLoop: eventLoop.EventLoop,

    pub fn init(
        allocator: std.mem.Allocator,
        cancelAlgorithm: common.CancelAlgorithm,
        pullAlgorithm: common.PullAlgorithm,
        strategyHwm: f64,
        autoAllocateChunkSize: ?u64,
        loop: eventLoop.EventLoop,
    ) !ReadableByteStreamController {
        return .{
            .allocator = allocator,
            .abortController = try AbortController.init(allocator),
            .autoAllocateChunkSize = autoAllocateChunkSize,
            .byobRequest = null,
            .cancelAlgorithm = cancelAlgorithm,
            .closeRequested = false,
            .pullAgain = false,
            .pullAlgorithm = pullAlgorithm,
            .pulling = false,
            .pendingPullIntos = .empty,
            .byteQueue = .empty,
            .queueTotalSize = 0.0,
            .started = false,
            .strategyHwm = strategyHwm,
            .stream = null,
            .eventLoop = loop,
        };
    }

    pub fn deinit(self: *ReadableByteStreamController) void {
        self.abortController.deinit();

        // Clean up byte queue buffers
        for (self.byteQueue.items) |entry| {
            entry.buffer.deinit(self.allocator);
            self.allocator.destroy(entry.buffer);
        }
        self.byteQueue.deinit(self.allocator);

        // Clean up pending pull-intos
        for (self.pendingPullIntos.items) |descriptor| {
            descriptor.buffer.deinit(self.allocator);
            self.allocator.destroy(descriptor.buffer);
            self.allocator.destroy(descriptor);
        }
        self.pendingPullIntos.deinit(self.allocator);

        // Clean up BYOB request
        if (self.byobRequest) |req| {
            self.allocator.destroy(req);
        }
    }

    // ============================================================================
    // WebIDL Interface: Readonly Attributes
    // ============================================================================

    /// readonly attribute ReadableStreamBYOBRequest? byobRequest
    /// Spec: https://streams.spec.whatwg.org/#rbs-controller-byob-request
    pub fn get_byobRequest(self: *const ReadableByteStreamController) ?*ReadableStreamBYOBRequest {
        return self.byobRequest;
    }

    /// readonly attribute unrestricted double? desiredSize
    /// Calculate desired size
    /// Spec: § 4.10.11 "ReadableByteStreamControllerGetDesiredSize(controller)"
    pub fn get_desiredSize(self: *const ReadableByteStreamController) ?f64 {
        // If stream is closed, return 0
        if (self.closeRequested and self.byteQueue.items.len == 0) {
            return 0.0;
        }

        // Return highWaterMark - queueTotalSize
        return self.strategyHwm - self.queueTotalSize;
    }

    // ============================================================================
    // WebIDL Interface: Instance Methods
    // ============================================================================

    /// undefined close()
    /// Close the controlled readable stream
    /// Spec: § 4.7.3 "The close() method steps are:"
    pub fn call_close(self: *ReadableByteStreamController) !void {
        // Step 1: If closeRequested is true, throw TypeError
        if (self.closeRequested) {
            return error.TypeError;
        }

        // Step 2: If stream state is not "readable", throw TypeError
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        if (stream.state != .readable) {
            return error.TypeError;
        }

        // Step 3: Perform ReadableByteStreamControllerClose
        self.closeInternal();
    }

    /// Enqueue the given chunk in the controlled readable stream
    ///
    /// Spec: § 4.7.3 "The enqueue(chunk) method steps are:"
    pub fn call_enqueue(self: *ReadableByteStreamController, chunk: webidl.ArrayBufferView) !void {
        // Step 1: If chunk ByteLength is 0, throw TypeError
        if (chunk.getByteLength() == 0) {
            return error.TypeError;
        }

        // Step 2: If buffer ByteLength is 0, throw TypeError
        const buffer = chunk.getViewedArrayBuffer();
        if (buffer.byteLength() == 0) {
            return error.TypeError;
        }

        // Step 3: If closeRequested is true, throw TypeError
        if (self.closeRequested) {
            return error.TypeError;
        }

        // Step 4: If stream state is not "readable", throw TypeError
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        if (stream.state != .readable) {
            return error.TypeError;
        }

        // Step 5: Perform ReadableByteStreamControllerEnqueue
        try self.enqueueInternal(chunk);
    }

    /// undefined error(optional any e)
    /// Error the controlled readable stream
    /// Spec: § 4.7.3 "The error(e) method steps are:"
    pub fn call_error(self: *ReadableByteStreamController, e: webidl.JSValue) void {
        const error_value = common.JSValue.fromWebIDL(e);
        self.errorInternal(error_value);
    }

    // ============================================================================
    // Controller Contracts (§ 4.7.4)
    // ============================================================================

    /// [[PullSteps]](readRequest) - Implements the controller contract
    ///
    /// Spec: § 4.7.4 "[[PullSteps]](readRequest)"
    ///
    /// This is called when a default reader reads from a byte stream.
    /// If autoAllocateChunkSize is set, this automatically allocates a buffer.
    pub fn pullSteps(
        self: *ReadableByteStreamController,
        reader: *anyopaque,
    ) !*AsyncPromise(common.ReadResult) {
        _ = reader; // Not used in this implementation

        // Step 1: Let stream be this.[[stream]].
        const stream_ptr = self.stream orelse {
            const promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = try self.allocator.dupe(u8, "Stream not initialized"),
                },
            };
            promise.reject(exception);
            return promise;
        };
        const ReadableStreamModule = @import("readable_stream");
        _ = ReadableStreamModule; // For future use
        _ = stream_ptr; // Stream ptr available if needed

        // Step 2: Assert: ! ReadableStreamHasDefaultReader(stream) is true.
        // (We assume this is true when called from a default reader)

        // Step 3: If this.[[queueTotalSize]] > 0,
        if (self.queueTotalSize > 0) {
            // Step 3.1: Assert: ! ReadableStreamGetNumReadRequests(stream) is 0.
            // (Implicit - if queue has data, no pending requests)

            // Step 3.2: Perform ! ReadableByteStreamControllerFillReadRequestFromQueue(this, readRequest).
            const promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);

            // Dequeue a chunk from the byte queue
            if (self.byteQueue.items.len > 0) {
                const entry = self.byteQueue.orderedRemove(0);

                // Update queue total size
                self.queueTotalSize -= @as(f64, @floatFromInt(entry.byteLength));

                // Create Uint8Array view of the chunk
                const chunk_data = entry.buffer.data[entry.byteOffset..][0..@intCast(entry.byteLength)];
                const chunk_value = common.JSValue{ .bytes = chunk_data };

                // Clean up the buffer
                entry.buffer.deinit(self.allocator);
                self.allocator.destroy(entry.buffer);

                // Fulfill promise with the chunk
                promise.fulfill(.{
                    .value = chunk_value,
                    .done = false,
                });
            } else {
                // Shouldn't happen if queueTotalSize > 0
                const exception = webidl.errors.Exception{
                    .simple = .{
                        .type = .TypeError,
                        .message = try self.allocator.dupe(u8, "Queue size mismatch"),
                    },
                };
                promise.reject(exception);
            }

            // Step 3.3: Return.
            return promise;
        }

        // Step 4: Let autoAllocateChunkSize be this.[[autoAllocateChunkSize]].
        const auto_allocate_chunk_size = self.autoAllocateChunkSize;

        // Step 5: If autoAllocateChunkSize is not undefined,
        if (auto_allocate_chunk_size) |chunk_size| {
            // Step 5.1: Let buffer be Construct(%ArrayBuffer%, « autoAllocateChunkSize »).
            const buffer = ArrayBuffer.init(self.allocator, chunk_size) catch {
                // Step 5.2: If buffer is an abrupt completion,
                const promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);
                const exception = webidl.errors.Exception{
                    .simple = .{
                        .type = .TypeError,
                        .message = try self.allocator.dupe(u8, "Failed to allocate buffer"),
                    },
                };
                promise.reject(exception);
                return promise;
            };

            const buffer_ptr = try self.allocator.create(ArrayBuffer);
            buffer_ptr.* = buffer;

            // Step 5.3: Let pullIntoDescriptor be a new pull-into descriptor with
            const pull_into_descriptor = try self.allocator.create(PullIntoDescriptor);
            pull_into_descriptor.* = PullIntoDescriptor.init(
                buffer_ptr,
                chunk_size,
                0, // byte offset
                chunk_size, // byte length
                1, // minimum fill (at least 1 byte)
                1, // element size (Uint8Array)
                ViewConstructor.uint8_array,
                .default, // reader type = "default"
            );

            // Step 5.4: Append pullIntoDescriptor to this.[[pendingPullIntos]].
            try self.pendingPullIntos.append(self.allocator, pull_into_descriptor);
        }

        // Step 6: Perform ! ReadableStreamAddReadRequest(stream, readRequest).
        const pending_promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);

        // Add to stream's read requests (this would normally be on the reader)
        // For now, we create a promise that will be fulfilled when data arrives
        // TODO: Properly integrate with reader's readRequests queue

        // Step 7: Perform ! ReadableByteStreamControllerCallPullIfNeeded(this).
        self.callPullIfNeeded();

        // Return the pending promise
        return pending_promise;
    }

    // ============================================================================
    // Queue Operations (§ 4.10.11)
    // ============================================================================

    /// Enqueue a chunk to the byte stream queue
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerEnqueueChunkToQueue"
    fn enqueueChunkToQueue(
        self: *ReadableByteStreamController,
        buffer: *ArrayBuffer,
        byteOffset: u64,
        byteLength: u64,
    ) !void {
        // Step 1: Append a new readable byte stream queue entry
        try self.byteQueue.append(self.allocator, .{
            .buffer = buffer,
            .byteOffset = byteOffset,
            .byteLength = byteLength,
        });

        // Step 2: Set controller.[[queueTotalSize]] += byteLength
        self.queueTotalSize += @as(f64, @floatFromInt(byteLength));
    }

    /// Enqueue cloned chunk to queue
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerEnqueueClonedChunkToQueue"
    fn enqueueClonedChunkToQueue(
        self: *ReadableByteStreamController,
        buffer: *ArrayBuffer,
        byteOffset: u64,
        byteLength: u64,
    ) !void {
        // Step 1: Let cloneResult be CloneArrayBuffer(buffer, byteOffset, byteLength)
        const clone_result = buffer.clone(
            self.allocator,
            @as(usize, @intCast(byteOffset)),
            @as(usize, @intCast(byteLength)),
        ) catch |err| {
            // Step 2: If cloneResult is an abrupt completion, error the controller
            const error_value = common.JSValue{ .string = "Failed to clone buffer" };
            self.errorInternal(error_value);
            return err;
        };

        // Step 3: Enqueue the cloned buffer
        const cloned_buffer = try self.allocator.create(ArrayBuffer);
        cloned_buffer.* = clone_result;

        try self.enqueueChunkToQueue(cloned_buffer, 0, byteLength);
    }

    /// Enqueue detached pull-into to queue
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerEnqueueDetachedPullIntoToQueue"
    fn enqueueDetachedPullIntoToQueue(
        self: *ReadableByteStreamController,
        pullIntoDescriptor: *PullIntoDescriptor,
    ) !void {
        // Step 1: Assert: pullIntoDescriptor's reader type is "none"
        // (Assertion - caller ensures this)

        // Step 2: If pullIntoDescriptor's bytes filled > 0
        if (pullIntoDescriptor.bytes_filled > 0) {
            try self.enqueueClonedChunkToQueue(
                pullIntoDescriptor.buffer,
                pullIntoDescriptor.byte_offset,
                pullIntoDescriptor.bytes_filled,
            );
        }

        // Step 3: Shift pending pull-into
        _ = self.shiftPendingPullInto();
    }

    // ============================================================================
    // BYOB Request Management (§ 4.10.11)
    // ============================================================================

    /// Invalidate the current BYOB request
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerInvalidateBYOBRequest"
    fn invalidateBYOBRequest(self: *ReadableByteStreamController) void {
        // Step 1: If controller.[[byobRequest]] is null, return
        if (self.byobRequest) |req| {
            // Step 2-4: Invalidate and clear the request
            self.byobRequest = null;
            self.allocator.destroy(req);
        }
    }

    /// Clear all pending pull-into descriptors
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerClearPendingPullIntos"
    fn clearPendingPullIntos(self: *ReadableByteStreamController) void {
        // Step 1: Invalidate BYOB request
        self.invalidateBYOBRequest();

        // Step 2: Clear the list
        for (self.pendingPullIntos.items) |descriptor| {
            descriptor.buffer.deinit(self.allocator);
            self.allocator.destroy(descriptor.buffer);
            self.allocator.destroy(descriptor);
        }
        self.pendingPullIntos.clearRetainingCapacity();
    }

    // ============================================================================
    // Pull-Into Descriptor Operations (§ 4.10.11)
    // ============================================================================

    /// Fill head pull-into descriptor with bytes
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerFillHeadPullIntoDescriptor"
    fn fillHeadPullIntoDescriptor(
        self: *ReadableByteStreamController,
        size: u64,
        pullIntoDescriptor: *PullIntoDescriptor,
    ) void {
        _ = self; // Assertion-only parameter

        // Step 1-2: Assertions (caller ensures validity)
        // Step 3: Increment bytes filled
        pullIntoDescriptor.bytes_filled += size;
    }

    /// Fill pull-into descriptor from queue
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerFillPullIntoDescriptorFromQueue"
    fn fillPullIntoDescriptorFromQueue(
        self: *ReadableByteStreamController,
        pullIntoDescriptor: *PullIntoDescriptor,
    ) bool {
        // Step 1: Calculate max bytes to copy
        const remaining_space = pullIntoDescriptor.byte_length - pullIntoDescriptor.bytes_filled;
        const max_bytes_to_copy = @min(
            @as(u64, @intFromFloat(self.queueTotalSize)),
            remaining_space,
        );

        // Step 2-3: Calculate fill targets
        const max_bytes_filled = pullIntoDescriptor.bytes_filled + max_bytes_to_copy;
        var total_bytes_to_copy_remaining = max_bytes_to_copy;

        // Step 4: Ready flag
        var ready = false;

        // Step 7-9: Check alignment and minimum fill
        const remainder_bytes = max_bytes_filled % pullIntoDescriptor.element_size;
        const max_aligned_bytes = max_bytes_filled - remainder_bytes;

        if (max_aligned_bytes >= pullIntoDescriptor.minimum_fill) {
            total_bytes_to_copy_remaining = max_aligned_bytes - pullIntoDescriptor.bytes_filled;
            ready = true;
        }

        // Step 11: Copy bytes from queue
        while (total_bytes_to_copy_remaining > 0) {
            var head_of_queue = &self.byteQueue.items[0];
            const bytes_to_copy = @min(total_bytes_to_copy_remaining, head_of_queue.byteLength);

            const dest_start = pullIntoDescriptor.byte_offset + pullIntoDescriptor.bytes_filled;
            const descriptor_buffer = pullIntoDescriptor.buffer;
            const queue_buffer = head_of_queue.buffer;
            const queue_byteOffset = head_of_queue.byteOffset;

            // Copy data
            const src_slice = queue_buffer.data[queue_byteOffset..][0..@intCast(bytes_to_copy)];
            const dst_slice = descriptor_buffer.data[@intCast(dest_start)..][0..@intCast(bytes_to_copy)];
            @memcpy(dst_slice, src_slice);

            // Update queue entry or remove it
            if (head_of_queue.byteLength == bytes_to_copy) {
                const removed = self.byteQueue.orderedRemove(0);
                removed.buffer.deinit(self.allocator);
                self.allocator.destroy(removed.buffer);
            } else {
                head_of_queue.byteOffset += bytes_to_copy;
                head_of_queue.byteLength -= bytes_to_copy;
            }

            self.queueTotalSize -= @as(f64, @floatFromInt(bytes_to_copy));
            self.fillHeadPullIntoDescriptor(bytes_to_copy, pullIntoDescriptor);
            total_bytes_to_copy_remaining -= bytes_to_copy;
        }

        // Step 13: Return ready
        return ready;
    }

    /// Shift (remove) the first pending pull-into descriptor
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerShiftPendingPullInto"
    fn shiftPendingPullInto(self: *ReadableByteStreamController) *PullIntoDescriptor {
        // Step 1: Assert: controller.[[byobRequest]] is null
        // Step 2: Return shift from list
        return self.pendingPullIntos.orderedRemove(0);
    }

    /// Convert pull-into descriptor to typed array view
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerConvertPullIntoDescriptor"
    fn convertPullIntoDescriptor(
        self: *ReadableByteStreamController,
        pullIntoDescriptor: *PullIntoDescriptor,
    ) !webidl.ArrayBufferView {
        // Step 1-4: Extract and validate fields
        const bytes_filled = pullIntoDescriptor.bytes_filled;
        const element_size = pullIntoDescriptor.element_size;

        // Step 5: Transfer buffer
        const transferred_buffer = try pullIntoDescriptor.buffer.transfer();
        const buffer_ptr = try self.allocator.create(ArrayBuffer);
        buffer_ptr.* = transferred_buffer;

        // Step 6: Construct view
        const length = bytes_filled / element_size;
        return try ViewConstruction.constructView(
            pullIntoDescriptor.view_constructor,
            buffer_ptr,
            pullIntoDescriptor.byte_offset,
            length,
        );
    }

    // ============================================================================
    // Internal Control Flow (§ 4.10.11)
    // ============================================================================

    /// Error the controller
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerError"
    fn errorInternal(self: *ReadableByteStreamController, e: common.JSValue) void {
        _ = e; // Will be used for stream error

        // Step 3: Clear pending pull-intos
        self.clearPendingPullIntos();

        // Step 4: Reset queue
        for (self.byteQueue.items) |entry| {
            entry.buffer.deinit(self.allocator);
            self.allocator.destroy(entry.buffer);
        }
        self.byteQueue.clearRetainingCapacity();
        self.queueTotalSize = 0.0;

        // Step 5: Clear algorithms
        self.clearAlgorithms();

        // Step 6: Error the stream (requires stream reference)
        // TODO: Implement when stream integration is ready
    }

    /// Clear all algorithm references
    ///
    /// Spec: § 4.7.4 "ReadableByteStreamControllerClearAlgorithms"
    fn clearAlgorithms(self: *ReadableByteStreamController) void {
        // Reset algorithms to defaults to allow GC
        self.cancelAlgorithm = common.defaultCancelAlgorithm();
        self.pullAlgorithm = common.defaultPullAlgorithm();
    }

    /// Close the controller
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerClose"
    fn closeInternal(self: *ReadableByteStreamController) void {
        // Step 1: Get stream
        const stream_ptr = self.stream orelse return;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 2: If closeRequested or stream not readable, return
        if (self.closeRequested or stream.state != .readable) {
            return;
        }

        // Step 3: If queueTotalSize > 0, set closeRequested and return
        if (self.queueTotalSize > 0) {
            self.closeRequested = true;
            return;
        }

        // Step 4: If pendingPullIntos not empty, check alignment
        if (self.pendingPullIntos.items.len > 0) {
            const first_pending = self.pendingPullIntos.items[0];

            if (first_pending.bytes_filled % first_pending.element_size != 0) {
                const e = common.JSValue{ .string = "Incomplete byte fill in pending pull-into" };
                self.errorInternal(e);
                return;
            }
        }

        // Step 5: Clear algorithms
        self.clearAlgorithms();

        // Step 6: Close the stream
        stream.closeInternal();
    }

    /// Enqueue a chunk
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerEnqueue"
    fn enqueueInternal(self: *ReadableByteStreamController, chunk: webidl.ArrayBufferView) !void {
        // Step 1: Get stream
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 2: If closeRequested or not readable, return
        if (self.closeRequested or stream.state != .readable) {
            return;
        }

        // Step 3-5: Extract buffer details
        const buffer = chunk.getViewedArrayBuffer();
        const byteOffset: u64 = @intCast(chunk.getByteOffset());
        const byteLength: u64 = @intCast(chunk.getByteLength());

        // Step 6: Check if buffer is detached
        if (buffer.isDetached()) {
            return error.TypeError;
        }

        // Step 7: Transfer the buffer
        const internal_buffer = try self.allocator.create(ArrayBuffer);
        internal_buffer.* = .{
            .data = buffer.data,
            .byte_length = buffer.data.len,
            .detached = buffer.detached,
        };
        const transferred_buffer = try internal_buffer.transfer();
        const buffer_ptr = try self.allocator.create(ArrayBuffer);
        buffer_ptr.* = transferred_buffer;
        self.allocator.destroy(internal_buffer);

        // Step 8: If pendingPullIntos not empty, handle specially
        if (self.pendingPullIntos.items.len > 0) {
            const first_pending = self.pendingPullIntos.items[0];

            if (first_pending.buffer.isDetached()) {
                return error.TypeError;
            }

            self.invalidateBYOBRequest();

            // Transfer first pending buffer
            const old_buffer = first_pending.buffer;
            const transferred = try old_buffer.transfer();
            const transferred_ptr = try self.allocator.create(ArrayBuffer);
            transferred_ptr.* = transferred;
            first_pending.buffer = transferred_ptr;
            self.allocator.destroy(old_buffer);

            if (first_pending.reader_type == .none) {
                try self.enqueueDetachedPullIntoToQueue(first_pending);
            }
        }

        // Step 9: If has default reader, process read requests
        if (stream.hasDefaultReader()) {
            try self.processReadRequestsUsingQueue();

            if (stream.getNumReadRequests() == 0) {
                try self.enqueueChunkToQueue(buffer_ptr, byteOffset, byteLength);
            } else {
                if (self.pendingPullIntos.items.len > 0) {
                    _ = self.shiftPendingPullInto();
                }

                const transferred_view = try ViewConstruction.constructView(
                    .uint8_array,
                    buffer_ptr,
                    byteOffset,
                    byteLength,
                );
                // Convert ArrayBufferView to JSValue
                // Note: We use .object since TypedArrays are objects in JavaScript
                // The view itself contains the buffer reference
                _ = transferred_view; // View created but stream expects raw bytes for now
                stream.fulfillReadRequest(common.JSValue{ .bytes = buffer_ptr.data }, false);
            }
        } else if (stream.hasBYOBReader()) {
            // Step 10: Enqueue and process BYOB requests
            try self.enqueueChunkToQueue(buffer_ptr, byteOffset, byteLength);

            var filled_pull_intos = try self.processPullIntoDescriptorsUsingQueue();
            defer filled_pull_intos.deinit(self.allocator);

            for (filled_pull_intos.items) |filled_pull_into| {
                try self.commitPullIntoDescriptor(filled_pull_into);
            }
        } else {
            // Step 11: No reader, just enqueue
            try self.enqueueChunkToQueue(buffer_ptr, byteOffset, byteLength);
        }

        // Step 12: Call pull if needed
        self.callPullIfNeeded();
    }

    // ============================================================================
    // BYOB Read Operations (§ 4.10.11) - CRITICAL ENTRY POINTS
    // ============================================================================

    /// Initiate a BYOB read operation
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerPullInto"
    ///
    /// This is the main entry point for BYOB (bring-your-own-buffer) reads.
    pub fn pullInto(
        self: *ReadableByteStreamController,
        view: webidl.ArrayBufferView,
        min: u64,
        readIntoRequest: ReadIntoRequest,
    ) !void {
        // Step 1: Let stream be controller.[[stream]]
        const stream = self.stream orelse return error.NoStream;
        _ = stream; // TODO: Use when stream integration is ready

        // Steps 2-4: Determine element size and constructor from view
        const element_size: u64 = view.getElementSize();

        // Map TypedArrayName to ViewConstructor
        const ctor = if (view.getTypedArrayName()) |name| blk: {
            break :blk switch (name) {
                .Int8Array => ViewConstructor.int8_array,
                .Uint8Array => ViewConstructor.uint8_array,
                .Uint8ClampedArray => ViewConstructor.uint8_clamped_array,
                .Int16Array => ViewConstructor.int16_array,
                .Uint16Array => ViewConstructor.uint16_array,
                .Int32Array => ViewConstructor.int32_array,
                .Uint32Array => ViewConstructor.uint32_array,
                .BigInt64Array => ViewConstructor.bigint64_array,
                .BigUint64Array => ViewConstructor.biguint64_array,
                .Float32Array => ViewConstructor.float32_array,
                .Float64Array => ViewConstructor.float64_array,
            };
        } else ViewConstructor.data_view;

        // Step 5: Calculate minimum fill
        const minimum_fill = min * element_size;

        // Steps 8-9: Extract byteOffset and byteLength
        const byteOffset: u64 = @intCast(view.getByteOffset());
        const byteLength: u64 = @intCast(view.getByteLength());

        // Step 10: Transfer the ArrayBuffer
        const view_buffer = view.getViewedArrayBuffer();

        // Convert webidl.ArrayBuffer to internal ArrayBuffer
        const internal_buffer = try self.allocator.create(ArrayBuffer);
        internal_buffer.* = .{
            .data = view_buffer.data,
            .byte_length = view_buffer.data.len,
            .detached = view_buffer.detached,
        };

        const transferred_buffer = try internal_buffer.transfer();
        const buffer_ptr = try self.allocator.create(ArrayBuffer);
        buffer_ptr.* = transferred_buffer;
        self.allocator.destroy(internal_buffer);

        // Step 13: Create pull-into descriptor
        const pullIntoDescriptor = try self.allocator.create(PullIntoDescriptor);
        pullIntoDescriptor.* = PullIntoDescriptor.init(
            buffer_ptr,
            buffer_ptr.byte_length,
            byteOffset,
            byteLength,
            minimum_fill,
            element_size,
            ctor,
            .byob,
        );

        // Step 17: Append descriptor to pending list
        try self.pendingPullIntos.append(self.allocator, pullIntoDescriptor);

        // Store the readIntoRequest for later fulfillment
        // TODO: Add to stream's readIntoRequests list
        _ = readIntoRequest;

        // Step 19: Call pull if needed
        // TODO: Implement callPullIfNeeded when stream integration is ready
    }

    /// Respond with bytes written to BYOB buffer
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerRespond"
    pub fn respond(self: *ReadableByteStreamController, bytesWritten: u64) !void {
        // Step 1: Assert controller.[[pendingPullIntos]] is not empty
        if (self.pendingPullIntos.items.len == 0) {
            return error.InvalidState;
        }

        // Step 2: Let firstDescriptor be controller.[[pendingPullIntos]][0]
        const firstDescriptor = self.pendingPullIntos.items[0];

        // Step 3: Let state be controller.[[stream]].[[state]]
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));
        const state = stream.state;

        // Step 4: If state is "closed"
        if (state == .closed) {
            // Step 4.1: If bytesWritten is not 0, throw TypeError
            if (bytesWritten != 0) {
                return error.TypeError;
            }
        } else {
            // Step 5: Otherwise (state is "readable")
            // Step 5.1: Assert state is "readable"
            if (state != .readable) {
                return error.InvalidState;
            }

            // Step 5.2: If bytesWritten is 0, throw TypeError
            if (bytesWritten == 0) {
                return error.TypeError;
            }

            // Step 5.3: If firstDescriptor's bytes filled + bytesWritten > firstDescriptor's byte length, throw RangeError
            if (firstDescriptor.bytes_filled + bytesWritten > firstDescriptor.byte_length) {
                return error.RangeError;
            }
        }

        // Step 6: Set firstDescriptor's buffer to ! TransferArrayBuffer(firstDescriptor's buffer)
        const old_buffer = firstDescriptor.buffer;
        const transferred = try old_buffer.transfer();
        const transferred_ptr = try self.allocator.create(ArrayBuffer);
        transferred_ptr.* = transferred;
        firstDescriptor.buffer = transferred_ptr;
        self.allocator.destroy(old_buffer);

        // Step 7: Perform ? ReadableByteStreamControllerRespondInternal(controller, bytesWritten)
        try self.respondInternal(bytesWritten);
    }

    /// Wrapper for WebIDL call convention
    pub fn call_respond(self: *ReadableByteStreamController, bytesWritten: u64) !void {
        return self.respond(bytesWritten);
    }

    /// Respond with a new view (replacement buffer)
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerRespondWithNewView"
    pub fn respondWithNewView(self: *ReadableByteStreamController, view: webidl.ArrayBufferView) !void {
        // Step 1: Assert: controller.[[pendingPullIntos]] is not empty
        if (self.pendingPullIntos.items.len == 0) {
            return error.InvalidState;
        }

        // Step 2: Assert: ! IsDetachedBuffer(view.[[ViewedArrayBuffer]]) is false
        if (view.isDetached()) {
            return error.DetachedBuffer;
        }

        // Step 3: Let firstDescriptor be controller.[[pendingPullIntos]][0]
        const firstDescriptor = self.pendingPullIntos.items[0];

        // Step 4: Let state be controller.[[stream]].[[state]]
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));
        const state = stream.state;

        // Step 5: If state is "closed"
        if (state == .closed) {
            // Step 5.1: If view.[[ByteLength]] is not 0, throw TypeError
            if (view.getByteLength() != 0) {
                return error.TypeError;
            }
        } else {
            // Step 6: Otherwise (state is "readable")
            // Step 6.1: Assert: state is "readable"
            if (state != .readable) {
                return error.InvalidState;
            }

            // Step 6.2: If view.[[ByteLength]] is 0, throw TypeError
            if (view.getByteLength() == 0) {
                return error.TypeError;
            }
        }

        // Extract view properties
        const view_byteOffset: u64 = @intCast(view.getByteOffset());
        const view_byteLength: u64 = @intCast(view.getByteLength());
        const view_buffer = view.getViewedArrayBuffer();

        // Step 7: If firstDescriptor's byte offset + firstDescriptor's bytes filled is not view.[[ByteOffset]], throw RangeError
        if (firstDescriptor.byte_offset + firstDescriptor.bytes_filled != view_byteOffset) {
            return error.RangeError;
        }

        // Step 8: If firstDescriptor's buffer byte length is not view.[[ViewedArrayBuffer]].[[ByteLength]], throw RangeError
        if (firstDescriptor.buffer.byte_length != view_buffer.data.len) {
            return error.RangeError;
        }

        // Step 9: If firstDescriptor's bytes filled + view.[[ByteLength]] > firstDescriptor's byte length, throw RangeError
        if (firstDescriptor.bytes_filled + view_byteLength > firstDescriptor.byte_length) {
            return error.RangeError;
        }

        // Step 10: Let viewByteLength be view.[[ByteLength]]
        const viewByteLength = view_byteLength;

        // Step 11: Set firstDescriptor's buffer to ? TransferArrayBuffer(view.[[ViewedArrayBuffer]])
        const internal_buffer = try self.allocator.create(ArrayBuffer);
        internal_buffer.* = .{
            .data = view_buffer.data,
            .byte_length = view_buffer.data.len,
            .detached = view_buffer.detached,
        };
        const transferred = try internal_buffer.transfer();

        // Free old buffer before replacing
        firstDescriptor.buffer.deinit(self.allocator);
        self.allocator.destroy(firstDescriptor.buffer);

        const transferred_ptr = try self.allocator.create(ArrayBuffer);
        transferred_ptr.* = transferred;
        firstDescriptor.buffer = transferred_ptr;
        self.allocator.destroy(internal_buffer);

        // Step 12: Perform ? ReadableByteStreamControllerRespondInternal(controller, viewByteLength)
        try self.respondInternal(viewByteLength);
    }

    /// Wrapper for WebIDL call convention
    pub fn call_respondWithNewView(self: *ReadableByteStreamController, view: webidl.ArrayBufferView) !void {
        return self.respondWithNewView(view);
    }

    /// Internal respond implementation
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerRespondInternal"
    fn respondInternal(self: *ReadableByteStreamController, bytesWritten: u64) !void {
        // Step 1: Let firstDescriptor be controller.[[pendingPullIntos]][0]
        const firstDescriptor = self.pendingPullIntos.items[0];

        // Step 2: Assert: ! CanTransferArrayBuffer(firstDescriptor's buffer) is true
        // (Already transferred in respond())

        // Step 3: Perform ! ReadableByteStreamControllerInvalidateBYOBRequest(controller)
        self.invalidateBYOBRequest();

        // Step 4: Let state be controller.[[stream]].[[state]]
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));
        const state = stream.state;

        // Step 5: If state is "closed"
        if (state == .closed) {
            // Step 5.1: Assert: bytesWritten is 0
            // Step 5.2: Perform ! ReadableByteStreamControllerRespondInClosedState(controller, firstDescriptor)
            self.respondInClosedState(firstDescriptor);
        } else {
            // Step 6: Otherwise (state is "readable")
            // Step 6.1: Assert: state is "readable"
            // Step 6.2: Assert: bytesWritten > 0
            // Step 6.3: Perform ? ReadableByteStreamControllerRespondInReadableState(controller, bytesWritten, firstDescriptor)
            try self.respondInReadableState(bytesWritten, firstDescriptor);
        }

        // Step 7: Perform ! ReadableByteStreamControllerCallPullIfNeeded(controller)
        self.callPullIfNeeded();
    }

    /// Respond when stream is in closed state
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerRespondInClosedState"
    fn respondInClosedState(
        self: *ReadableByteStreamController,
        firstDescriptor: *PullIntoDescriptor,
    ) void {
        // Step 1: Assert: the remainder after dividing firstDescriptor's bytes filled by firstDescriptor's element size is 0
        // (Assertion - caller ensures this)

        // Step 2: If firstDescriptor's reader type is "none", perform ! ReadableByteStreamControllerShiftPendingPullInto(controller)
        if (firstDescriptor.reader_type == .none) {
            _ = self.shiftPendingPullInto();
        }

        // Step 3: Let stream be controller.[[stream]]
        const stream_ptr = self.stream orelse return;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 4: If ! ReadableStreamHasBYOBReader(stream) is true
        if (stream.hasBYOBReader()) {
            // Step 4.1: Let filledPullIntos be a new empty list
            var filled_pull_intos = infra.List(*PullIntoDescriptor){};
            defer filled_pull_intos.deinit(self.allocator);

            // Step 4.2: While filledPullIntos's size < ! ReadableStreamGetNumReadIntoRequests(stream)
            while (filled_pull_intos.items.len < stream.getNumReadIntoRequests()) {
                // Step 4.2.1: Let pullIntoDescriptor be ! ReadableByteStreamControllerShiftPendingPullInto(controller)
                const pull_into_descriptor = self.shiftPendingPullInto();

                // Step 4.2.2: Append pullIntoDescriptor to filledPullIntos
                filled_pull_intos.append(self.allocator, pull_into_descriptor) catch break;
            }

            // Step 4.3: For each filledPullInto of filledPullIntos
            for (filled_pull_intos.items) |filled_pull_into| {
                // Step 4.3.1: Perform ! ReadableByteStreamControllerCommitPullIntoDescriptor(stream, filledPullInto)
                self.commitPullIntoDescriptor(filled_pull_into) catch continue;
            }
        }
    }

    /// Respond when stream is in readable state
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerRespondInReadableState"
    fn respondInReadableState(
        self: *ReadableByteStreamController,
        bytesWritten: u64,
        pullIntoDescriptor: *PullIntoDescriptor,
    ) !void {
        // Step 2: Fill the descriptor
        self.fillHeadPullIntoDescriptor(bytesWritten, pullIntoDescriptor);

        // Step 3: Handle reader type "none"
        if (pullIntoDescriptor.reader_type == .none) {
            try self.enqueueDetachedPullIntoToQueue(pullIntoDescriptor);
            // TODO: Process pull-into descriptors using queue
            return;
        }

        // Step 4: Check if minimum fill is met
        if (pullIntoDescriptor.bytes_filled < pullIntoDescriptor.minimum_fill) {
            return;
        }

        // Step 5: Shift the descriptor
        _ = self.shiftPendingPullInto();

        // Step 6-8: Handle remainder bytes
        const remainder_size = pullIntoDescriptor.bytes_filled % pullIntoDescriptor.element_size;
        if (remainder_size > 0) {
            const end = pullIntoDescriptor.byte_offset + pullIntoDescriptor.bytes_filled;
            try self.enqueueClonedChunkToQueue(
                pullIntoDescriptor.buffer,
                end - remainder_size,
                remainder_size,
            );
            pullIntoDescriptor.bytes_filled -= remainder_size;
        }

        // Step 10: Commit the descriptor
        try self.commitPullIntoDescriptor(pullIntoDescriptor);

        // Clean up the descriptor
        pullIntoDescriptor.buffer.deinit(self.allocator);
        self.allocator.destroy(pullIntoDescriptor.buffer);
        self.allocator.destroy(pullIntoDescriptor);
    }

    /// Commit a pull-into descriptor by converting and fulfilling
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerCommitPullIntoDescriptor"
    fn commitPullIntoDescriptor(
        self: *ReadableByteStreamController,
        pullIntoDescriptor: *PullIntoDescriptor,
    ) !void {
        // Step 1: Get stream
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 3: Determine done flag
        var done = false;
        if (stream.state == .closed) {
            done = true;
        }

        // Step 5: Convert descriptor to view
        const filled_view = try self.convertPullIntoDescriptor(pullIntoDescriptor);

        // Step 6-7: Fulfill based on reader type
        if (pullIntoDescriptor.reader_type == .default) {
            // Step 6: Fulfill read request
            // For default readers, we fulfill with an object marker
            // Note: filled_view is an ArrayBufferView which would be the actual value
            // but fulfillReadRequest currently expects a simple JSValue marker
            stream.fulfillReadRequest(common.JSValue{ .object = {} }, done);
        } else {
            // Step 7: Fulfill read-into request
            // For BYOB readers, pass the actual view
            stream.fulfillReadIntoRequest(filled_view, done);
        }
    }

    // ============================================================================
    // Pull Coordination and Queue Processing (§ 4.10.11)
    // ============================================================================

    /// Check if pull should be called
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerShouldCallPull"
    fn shouldCallPull(self: *const ReadableByteStreamController) bool {
        // Step 1: Let stream be controller.[[stream]]
        const stream_ptr = self.stream orelse return false;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *const ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 2: If stream.[[state]] is not "readable", return false
        if (stream.state != .readable) {
            return false;
        }

        // Step 3: If controller.[[closeRequested]] is true, return false
        if (self.closeRequested) {
            return false;
        }

        // Step 4: If controller.[[started]] is false, return false
        if (!self.started) {
            return false;
        }

        // Step 5: If has default reader and read requests > 0, return true
        if (stream.hasDefaultReader() and stream.getNumReadRequests() > 0) {
            return true;
        }

        // Step 6: If has BYOB reader and read-into requests > 0, return true
        if (stream.hasBYOBReader() and stream.getNumReadIntoRequests() > 0) {
            return true;
        }

        // Step 7-9: Check desired size
        const desired_size = self.get_desiredSize();
        if (desired_size) |size| {
            if (size > 0) {
                return true;
            }
        }

        // Step 10: Return false
        return false;
    }

    /// Call pull if needed
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerCallPullIfNeeded"
    pub fn callPullIfNeeded(self: *ReadableByteStreamController) void {
        // Step 1: Determine if pull should be called
        const should_pull = self.shouldCallPull();

        // Step 2: If not needed, return
        if (!should_pull) {
            return;
        }

        // Step 3: If already pulling, set pullAgain flag
        if (self.pulling) {
            self.pullAgain = true;
            return;
        }

        // Step 5: Set pulling flag
        self.pulling = true;

        // Step 6: Call pull algorithm
        const pull_result = self.pullAlgorithm.call();

        // Step 7: On fulfillment
        if (pull_result.isFulfilled()) {
            self.pulling = false;

            // Step 7.2: If pullAgain, call again
            if (self.pullAgain) {
                self.pullAgain = false;
                self.callPullIfNeeded();
            }
        }

        // Step 8: On rejection
        if (pull_result.isRejected()) {
            const exception = pull_result.error_value orelse webidl.errors.Exception.typeError(self.allocator, "Pull failed") catch return;
            const error_value = common.JSValue{ .string = exception.toString() };
            self.errorInternal(error_value);
        }
    }

    /// Process pull-into descriptors using queue
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue"
    fn processPullIntoDescriptorsUsingQueue(
        self: *ReadableByteStreamController,
    ) !infra.List(*PullIntoDescriptor) {
        // Step 2: Create result list
        var filled_pull_intos = infra.List(*PullIntoDescriptor){};
        errdefer filled_pull_intos.deinit(self.allocator);

        // Step 3: Process pending pull-intos
        while (self.pendingPullIntos.items.len > 0) {
            // Step 3.1: If queue is empty, break
            if (self.queueTotalSize == 0) {
                break;
            }

            // Step 3.2: Get first descriptor
            const pullIntoDescriptor = self.pendingPullIntos.items[0];

            // Step 3.3: Try to fill from queue
            if (self.fillPullIntoDescriptorFromQueue(pullIntoDescriptor)) {
                // Step 3.3.1: Shift the descriptor
                _ = self.shiftPendingPullInto();

                // Step 3.3.2: Add to filled list
                try filled_pull_intos.append(self.allocator, pullIntoDescriptor);
            }
        }

        // Step 4: Return filled descriptors
        return filled_pull_intos;
    }

    /// Handle queue drain (empty queue with close requested)
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerHandleQueueDrain"
    pub fn handleQueueDrain(self: *ReadableByteStreamController) void {
        // Step 2: If queue is empty and close requested, close the stream
        if (self.queueTotalSize == 0.0 and self.closeRequested) {
            self.clearAlgorithms();

            const stream_ptr = self.stream orelse return;
            const ReadableStreamModule = @import("readable_stream");
            const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));
            stream.closeInternal();
        } else {
            // Step 3: Otherwise, call pull if needed
            self.callPullIfNeeded();
        }
    }

    /// Process all pending read requests using queue (for default readers)
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerProcessReadRequestsUsingQueue"
    pub fn processReadRequestsUsingQueue(self: *ReadableByteStreamController) !void {
        // Step 1: Get stream
        const stream_ptr = self.stream orelse return;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 3: Process all read requests
        while (stream.getNumReadRequests() > 0) {
            // Step 3.1: If queue is empty, return
            if (self.queueTotalSize == 0) {
                return;
            }

            // Step 3.4: Fill read request from queue
            try self.fillReadRequestFromQueue();
        }
    }

    /// Fill a read request from the queue (for default readers)
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerFillReadRequestFromQueue"
    fn fillReadRequestFromQueue(self: *ReadableByteStreamController) !void {
        // Step 2: Remove first queue entry
        const entry = self.byteQueue.items[0];
        _ = self.byteQueue.orderedRemove(0);

        // Step 4: Update queue size
        self.queueTotalSize -= @as(f64, @floatFromInt(entry.byteLength));

        // Step 5: Handle queue drain
        self.handleQueueDrain();

        // Step 6: Create Uint8Array view
        const view = try ViewConstruction.constructView(
            .uint8_array,
            entry.buffer,
            entry.byteOffset,
            entry.byteLength,
        );

        // Step 7: Fulfill the read request
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Convert view to JSValue
        // The view is an ArrayBufferView (Uint8Array), which is an object in JavaScript
        // For now, we pass the raw bytes since fulfillReadRequest expects bytes
        // Full implementation would wrap this in a proper JSValue.object variant
        _ = view; // View constructed but raw bytes used for fulfillment
        const chunk_value = common.JSValue{ .bytes = entry.buffer.data };
        stream.fulfillReadRequest(chunk_value, false);
    }

    /// Get BYOB request for this controller
    ///
    /// Spec: § 4.10.11 "ReadableByteStreamControllerGetBYOBRequest"
    pub fn call_getBYOBRequest(self: *ReadableByteStreamController) !?*ReadableStreamBYOBRequest {
        // Step 1: If byobRequest is null and pendingPullIntos is not empty
        if (self.byobRequest == null and self.pendingPullIntos.items.len > 0) {
            const firstDescriptor = self.pendingPullIntos.items[0];

            // Create Uint8Array view for the BYOB request
            const view_byteOffset = firstDescriptor.byte_offset + firstDescriptor.bytes_filled;
            const view_byteLength = firstDescriptor.byte_length - firstDescriptor.bytes_filled;

            // Convert internal ArrayBuffer to webidl.ArrayBuffer
            var webidl_buffer = webidl.ArrayBuffer{
                .data = firstDescriptor.buffer.data,
                .detached = firstDescriptor.buffer.detached,
            };

            const Uint8ArrayType = webidl.TypedArray(u8);
            const uint8_view = try Uint8ArrayType.init(
                &webidl_buffer,
                view_byteOffset,
                view_byteLength,
            );
            const view = webidl.ArrayBufferView{ .uint8_array = uint8_view };

            // Create BYOB request
            const byobRequest = try self.allocator.create(ReadableStreamBYOBRequest);
            errdefer self.allocator.destroy(byobRequest);

            // Initialize BYOB request with controller and view
            byobRequest.* = try ReadableStreamBYOBRequest.init(
                self.allocator,
                @ptrCast(self),
                view,
            );

            self.byobRequest = byobRequest;
        }

        // Step 2: Return the request
        return self.byobRequest;
    }

    // ============================================================================
    // Byte Stream Tee (§ 3.3.9)
    // ============================================================================

    /// Tee this byte stream into two independent branches
    ///
    /// Spec: § 3.3.9 "ReadableByteStreamTee(stream)"
    ///
    /// This is a simplified implementation suitable for basic use cases.
    /// Full spec implementation requires:
    /// - Dynamic reader switching (default ↔ BYOB)
    /// - Microtask queueing
    /// - CloneAsUint8Array for chunks
    /// - Complex error forwarding
    ///
    /// Current implementation creates two independent branches that share
    /// the underlying byte stream controller.
    pub fn tee(self: *ReadableByteStreamController) !struct { branch1: *anyopaque, branch2: *anyopaque } {
        // Get the stream
        const stream_ptr = self.stream orelse return error.NoStream;
        const ReadableStreamModule = @import("readable_stream");
        const stream: *ReadableStreamModule.ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Create two new streams that share this controller
        const branch1 = try self.allocator.create(ReadableStreamModule.ReadableStream);
        errdefer self.allocator.destroy(branch1);
        branch1.* = try ReadableStreamModule.ReadableStream.init(self.allocator);

        const branch2 = try self.allocator.create(ReadableStreamModule.ReadableStream);
        errdefer self.allocator.destroy(branch2);
        branch2.* = try ReadableStreamModule.ReadableStream.init(self.allocator);

        // TODO: Wire both branches to share this controller
        // BLOCKED: ReadableStream.controller is typed as *ReadableStreamDefaultController
        // but needs to be union to support *ReadableByteStreamController too
        // For now, just return the branches without proper controller wiring
        branch1.state = stream.state;
        branch2.state = stream.state;

        return .{
            .branch1 = @ptrCast(branch1),
            .branch2 = @ptrCast(branch2),
        };
    }
}, .{
    .exposed = &.{.global},
});
