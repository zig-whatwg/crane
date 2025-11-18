//! Generated from: managed-configuration.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorManagedDataImpl = @import("../impls/NavigatorManagedData.zig");
const EventTarget = @import("EventTarget.zig");

pub const NavigatorManagedData = struct {
    pub const Meta = struct {
        pub const name = "NavigatorManagedData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onmanagedconfigurationchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorManagedData, .{
        .deinit_fn = &deinit_wrapper,

        .get_onmanagedconfigurationchange = &get_onmanagedconfigurationchange,

        .set_onmanagedconfigurationchange = &set_onmanagedconfigurationchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAnnotatedAssetId = &call_getAnnotatedAssetId,
        .call_getAnnotatedLocation = &call_getAnnotatedLocation,
        .call_getDirectoryId = &call_getDirectoryId,
        .call_getHostname = &call_getHostname,
        .call_getManagedConfiguration = &call_getManagedConfiguration,
        .call_getSerialNumber = &call_getSerialNumber,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NavigatorManagedDataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NavigatorManagedDataImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onmanagedconfigurationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorManagedDataImpl.get_onmanagedconfigurationchange(state);
    }

    pub fn set_onmanagedconfigurationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NavigatorManagedDataImpl.set_onmanagedconfigurationchange(state, value);
    }

    pub fn call_getManagedConfiguration(instance: *runtime.Instance, keys: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorManagedDataImpl.call_getManagedConfiguration(state, keys);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorManagedDataImpl.call_when(state, type_, options);
    }

    pub fn call_getAnnotatedAssetId(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorManagedDataImpl.call_getAnnotatedAssetId(state);
    }

    pub fn call_getDirectoryId(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorManagedDataImpl.call_getDirectoryId(state);
    }

    pub fn call_getAnnotatedLocation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorManagedDataImpl.call_getAnnotatedLocation(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NavigatorManagedDataImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getHostname(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorManagedDataImpl.call_getHostname(state);
    }

    pub fn call_getSerialNumber(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NavigatorManagedDataImpl.call_getSerialNumber(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorManagedDataImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NavigatorManagedDataImpl.call_removeEventListener(state, type_, callback, options);
    }

};
