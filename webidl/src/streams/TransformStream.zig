//! TransformStream class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#ts-class
//!
//! Represents a transformation that consists of a pair of streams.

const std = @import("std");
const webidl = @import("webidl");

const common = @import("common");
const dict_parsing = @import("dict_parsing");
const ReadableStream = @import("readable_stream").ReadableStream;
const WritableStream = @import("writable_stream").WritableStream;
const TransformStreamDefaultController = @import("transform_stream_default_controller").TransformStreamDefaultController;

pub const TransformStream = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[backpressure]]: boolean - whether backpressure signal has been sent
    backpressure: bool,

    /// [[readable]]: ReadableStream representing the readable side
    readableStream: *ReadableStream,

    /// [[writable]]: WritableStream representing the writable side
    writableStream: *WritableStream,

    /// [[controller]]: TransformStreamDefaultController
    controller: *TransformStreamDefaultController,

    pub fn init(allocator: std.mem.Allocator) !TransformStream {
        return initWithTransformer(allocator, null, null, null);
    }

    pub fn deinit(self: *TransformStream) void {
        self.readableStream.deinit();
        self.allocator.destroy(self.readableStream);
        self.writableStream.deinit();
        self.allocator.destroy(self.writableStream);
        self.controller.deinit();
        self.allocator.destroy(self.controller);
    }

    pub fn initWithTransformer(
        allocator: std.mem.Allocator,
        transformer: ?webidl.JSValue,
        writableStrategy: ?webidl.JSValue,
        readableStrategy: ?webidl.JSValue,
    ) !TransformStream {
        _ = transformer;
        _ = writableStrategy;
        _ = readableStrategy;

        const readable_stream = try allocator.create(ReadableStream);
        errdefer allocator.destroy(readable_stream);
        readable_stream.* = try ReadableStream.init(allocator);

        const writable_stream = try allocator.create(WritableStream);
        errdefer allocator.destroy(writable_stream);
        writable_stream.* = try WritableStream.init(allocator);

        const ctrl = try allocator.create(TransformStreamDefaultController);
        errdefer allocator.destroy(ctrl);
        ctrl.* = TransformStreamDefaultController.init(allocator, null);

        var stream = TransformStream{
            .allocator = allocator,
            .backpressure = false,
            .readableStream = readable_stream,
            .writableStream = writable_stream,
            .controller = ctrl,
        };

        ctrl.stream = @ptrCast(&stream);
        readable_stream.controller.stream = @ptrCast(readable_stream);
        writable_stream.controller.stream = @ptrCast(writable_stream);

        return stream;
    }

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn get_readable(self: *const TransformStream) *ReadableStream {
        return self.readableStream;
    }

    pub fn get_writable(self: *const TransformStream) *WritableStream {
        return self.writableStream;
    }
}, .{
    .exposed = &.{.all},
    .transferable = true,
});
