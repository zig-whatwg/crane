//! Generated from: fenced-frame.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FenceImpl = @import("impls").Fence;
const FenceEvent = @import("dictionaries").FenceEvent;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const ReportEventType = @import("typedefs").ReportEventType;
const Event = @import("interfaces").Event;

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
        
        // Initialize the instance (Impl receives full instance)
        FenceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FenceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_reportEvent(instance: *runtime.Instance, event: ReportEventType) anyerror!void {
        
        return try FenceImpl.call_reportEvent(instance, event);
    }

    pub fn call_getNestedConfigs(instance: *runtime.Instance) anyerror!anyopaque {
        return try FenceImpl.call_getNestedConfigs(instance);
    }

    pub fn call_setReportEventDataForAutomaticBeacons(instance: *runtime.Instance, event: FenceEvent) anyerror!void {
        
        return try FenceImpl.call_setReportEventDataForAutomaticBeacons(instance, event);
    }

    pub fn call_disableUntrustedNetwork(instance: *runtime.Instance) anyerror!anyopaque {
        return try FenceImpl.call_disableUntrustedNetwork(instance);
    }

    pub fn call_notifyEvent(instance: *runtime.Instance, event: Event) anyerror!void {
        
        return try FenceImpl.call_notifyEvent(instance, event);
    }

};
