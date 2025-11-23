//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DeviceChangeEventImpl = @import("impls").DeviceChangeEvent;
const Event = @import("interfaces").Event;
const MediaDeviceInfo = @import("interfaces").MediaDeviceInfo;
const EventTarget = @import("interfaces").EventTarget;
const DeviceChangeEventInit = @import("dictionaries").DeviceChangeEventInit;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const DeviceChangeEvent = struct {
    pub const Meta = struct {
        pub const name = "DeviceChangeEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "devices", "get_devices", null },
            .{ "userInsertedDevices", "get_userInsertedDevices", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "devices", "get_devices", null },
            .{ "userInsertedDevices", "get_userInsertedDevices", null },
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
            devices: runtime.FrozenArray(MediaDeviceInfo) = undefined,
            userInsertedDevices: runtime.FrozenArray(MediaDeviceInfo) = undefined,
            cached_devices: ?runtime.FrozenArray(MediaDeviceInfo) = null,
            cached_userInsertedDevices: ?runtime.FrozenArray(MediaDeviceInfo) = null,
            _internal: ?*DeviceChangeEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_devices = &get_devices,
        .get_userInsertedDevices = &get_userInsertedDevices,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DeviceChangeEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DeviceChangeEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: DeviceChangeEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DeviceChangeEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_devices(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_devices) |cached| {
            return cached;
        }
        const value = try DeviceChangeEventImpl.get_devices(instance);
        state.own.cached_devices = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_userInsertedDevices(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_userInsertedDevices) |cached| {
            return cached;
        }
        const value = try DeviceChangeEventImpl.get_userInsertedDevices(instance);
        state.own.cached_userInsertedDevices = value;
        return value;
    }

};
