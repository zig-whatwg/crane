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

    /// [[view]]: The view to write into
    view: ?webidl.JSValue,

    pub fn init(allocator: std.mem.Allocator) !ReadableStreamBYOBRequest {
        return .{
            .allocator = allocator,
            .controller = null,
            .view = null,
        };
    }

    pub fn deinit(_: *ReadableStreamBYOBRequest) void {}

    // ============================================================================
    // WebIDL Interface Methods
    // ============================================================================

    pub fn get_view(self: *const ReadableStreamBYOBRequest) ?webidl.JSValue {
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
    /// Spec: § 4.8.3 "The respondWithNewView(view) method steps"
    pub fn call_respondWithNewView(self: *ReadableStreamBYOBRequest, view: ?webidl.JSValue) !void {
        // Spec step 1: If this.[[controller]] is undefined, throw TypeError
        const controller_ptr = self.controller orelse return error.TypeError;

        // Get the view
        const view_val = view orelse return error.TypeError;

        // Spec step 2: Check buffer not detached (TODO when webidl provides API)

        // Spec step 3: Return ? ReadableByteStreamControllerRespondWithNewView(this.[[controller]], view)
        // TODO: Implement when controller.respondWithNewView is ready
        // For now, just mark as responded
        _ = controller_ptr;
        _ = view_val;

        // Mark as responded by clearing references
        self.controller = null;
        self.view = null;
    }
}, .{
    .exposed = &.{.global},
});
