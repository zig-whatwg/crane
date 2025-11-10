//! ReadableStreamBYOBReader class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#byob-reader-class
//!
//! Allows reading bytes with zero-copy optimization using user-provided buffers.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const eventLoop = @import("event_loop");
const AsyncPromise = @import("async_promise").AsyncPromise;

const ReadableStream = @import("readable_stream").ReadableStream;
const ReadableStreamGenericReader = @import("readable_stream_generic_reader").ReadableStreamGenericReader;

// BYOB-specific imports
const ReadIntoRequestModule = @import("read_into_request");
const ReadIntoRequest = ReadIntoRequestModule.ReadIntoRequest;
const ReadableByteStreamController = @import("readable_byte_stream_controller").ReadableByteStreamController;
const DictionaryParsing = @import("dictionary_parsing");

pub const ReadableStreamBYOBReader = webidl.interface(struct {
    /// Mixin: ReadableStreamGenericReader (provides closed, cancel)
    ///
    /// The generic reader mixin is embedded to provide shared functionality
    /// between ReadableStreamDefaultReader and ReadableStreamBYOBReader
    mixin: ReadableStreamGenericReader,

    /// [[readIntoRequests]]: List of pending read-into requests
    readIntoRequests: std.ArrayList(*AsyncPromise(common.ReadResult)),

    pub fn init(
        allocator: std.mem.Allocator,
        stream: *ReadableStream,
        loop: eventLoop.EventLoop,
    ) !ReadableStreamBYOBReader {
        const closedPromise = try AsyncPromise(void).init(allocator, loop);

        return .{
            .mixin = .{
                .allocator = allocator,
                .closedPromise = closedPromise,
                .stream = stream,
                .eventLoop = loop,
            },
            .readIntoRequests = std.ArrayList(*AsyncPromise(common.ReadResult)).init(allocator),
        };
    }

    pub fn deinit(self: *ReadableStreamBYOBReader) void {
        self.readIntoRequests.deinit();
    }

    // ============================================================================
    // WebIDL Interface Methods (from ReadableStreamGenericReader mixin)
    // ============================================================================

    pub fn closed(self: *const ReadableStreamBYOBReader) webidl.Promise(void) {
        return self.mixin.closed();
    }

    pub fn cancel(self: *ReadableStreamBYOBReader, reason: ?webidl.JSValue) !*AsyncPromise(void) {
        return self.mixin.cancel(reason);
    }

    /// Read data into the provided view
    ///
    /// Spec: § 4.5.3 "The read(view, options) method steps are:"
    pub fn read(
        self: *ReadableStreamBYOBReader,
        view: webidl.ArrayBufferView,
        options: ?webidl.JSValue,
    ) !*AsyncPromise(common.ReadResult) {
        const allocator = self.mixin.allocator;
        const loop = self.mixin.eventLoop;

        // Step 1: If view.[[ByteLength]] is 0, reject with TypeError
        if (view.getByteLength() == 0) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            promise.reject(common.JSValue{ .string = "View byte length is 0" });
            return promise;
        }

        // Step 2: If buffer byte length is 0, reject with TypeError
        const buffer = view.getViewedArrayBuffer();
        if (buffer.byteLength() == 0) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            promise.reject(common.JSValue{ .string = "Buffer byte length is 0" });
            return promise;
        }

        // Step 3: If buffer is detached, reject with TypeError
        if (view.isDetached()) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            promise.reject(common.JSValue{ .string = "Buffer is detached" });
            return promise;
        }

        // Step 4: If stream is undefined, reject with TypeError
        if (self.mixin.stream == null) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            promise.reject(common.JSValue{ .string = "Reader released" });
            return promise;
        }

        // Step 5: Parse options (default min = 1)
        const min: u64 = if (options) |opt| blk: {
            const parsed = DictionaryParsing.parseReadableStreamBYOBReaderReadOptions(allocator, opt) catch {
                const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
                promise.reject(common.JSValue{ .string = "Failed to parse options" });
                return promise;
            };
            break :blk parsed.min;
        } else 1;

        // Step 6: Return ReadableStreamBYOBReaderRead(this, view, min)
        return try self.readInternal(view, min);
    }

    /// Internal read implementation
    ///
    /// Spec: § 4.5.4 "ReadableStreamBYOBReaderRead(reader, view, min)"
    fn readInternal(
        self: *ReadableStreamBYOBReader,
        view: webidl.ArrayBufferView,
        min: u64,
    ) !*AsyncPromise(common.ReadResult) {
        const allocator = self.mixin.allocator;
        const loop = self.mixin.eventLoop;
        const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);

        // Step 1: Let stream be reader.[[stream]]
        const stream_ptr = self.mixin.stream orelse {
            promise.reject(common.JSValue{ .string = "Reader has no stream" });
            return promise;
        };

        // Cast to actual ReadableStream type
        const stream: *ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 3: Set stream.[[disturbed]] to true
        stream.disturbed = true;

        // Step 4: If stream is errored, reject promise
        if (stream.state == .errored) {
            const storedError = stream.storedError orelse common.JSValue{ .string = "Stream errored" };
            promise.reject(storedError);
            return promise;
        }

        // Step 5: Call controller.pullInto()
        // Create ReadIntoRequest that will fulfill our promise
        const PromiseContext = struct {
            promisePtr: *AsyncPromise(common.ReadResult),

            fn chunkSteps(ctx: ?*anyopaque, chunk: ReadIntoRequestModule.ArrayBufferView) void {
                const context: *@This() = @ptrCast(@alignCast(ctx.?));
                // Fulfill promise with the filled view
                context.promisePtr.fulfill(.{
                    .value = common.JSValue{ .bytes = chunk.data },
                    .done = false,
                });
            }

            fn closeSteps(ctx: ?*anyopaque) void {
                const context: *@This() = @ptrCast(@alignCast(ctx.?));
                // Fulfill promise with done=true
                context.promisePtr.fulfill(.{
                    .value = common.JSValue{ .undefined = {} },
                    .done = true,
                });
            }

            fn errorSteps(ctx: ?*anyopaque, e: ReadIntoRequestModule.Value) void {
                const context: *@This() = @ptrCast(@alignCast(ctx.?));
                // Reject promise with error
                const err_value = switch (e) {
                    .string => |s| common.JSValue{ .string = s },
                    else => common.JSValue{ .string = "Unknown error" },
                };
                context.promisePtr.reject(err_value);
            }
        };

        // Allocate context for the callback closures
        const ctx = try allocator.create(PromiseContext);
        ctx.* = .{ .promisePtr = promise };

        const readIntoRequest = ReadIntoRequest.init(
            allocator,
            PromiseContext.chunkSteps,
            PromiseContext.closeSteps,
            PromiseContext.errorSteps,
            ctx,
        );

        // Get the byte stream controller and call pullInto
        // Note: stream.controller should be *ReadableByteStreamController for BYOB
        const controller: *ReadableByteStreamController = @ptrCast(@alignCast(stream.controller));

        controller.pullInto(view, min, readIntoRequest) catch {
            allocator.destroy(ctx);
            promise.reject(common.JSValue{ .string = "Pull into failed" });
            return promise;
        };

        return promise;
    }

    pub fn releaseLock(self: *ReadableStreamBYOBReader) void {
        if (self.mixin.stream == null) {
            return;
        }
        // Delegate to mixin's generic release
        self.mixin.genericRelease();
    }
});
