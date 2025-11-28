//! Generated from: permissions.idl
//! Generated at: 2025-11-28T19:11:17Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PermissionStatusImpl = @import("impls").PermissionStatus;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const PermissionState = @import("enums").PermissionState;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const PermissionStatus = struct {
    pub const Meta = struct {
        pub const name = "PermissionStatus";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
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
            .{ "state", "get_state", null },
            .{ "name", "get_name", null },
            .{ "onchange", "get_onchange", "set_onchange" },
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
            .{ "state", "get_state", null },
            .{ "name", "get_name", null },
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
            state: PermissionState = undefined,
            name: runtime.DOMString = undefined,
            onchange: EventHandler = undefined,
            _internal: ?*PermissionStatusImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_onchange = &get_onchange,
        .get_state = &get_state,

        .set_onchange = &set_onchange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PermissionStatusImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PermissionStatusImpl.deinit(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PermissionState {
        return try PermissionStatusImpl.get_state(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try PermissionStatusImpl.get_name(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try PermissionStatusImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PermissionStatusImpl.set_onchange(instance, value);
    }

};
