//! ReadableStreamBYOBRequest class per WHATWG Streams Standard
//!
//! Spec: https://streams.spec.whatwg.org/#rs-byob-request-class
//!
//! Represents a request to fill a user-provided buffer.

const std = @import("std");
const webidl = @import("webidl");

pub const ReadableStreamBYOBRequest = webidl.interface(struct {
    allocator: std.mem.Allocator,

    /// [[controller]]: The parent controller
    controller: ?*anyopaque,

    /// [[view]]: The view to write into (as ArrayBufferView)
    view: ?webidl.ArrayBufferView,

    pub fn init(
        allocator: std.mem.Allocator,
        controller: *anyopaque,
        view: webidl.ArrayBufferView,
    ) !ReadableStreamBYOBRequest {
        return .{
            .allocator = allocator,
            .controller = controller,
            .view = view,
        };
    }

    pub fn deinit(_: *ReadableStreamBYOBRequest) void {}

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    /// Get the view for writing
    ///
    /// Spec: § 4.8.2 "The view getter steps are:"
    pub fn get_view(self: *const ReadableStreamBYOBRequest) ?webidl.ArrayBufferView {
        return self.view;
    }

    /// Respond with the number of bytes written
    ///
    /// Spec: § 4.8.3 "The respond(bytesWritten) method steps"
    pub fn call_respond(self: *ReadableStreamBYOBRequest, bytesWritten: u64) !void {
        // Spec step 1: If this.[[controller]] is undefined, throw TypeError
        const controller_ptr = self.controller orelse return error.TypeError;

        // Spec step 2-4: Additional validation (buffer not detached, etc.)
        // For now, delegate validation to controller

        // Spec step 5: Perform ? ReadableByteStreamControllerRespond(this.[[controller]], bytesWritten)
        const ReadableByteStreamController = @import("readable_byte_stream_controller").ReadableByteStreamController;
        const ctrl: *ReadableByteStreamController = @ptrCast(@alignCast(controller_ptr));
        try ctrl.respond(bytesWritten);

        // Mark as responded by clearing references
        self.controller = null;
        self.view = null;
    }

    /// Respond with a new view
    ///
    /// Spec: § 4.8.3 "The respondWithNewView(view) method steps are:"
    pub fn call_respondWithNewView(self: *ReadableStreamBYOBRequest, view: webidl.ArrayBufferView) !void {
        // Spec step 1: If this.[[controller]] is undefined, throw TypeError
        const controller_ptr = self.controller orelse return error.TypeError;

        // Spec step 2: If ! IsDetachedBuffer(view.[[ViewedArrayBuffer]]) is true, throw TypeError
        if (view.isDetached()) {
            return error.TypeError;
        }

        // Spec step 3: Return ? ReadableByteStreamControllerRespondWithNewView(this.[[controller]], view)
        const ReadableByteStreamController = @import("readable_byte_stream_controller").ReadableByteStreamController;
        const ctrl: *ReadableByteStreamController = @ptrCast(@alignCast(controller_ptr));
        try ctrl.respondWithNewView(view);

        // Mark as responded by clearing references
        self.controller = null;
        self.view = null;
    }
}, .{
    .exposed = &.{.global},
});
