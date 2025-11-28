//! Generated from: mediaqueries-5.idl
//! Generated at: 2025-11-28T22:33:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PreferenceObjectImpl = @import("impls").PreferenceObject;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const PreferenceObject = struct {
    pub const Meta = struct {
        pub const name = "PreferenceObject";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "override", "get_override", null },
            .{ "value", "get_value", null },
            .{ "validValues", "get_validValues", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clearOverride", "call_clearOverride", 0 },
            .{ "requestOverride", "call_requestOverride", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clearOverride",
            "requestOverride",
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
            .{ "override", "get_override", null },
            .{ "value", "get_value", null },
            .{ "validValues", "get_validValues", null },
            .{ "onchange", "get_onchange", "set_onchange" },
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
            override: ?runtime.DOMString = null,
            value: runtime.DOMString = undefined,
            validValues: runtime.FrozenArray(runtime.DOMString) = undefined,
            onchange: EventHandler = undefined,
            _internal: ?*PreferenceObjectImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onchange = &get_onchange,
        .get_override = &get_override,
        .get_validValues = &get_validValues,
        .get_value = &get_value,

        .set_onchange = &set_onchange,

        .call_clearOverride = &call_clearOverride,
        .call_requestOverride = &call_requestOverride,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PreferenceObjectImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PreferenceObjectImpl.deinit(instance);
    }

    pub fn get_override(instance: *runtime.Instance) anyerror!?DOMString {
        return try PreferenceObjectImpl.get_override(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try PreferenceObjectImpl.get_value(instance);
    }

    pub fn get_validValues(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PreferenceObjectImpl.get_validValues(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PreferenceObjectImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PreferenceObjectImpl.set_onchange(instance, value);
    }

    pub fn call_clearOverride(instance: *runtime.Instance) anyerror!void {
        return try PreferenceObjectImpl.call_clearOverride(instance);
    }

    pub fn call_requestOverride(instance: *runtime.Instance, value: ?DOMString) anyerror!*const anyopaque {
        
        return try PreferenceObjectImpl.call_requestOverride(instance, value);
    }

};
