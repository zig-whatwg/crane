//! Generated from: webhid.idl
//! Generated at: 2025-11-23T19:17:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HIDDeviceImpl = @import("impls").HIDDevice;
const EventTarget = @import("interfaces").EventTarget;
const HIDCollectionInfo = @import("dictionaries").HIDCollectionInfo;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const HIDDevice = struct {
    pub const Meta = struct {
        pub const name = "HIDDevice";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "oninputreport", "get_oninputreport", "set_oninputreport" },
            .{ "opened", "get_opened", null },
            .{ "vendorId", "get_vendorId", null },
            .{ "productId", "get_productId", null },
            .{ "productName", "get_productName", null },
            .{ "collections", "get_collections", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "open", "call_open", 0 },
            .{ "close", "call_close", 0 },
            .{ "forget", "call_forget", 0 },
            .{ "sendReport", "call_sendReport", 2 },
            .{ "sendFeatureReport", "call_sendFeatureReport", 2 },
            .{ "receiveFeatureReport", "call_receiveFeatureReport", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "close",
            "forget",
            "sendReport",
            "sendFeatureReport",
            "receiveFeatureReport",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "oninputreport", "get_oninputreport", "set_oninputreport" },
            .{ "opened", "get_opened", null },
            .{ "vendorId", "get_vendorId", null },
            .{ "productId", "get_productId", null },
            .{ "productName", "get_productName", null },
            .{ "collections", "get_collections", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            oninputreport: EventHandler = undefined,
            opened: bool = undefined,
            vendorId: u16 = undefined,
            productId: u16 = undefined,
            productName: runtime.DOMString = undefined,
            collections: runtime.FrozenArray(HIDCollectionInfo) = undefined,
            _internal: ?*HIDDeviceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_collections = &get_collections,
        .get_oninputreport = &get_oninputreport,
        .get_opened = &get_opened,
        .get_productId = &get_productId,
        .get_productName = &get_productName,
        .get_vendorId = &get_vendorId,

        .set_oninputreport = &set_oninputreport,

        .call_close = &call_close,
        .call_forget = &call_forget,
        .call_open = &call_open,
        .call_receiveFeatureReport = &call_receiveFeatureReport,
        .call_sendFeatureReport = &call_sendFeatureReport,
        .call_sendReport = &call_sendReport,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HIDDeviceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HIDDeviceImpl.deinit(instance);
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

    pub fn get_collections(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HIDDeviceImpl.get_collections(instance);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HIDDeviceImpl.call_forget(instance);
    }

    pub fn call_open(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HIDDeviceImpl.call_open(instance);
    }

    pub fn call_sendFeatureReport(instance: *runtime.Instance, reportId: u8, data: BufferSource) anyerror!*const anyopaque {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(u8, reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_sendFeatureReport(instance, reportId, data);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HIDDeviceImpl.call_close(instance);
    }

    pub fn call_receiveFeatureReport(instance: *runtime.Instance, reportId: u8) anyerror!*const anyopaque {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(u8, reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_receiveFeatureReport(instance, reportId);
    }

    pub fn call_sendReport(instance: *runtime.Instance, reportId: u8, data: BufferSource) anyerror!*const anyopaque {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(u8, reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_sendReport(instance, reportId, data);
    }

};
