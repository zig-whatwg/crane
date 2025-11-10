//! CustomEvent interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const Event = @import("event").Event;

pub const CustomEvent = webidl.interface(struct {
    allocator: std.mem.Allocator,
    event: Event,
    detail: ?webidl.JSValue,

    pub fn init(allocator: std.mem.Allocator, event_type: []const u8, event_init: ?CustomEventInit) !CustomEvent {
        const custom_init = event_init orelse CustomEventInit{};

        return .{
            .allocator = allocator,
            .event = try Event.init(allocator, event_type, custom_init.event_init),
            .detail = custom_init.detail,
        };
    }

    pub fn deinit(self: *CustomEvent) void {
        self.event.deinit();
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
