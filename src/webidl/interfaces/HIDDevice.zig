//! Generated from: webhid.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HIDDeviceImpl = @import("impls").HIDDevice;
const EventTarget = @import("interfaces").EventTarget;
const Promise<DataView> = @import("interfaces").Promise<DataView>;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const FrozenArray<HIDCollectionInfo> = @import("interfaces").FrozenArray<HIDCollectionInfo>;
const EventHandler = @import("typedefs").EventHandler;
const BufferSource = @import("typedefs").BufferSource;

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
        
        // Initialize the instance (Impl receives full instance)
        HIDDeviceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HIDDeviceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_oninputreport(instance: *runtime.Instance) anyerror!EventHandler {
        return try HIDDeviceImpl.get_oninputreport(instance);
    }

    pub fn set_oninputreport(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try HIDDeviceImpl.set_oninputreport(instance, value);
    }

    pub fn get_opened(instance: *runtime.Instance) anyerror!bool {
        return try HIDDeviceImpl.get_opened(instance);
    }

    pub fn get_vendorId(instance: *runtime.Instance) anyerror!u16 {
        return try HIDDeviceImpl.get_vendorId(instance);
    }

    pub fn get_productId(instance: *runtime.Instance) anyerror!u16 {
        return try HIDDeviceImpl.get_productId(instance);
    }

    pub fn get_productName(instance: *runtime.Instance) anyerror!DOMString {
        return try HIDDeviceImpl.get_productName(instance);
    }

    pub fn get_collections(instance: *runtime.Instance) anyerror!anyopaque {
        return try HIDDeviceImpl.get_collections(instance);
    }

    pub fn call_receiveFeatureReport(instance: *runtime.Instance, reportId: u8) anyerror!anyopaque {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_receiveFeatureReport(instance, reportId);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try HIDDeviceImpl.call_when(instance, type_, options);
    }

    pub fn call_open(instance: *runtime.Instance) anyerror!anyopaque {
        return try HIDDeviceImpl.call_open(instance);
    }

    pub fn call_sendFeatureReport(instance: *runtime.Instance, reportId: u8, data: BufferSource) anyerror!anyopaque {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_sendFeatureReport(instance, reportId, data);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try HIDDeviceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_sendReport(instance: *runtime.Instance, reportId: u8, data: BufferSource) anyerror!anyopaque {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_sendReport(instance, reportId, data);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!anyopaque {
        return try HIDDeviceImpl.call_forget(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try HIDDeviceImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try HIDDeviceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try HIDDeviceImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
