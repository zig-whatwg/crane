//! ReadableStreamBYOBReader class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#byob-reader-class
//!
//! Allows reading bytes with zero-copy optimization using user-provided buffers.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const eventLoop = @import("eventLoop");
const AsyncPromise = @import("async_promise").AsyncPromise;

const ReadableStream = @import("ReadableStream").ReadableStream;
const ReadableStreamGenericReader = @import("ReadableStreamGenericReader").ReadableStreamGenericReader;

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

    pub fn read(self: *ReadableStreamBYOBReader, view: ?webidl.JSValue) !*AsyncPromise(common.ReadResult) {
        _ = view;

        if (self.mixin.stream == null) {
            const promise = try AsyncPromise(common.ReadResult).init(self.mixin.allocator, self.mixin.eventLoop);
            promise.reject(common.JSValue{ .string = "Reader released" });
            return promise;
        }

        // Simplified: return empty result
        const promise = try AsyncPromise(common.ReadResult).init(self.mixin.allocator, self.mixin.eventLoop);
        promise.fulfill(.{ .value = null, .done = true });
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
