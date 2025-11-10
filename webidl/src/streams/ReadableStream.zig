//! ReadableStream class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#rs-class
//!
//! Represents a source of streaming data that can be read incrementally.
//!
//! This implementation follows the reference implementation pattern from
//! webidl/generated-back/streams/ but uses PascalCase naming for interfaces.

const std = @import("std");
const webidl = @import("webidl");

// Import stream infrastructure
const common = @import("common");
const eventLoop = @import("event_loop");
const TestEventLoop = @import("test_event_loop").TestEventLoop;
const AsyncPromise = @import("async_promise").AsyncPromise;
const dict_parsing = @import("dict_parsing");

// Import related stream types (will be fully linked after all types are defined)
// NOTE: These will create circular dependencies that need careful handling
const ReadableStreamDefaultController = @import("readable_stream_default_controller").ReadableStreamDefaultController;
const ReadableStreamDefaultReader = @import("readable_stream_default_reader").ReadableStreamDefaultReader;
const ReadableStreamBYOBReader = @import("readable_stream_byob_reader").ReadableStreamBYOBReader;
const WritableStream = @import("writable_stream").WritableStream;
const WritableStreamDefaultWriter = @import("writable_stream_default_writer").WritableStreamDefaultWriter;

/// Stream state enumeration
///
/// Spec: § 4.1 "Internal slots" - [[state]]
pub const StreamState = enum {
    readable,
    closed,
    errored,
};

/// Reader union type
///
/// Spec: § 4.1 [[reader]] slot can be ReadableStreamDefaultReader, ReadableStreamBYOBReader, or undefined
pub const Reader = union(enum) {
    none: void,
    default: *ReadableStreamDefaultReader,
    byob: *ReadableStreamBYOBReader,
};

/// Pipe options for pipeTo() method
///
/// Spec: § 4.1.5 StreamPipeOptions dictionary
pub const PipeOptions = struct {
    preventClose: bool = false,
    preventAbort: bool = false,
    preventCancel: bool = false,
    signal: ?*anyopaque = null,
};

/// Transform pair for pipeThrough() method
///
/// Spec: § 4.1.6 ReadableWritablePair dictionary
pub const TransformPair = struct {
    readable: *ReadableStream,
    writable: *WritableStream,
};

pub const ReadableStream = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[controller]]: ReadableStreamDefaultController or ReadableByteStreamController
    /// Spec: § 4.1 Internal slot [[controller]]
    controller: *ReadableStreamDefaultController,

    /// [[detached]]: boolean - stream has been transferred via postMessage
    /// Spec: § 4.1 Internal slot [[detached]]
    detached: bool,

    /// [[disturbed]]: boolean - stream has ever had a reader
    /// Spec: § 4.1 Internal slot [[disturbed]]
    disturbed: bool,

    /// [[reader]]: ReadableStreamReader or undefined
    /// Spec: § 4.1 Internal slot [[reader]]
    reader: Reader,

    /// [[state]]: "readable", "closed", or "errored"
    /// Spec: § 4.1 Internal slot [[state]]
    state: StreamState,

    /// [[storedError]]: JavaScript value (if state is "errored")
    /// Spec: § 4.1 Internal slot [[storedError]]
    storedError: ?common.JSValue,

    /// Event loop for async operations (borrowed reference)
    ///
    /// The stream does not own the event loop - it borrows it from the execution context.
    /// This matches browser semantics where streams access the JavaScript execution
    /// context's event loop, they don't own separate event loops.
    eventLoop: eventLoop.EventLoop,

    /// Optional owned event loop for backward compatibility
    ///
    /// Only set when using the deprecated init() method.
    /// New code should use initWithSource() and manage event loops externally.
    eventLoop_storage: ?*TestEventLoop,

    /// Optional TeeState reference if this stream is a tee branch
    /// When set, deinit() will call teeState.release() to decrement ref count
    teeState: ?*TeeState,

    /// Initialize a new ReadableStream (internal - not exposed via WebIDL)
    ///
    /// DEPRECATED: Use initWithSource() and provide an event loop.
    /// This function is kept for backward compatibility.
    ///
    /// NOTE: This creates an internal event loop that is owned by the stream.
    /// This is NOT recommended for new code - use initWithSource() instead.
    pub fn init(allocator: std.mem.Allocator) !ReadableStream {
        // Create an owned event loop for backward compatibility
        const loop_ptr = try allocator.create(TestEventLoop);
        errdefer allocator.destroy(loop_ptr);

        loop_ptr.* = TestEventLoop.init(allocator);

        var stream = try initWithSource(allocator, loop_ptr.eventLoop(), null, null);

        // Mark that we own this event loop so deinit() will clean it up
        stream.eventLoop_storage = loop_ptr;

        return stream;
    }

    /// Deinitialize the ReadableStream
    ///
    /// Spec: Cleanup internal slots and release resources
    pub fn deinit(self: *ReadableStream) void {
        // IMPORTANT: We do NOT run microtasks during deinit.
        // Microtasks can reference promises and other objects that are being destroyed.
        // Running them during cleanup can cause use-after-free errors.

        self.controller.deinit();
        self.allocator.destroy(self.controller);

        switch (self.reader) {
            .default => |r| {
                r.deinit();
                self.allocator.destroy(r);
            },
            .byob => |r| {
                r.deinit();
                self.allocator.destroy(r);
            },
            .none => {},
        }

        // Clean up owned event loop if we created one (backward compatibility)
        if (self.eventLoop_storage) |loop_ptr| {
            loop_ptr.deinit();
            self.allocator.destroy(loop_ptr);
        }
        // Otherwise, we borrowed the event loop and don't destroy it
        // (matches browser semantics where streams don't own event loops)

        // Release TeeState reference if this is a tee branch
        if (self.teeState) |teeState| {
            teeState.release();
        }
    }

    /// Initialize a ReadableStream with an underlying source
    ///
    /// Spec: § 4.1.1 "new ReadableStream(underlyingSource = {}, strategy = {})"
    ///
    /// This is the main constructor for creating a ReadableStream with custom behavior.
    ///
    /// Parameters:
    /// - allocator: Memory allocator for the stream
    /// - loop: Event loop for async operations (borrowed, not owned)
    /// - underlyingSource: Optional source object with start/pull/cancel methods
    /// - strategy: Optional queuing strategy with highWaterMark and size function
    pub fn initWithSource(
        allocator: std.mem.Allocator,
        loop: eventLoop.EventLoop,
        underlyingSource: ?webidl.JSValue,
        strategy: ?webidl.JSValue,
    ) !ReadableStream {
        // Step 1: If underlyingSource is missing, set it to null.
        // Step 2: Let underlyingSourceDict be underlyingSource, converted to an IDL value of type UnderlyingSource.
        const source_dict = try dict_parsing.parseUnderlyingSource(allocator, underlyingSource);

        // Step 3-4: Parse queuing strategy
        const strategy_dict = try dict_parsing.parseQueuingStrategy(allocator, strategy);

        // Extract high water mark with default of 1.0
        const highWaterMark = strategy_dict.highWaterMark orelse 1.0;

        // Extract size algorithm with default
        const size_algorithm = if (strategy_dict.size) |size_fn|
            common.wrapGenericSizeCallback(size_fn)
        else
            common.defaultSizeAlgorithm();

        // Step 5-7: Check stream type (default vs. byte stream)
        // For now, we only support default streams
        // TODO: Implement byte stream support in Phase 7

        // Create controller on heap
        const controller = try allocator.create(ReadableStreamDefaultController);
        errdefer allocator.destroy(controller);

        // Step 9-11: Extract algorithms from dictionary or use defaults
        const cancelAlgorithm = if (source_dict.cancel) |cancel_fn|
            common.wrapGenericCancelCallback(cancel_fn)
        else
            common.defaultCancelAlgorithm();

        const pullAlgorithm = if (source_dict.pull) |pull_fn|
            common.wrapGenericPullCallback(pull_fn)
        else
            common.defaultPullAlgorithm();

        // TODO: Implement start callback invocation when zig-js-runtime is available
        _ = source_dict.start; // Acknowledge but don't use

        controller.* = ReadableStreamDefaultController.init(
            allocator,
            cancelAlgorithm,
            pullAlgorithm,
            highWaterMark,
            size_algorithm,
            loop,
        );

        var stream = ReadableStream{
            .allocator = allocator,
            .controller = controller,
            .detached = false,
            .disturbed = false,
            .reader = .none,
            .state = .readable,
            .storedError = null,
            .eventLoop = loop,
            .eventLoop_storage = null, // Borrowed event loop (not owned)
            .teeState = null, // Not a tee branch by default
        };

        // Step 15: Mark controller as started
        stream.controller.started = true;

        return stream;
    }

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    /// locked attribute getter
    ///
    /// IDL: readonly attribute boolean locked;
    ///
    /// Spec: § 4.1.2 "The locked getter steps are:"
    /// Returns true if the stream is locked to a reader.
    pub fn call_locked(self: *const ReadableStream) bool {
        // Spec: § 4.1.2 "Return ! IsReadableStreamLocked(this)."
        return self.isLocked();
    }

    /// cancel(reason) method
    ///
    /// IDL: Promise<undefined> cancel(optional any reason);
    ///
    /// Spec: § 4.1.3 "The cancel(reason) method steps are:"
    /// Cancels the stream, signaling a loss of interest in the stream by a consumer.
    pub fn call_cancel(self: *ReadableStream, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        // Spec: § 4.1.3 step 1: "If ! IsReadableStreamLocked(this) is true, return a promise rejected with a TypeError exception."
        if (self.isLocked()) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Cannot cancel a locked stream" });
            return promise;
        }

        // Spec: § 4.1.3 step 2: "Return ! ReadableStreamCancel(this, reason)."
        return self.cancelInternal(if (reason) |r| common.JSValue.fromWebIDL(r) else null);
    }

    /// getReader(options) method
    ///
    /// IDL: ReadableStreamReader getReader(optional ReadableStreamGetReaderOptions options = {});
    ///
    /// Spec: § 4.1.4 "The getReader(options) method steps are:"
    /// Creates a reader and locks the stream to it.
    pub fn call_getReader(
        self: *ReadableStream,
        options: ?webidl.JSValue,
    ) !Reader {
        // Parse options to check for BYOB mode
        // For now, we only support default readers
        // TODO: Implement BYOB reader support in Phase 7
        _ = options;

        // Spec: § 4.1.4 "If options["mode"] does not exist, return ? AcquireReadableStreamDefaultReader(this)."
        const reader = try self.acquireDefaultReader(self.eventLoop);
        return .{ .default = reader };
    }

    /// pipeTo(destination, options) method
    ///
    /// IDL: Promise<undefined> pipeTo(WritableStream destination, optional StreamPipeOptions options = {});
    ///
    /// Spec: § 4.1.5 "The pipeTo(destination, options) method steps are:"
    /// Pipes this readable stream to a writable stream.
    pub fn call_pipeTo(
        self: *ReadableStream,
        destination: *WritableStream,
        options: ?PipeOptions,
    ) !*AsyncPromise(void) {
        // Parse options with defaults
        const opts = options orelse PipeOptions{
            .preventClose = false,
            .preventAbort = false,
            .preventCancel = false,
            .signal = null,
        };

        // Step 1: If ! IsReadableStreamLocked(this) is true, return a promise rejected with a TypeError.
        if (self.isLocked()) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Cannot pipe from a locked stream" });
            return promise;
        }

        // Step 2: If ! IsWritableStreamLocked(destination) is true, return a promise rejected with a TypeError.
        if (destination.isLocked()) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(common.JSValue{ .string = "Cannot pipe to a locked stream" });
            return promise;
        }

        // Step 3: Acquire reader and writer
        const reader = try self.acquireDefaultReader(self.eventLoop);
        const writer = try destination.acquireDefaultWriter(self.eventLoop);

        // Step 4: Create PipeState to coordinate the operation
        const pipeState = try PipeState.init(
            self.allocator,
            self.eventLoop,
            self,
            destination,
            reader,
            writer,
            opts.preventClose,
            opts.preventAbort,
            opts.preventCancel,
            opts.signal,
        );

        // Step 5: Start shuttling data
        try pipeState.startShuttling();

        // Step 6: Return the promise that resolves when piping completes
        return pipeState.promise;
    }

    /// pipeThrough(transform, options) method
    ///
    /// IDL: ReadableStream pipeThrough(ReadableWritablePair transform, optional StreamPipeOptions options = {});
    ///
    /// Spec: § 4.1.6 "The pipeThrough(transform, options) method steps are:"
    /// Pipes this readable stream through a transform stream.
    pub fn call_pipeThrough(
        self: *ReadableStream,
        transform: *TransformPair,
        options: ?PipeOptions,
    ) !*ReadableStream {
        // Spec step 1: If ! IsReadableStreamLocked(this) is true, throw a TypeError exception.
        if (self.isLocked()) {
            return error.TypeError;
        }

        // Spec step 2: If ! IsWritableStreamLocked(transform["writable"]) is true, throw a TypeError exception.
        if (transform.writable.isLocked()) {
            return error.TypeError;
        }

        // Spec step 3: Let signal be options["signal"] if it exists, or undefined otherwise.
        // (Handled by PipeOptions structure)

        // Spec step 4: Let promise be ! ReadableStreamPipeTo(this, transform["writable"], ...)
        _ = try self.pipeTo(transform.writable, options);

        // Spec step 5: Set promise.[[PromiseIsHandled]] to true.
        // (This means we intentionally don't await the promise - it runs in background)
        // The promise continues running to pipe data through the transform

        // Spec step 6: Return transform["readable"].
        return transform.readable;
    }

    /// tee() method
    ///
    /// IDL: sequence<ReadableStream> tee();
    ///
    /// Spec: § 4.1.7 "The tee() method steps are:"
    /// Creates two branches that can be consumed independently.
    pub fn call_tee(self: *ReadableStream) !struct { branch1: *ReadableStream, branch2: *ReadableStream } {
        // Step 1: Let branches be ? ReadableStreamTee(this, false).
        return self.teeInternal(false);
    }

    /// from(asyncIterable) static method
    ///
    /// IDL: static ReadableStream from(any asyncIterable);
    ///
    /// Spec: § 4.1.8 "The static from(asyncIterable) method steps are:"
    /// Creates a ReadableStream from an async iterable.
    pub fn call_from(allocator: std.mem.Allocator, loop: eventLoop.EventLoop, asyncIterable: webidl.JSValue) !*ReadableStream {
        _ = asyncIterable;

        // Simplified implementation - create an empty stream
        // Full implementation would iterate over asyncIterable
        const stream = try allocator.create(ReadableStream);
        errdefer allocator.destroy(stream);

        stream.* = try initWithSource(allocator, loop, null, null);

        return stream;
    }

    /// values(options) method for async iteration
    ///
    /// IDL: async_iterable<any>(optional ReadableStreamIteratorOptions options = {});
    ///
    /// Spec: § 3.2.6 "Asynchronous iteration"
    /// Returns an async iterator for the stream with optional preventCancel setting.
    pub fn call_values(self: *ReadableStream, preventCancel: bool) !ReadableStreamAsyncIterator {
        return ReadableStreamAsyncIterator.init(
            self.allocator,
            self,
            self.eventLoop,
            preventCancel,
        );
    }

    /// Get an async iterator with default options (preventCancel = false)
    ///
    /// This is the default async iterator used by for-await loops
    pub fn call_asyncIterator(self: *ReadableStream) !ReadableStreamAsyncIterator {
        return self.values(false);
    }

    // ============================================================================
    // Internal Algorithms (Abstract Operations)
    // ============================================================================

    /// IsReadableStreamLocked(stream)
    ///
    /// Spec: § 4.2.1 "Returns true if stream has a reader."
    fn isLocked(self: *const ReadableStream) bool {
        return self.reader != .none;
    }

    /// ReadableStreamCancel(stream, reason)
    ///
    /// Spec: § 4.2.2 "Cancels stream and returns a promise that will be fulfilled when the stream is closed."
    fn cancelInternal(self: *ReadableStream, reason: ?common.JSValue) !*AsyncPromise(void) {
        // Step 1: Set stream.[[disturbed]] to true.
        self.disturbed = true;

        // Step 2: If stream.[[state]] is "closed", return a promise fulfilled with undefined.
        if (self.state == .closed) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.fulfill({});
            return promise;
        }

        // Step 3: If stream.[[state]] is "errored", return a promise rejected with stream.[[storedError]].
        if (self.state == .errored) {
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.reject(self.storedError orelse common.JSValue.undefined_value());
            return promise;
        }

        // Step 4-6: Perform cancel on controller
        // For now, we delegate to controller's cancel algorithm
        return self.controller.cancelInternal(reason);
    }

    /// AcquireReadableStreamDefaultReader(stream)
    ///
    /// Spec: § 4.2.3 "Creates a default reader and locks the stream to it."
    fn acquireDefaultReader(self: *ReadableStream, loop: eventLoop.EventLoop) !*ReadableStreamDefaultReader {
        // Create reader on heap
        const reader = try self.allocator.create(ReadableStreamDefaultReader);
        errdefer self.allocator.destroy(reader);

        // Initialize reader
        reader.* = try ReadableStreamDefaultReader.init(self.allocator, self, loop);

        // Lock stream to reader
        self.reader = .{ .default = reader };

        return reader;
    }

    /// ReadableStreamGetNumReadRequests(stream)
    ///
    /// Spec: § 4.2.4 "Get number of pending read requests"
    pub fn getNumReadRequests(self: *const ReadableStream) usize {
        return switch (self.reader) {
            .none => 0,
            .default => |reader| reader.readRequests.items.len,
            .byob => 0, // BYOB reader uses read-into requests, not read requests
        };
    }

    /// Check if stream has a default reader
    ///
    /// Spec: § 4.1.4 "ReadableStreamHasDefaultReader(stream)"
    pub fn hasDefaultReader(self: *const ReadableStream) bool {
        return switch (self.reader) {
            .default => true,
            else => false,
        };
    }

    /// Check if stream has a BYOB reader
    ///
    /// Spec: § 4.1.4 "ReadableStreamHasBYOBReader(stream)"
    pub fn hasBYOBReader(self: *const ReadableStream) bool {
        return switch (self.reader) {
            .byob => true,
            else => false,
        };
    }

    /// Get number of pending read-into requests (BYOB)
    ///
    /// Spec: § 4.1.4 "ReadableStreamGetNumReadIntoRequests(stream)"
    pub fn getNumReadIntoRequests(self: *const ReadableStream) usize {
        return switch (self.reader) {
            .none => 0,
            .default => 0, // Default reader doesn't have read-into requests
            .byob => |reader| reader.readIntoRequests.items.len,
        };
    }

    /// ReadableStreamFulfillReadRequest(stream, chunk, done)
    ///
    /// Spec: § 4.2.5 "Fulfill a pending read request"
    pub fn fulfillReadRequest(self: *ReadableStream, chunk: common.JSValue, done: bool) void {
        switch (self.reader) {
            .none => return, // No reader, nothing to fulfill
            .default => |reader| {
                // Remove the first read request
                if (reader.readRequests.items.len == 0) return;

                const promise = reader.readRequests.orderedRemove(0);

                // Fulfill the promise with the read result
                if (done) {
                    promise.fulfill(.{
                        .value = null,
                        .done = true,
                    });
                } else {
                    promise.fulfill(.{
                        .value = chunk,
                        .done = false,
                    });
                }
            },
            .byob => {}, // BYOB uses fulfillReadIntoRequest
        }
    }

    /// ReadableStreamFulfillReadIntoRequest(stream, chunk, done)
    ///
    /// Spec: § 4.5.5 "Fulfill a pending read-into request (BYOB)"
    pub fn fulfillReadIntoRequest(self: *ReadableStream, chunk: webidl.ArrayBufferView, done: bool) void {
        switch (self.reader) {
            .none => return, // No reader, nothing to fulfill
            .default => return, // Default reader doesn't have read-into requests
            .byob => |reader| {
                // Remove the first read-into request
                if (reader.readIntoRequests.items.len == 0) return;

                const request = reader.readIntoRequests.orderedRemove(0);

                // Execute the appropriate steps based on done flag
                if (done) {
                    const ReadIntoRequestModule = @import("read_into_request");
                    // Convert chunk to ReadIntoRequest ArrayBufferView
                    const view = ReadIntoRequestModule.ArrayBufferView{
                        .data = chunk.getViewedArrayBuffer().data,
                        .offset = @intCast(chunk.getByteOffset()),
                        .length = @intCast(chunk.getByteLength()),
                    };
                    request.executeCloseSteps();
                    _ = view; // TODO: Should pass view to close steps with done=true
                } else {
                    const ReadIntoRequestModule = @import("read_into_request");
                    // Convert chunk to ReadIntoRequest ArrayBufferView
                    const view = ReadIntoRequestModule.ArrayBufferView{
                        .data = chunk.getViewedArrayBuffer().data,
                        .offset = @intCast(chunk.getByteOffset()),
                        .length = @intCast(chunk.getByteLength()),
                    };
                    request.executeChunkSteps(view);
                }
            },
        }
    }

    /// ReadableStreamClose(stream)
    ///
    /// Spec: § 4.2.6 "Close the stream"
    pub fn closeInternal(self: *ReadableStream) void {
        // Step 1: Assert: stream.[[state]] is "readable".
        // Step 2: Set stream.[[state]] to "closed".
        self.state = .closed;

        // Step 3-5: Resolve reader's closed promise
        // (Full implementation would resolve reader's closed promise)
    }

    /// ReadableStreamError(stream, e)
    ///
    /// Spec: § 4.2.7 "Error the stream"
    pub fn errorInternal(self: *ReadableStream, e: common.JSValue) void {
        // Step 1: Assert: stream.[[state]] is "readable".
        if (self.state != .readable) {
            return;
        }

        // Step 2: Set stream.[[state]] to "errored".
        self.state = .errored;

        // Step 3: Set stream.[[storedError]] to e.
        self.storedError = e;

        // Step 4: Let reader be stream.[[reader]].
        // Step 5-7: Reject reader's closed promise and all pending reads
        switch (self.reader) {
            .none => {},
            .default => |reader| {
                // Reject closed promise
                reader.closedPromise.reject(e);

                // Reject all pending read requests
                while (reader.readRequests.items.len > 0) {
                    const promise = reader.readRequests.orderedRemove(0);
                    promise.reject(e);
                }
            },
            .byob => {}, // TODO: BYOB reader error handling (Phase 7)
        }
    }

    /// ReadableStreamTee(stream, cloneForBranch2)
    ///
    /// Spec: § 4.10.5 "Create two branches of a readable stream"
    fn teeInternal(self: *ReadableStream, cloneForBranch2: bool) !struct { branch1: *ReadableStream, branch2: *ReadableStream } {
        // Spec step 1-2: Asserts (checked by type system)

        // Spec step 3: Acquire reader
        const reader = try self.acquireDefaultReader(self.eventLoop);

        // Spec step 4-12: Initialize state variables (now in TeeState)
        const teeState = try TeeState.init(
            self.allocator,
            self,
            reader,
            self.eventLoop,
            cloneForBranch2,
        );
        errdefer teeState.deinit();

        // Spec step 16-18: Create branch streams with custom pull/cancel algorithms
        // We create two streams that share the TeeState for coordination

        const branch1 = try self.allocator.create(ReadableStream);
        errdefer self.allocator.destroy(branch1);

        const branch2 = try self.allocator.create(ReadableStream);
        errdefer self.allocator.destroy(branch2);

        // Initialize branch streams
        branch1.* = try initWithSource(self.allocator, self.eventLoop, null, null);
        branch2.* = try initWithSource(self.allocator, self.eventLoop, null, null);

        // Link branches to tee state
        teeState.branch1 = branch1;
        teeState.branch2 = branch2;
        branch1.teeState = teeState;
        branch2.teeState = teeState;

        // Spec step 19: Forward reader errors to both branches
        // (Would be implemented with reader.closedPromise reaction)
        // TODO: Implement error forwarding when reader's closedPromise rejects

        // Spec step 20: Return the two branches
        return .{ .branch1 = branch1, .branch2 = branch2 };
    }
});

/// PipeState - Coordinates pipe operation between readable and writable streams
///
/// Spec: § 4.1.5 "ReadableStreamPipeTo(source, dest, ...)"
pub const PipeState = struct {
    allocator: std.mem.Allocator,
    eventLoop: eventLoop.EventLoop,

    // Reader and writer
    reader: *ReadableStreamDefaultReader,
    writer: *WritableStreamDefaultWriter,

    // Source and destination streams
    source: *ReadableStream,
    dest: *WritableStream,

    // Prevent flags
    preventClose: bool,
    preventAbort: bool,
    preventCancel: bool,

    // Shutdown coordination
    shuttingDown: bool,
    shutdownError: ?common.JSValue,

    // Promise for the pipe operation
    promise: *AsyncPromise(void),

    // Currently pending operations
    pendingRead: ?*AsyncPromise(common.ReadResult),
    pendingWrite: ?*AsyncPromise(void),

    // Abort signal (optional)
    signal: ?*anyopaque,

    pub fn init(
        allocator: std.mem.Allocator,
        loop: eventLoop.EventLoop,
        source: *ReadableStream,
        dest: *WritableStream,
        reader: *ReadableStreamDefaultReader,
        writer: *WritableStreamDefaultWriter,
        preventClose: bool,
        preventAbort: bool,
        preventCancel: bool,
        signal: ?*anyopaque,
    ) !*PipeState {
        const self = try allocator.create(PipeState);
        errdefer allocator.destroy(self);

        const promise = try AsyncPromise(void).init(allocator, loop);
        errdefer promise.deinit();

        self.* = .{
            .allocator = allocator,
            .eventLoop = loop,
            .reader = reader,
            .writer = writer,
            .source = source,
            .dest = dest,
            .preventClose = preventClose,
            .preventAbort = preventAbort,
            .preventCancel = preventCancel,
            .shuttingDown = false,
            .shutdownError = null,
            .promise = promise,
            .pendingRead = null,
            .pendingWrite = null,
            .signal = signal,
        };

        return self;
    }

    pub fn deinit(self: *PipeState) void {
        if (self.pendingRead) |p| {
            p.deinit();
        }
        if (self.pendingWrite) |p| {
            p.deinit();
        }
        self.promise.deinit();
        self.allocator.destroy(self);
    }

    /// Start the shuttling loop
    ///
    /// Spec: § 4.7.4 step 15 "read all chunks from source and write them to dest"
    pub fn startShuttling(self: *PipeState) !void {
        // Set source.[[disturbed]] to true (spec step 11)
        self.source.disturbed = true;

        // Set up error and close propagation watchers
        try self.setupPropagationHandlers();

        // Start the read-write loop
        try self.shuttleLoop();
    }

    /// Set up propagation handlers for errors and close events
    ///
    /// Spec: § 4.7.4 step 15 "Error and close states must be propagated"
    fn setupPropagationHandlers(self: *PipeState) !void {
        // These will be checked during the shuttle loop
        // For now, we implement a simplified version that checks state at each iteration
        _ = self;
    }

    /// Main shuttling loop - reads chunks and writes them
    ///
    /// Spec: § 4.7.4 step 15 "read all chunks from source and write them to dest"
    fn shuttleLoop(self: *PipeState) !void {
        // Check if we should shutdown before reading
        if (self.shuttingDown) {
            return self.finalize(self.shutdownError);
        }

        // Check propagation conditions
        try self.checkPropagationConditions();

        if (self.shuttingDown) {
            return self.finalize(self.shutdownError);
        }

        // Check backpressure: don't read if writer's desiredSize <= 0
        // Spec: "While WritableStreamDefaultWriterGetDesiredSize(writer) is ≤ 0 or is null,
        //        the user agent must not read from reader."
        const desiredSize = self.writer.desiredSize();
        if (desiredSize == null or desiredSize.? <= 0) {
            // Wait for ready promise to fulfill (backpressure)
            // In a full async implementation, we'd await writer.ready
            // For now, we'll just finish - a complete impl would register a callback
            self.promise.fulfill({});
            return;
        }

        // Read a chunk from the source
        const readPromise = try self.reader.read();
        self.pendingRead = readPromise;

        // Process the read result
        // In a full async implementation, this would be a then() callback
        // For this simplified version, we handle it synchronously
        self.eventLoop.runMicrotasks();

        if (readPromise.isFulfilled()) {
            const result = readPromise.state.fulfilled;

            if (result.done) {
                // Source is closed - propagate close forward
                self.handleSourceClosed();
                return;
            }

            // Write the chunk to the destination
            if (result.value) |chunk| {
                const writePromise = try self.writer.write(webidl.JSValue.fromCommon(chunk));
                self.pendingWrite = writePromise;

                // Wait for write to complete
                self.eventLoop.runMicrotasks();

                if (writePromise.isFulfilled()) {
                    // Continue shuttling
                    writePromise.deinit();
                    readPromise.deinit();
                    self.pendingWrite = null;
                    self.pendingRead = null;

                    // Recursive call to continue the loop
                    // In a real async implementation, this would be a promise chain
                    return try self.shuttleLoop();
                } else if (writePromise.isRejected()) {
                    // Write failed - propagate error
                    self.shutdownWithError(writePromise.state.rejected);
                    return;
                }
            }

            // No chunk (shouldn't happen if !done, but handle it)
            readPromise.deinit();
            self.pendingRead = null;
            self.promise.fulfill({});
        } else if (readPromise.isRejected()) {
            // Read failed - propagate error
            self.shutdownWithError(readPromise.state.rejected);
        } else {
            // Read is still pending - in a full async implementation, we'd wait
            // For now, just fulfill
            self.promise.fulfill({});
        }
    }

    /// Check propagation conditions and initiate shutdown if needed
    ///
    /// Spec: § 4.7.4 step 15 "Error and close states must be propagated"
    fn checkPropagationConditions(self: *PipeState) !void {
        // 1. Error propagation forward: source errored -> abort dest
        if (self.source.state == .errored) {
            if (!self.preventAbort and self.dest.state == .writable) {
                // Shutdown with action of WritableStreamAbort(dest, source.storedError)
                const err_value = self.source.storedError orelse common.JSValue{ .string = "Source errored" };
                const abortPromise = try self.dest.abort(webidl.JSValue.fromCommon(err_value));
                self.shutdownWithAction(abortPromise, err_value);
            } else {
                // Shutdown with error but no action
                const err_value = self.source.storedError orelse common.JSValue{ .string = "Source errored" };
                self.shutdownWithError(err_value);
            }
            return;
        }

        // 2. Error propagation backward: dest errored -> cancel source
        if (self.dest.state == .errored) {
            if (!self.preventCancel and self.source.state == .readable) {
                // Shutdown with action of ReadableStreamCancel(source, dest.storedError)
                const err_value = self.dest.storedError orelse common.JSValue{ .string = "Destination errored" };
                const cancelPromise = try self.source.cancel(webidl.JSValue.fromCommon(err_value));
                self.shutdownWithAction(cancelPromise, err_value);
            } else {
                // Shutdown with error but no action
                const err_value = self.dest.storedError orelse common.JSValue{ .string = "Destination errored" };
                self.shutdownWithError(err_value);
            }
            return;
        }

        // 3. Close propagation forward: source closed -> close dest
        if (self.source.state == .closed) {
            self.handleSourceClosed();
            return;
        }

        // 4. Close propagation backward: dest close queued or closed -> cancel source
        if (self.dest.state == .closed) {
            if (!self.preventCancel) {
                const err_value = common.JSValue{ .string = "Destination closed" };
                const cancelPromise = try self.source.cancel(webidl.JSValue.fromCommon(err_value));
                self.shutdownWithAction(cancelPromise, err_value);
            } else {
                const err_value = common.JSValue{ .string = "Destination closed" };
                self.shutdownWithError(err_value);
            }
            return;
        }
    }

    /// Handle source stream being closed
    fn handleSourceClosed(self: *PipeState) void {
        if (!self.preventClose) {
            // Close the writer with error propagation
            // Spec: WritableStreamDefaultWriterCloseWithErrorPropagation(writer)
            // For now, simplified to just close
            const closePromise = self.writer.close() catch {
                self.finalize(null);
                return;
            };
            self.shutdownWithAction(closePromise, null);
        } else {
            // Shutdown without closing dest
            self.shutdownWithoutAction(null);
        }
    }

    /// Shutdown with an action (abort/cancel/close)
    ///
    /// Spec: § 4.7.4 step 15 "Shutdown with an action"
    fn shutdownWithAction(self: *PipeState, action: *AsyncPromise(void), originalError: ?common.JSValue) void {
        if (self.shuttingDown) {
            return; // Already shutting down
        }

        self.shuttingDown = true;
        self.shutdownError = originalError;

        // Wait for pending writes to complete (simplified)
        // TODO: Properly wait for all pending writes

        // Wait for action to complete
        self.eventLoop.runMicrotasks();

        if (action.isFulfilled()) {
            action.deinit();
            self.finalize(originalError);
        } else if (action.isRejected()) {
            const err_value = action.state.rejected;
            action.deinit();
            self.finalize(err_value);
        } else {
            // Action still pending - in full async impl, would await
            action.deinit();
            self.finalize(originalError);
        }
    }

    /// Shutdown without an action
    ///
    /// Spec: § 4.7.4 step 15 "Shutdown"
    fn shutdownWithoutAction(self: *PipeState, err_value: ?common.JSValue) void {
        if (self.shuttingDown) {
            return;
        }

        self.shuttingDown = true;
        self.shutdownError = err_value;

        // Wait for pending writes to complete (simplified)
        // TODO: Properly wait for all pending writes

        self.finalize(err_value);
    }

    /// Shutdown with an error
    fn shutdownWithError(self: *PipeState, err_value: common.JSValue) void {
        self.shutdownWithoutAction(err_value);
    }

    /// Finalize the pipe operation
    ///
    /// Spec: § 4.7.4 step 15 "Finalize"
    fn finalize(self: *PipeState, err: ?common.JSValue) void {
        // 1. Release writer
        self.writer.releaseLock();

        // 2. Release reader
        self.reader.releaseLock();

        // 3. Remove abort algorithm from signal (if signal is not undefined)
        // TODO: Implement AbortSignal support

        // 4. Resolve or reject the promise
        if (err) |e| {
            self.promise.reject(e);
        } else {
            self.promise.fulfill({});
        }
    }
};

/// TeeState - Shared state for coordinating tee branches
///
/// Spec: § 4.10.5 "ReadableStreamDefaultTee(stream, cloneForBranch2)"
///
/// This structure holds the shared state between two tee branches that allows them
/// to coordinate reading from a single source stream.
pub const TeeState = struct {
    allocator: std.mem.Allocator,
    refCount: usize,

    // Shared reader
    reader: *ReadableStreamDefaultReader,

    // Original source stream
    source: *ReadableStream,

    // Branch streams
    branch1: ?*ReadableStream,
    branch2: ?*ReadableStream,

    // Reading coordination
    reading: bool,
    readAgain: bool,

    // Cancel coordination
    canceled1: bool,
    canceled2: bool,
    reason1: ?common.JSValue,
    reason2: ?common.JSValue,
    cancelPromise: *AsyncPromise(void),

    // Clone flag
    cloneForBranch2: bool,

    // Event loop
    eventLoop: eventLoop.EventLoop,

    pub fn init(
        allocator: std.mem.Allocator,
        source: *ReadableStream,
        reader: *ReadableStreamDefaultReader,
        loop: eventLoop.EventLoop,
        cloneForBranch2: bool,
    ) !*TeeState {
        const self = try allocator.create(TeeState);
        errdefer allocator.destroy(self);

        const cancelPromise = try AsyncPromise(void).init(allocator, loop);
        errdefer cancelPromise.deinit();

        self.* = .{
            .allocator = allocator,
            .refCount = 2, // Two branches
            .reader = reader,
            .source = source,
            .branch1 = null,
            .branch2 = null,
            .reading = false,
            .readAgain = false,
            .canceled1 = false,
            .canceled2 = false,
            .reason1 = null,
            .reason2 = null,
            .cancelPromise = cancelPromise,
            .cloneForBranch2 = cloneForBranch2,
            .eventLoop = loop,
        };

        return self;
    }

    pub fn deinit(self: *TeeState) void {
        self.cancelPromise.deinit();
        self.allocator.destroy(self);
    }

    pub fn release(self: *TeeState) void {
        self.refCount -= 1;
        if (self.refCount == 0) {
            self.deinit();
        }
    }

    /// Pull algorithm for tee branches
    ///
    /// Spec: § 4.10.5 step 13 "pullAlgorithm"
    pub fn pullAlgorithm(self: *TeeState) !*AsyncPromise(void) {
        // Step 13.1: If reading is true, set readAgain to true and return
        if (self.reading) {
            self.readAgain = true;
            const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
            promise.fulfill({});
            return promise;
        }

        // Step 13.2: Set reading to true
        self.reading = true;

        // Step 13.3-4: Create read request and perform read
        const readPromise = try self.reader.read();

        // Wait for read to complete
        self.eventLoop.runMicrotasks();

        if (readPromise.isFulfilled()) {
            const result = readPromise.state.fulfilled;
            defer readPromise.deinit();

            if (result.done) {
                // Close steps (spec step 13 close steps)
                self.reading = false;

                if (!self.canceled1 and self.branch1 != null) {
                    self.branch1.?.controller.closeInternal();
                }
                if (!self.canceled2 and self.branch2 != null) {
                    self.branch2.?.controller.closeInternal();
                }
                if (!self.canceled1 or !self.canceled2) {
                    self.cancelPromise.fulfill({});
                }
            } else if (result.value) |chunk| {
                // Chunk steps (spec step 13 chunk steps)
                // Queue microtask to perform these steps
                self.handleChunk(chunk);
            }
        } else if (readPromise.isRejected()) {
            // Error steps (spec step 13 error steps)
            self.reading = false;
            readPromise.deinit();
        }

        // Step 13.5: Return promise resolved with undefined
        const promise = try AsyncPromise(void).init(self.allocator, self.eventLoop);
        promise.fulfill({});
        return promise;
    }

    /// Handle a chunk read from the source
    ///
    /// Spec: § 4.10.5 step 13 chunk steps
    fn handleChunk(self: *TeeState, chunk: common.JSValue) void {
        // Microtask step 1: Set readAgain to false
        self.readAgain = false;

        // Microtask step 2: Let chunk1 and chunk2 be chunk
        const chunk1 = chunk;
        const chunk2 = chunk;

        // Microtask step 3: If canceled2 is false and cloneForBranch2 is true
        // TODO: Implement StructuredClone for when cloneForBranch2 is true
        // For now, both chunks reference the same value

        // Microtask step 4: If canceled1 is false, enqueue chunk1 to branch1
        if (!self.canceled1 and self.branch1 != null) {
            self.branch1.?.controller.enqueueInternal(chunk1) catch {};
        }

        // Microtask step 5: If canceled2 is false, enqueue chunk2 to branch2
        if (!self.canceled2 and self.branch2 != null) {
            self.branch2.?.controller.enqueueInternal(chunk2) catch {};
        }

        // Microtask step 6: Set reading to false
        self.reading = false;

        // Microtask step 7: If readAgain is true, perform pullAlgorithm
        if (self.readAgain) {
            _ = self.pullAlgorithm() catch {};
        }
    }

    /// Cancel algorithm for branch 1
    ///
    /// Spec: § 4.10.5 step 14 "cancel1Algorithm"
    pub fn cancel1Algorithm(self: *TeeState, reason: ?common.JSValue) *AsyncPromise(void) {
        // Step 1: Set canceled1 to true
        self.canceled1 = true;

        // Step 2: Set reason1 to reason
        self.reason1 = reason;

        // Step 3: If canceled2 is true
        if (self.canceled2) {
            // Create composite reason
            const compositeReason = common.JSValue{ .string = "Both branches canceled" };

            // Cancel source with composite reason
            const cancelResult = self.source.cancelInternal(compositeReason) catch self.cancelPromise;

            // Resolve cancelPromise with cancelResult
            self.eventLoop.runMicrotasks();
            if (cancelResult.isFulfilled()) {
                self.cancelPromise.fulfill({});
                cancelResult.deinit();
            }
        }

        // Step 4: Return cancelPromise
        return self.cancelPromise;
    }

    /// Cancel algorithm for branch 2
    ///
    /// Spec: § 4.10.5 step 15 "cancel2Algorithm"
    pub fn cancel2Algorithm(self: *TeeState, reason: ?common.JSValue) *AsyncPromise(void) {
        // Step 1: Set canceled2 to true
        self.canceled2 = true;

        // Step 2: Set reason2 to reason
        self.reason2 = reason;

        // Step 3: If canceled1 is true
        if (self.canceled1) {
            // Create composite reason
            const compositeReason = common.JSValue{ .string = "Both branches canceled" };

            // Cancel source with composite reason
            const cancelResult = self.source.cancelInternal(compositeReason) catch self.cancelPromise;

            // Resolve cancelPromise with cancelResult
            self.eventLoop.runMicrotasks();
            if (cancelResult.isFulfilled()) {
                self.cancelPromise.fulfill({});
                cancelResult.deinit();
            }
        }

        // Step 4: Return cancelPromise
        return self.cancelPromise;
    }
};

/// Async Iterator for reading chunks from a ReadableStream
///
/// Spec: § 3.2.6 "Asynchronous iteration"
///
/// This implements the async iterator protocol for ReadableStream, enabling
/// for-await loops and the values() method.
///
/// Usage:
/// ```zig
/// var iter = try stream.asyncIterator();
/// defer iter.deinit();
/// while (try iter.next()) |chunk| {
///     // process chunk
/// }
/// ```
pub const ReadableStreamAsyncIterator = struct {
    allocator: std.mem.Allocator,
    reader: *ReadableStreamDefaultReader,
    preventCancel: bool,
    done: bool,

    /// Initialize async iterator
    ///
    /// Spec: § 3.2.6 "Initialization steps"
    pub fn init(
        allocator: std.mem.Allocator,
        stream: *ReadableStream,
        loop: eventLoop.EventLoop,
        preventCancel: bool,
    ) !ReadableStreamAsyncIterator {
        // Spec step 1: Let reader be ? AcquireReadableStreamDefaultReader(stream)
        const reader = try stream.acquireDefaultReader(loop);

        // Spec step 2: Set iterator's reader to reader
        // Spec step 3: Let preventCancel be args[0]["preventCancel"]
        // Spec step 4: Set iterator's prevent cancel to preventCancel
        return .{
            .allocator = allocator,
            .reader = reader,
            .preventCancel = preventCancel,
            .done = false,
        };
    }

    /// Release the iterator and unlock the stream
    ///
    /// This should be called when done iterating (via defer or explicit call)
    pub fn deinit(self: *ReadableStreamAsyncIterator) void {
        if (!self.done) {
            // Release reader (unlocks the stream)
            self.reader.releaseLock();
            self.done = true;
        }
    }

    /// Get next iteration result
    ///
    /// Spec: § 3.2.6 "Get the next iteration result"
    ///
    /// Returns:
    /// - `chunk` if there's data available
    /// - `null` when stream is closed/done
    /// - `error` if stream errors
    pub fn next(self: *ReadableStreamAsyncIterator) !?common.JSValue {
        if (self.done) {
            return null;
        }

        // Spec step 1: Let reader be iterator's reader
        // Spec step 2: Assert: reader.[[stream]] is not undefined
        // (Checked by reader being non-null)

        // Spec step 3: Let promise be a new promise
        // Spec step 4: Let readRequest be a new read request
        // Spec step 5: Perform ! ReadableStreamDefaultReaderRead(this, readRequest)
        const read_promise = try self.reader.read();

        // Process microtasks to settle the promise
        // In a full async implementation, this would await the promise
        self.reader.eventLoop.runMicrotasks();

        if (read_promise.isFulfilled()) {
            const result = read_promise.state.fulfilled;
            defer read_promise.deinit();

            if (result.done) {
                // Spec: close steps
                // Step 1: Perform ! ReadableStreamDefaultReaderRelease(reader)
                self.reader.releaseLock();
                self.done = true;

                // Step 2: Resolve promise with end of iteration
                return null;
            } else {
                // Spec: chunk steps, given chunk
                // Step 1: Resolve promise with chunk
                return result.value;
            }
        } else if (read_promise.isRejected()) {
            // Spec: error steps, given e
            const err = read_promise.state.rejected;
            defer read_promise.deinit();

            // Step 1: Perform ! ReadableStreamDefaultReaderRelease(reader)
            self.reader.releaseLock();
            self.done = true;

            // Step 2: Reject promise with e
            _ = err; // Error is captured, would be thrown in full async
            return error.StreamError;
        } else {
            // Still pending - in full async implementation, would await
            self.done = true;
            return error.ReadPending;
        }
    }

    /// Return from async iteration (early termination)
    ///
    /// Spec: § 3.2.6 "Asynchronous iterator return steps"
    ///
    /// This is called when breaking out of a for-await loop early.
    /// If preventCancel is false, it cancels the stream.
    pub fn returnEarly(self: *ReadableStreamAsyncIterator, reason: ?common.JSValue) !*AsyncPromise(void) {
        if (self.done) {
            const promise = try AsyncPromise(void).init(self.allocator, self.reader.eventLoop);
            promise.fulfill({});
            return promise;
        }

        // Spec step 1: Let reader be iterator's reader
        // Spec step 2: Assert: reader.[[stream]] is not undefined
        // Spec step 3: Assert: reader.[[readRequests]] is empty

        // Spec step 4: If iterator's prevent cancel is false:
        if (!self.preventCancel) {
            // Step 4.1: Let result be ! ReadableStreamReaderGenericCancel(reader, arg)
            const cancelPromise = try self.reader.cancelInternal(reason);

            // Step 4.2: Perform ! ReadableStreamDefaultReaderRelease(reader)
            self.reader.releaseLock();
            self.done = true;

            // Step 4.3: Return result
            return cancelPromise;
        }

        // Spec step 5: Perform ! ReadableStreamDefaultReaderRelease(reader)
        self.reader.releaseLock();
        self.done = true;

        // Spec step 6: Return a promise resolved with undefined
        const promise = try AsyncPromise(void).init(self.allocator, self.reader.eventLoop);
        promise.fulfill({});
        return promise;
    }
};

// Backward compatibility alias
pub const ReadableStreamIterator = ReadableStreamAsyncIterator;
