//! ReadableStreamDefaultReader class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#default-reader-class
//!
//! Allows reading chunks from a ReadableStream.
//!
//! This implementation follows the reference implementation pattern from
//! webidl/generated-back/streams/ but uses PascalCase naming for interfaces.

const std = @import("std");
const webidl = @import("webidl");

// Import stream infrastructure
const common = @import("common");
const eventLoop = @import("event_loop");
const AsyncPromise = @import("async_promise").AsyncPromise;
const ReadRequest = @import("read_request").ReadRequest;

// Import ReadableStream (circular dependency handled carefully)
const ReadableStream = @import("readable_stream").ReadableStream;
const ReadableStreamGenericReader = @import("readable_stream_generic_reader").ReadableStreamGenericReader;

/// ReadableStreamDefaultReader WebIDL interface
///
/// IDL:
/// ```webidl
/// [Exposed=*]
/// interface ReadableStreamDefaultReader {
///   constructor(ReadableStream stream);
///
///   Promise<ReadableStreamReadResult> read();
///   undefined releaseLock();
/// };
/// ReadableStreamDefaultReader includes ReadableStreamGenericReader;
/// ```
///
/// This interface includes the ReadableStreamGenericReader mixin, which provides:
/// - readonly attribute Promise<undefined> closed;
/// - Promise<undefined> cancel(optional any reason);
pub const ReadableStreamDefaultReader = webidl.interface(struct {
    /// WebIDL includes: ReadableStreamGenericReader (provides closed, cancel, and shared fields)
    ///
    /// The generic reader mixin is flattened into this interface by the codegen
    /// to provide shared functionality between ReadableStreamDefaultReader and ReadableStreamBYOBReader
    pub const includes = .{ReadableStreamGenericReader};

    /// [[readRequests]]: List of pending read requests (async promises)
    ///
    /// Spec: § 4.3.2 Internal slot [[readRequests]]
    /// Changed from ArrayList(ReadRequest) to support async operations
    readRequests: std.ArrayList(*AsyncPromise(common.ReadResult)),

    /// Initialize a new default reader (internal - not exposed via WebIDL)
    ///
    /// Spec: § 4.3.4 "SetUpReadableStreamDefaultReader(reader, stream)"
    pub fn init(
        allocator: std.mem.Allocator,
        stream: *ReadableStream,
        loop: eventLoop.EventLoop,
    ) !ReadableStreamDefaultReader {
        // Initialize closed promise as pending
        const closedPromise = try AsyncPromise(void).init(allocator, loop);

        return .{
            .allocator = allocator,
            .eventLoop = loop,
            .closedPromise = closedPromise,
            .stream = stream,
            .readRequests = std.ArrayList(*AsyncPromise(common.ReadResult)){},
        };
    }

    /// Deinitialize the reader
    ///
    /// Spec: Cleanup internal slots
    pub fn deinit(self: *ReadableStreamDefaultReader) void {
        // Note: readRequests promises are owned by callers, just clear the list
        self.readRequests.deinit(self.allocator);
    }

    // ============================================================================
    // WebIDL Interface Methods (ReadableStreamDefaultReader)
    // ============================================================================
    // Note: closed() and cancel() methods are included from ReadableStreamGenericReader mixin

    /// read() method (ASYNC VERSION)
    ///
    /// IDL: Promise<ReadableStreamReadResult> read();
    ///
    /// Spec: § 4.3.3 "The read() method steps are:"
    ///
    /// Returns an AsyncPromise that will be fulfilled when data arrives
    /// or rejected if the stream errors. The promise is PENDING if no
    /// data is immediately available.
    ///
    /// **IMPORTANT**: Caller owns the returned promise and must call deinit()
    pub fn read(self: *ReadableStreamDefaultReader) !*AsyncPromise(common.ReadResult) {
        // Step 1: If this.[[stream]] is undefined, return a promise rejected with a TypeError exception.
        if (self.stream == null) {
            const promise = try AsyncPromise(common.ReadResult).init(
                self.allocator,
                self.eventLoop,
            );
            promise.reject(common.JSValue{ .string = "Reader released" });
            return promise;
        }

        // Step 2: Return ! ReadableStreamDefaultReaderRead(this).
        return self.readInternal();
    }

    /// releaseLock() method
    ///
    /// IDL: undefined releaseLock();
    ///
    /// Spec: § 4.3.3 "The releaseLock() method steps are:"
    /// Releases the reader's lock on the stream.
    pub fn call_releaseLock(self: *ReadableStreamDefaultReader) void {
        // Step 1: If this.[[stream]] is undefined, return.
        if (self.stream == null) {
            return;
        }

        // Step 2: Perform ! ReadableStreamDefaultReaderRelease(this).
        // Delegate to mixin's generic release
        self.genericRelease();
    }

    /// Alias for generated code compatibility
    pub fn releaseLock(self: *ReadableStreamDefaultReader) void {
        self.call_releaseLock();
    }

    // ============================================================================
    // Internal Algorithms (Abstract Operations)
    // ============================================================================

    /// ReadableStreamDefaultReaderRead(reader) - ASYNC VERSION
    ///
    /// Spec: § 4.3.4 "ReadableStreamDefaultReaderRead(reader)"
    ///
    /// This is the core async read logic. It returns:
    /// - Immediately fulfilled promise if data is available in the queue
    /// - Pending promise if no data is available (will be fulfilled later when data arrives)
    /// - Rejected promise if stream is errored
    fn readInternal(self: *ReadableStreamDefaultReader) !*AsyncPromise(common.ReadResult) {
        // Step 1: Let stream be reader.[[stream]].
        const stream = self.stream.?;

        // Step 2: Assert: stream.[[reader]] is reader.
        std.debug.assert(stream.reader == .default);

        // Step 3: Set stream.[[disturbed]] to true.
        stream.disturbed = true;

        // Step 4: If stream.[[state]] is "closed", return a promise fulfilled with {value: undefined, done: true}.
        if (stream.state == .closed) {
            const promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);
            promise.fulfill(common.ReadResult{ .value = null, .done = true });
            return promise;
        }

        // Step 5: If stream.[[state]] is "errored", return a promise rejected with stream.[[storedError]].
        if (stream.state == .errored) {
            const promise = try AsyncPromise(common.ReadResult).init(self.allocator, self.eventLoop);
            promise.reject(stream.storedError orelse common.JSValue.undefined_value());
            return promise;
        }

        // Step 6: Assert: stream.[[state]] is "readable".
        std.debug.assert(stream.state == .readable);

        // Step 7: Return ! stream.[[controller]].[[PullSteps]]().
        // This delegates to the controller to actually pull data
        return stream.controller.pullSteps(self);
    }
}, .{
    .exposed = &.{.global},
});
