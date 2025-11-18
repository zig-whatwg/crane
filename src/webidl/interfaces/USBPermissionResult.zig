//! Generated from: webusb.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBPermissionResultImpl = @import("impls").USBPermissionResult;
const PermissionStatus = @import("interfaces").PermissionStatus;
const FrozenArray<USBDevice> = @import("interfaces").FrozenArray<USBDevice>;

pub const USBPermissionResult = struct {
    pub const Meta = struct {
        pub const name = "USBPermissionResult";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *PermissionStatus;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            devices: FrozenArray<USBDevice> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBPermissionResult, .{
        .deinit_fn = &deinit_wrapper,

        .get_devices = &get_devices,
        .get_name = &get_name,
        .get_onchange = &get_onchange,
        .get_state = &get_state,

        .set_devices = &set_devices,
        .set_onchange = &set_onchange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
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
        USBPermissionResultImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBPermissionResultImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PermissionState {
        return try USBPermissionResultImpl.get_state(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try USBPermissionResultImpl.get_name(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try USBPermissionResultImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try USBPermissionResultImpl.set_onchange(instance, value);
    }

    pub fn get_devices(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBPermissionResultImpl.get_devices(instance);
    }

    pub fn set_devices(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try USBPermissionResultImpl.set_devices(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try USBPermissionResultImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try USBPermissionResultImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try USBPermissionResultImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try USBPermissionResultImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
