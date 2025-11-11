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
const DictionaryParsing = @import("dict_parsing");

pub const ReadableStreamBYOBReader = webidl.interface(struct {
    /// WebIDL includes: ReadableStreamGenericReader (provides closed, cancel, and shared fields)
    ///
    /// The generic reader mixin is flattened into this interface by the codegen
    /// to provide shared functionality between ReadableStreamDefaultReader and ReadableStreamBYOBReader
    pub const includes = .{ReadableStreamGenericReader};

    /// [[readIntoRequests]]: List of pending read-into requests
    readIntoRequests: std.ArrayList(*AsyncPromise(common.ReadResult)),

    pub fn init(
        allocator: std.mem.Allocator,
        stream: *ReadableStream,
        loop: eventLoop.EventLoop,
    ) !ReadableStreamBYOBReader {
        const closedPromise = try AsyncPromise(void).init(allocator, loop);

        return .{
            .allocator = allocator,
            .closedPromise = closedPromise,
            .stream = stream,
            .eventLoop = loop,
            .readIntoRequests = std.ArrayList(*AsyncPromise(common.ReadResult)){},
        };
    }

    pub fn deinit(self: *ReadableStreamBYOBReader) void {
        self.readIntoRequests.deinit(self.allocator);
    }

    /// Read data into the provided view
    ///
    /// Spec: § 4.5.3 "The read(view, options) method steps are:"
    pub fn call_read(
        self: *ReadableStreamBYOBReader,
        view: webidl.ArrayBufferView,
        options: ?webidl.JSValue,
    ) !*AsyncPromise(common.ReadResult) {
        const allocator = self.allocator;
        const loop = self.eventLoop;

        // Step 1: If view.[[ByteLength]] is 0, reject with TypeError
        if (view.getByteLength() == 0) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = try allocator.dupe(u8, "View byte length is 0"),
                },
            };
            promise.reject(exception);
            return promise;
        }

        // Step 2: If buffer byte length is 0, reject with TypeError
        const buffer = view.getViewedArrayBuffer();
        if (buffer.byteLength() == 0) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = try allocator.dupe(u8, "Buffer byte length is 0"),
                },
            };
            promise.reject(exception);
            return promise;
        }

        // Step 3: If buffer is detached, reject with TypeError
        if (view.isDetached()) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = try allocator.dupe(u8, "Buffer is detached"),
                },
            };
            promise.reject(exception);
            return promise;
        }

        // Step 4: If stream is undefined, reject with TypeError
        if (self.stream == null) {
            const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = try allocator.dupe(u8, "Reader released"),
                },
            };
            promise.reject(exception);
            return promise;
        }

        // Step 5: Parse options (default min = 1)
        const min: u64 = if (options) |opt| blk: {
            const parsed = DictionaryParsing.parseReadableStreamBYOBReaderReadOptions(allocator, opt) catch {
                const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);
                const exception = webidl.errors.Exception{
                    .simple = .{
                        .type = .TypeError,
                        .message = try allocator.dupe(u8, "Failed to parse options"),
                    },
                };
                promise.reject(exception);
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
        const allocator = self.allocator;
        const loop = self.eventLoop;
        const promise = try AsyncPromise(common.ReadResult).init(allocator, loop);

        // Step 1: Let stream be reader.[[stream]]
        const stream_ptr = self.stream orelse {
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = try allocator.dupe(u8, "Reader has no stream"),
                },
            };
            promise.reject(exception);
            return promise;
        };

        // Cast to actual ReadableStream type
        const stream: *ReadableStream = @ptrCast(@alignCast(stream_ptr));

        // Step 3: Set stream.[[disturbed]] to true
        stream.disturbed = true;

        // Step 4: If stream is errored, reject promise
        if (stream.state == .errored) {
            const storedError = stream.storedError orelse common.JSValue{ .string = "Stream errored" };
            const exception = try storedError.toException(self.allocator);
            promise.reject(exception);
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
                const exception = err_value.toException(allocator) catch return;
                context.promisePtr.reject(exception);
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
            const exception = webidl.errors.Exception{
                .simple = .{
                    .type = .TypeError,
                    .message = try allocator.dupe(u8, "Pull into failed"),
                },
            };
            promise.reject(exception);
            return promise;
        };

        return promise;
    }

    pub fn call_releaseLock(self: *ReadableStreamBYOBReader) void {
        if (self.stream == null) {
            return;
        }
        // Delegate to mixin's generic release
        self.genericRelease();
    }
}, .{
    .exposed = &.{.global},
});
