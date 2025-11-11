//! AbortController interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const AbortSignal = @import("abort_signal").AbortSignal;

pub const AbortController = webidl.interface(struct {
    allocator: std.mem.Allocator,
    signal: AbortSignal,

    pub fn init(allocator: std.mem.Allocator) !AbortController {
        return .{
            .allocator = allocator,
            .signal = try AbortSignal.init(allocator),
        };
    }

    pub fn deinit(self: *AbortController) void {
        self.signal.deinit();
    }

    /// abort(reason) method
    /// Spec: https://dom.spec.whatwg.org/#dom-abortcontroller-abort
    pub fn call_abort(self: *AbortController, reason: ?webidl.Exception) void {
        // Spec: "signal abort on this with reason if it is given"
        self.signal.signalAbort(reason);
    }

    pub fn get_signal(self: *const AbortController) *const AbortSignal {
        return &self.signal;
    }
}, .{
    .exposed = &.{.global},
});
