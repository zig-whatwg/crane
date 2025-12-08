//! Generated from: background-fetch.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BackgroundFetchManagerImpl = @import("impls").BackgroundFetchManager;
const mixins = @import("mixins");
const BackgroundFetchRegistration = @import("interfaces").BackgroundFetchRegistration;
const RequestInfo = @import("typedefs").RequestInfo;
const sequence = @import("interfaces").sequence;
const DOMString = @import("typedefs").DOMString;
const BackgroundFetchOptions = @import("dictionaries").BackgroundFetchOptions;

pub const BackgroundFetchManager = struct {
    pub const Meta = struct {
        pub const name = "BackgroundFetchManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "fetch", "call_fetch", 2 },
            .{ "get", "call_get", 1 },
            .{ "getIds", "call_getIds", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "fetch",
            "get",
            "getIds",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*BackgroundFetchManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_fetch = &call_fetch,
        .call_get = &call_get,
        .call_getIds = &call_getIds,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BackgroundFetchManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BackgroundFetchManagerImpl.deinit(instance);
    }

    pub fn call_get(instance: *runtime.Instance, id: DOMString) anyerror!*const anyopaque {
        
        return try BackgroundFetchManagerImpl.call_get(instance, id);
    }

    pub fn call_getIds(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try BackgroundFetchManagerImpl.call_getIds(instance);
    }

    pub fn call_fetch(instance: *runtime.Instance, id: DOMString, requests: *const anyopaque, options: webidl.Opt(BackgroundFetchOptions)) anyerror!*const anyopaque {
        
        return try BackgroundFetchManagerImpl.call_fetch(instance, id, requests, options);
    }

};
