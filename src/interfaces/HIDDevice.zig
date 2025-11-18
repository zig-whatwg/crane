//! Generated from: webhid.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HIDDeviceImpl = @import("../impls/HIDDevice.zig");
const EventTarget = @import("EventTarget.zig");

pub const HIDDevice = struct {
    pub const Meta = struct {
        pub const name = "HIDDevice";
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
            oninputreport: EventHandler = undefined,
            opened: bool = undefined,
            vendorId: u16 = undefined,
            productId: u16 = undefined,
            productName: runtime.DOMString = undefined,
            collections: FrozenArray<HIDCollectionInfo> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HIDDevice, .{
        .deinit_fn = &deinit_wrapper,

        .get_collections = &get_collections,
        .get_oninputreport = &get_oninputreport,
        .get_opened = &get_opened,
        .get_productId = &get_productId,
        .get_productName = &get_productName,
        .get_vendorId = &get_vendorId,

        .set_oninputreport = &set_oninputreport,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_forget = &call_forget,
        .call_open = &call_open,
        .call_receiveFeatureReport = &call_receiveFeatureReport,
        .call_removeEventListener = &call_removeEventListener,
        .call_sendFeatureReport = &call_sendFeatureReport,
        .call_sendReport = &call_sendReport,
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
        HIDDeviceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HIDDeviceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_oninputreport(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HIDDeviceImpl.get_oninputreport(state);
    }

    pub fn set_oninputreport(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HIDDeviceImpl.set_oninputreport(state, value);
    }

    pub fn get_opened(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return HIDDeviceImpl.get_opened(state);
    }

    pub fn get_vendorId(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return HIDDeviceImpl.get_vendorId(state);
    }

    pub fn get_productId(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return HIDDeviceImpl.get_productId(state);
    }

    pub fn get_productName(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return HIDDeviceImpl.get_productName(state);
    }

    pub fn get_collections(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HIDDeviceImpl.get_collections(state);
    }

    pub fn call_receiveFeatureReport(instance: *runtime.Instance, reportId: u8) anyopaque {
        const state = instance.getState(State);
        
        return HIDDeviceImpl.call_receiveFeatureReport(state, reportId);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HIDDeviceImpl.call_when(state, type_, options);
    }

    pub fn call_open(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HIDDeviceImpl.call_open(state);
    }

    pub fn call_sendFeatureReport(instance: *runtime.Instance, reportId: u8, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HIDDeviceImpl.call_sendFeatureReport(state, reportId, data);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return HIDDeviceImpl.call_dispatchEvent(state, event);
    }

    pub fn call_sendReport(instance: *runtime.Instance, reportId: u8, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HIDDeviceImpl.call_sendReport(state, reportId, data);
    }

    pub fn call_forget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HIDDeviceImpl.call_forget(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HIDDeviceImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HIDDeviceImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HIDDeviceImpl.call_removeEventListener(state, type_, callback, options);
    }

};
