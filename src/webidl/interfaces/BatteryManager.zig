//! Generated from: battery-status.idl
//! Generated at: 2025-11-28T22:33:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BatteryManagerImpl = @import("impls").BatteryManager;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const BatteryManager = struct {
    pub const Meta = struct {
        pub const name = "BatteryManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "charging", "get_charging", null },
            .{ "chargingTime", "get_chargingTime", null },
            .{ "dischargingTime", "get_dischargingTime", null },
            .{ "level", "get_level", null },
            .{ "onchargingchange", "get_onchargingchange", "set_onchargingchange" },
            .{ "onchargingtimechange", "get_onchargingtimechange", "set_onchargingtimechange" },
            .{ "ondischargingtimechange", "get_ondischargingtimechange", "set_ondischargingtimechange" },
            .{ "onlevelchange", "get_onlevelchange", "set_onlevelchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "charging", "get_charging", null },
            .{ "chargingTime", "get_chargingTime", null },
            .{ "dischargingTime", "get_dischargingTime", null },
            .{ "level", "get_level", null },
            .{ "onchargingchange", "get_onchargingchange", "set_onchargingchange" },
            .{ "onchargingtimechange", "get_onchargingtimechange", "set_onchargingtimechange" },
            .{ "ondischargingtimechange", "get_ondischargingtimechange", "set_ondischargingtimechange" },
            .{ "onlevelchange", "get_onlevelchange", "set_onlevelchange" },
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
            charging: bool = undefined,
            chargingTime: f64 = undefined,
            dischargingTime: f64 = undefined,
            level: f64 = undefined,
            onchargingchange: EventHandler = undefined,
            onchargingtimechange: EventHandler = undefined,
            ondischargingtimechange: EventHandler = undefined,
            onlevelchange: EventHandler = undefined,
            _internal: ?*BatteryManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_charging = &get_charging,
        .get_chargingTime = &get_chargingTime,
        .get_dischargingTime = &get_dischargingTime,
        .get_level = &get_level,
        .get_onchargingchange = &get_onchargingchange,
        .get_onchargingtimechange = &get_onchargingtimechange,
        .get_ondischargingtimechange = &get_ondischargingtimechange,
        .get_onlevelchange = &get_onlevelchange,

        .set_onchargingchange = &set_onchargingchange,
        .set_onchargingtimechange = &set_onchargingtimechange,
        .set_ondischargingtimechange = &set_ondischargingtimechange,
        .set_onlevelchange = &set_onlevelchange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BatteryManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BatteryManagerImpl.deinit(instance);
    }

    pub fn get_charging(instance: *runtime.Instance) anyerror!bool {
        return try BatteryManagerImpl.get_charging(instance);
    }

    pub fn get_chargingTime(instance: *runtime.Instance) anyerror!f64 {
        return try BatteryManagerImpl.get_chargingTime(instance);
    }

    pub fn get_dischargingTime(instance: *runtime.Instance) anyerror!f64 {
        return try BatteryManagerImpl.get_dischargingTime(instance);
    }

    pub fn get_level(instance: *runtime.Instance) anyerror!f64 {
        return try BatteryManagerImpl.get_level(instance);
    }

    pub fn get_onchargingchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BatteryManagerImpl.get_onchargingchange(instance);
    }

    pub fn set_onchargingchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BatteryManagerImpl.set_onchargingchange(instance, value);
    }

    pub fn get_onchargingtimechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BatteryManagerImpl.get_onchargingtimechange(instance);
    }

    pub fn set_onchargingtimechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BatteryManagerImpl.set_onchargingtimechange(instance, value);
    }

    pub fn get_ondischargingtimechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BatteryManagerImpl.get_ondischargingtimechange(instance);
    }

    pub fn set_ondischargingtimechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BatteryManagerImpl.set_ondischargingtimechange(instance, value);
    }

    pub fn get_onlevelchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BatteryManagerImpl.get_onlevelchange(instance);
    }

    pub fn set_onlevelchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BatteryManagerImpl.set_onlevelchange(instance, value);
    }

};
