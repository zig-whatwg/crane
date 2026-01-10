//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MessagePortImpl = @import("impls").MessagePort;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const MessageEventTarget = @import("mixins").MessageEventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("Event.zig").Event;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("Observable.zig").Observable;

pub const MessagePort = struct {
    pub const Meta = struct {
        pub const name = "MessagePort";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "AudioWorklet" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .AudioWorklet = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 1 },
            .{ "start", "call_start", 0 },
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
            "start",
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
            .{ "onclose", "get_onclose", "set_onclose" },
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
            onclose: typedefs.EventHandler = undefined,
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            _internal: ?*MessagePortImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onclose = &get_onclose,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onclose = &set_onclose,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_close = &call_close,
        .call_postMessage = &call_postMessage,
        .call_start = &call_start,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MessagePortImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MessagePortImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MessagePortImpl.deinit(instance);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try MessagePortImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MessagePortImpl.set_onclose(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try MessagePortImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MessagePortImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try MessagePortImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MessagePortImpl.set_onmessageerror(instance, value);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
        
        return try MessagePortImpl.call_postMessage(instance, message, transfer);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try MessagePortImpl.call_start(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try MessagePortImpl.call_close(instance);
    }

};
