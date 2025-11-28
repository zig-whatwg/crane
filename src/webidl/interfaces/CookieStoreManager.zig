//! Generated from: cookiestore.idl
//! Generated at: 2025-11-28T22:33:21Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CookieStoreManagerImpl = @import("impls").CookieStoreManager;
const mixins = @import("mixins");
const CookieStoreGetOptions = @import("dictionaries").CookieStoreGetOptions;

pub const CookieStoreManager = struct {
    pub const Meta = struct {
        pub const name = "CookieStoreManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "ServiceWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .ServiceWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "subscribe", "call_subscribe", 1 },
            .{ "getSubscriptions", "call_getSubscriptions", 0 },
            .{ "unsubscribe", "call_unsubscribe", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "subscribe",
            "getSubscriptions",
            "unsubscribe",
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
            _internal: ?*CookieStoreManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getSubscriptions = &call_getSubscriptions,
        .call_subscribe = &call_subscribe,
        .call_unsubscribe = &call_unsubscribe,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CookieStoreManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CookieStoreManagerImpl.deinit(instance);
    }

    pub fn call_unsubscribe(instance: *runtime.Instance, subscriptions: *const anyopaque) anyerror!*const anyopaque {
        
        return try CookieStoreManagerImpl.call_unsubscribe(instance, subscriptions);
    }

    pub fn call_subscribe(instance: *runtime.Instance, subscriptions: *const anyopaque) anyerror!*const anyopaque {
        
        return try CookieStoreManagerImpl.call_subscribe(instance, subscriptions);
    }

    pub fn call_getSubscriptions(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CookieStoreManagerImpl.call_getSubscriptions(instance);
    }

};
