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

    pub fn call_abort(self: *AbortController, reason: ?webidl.JSValue) void {
        self.signal.aborted = true;
        self.signal.reason = reason;
    }

    pub fn get_signal(self: *const AbortController) *const AbortSignal {
        return &self.signal;
    }
});
