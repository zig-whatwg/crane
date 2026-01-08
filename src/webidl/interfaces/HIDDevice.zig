//! Generated from: webhid.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HIDDeviceImpl = @import("impls").HIDDevice;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const HIDCollectionInfo = @import("dictionaries").HIDCollectionInfo;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("Observable.zig").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("Event.zig").Event;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const HIDDevice = struct {
    pub const Meta = struct {
        pub const name = "HIDDevice";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            oninputreport: typedefs.EventHandler = undefined,
            opened: bool = undefined,
            vendorId: u16 = undefined,
            productId: u16 = undefined,
            productName: typedefs.DOMString = undefined,
            collections: runtime.JSValue = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HIDDeviceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HIDDeviceImpl.init(allocator, StateType, vtable_ptr, ctx);
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

    pub fn get_collections(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HIDDeviceImpl.get_collections(instance);
    }

    pub fn call_sendFeatureReport(instance: *runtime.Instance, reportId: u8, data: BufferSource) anyerror!runtime.JSValue {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(u8, reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_sendFeatureReport(instance, reportId, data);
    }

    pub fn call_receiveFeatureReport(instance: *runtime.Instance, reportId: u8) anyerror!runtime.JSValue {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(u8, reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_receiveFeatureReport(instance, reportId);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HIDDeviceImpl.call_close(instance);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HIDDeviceImpl.call_forget(instance);
    }

    pub fn call_open(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try HIDDeviceImpl.call_open(instance);
    }

    pub fn call_sendReport(instance: *runtime.Instance, reportId: u8, data: BufferSource) anyerror!runtime.JSValue {
        // [EnforceRange] on reportId
        if (!runtime.isInRange(u8, reportId)) return error.TypeError;
        
        return try HIDDeviceImpl.call_sendReport(instance, reportId, data);
    }

};
