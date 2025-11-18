//! Generated from: web-bluetooth.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ServiceEventHandlersImpl = @import("../impls/ServiceEventHandlers.zig");

pub const ServiceEventHandlers = struct {
    pub const Meta = struct {
        pub const name = "ServiceEventHandlers";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onserviceadded: EventHandler = undefined,
            onservicechanged: EventHandler = undefined,
            onserviceremoved: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ServiceEventHandlers, .{
        .deinit_fn = &deinit_wrapper,

        .get_onserviceadded = &get_onserviceadded,
        .get_onservicechanged = &get_onservicechanged,
        .get_onserviceremoved = &get_onserviceremoved,

        .set_onserviceadded = &set_onserviceadded,
        .set_onservicechanged = &set_onservicechanged,
        .set_onserviceremoved = &set_onserviceremoved,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ServiceEventHandlersImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ServiceEventHandlersImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onserviceadded(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceEventHandlersImpl.get_onserviceadded(state);
    }

    pub fn set_onserviceadded(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceEventHandlersImpl.set_onserviceadded(state, value);
    }

    pub fn get_onservicechanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceEventHandlersImpl.get_onservicechanged(state);
    }

    pub fn set_onservicechanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceEventHandlersImpl.set_onservicechanged(state, value);
    }

    pub fn get_onserviceremoved(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ServiceEventHandlersImpl.get_onserviceremoved(state);
    }

    pub fn set_onserviceremoved(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ServiceEventHandlersImpl.set_onserviceremoved(state, value);
    }

};
