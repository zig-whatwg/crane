//! Generated from: managed-configuration.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorManagedDataImpl = @import("impls").NavigatorManagedData;
const EventTarget = @import("interfaces").EventTarget;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const EventHandler = @import("typedefs").EventHandler;
const Promise<record<DOMString,object>> = @import("interfaces").Promise<record<DOMString,object>>;

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
        
        // Initialize the instance (Impl receives full instance)
        NavigatorManagedDataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorManagedDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onmanagedconfigurationchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try NavigatorManagedDataImpl.get_onmanagedconfigurationchange(instance);
    }

    pub fn set_onmanagedconfigurationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NavigatorManagedDataImpl.set_onmanagedconfigurationchange(instance, value);
    }

    pub fn call_getManagedConfiguration(instance: *runtime.Instance, keys: anyopaque) anyerror!anyopaque {
        
        return try NavigatorManagedDataImpl.call_getManagedConfiguration(instance, keys);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try NavigatorManagedDataImpl.call_when(instance, type_, options);
    }

    pub fn call_getAnnotatedAssetId(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorManagedDataImpl.call_getAnnotatedAssetId(instance);
    }

    pub fn call_getDirectoryId(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorManagedDataImpl.call_getDirectoryId(instance);
    }

    pub fn call_getAnnotatedLocation(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorManagedDataImpl.call_getAnnotatedLocation(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try NavigatorManagedDataImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getHostname(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorManagedDataImpl.call_getHostname(instance);
    }

    pub fn call_getSerialNumber(instance: *runtime.Instance) anyerror!anyopaque {
        return try NavigatorManagedDataImpl.call_getSerialNumber(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NavigatorManagedDataImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try NavigatorManagedDataImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
