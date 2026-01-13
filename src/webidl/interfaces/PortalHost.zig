//! Generated from: portals.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PortalHostImpl = @import("impls").PortalHost;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("Event.zig").Event;
const PostMessageOptions = @import("dictionaries").PostMessageOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("Observable.zig").Observable;

pub const PortalHost = struct {
    pub const Meta = struct {
        pub const name = "PortalHost";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
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
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            _internal: ?*PortalHostImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_postMessage = &call_postMessage,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PortalHostImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PortalHostImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PortalHostImpl.deinit(instance);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try PortalHostImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PortalHostImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try PortalHostImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PortalHostImpl.set_onmessageerror(instance, value);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(PostMessageOptions)) anyerror!void {
        
        return try PortalHostImpl.call_postMessage(instance, message, options);
    }

};
