//! Generated from: webhid.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HIDInputReportEventImpl = @import("impls").HIDInputReportEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const HIDDevice = @import("interfaces").HIDDevice;
const EventTarget = @import("interfaces").EventTarget;
const HIDInputReportEventInit = @import("dictionaries").HIDInputReportEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const HIDInputReportEvent = struct {
    pub const Meta = struct {
        pub const name = "HIDInputReportEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
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
            .{ "device", "get_device", null },
            .{ "reportId", "get_reportId", null },
            .{ "data", "get_data", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "device", "get_device", null },
            .{ "reportId", "get_reportId", null },
            .{ "data", "get_data", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            device: *runtime.Instance = undefined,
            reportId: u8 = undefined,
            data: runtime.DataView = undefined,
            cached_device: ?*runtime.Instance = null,
            _internal: ?*HIDInputReportEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_device = &get_device,
        .get_reportId = &get_reportId,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HIDInputReportEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HIDInputReportEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: HIDInputReportEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HIDInputReportEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_device(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_device) |cached| {
            return cached;
        }
        const value = try HIDInputReportEventImpl.get_device(instance);
        state.own.cached_device = value;
        return value;
    }

    pub fn get_reportId(instance: *runtime.Instance) anyerror!u8 {
        return try HIDInputReportEventImpl.get_reportId(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HIDInputReportEventImpl.get_data(instance);
    }

};
