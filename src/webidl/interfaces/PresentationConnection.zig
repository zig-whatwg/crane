//! Generated from: presentation-api.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PresentationConnectionImpl = @import("impls").PresentationConnection;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PresentationConnectionState = @import("enums").PresentationConnectionState;
const Blob = @import("interfaces").Blob;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const USVString = @import("interfaces").USVString;
const BinaryType = @import("enums").BinaryType;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const PresentationConnection = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnection";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "url", "get_url", null },
            .{ "state", "get_state", null },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onterminate", "get_onterminate", "set_onterminate" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "terminate", "call_terminate", 0 },
            .{ "send", "call_send", 1 },
            .{ "send", "call_send", 1 },
            .{ "send", "call_send", 1 },
            .{ "send", "call_send", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "terminate",
            "send",
            "send",
            "send",
            "send",
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
            .{ "id", "get_id", null },
            .{ "url", "get_url", null },
            .{ "state", "get_state", null },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onterminate", "get_onterminate", "set_onterminate" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
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
            id: runtime.USVString = undefined,
            url: runtime.USVString = undefined,
            state: PresentationConnectionState = undefined,
            onconnect: EventHandler = undefined,
            onclose: EventHandler = undefined,
            onterminate: EventHandler = undefined,
            binaryType: BinaryType = undefined,
            onmessage: EventHandler = undefined,
        },
    );

    const delegates = .{

        .get_binaryType = &get_binaryType,
        .get_id = &get_id,
        .get_onclose = &get_onclose,
        .get_onconnect = &get_onconnect,
        .get_onmessage = &get_onmessage,
        .get_onterminate = &get_onterminate,
        .get_state = &get_state,
        .get_url = &get_url,

        .set_binaryType = &set_binaryType,
        .set_onclose = &set_onclose,
        .set_onconnect = &set_onconnect,
        .set_onmessage = &set_onmessage,
        .set_onterminate = &set_onterminate,

        .call_close = &call_close,
        .call_send = &call_send,
        .call_terminate = &call_terminate,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PresentationConnectionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PresentationConnectionImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PresentationConnectionImpl.get_id(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PresentationConnectionImpl.get_url(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PresentationConnectionState {
        return try PresentationConnectionImpl.get_state(instance);
    }

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onconnect(instance);
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onconnect(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onclose(instance, value);
    }

    pub fn get_onterminate(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onterminate(instance);
    }

    pub fn set_onterminate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onterminate(instance, value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyerror!BinaryType {
        return try PresentationConnectionImpl.get_binaryType(instance);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: BinaryType) anyerror!void {
        try PresentationConnectionImpl.set_binaryType(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try PresentationConnectionImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try PresentationConnectionImpl.set_onmessage(instance, value);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
        return try PresentationConnectionImpl.call_terminate(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try PresentationConnectionImpl.call_close(instance);
    }

    pub fn call_send(instance: *runtime.Instance, message: DOMString) anyerror!void {
        
        return try PresentationConnectionImpl.call_send(instance, message);
    }

};
