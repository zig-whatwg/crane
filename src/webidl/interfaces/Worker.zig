//! Generated from: html.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkerImpl = @import("impls").Worker;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AbstractWorker = @import("interfaces").AbstractWorker;
const MessageEventTarget = @import("interfaces").MessageEventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const USVString = @import("interfaces").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const WorkerOptions = @import("dictionaries").WorkerOptions;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const Worker = struct {
    pub const Meta = struct {
        pub const name = "Worker";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{
            AbstractWorker,
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "terminate", "call_terminate", 0 },
            .{ "postMessage", "call_postMessage", 2 },
            .{ "postMessage", "call_postMessage", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "terminate",
            "postMessage",
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
            .{ "onerror", "get_onerror", "set_onerror" },
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
            onerror: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            onmessageerror: EventHandler = undefined,
            _internal: ?*WorkerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onerror = &get_onerror,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onerror = &set_onerror,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_postMessage = &call_postMessage,
        .call_terminate = &call_terminate,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WorkerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, scriptURL: DOMString, options: webidl.Opt(WorkerOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WorkerImpl.call_constructor(allocator, ctx, scriptURL, options);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerImpl.set_onerror(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try WorkerImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WorkerImpl.set_onmessageerror(instance, value);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
        return try WorkerImpl.call_terminate(instance);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: *const anyopaque, transfer: *const anyopaque) anyerror!void {
        
        return try WorkerImpl.call_postMessage(instance, message, transfer);
    }

};
