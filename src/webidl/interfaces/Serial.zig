//! Generated from: serial.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SerialImpl = @import("impls").Serial;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const SerialPortRequestOptions = @import("dictionaries").SerialPortRequestOptions;
const SerialPort = @import("SerialPort.zig").SerialPort;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("Observable.zig").Observable;

pub const Serial = struct {
    pub const Meta = struct {
        pub const name = "Serial";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getPorts", "call_getPorts", 0 },
            .{ "requestPort", "call_requestPort", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getPorts",
            "requestPort",
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
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
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
            onconnect: typedefs.EventHandler = undefined,
            ondisconnect: typedefs.EventHandler = undefined,
            _internal: ?*SerialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onconnect = &get_onconnect,
        .get_ondisconnect = &get_ondisconnect,

        .set_onconnect = &set_onconnect,
        .set_ondisconnect = &set_ondisconnect,

        .call_getPorts = &call_getPorts,
        .call_requestPort = &call_requestPort,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SerialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SerialImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SerialImpl.deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialImpl.set_ondisconnect(instance, value);
    }

    pub fn call_getPorts(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SerialImpl.call_getPorts(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPort(instance: *runtime.Instance, options: webidl.Opt(SerialPortRequestOptions)) anyerror!runtime.JSValue {
        
        return try SerialImpl.call_requestPort(instance, options);
    }

};
