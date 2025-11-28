//! Generated from: html.idl
//! Generated at: 2025-11-28T19:11:17Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BroadcastChannelImpl = @import("impls").BroadcastChannel;
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

pub const BroadcastChannel = struct {
    pub const Meta = struct {
        pub const name = "BroadcastChannel";
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
            .{ "name", "get_name", null },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 1 },
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
            "close",
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
            .{ "name", "get_name", null },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
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
            name: runtime.DOMString = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            _internal: ?*BroadcastChannelImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_close = &call_close,
        .call_postMessage = &call_postMessage,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BroadcastChannelImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BroadcastChannelImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, name: DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try BroadcastChannelImpl.call_constructor(allocator, ctx, name);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try BroadcastChannelImpl.get_name(instance);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try BroadcastChannelImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BroadcastChannelImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try BroadcastChannelImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BroadcastChannelImpl.set_onmessageerror(instance, value);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try BroadcastChannelImpl.call_close(instance);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: *const anyopaque) anyerror!void {
        
        return try BroadcastChannelImpl.call_postMessage(instance, message);
    }

};
