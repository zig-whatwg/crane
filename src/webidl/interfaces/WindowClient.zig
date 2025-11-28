//! Generated from: service-workers.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WindowClientImpl = @import("impls").WindowClient;
const mixins = @import("mixins");
const Client = @import("interfaces").Client;
const VisibilityState = @import("interfaces").VisibilityState;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const FrameType = @import("enums").FrameType;
const ClientLifecycleState = @import("enums").ClientLifecycleState;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;
const ClientType = @import("enums").ClientType;

pub const WindowClient = struct {
    pub const Meta = struct {
        pub const name = "WindowClient";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Client;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "ServiceWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .ServiceWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "visibilityState", "get_visibilityState", null },
            .{ "focused", "get_focused", null },
            .{ "ancestorOrigins", "get_ancestorOrigins", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "focus", "call_focus", 0 },
            .{ "navigate", "call_navigate", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "focus",
            "navigate",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "postMessage",
            "postMessage",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "visibilityState", "get_visibilityState", null },
            .{ "focused", "get_focused", null },
            .{ "ancestorOrigins", "get_ancestorOrigins", null },
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
            visibilityState: VisibilityState = undefined,
            focused: bool = undefined,
            ancestorOrigins: runtime.FrozenArray(runtime.USVString) = undefined,
            cached_ancestorOrigins: ?runtime.FrozenArray(runtime.USVString) = null,
            _internal: ?*WindowClientImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_ancestorOrigins = &get_ancestorOrigins,
        .get_focused = &get_focused,
        .get_visibilityState = &get_visibilityState,

        .call_focus = &call_focus,
        .call_navigate = &call_navigate,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WindowClientImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WindowClientImpl.deinit(instance);
    }

    pub fn get_visibilityState(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try WindowClientImpl.get_visibilityState(instance);
    }

    pub fn get_focused(instance: *runtime.Instance) anyerror!bool {
        return try WindowClientImpl.get_focused(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_ancestorOrigins(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_ancestorOrigins) |cached| {
            return cached;
        }
        const value = try WindowClientImpl.get_ancestorOrigins(instance);
        state.own.cached_ancestorOrigins = value;
        return value;
    }

    /// Extended attributes: [NewObject]
    pub fn call_focus(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try WindowClientImpl.call_focus(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try WindowClientImpl.call_navigate(instance, url);
    }

};
