//! Generated from: webhid.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HIDImpl = @import("impls").HID;
const EventTarget = @import("interfaces").EventTarget;
const Promise<sequence<HIDDevice>> = @import("interfaces").Promise<sequence<HIDDevice>>;
const HIDDeviceRequestOptions = @import("dictionaries").HIDDeviceRequestOptions;
const EventHandler = @import("typedefs").EventHandler;

pub const HID = struct {
    pub const Meta = struct {
        pub const name = "HID";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "ServiceWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .ServiceWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onconnect: EventHandler = undefined,
            ondisconnect: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HID, .{
        .deinit_fn = &deinit_wrapper,

        .get_onconnect = &get_onconnect,
        .get_ondisconnect = &get_ondisconnect,

        .set_onconnect = &set_onconnect,
        .set_ondisconnect = &set_ondisconnect,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getDevices = &call_getDevices,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestDevice = &call_requestDevice,
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
        HIDImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HIDImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try HIDImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try HIDImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try HIDImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try HIDImpl.set_ondisconnect(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try HIDImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try HIDImpl.call_when(instance, type_, options);
    }

    pub fn call_getDevices(instance: *runtime.Instance) anyerror!anyopaque {
        return try HIDImpl.call_getDevices(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestDevice(instance: *runtime.Instance, options: HIDDeviceRequestOptions) anyerror!anyopaque {
        
        return try HIDImpl.call_requestDevice(instance, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try HIDImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try HIDImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
