//! Generated from: netinfo.idl
//! Generated at: 2025-11-29T02:15:46Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NetworkInformationImpl = @import("impls").NetworkInformation;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const NetworkInformationSaveData = @import("interfaces").NetworkInformationSaveData;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Millisecond = @import("typedefs").Millisecond;
const Megabit = @import("typedefs").Megabit;
const ConnectionType = @import("enums").ConnectionType;
const EffectiveConnectionType = @import("enums").EffectiveConnectionType;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const NetworkInformation = struct {
    pub const Meta = struct {
        pub const name = "NetworkInformation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{
            NetworkInformationSaveData,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "effectiveType", "get_effectiveType", null },
            .{ "downlinkMax", "get_downlinkMax", null },
            .{ "downlink", "get_downlink", null },
            .{ "rtt", "get_rtt", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "saveData", "get_saveData", null },
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
            .{ "type", "get_type", null },
            .{ "effectiveType", "get_effectiveType", null },
            .{ "downlinkMax", "get_downlinkMax", null },
            .{ "downlink", "get_downlink", null },
            .{ "rtt", "get_rtt", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "saveData", "get_saveData", null },
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
            @"type": ConnectionType = undefined,
            effectiveType: EffectiveConnectionType = undefined,
            downlinkMax: Megabit = undefined,
            downlink: Megabit = undefined,
            rtt: Millisecond = undefined,
            onchange: EventHandler = undefined,
            saveData: bool = undefined,
            cached_saveData: ?bool = null,
            _internal: ?*NetworkInformationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_downlink = &get_downlink,
        .get_downlinkMax = &get_downlinkMax,
        .get_effectiveType = &get_effectiveType,
        .get_onchange = &get_onchange,
        .get_rtt = &get_rtt,
        .get_saveData = &get_saveData,
        .get_type = &get_type,

        .set_onchange = &set_onchange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NetworkInformationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NetworkInformationImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!ConnectionType {
        return try NetworkInformationImpl.get_type(instance);
    }

    pub fn get_effectiveType(instance: *runtime.Instance) anyerror!EffectiveConnectionType {
        return try NetworkInformationImpl.get_effectiveType(instance);
    }

    pub fn get_downlinkMax(instance: *runtime.Instance) anyerror!Megabit {
        return try NetworkInformationImpl.get_downlinkMax(instance);
    }

    pub fn get_downlink(instance: *runtime.Instance) anyerror!Megabit {
        return try NetworkInformationImpl.get_downlink(instance);
    }

    pub fn get_rtt(instance: *runtime.Instance) anyerror!Millisecond {
        return try NetworkInformationImpl.get_rtt(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try NetworkInformationImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try NetworkInformationImpl.set_onchange(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_saveData(instance: *runtime.Instance) anyerror!bool {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_saveData) |cached| {
            return cached;
        }
        const value = try NetworkInformationImpl.get_saveData(instance);
        state.own.cached_saveData = value;
        return value;
    }

};
