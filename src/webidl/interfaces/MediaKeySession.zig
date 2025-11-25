//! Generated from: encrypted-media.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaKeySessionImpl = @import("impls").MediaKeySession;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MediaKeyStatusMap = @import("interfaces").MediaKeyStatusMap;
const MediaKeySessionClosedReason = @import("enums").MediaKeySessionClosedReason;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const MediaKeySession = struct {
    pub const Meta = struct {
        pub const name = "MediaKeySession";
        pub const is_mixin = false;
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
            .{ "sessionId", "get_sessionId", null },
            .{ "expiration", "get_expiration", null },
            .{ "closed", "get_closed", null },
            .{ "keyStatuses", "get_keyStatuses", null },
            .{ "onkeystatuseschange", "get_onkeystatuseschange", "set_onkeystatuseschange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "generateRequest", "call_generateRequest", 2 },
            .{ "load", "call_load", 1 },
            .{ "update", "call_update", 1 },
            .{ "close", "call_close", 0 },
            .{ "remove", "call_remove", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "generateRequest",
            "load",
            "update",
            "close",
            "remove",
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
            .{ "sessionId", "get_sessionId", null },
            .{ "expiration", "get_expiration", null },
            .{ "closed", "get_closed", null },
            .{ "keyStatuses", "get_keyStatuses", null },
            .{ "onkeystatuseschange", "get_onkeystatuseschange", "set_onkeystatuseschange" },
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
            sessionId: runtime.DOMString = undefined,
            expiration: f64 = undefined,
            closed: runtime.Promise(MediaKeySessionClosedReason) = undefined,
            keyStatuses: *runtime.Instance = undefined,
            onkeystatuseschange: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            _internal: ?*MediaKeySessionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_closed = &get_closed,
        .get_expiration = &get_expiration,
        .get_keyStatuses = &get_keyStatuses,
        .get_onkeystatuseschange = &get_onkeystatuseschange,
        .get_onmessage = &get_onmessage,
        .get_sessionId = &get_sessionId,

        .set_onkeystatuseschange = &set_onkeystatuseschange,
        .set_onmessage = &set_onmessage,

        .call_close = &call_close,
        .call_generateRequest = &call_generateRequest,
        .call_load = &call_load,
        .call_remove = &call_remove,
        .call_update = &call_update,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaKeySessionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaKeySessionImpl.deinit(instance);
    }

    pub fn get_sessionId(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaKeySessionImpl.get_sessionId(instance);
    }

    pub fn get_expiration(instance: *runtime.Instance) anyerror!f64 {
        return try MediaKeySessionImpl.get_expiration(instance);
    }

    pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaKeySessionImpl.get_closed(instance);
    }

    pub fn get_keyStatuses(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaKeySessionImpl.get_keyStatuses(instance);
    }

    pub fn get_onkeystatuseschange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaKeySessionImpl.get_onkeystatuseschange(instance);
    }

    pub fn set_onkeystatuseschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaKeySessionImpl.set_onkeystatuseschange(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaKeySessionImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaKeySessionImpl.set_onmessage(instance, value);
    }

    pub fn call_update(instance: *runtime.Instance, response: BufferSource) anyerror!*const anyopaque {
        
        return try MediaKeySessionImpl.call_update(instance, response);
    }

    pub fn call_remove(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaKeySessionImpl.call_remove(instance);
    }

    pub fn call_load(instance: *runtime.Instance, sessionId: DOMString) anyerror!*const anyopaque {
        
        return try MediaKeySessionImpl.call_load(instance, sessionId);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaKeySessionImpl.call_close(instance);
    }

    pub fn call_generateRequest(instance: *runtime.Instance, initDataType: DOMString, initData: BufferSource) anyerror!*const anyopaque {
        
        return try MediaKeySessionImpl.call_generateRequest(instance, initDataType, initData);
    }

};
