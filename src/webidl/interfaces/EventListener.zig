//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EventListenerImpl = @import("impls").EventListener;
const Event = @import("interfaces").Event;

pub const EventListener = struct {
    pub const Meta = struct {
        pub const name = "EventListener";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(EventListener, .{
        .deinit_fn = &deinit_wrapper,

        .call_handleEvent = &call_handleEvent,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return EventListenerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EventListenerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_handleEvent(instance: *runtime.Instance, event: Event) anyerror!void {
        
        return try EventListenerImpl.call_handleEvent(instance, event);
    }

};
