//! AbortSignal interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const EventTarget = @import("event_target").EventTarget;

pub const AbortSignal = webidl.interface(struct {
    allocator: std.mem.Allocator,
    event_target: EventTarget,
    aborted: bool,
    reason: ?webidl.JSValue,

    pub fn init(allocator: std.mem.Allocator) !AbortSignal {
        return .{
            .allocator = allocator,
            .event_target = try EventTarget.init(allocator),
            .aborted = false,
            .reason = null,
        };
    }

    pub fn deinit(self: *AbortSignal) void {
        self.event_target.deinit();
    }

    pub fn get_aborted(self: *const AbortSignal) bool {
        return self.aborted;
    }

    pub fn get_reason(self: *const AbortSignal) ?webidl.JSValue {
        return self.reason;
    }

    pub fn call_throwIfAborted(self: *const AbortSignal) !void {
        if (self.aborted) {
            return error.Aborted;
        }
    }
}, .{
    .exposed = &.{.global},
});
