//! Generated from: fenced-frame.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FenceImpl = @import("../impls/Fence.zig");

pub const Fence = struct {
    pub const Meta = struct {
        pub const name = "Fence";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Fence, .{
        .deinit_fn = &deinit_wrapper,

        .call_disableUntrustedNetwork = &call_disableUntrustedNetwork,
        .call_getNestedConfigs = &call_getNestedConfigs,
        .call_notifyEvent = &call_notifyEvent,
        .call_reportEvent = &call_reportEvent,
        .call_setReportEventDataForAutomaticBeacons = &call_setReportEventDataForAutomaticBeacons,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FenceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FenceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_reportEvent(instance: *runtime.Instance, event: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FenceImpl.call_reportEvent(state, event);
    }

    pub fn call_getNestedConfigs(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FenceImpl.call_getNestedConfigs(state);
    }

    pub fn call_setReportEventDataForAutomaticBeacons(instance: *runtime.Instance, event: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FenceImpl.call_setReportEventDataForAutomaticBeacons(state, event);
    }

    pub fn call_disableUntrustedNetwork(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FenceImpl.call_disableUntrustedNetwork(state);
    }

    pub fn call_notifyEvent(instance: *runtime.Instance, event: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FenceImpl.call_notifyEvent(state, event);
    }

};
