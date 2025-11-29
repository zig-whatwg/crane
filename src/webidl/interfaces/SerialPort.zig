//! Generated from: serial.idl
//! Generated at: 2025-11-29T02:15:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SerialPortImpl = @import("impls").SerialPort;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const SerialOutputSignals = @import("dictionaries").SerialOutputSignals;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const SerialInputSignals = @import("dictionaries").SerialInputSignals;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const ReadableStream = @import("interfaces").ReadableStream;
const SerialPortInfo = @import("dictionaries").SerialPortInfo;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const SerialOptions = @import("dictionaries").SerialOptions;
const WritableStream = @import("interfaces").WritableStream;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const SerialPort = struct {
    pub const Meta = struct {
        pub const name = "SerialPort";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            .{ "connected", "get_connected", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getInfo", "call_getInfo", 0 },
            .{ "open", "call_open", 1 },
            .{ "setSignals", "call_setSignals", 0 },
            .{ "getSignals", "call_getSignals", 0 },
            .{ "close", "call_close", 0 },
            .{ "forget", "call_forget", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getInfo",
            "open",
            "setSignals",
            "getSignals",
            "close",
            "forget",
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
            .{ "connected", "get_connected", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
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
            onconnect: EventHandler = undefined,
            ondisconnect: EventHandler = undefined,
            connected: bool = undefined,
            readable: *runtime.Instance = undefined,
            writable: *runtime.Instance = undefined,
            _internal: ?*SerialPortImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_connected = &get_connected,
        .get_onconnect = &get_onconnect,
        .get_ondisconnect = &get_ondisconnect,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .set_onconnect = &set_onconnect,
        .set_ondisconnect = &set_ondisconnect,

        .call_close = &call_close,
        .call_forget = &call_forget,
        .call_getInfo = &call_getInfo,
        .call_getSignals = &call_getSignals,
        .call_open = &call_open,
        .call_setSignals = &call_setSignals,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SerialPortImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SerialPortImpl.deinit(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialPortImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialPortImpl.set_onconnect(instance, value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try SerialPortImpl.get_ondisconnect(instance);
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SerialPortImpl.set_ondisconnect(instance, value);
    }

    pub fn get_connected(instance: *runtime.Instance) anyerror!bool {
        return try SerialPortImpl.get_connected(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SerialPortImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SerialPortImpl.get_writable(instance);
    }

    pub fn call_forget(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SerialPortImpl.call_forget(instance);
    }

    pub fn call_getInfo(instance: *runtime.Instance) anyerror!SerialPortInfo {
        return try SerialPortImpl.call_getInfo(instance);
    }

    pub fn call_open(instance: *runtime.Instance, options: SerialOptions) anyerror!*const anyopaque {
        
        return try SerialPortImpl.call_open(instance, options);
    }

    pub fn call_setSignals(instance: *runtime.Instance, signals: webidl.Opt(SerialOutputSignals)) anyerror!*const anyopaque {
        
        return try SerialPortImpl.call_setSignals(instance, signals);
    }

    pub fn call_getSignals(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SerialPortImpl.call_getSignals(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SerialPortImpl.call_close(instance);
    }

};
