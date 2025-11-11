//! CustomEvent interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const Event = @import("event").Event;

/// DOM Spec: interface CustomEvent : Event
pub const CustomEvent = webidl.interface(struct {
    pub const extends = Event;

    allocator: std.mem.Allocator,
    detail: ?webidl.JSValue,

    pub fn init(allocator: std.mem.Allocator, event_type: []const u8, event_init: ?CustomEventInit) !CustomEvent {
        _ = event_type;
        const custom_init = event_init orelse CustomEventInit{};

        return .{
            .allocator = allocator,
            .detail = custom_init.detail,
            // TODO: Initialize Event parent fields (will be added by codegen)
        };
    }

    pub fn deinit(self: *CustomEvent) void {
        _ = self;
        // NOTE: Parent Event cleanup will be handled by codegen
        // TODO: Call parent Event deinit (will be added by codegen)
    }

    pub fn get_detail(self: *const CustomEvent) ?webidl.JSValue {
        return self.detail;
    }
}, .{
    .exposed = &.{.global},
});

pub const CustomEventInit = struct {
    event_init: ?Event.EventInit = null,
    detail: ?webidl.JSValue = null,
};
