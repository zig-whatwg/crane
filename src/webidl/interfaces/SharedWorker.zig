//! Generated from: html.idl
//! Generated at: 2025-11-28T22:33:18Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SharedWorkerImpl = @import("impls").SharedWorker;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AbstractWorker = @import("interfaces").AbstractWorker;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const USVString = @import("interfaces").USVString;
const WorkerOptions = @import("dictionaries").WorkerOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const TrustedScriptURL = @import("interfaces").TrustedScriptURL;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MessagePort = @import("interfaces").MessagePort;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const SharedWorker = struct {
    pub const Meta = struct {
        pub const name = "SharedWorker";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{
            AbstractWorker,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "port", "get_port", null },
            .{ "onerror", "get_onerror", "set_onerror" },
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
            .{ "port", "get_port", null },
            .{ "onerror", "get_onerror", "set_onerror" },
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
            port: *runtime.Instance = undefined,
            onerror: EventHandler = undefined,
            _internal: ?*SharedWorkerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onerror = &get_onerror,
        .get_port = &get_port,

        .set_onerror = &set_onerror,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SharedWorkerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedWorkerImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, scriptURL: DOMString, options: webidl.Opt(*const anyopaque)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SharedWorkerImpl.call_constructor(allocator, ctx, scriptURL, options);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SharedWorkerImpl.get_port(instance);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SharedWorkerImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SharedWorkerImpl.set_onerror(instance, value);
    }

};
