//! Generated from: service-workers.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FetchEventImpl = @import("impls").FetchEvent;
const ExtendableEvent = @import("interfaces").ExtendableEvent;
const ExtendableEventInit = @import("dictionaries").ExtendableEventInit;
const EventTarget = @import("interfaces").EventTarget;
const Request = @import("interfaces").Request;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const Response = @import("interfaces").Response;
const DOMString = @import("typedefs").DOMString;
const FetchEventInit = @import("dictionaries").FetchEventInit;

pub const FetchEvent = struct {
    pub const Meta = struct {
        pub const name = "FetchEvent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ExtendableEvent;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "request", "get_request", null },
            .{ "preloadResponse", "get_preloadResponse", null },
            .{ "clientId", "get_clientId", null },
            .{ "resultingClientId", "get_resultingClientId", null },
            .{ "replacesClientId", "get_replacesClientId", null },
            .{ "handled", "get_handled", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "respondWith", "call_respondWith", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "respondWith",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
            "waitUntil",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "request", "get_request", null },
            .{ "preloadResponse", "get_preloadResponse", null },
            .{ "clientId", "get_clientId", null },
            .{ "resultingClientId", "get_resultingClientId", null },
            .{ "replacesClientId", "get_replacesClientId", null },
            .{ "handled", "get_handled", null },
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
            request: Request = undefined,
            preloadResponse: runtime.Promise(*const anyopaque) = undefined,
            clientId: runtime.DOMString = undefined,
            resultingClientId: runtime.DOMString = undefined,
            replacesClientId: runtime.DOMString = undefined,
            handled: runtime.Promise(void) = undefined,
            cached_request: ?Request = null,
        },
    );

    const delegates = .{

        .get_clientId = &get_clientId,
        .get_handled = &get_handled,
        .get_preloadResponse = &get_preloadResponse,
        .get_replacesClientId = &get_replacesClientId,
        .get_request = &get_request,
        .get_resultingClientId = &get_resultingClientId,

        .call_respondWith = &call_respondWith,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FetchEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FetchEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: FetchEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FetchEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_request(instance: *runtime.Instance) anyerror!Request {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_request) |cached| {
            return cached;
        }
        const value = try FetchEventImpl.get_request(instance);
        state.own.cached_request = value;
        return value;
    }

    pub fn get_preloadResponse(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FetchEventImpl.get_preloadResponse(instance);
    }

    pub fn get_clientId(instance: *runtime.Instance) anyerror!DOMString {
        return try FetchEventImpl.get_clientId(instance);
    }

    pub fn get_resultingClientId(instance: *runtime.Instance) anyerror!DOMString {
        return try FetchEventImpl.get_resultingClientId(instance);
    }

    pub fn get_replacesClientId(instance: *runtime.Instance) anyerror!DOMString {
        return try FetchEventImpl.get_replacesClientId(instance);
    }

    pub fn get_handled(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FetchEventImpl.get_handled(instance);
    }

    pub fn call_respondWith(instance: *runtime.Instance, r: *const anyopaque) anyerror!void {
        
        return try FetchEventImpl.call_respondWith(instance, r);
    }

};
