//! Generated from: push-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PushManagerImpl = @import("impls").PushManager;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PermissionState = @import("enums").PermissionState;
const PushSubscription = @import("PushSubscription.zig").PushSubscription;
const PushSubscriptionOptionsInit = @import("dictionaries").PushSubscriptionOptionsInit;
const DOMString = @import("typedefs").DOMString;

pub const PushManager = struct {
    pub const Meta = struct {
        pub const name = "PushManager";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "supportedContentEncodings", "get_supportedContentEncodings", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "subscribe", "call_subscribe", 0 },
            .{ "getSubscription", "call_getSubscription", 0 },
            .{ "permissionState", "call_permissionState", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "subscribe",
            "getSubscription",
            "permissionState",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "supportedContentEncodings", "get_supportedContentEncodings", null },
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
            _internal: ?*PushManagerImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_supportedContentEncodings = &get_supportedContentEncodings,

        .call_getSubscription = &call_getSubscription,
        .call_permissionState = &call_permissionState,
        .call_subscribe = &call_subscribe,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PushManagerImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PushManagerImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushManagerImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_supportedContentEncodings(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PushManagerImpl.get_supportedContentEncodings(instance);
    }

    pub fn call_subscribe(instance: *runtime.Instance, options: webidl.Opt(PushSubscriptionOptionsInit)) anyerror!runtime.JSValue {
        
        return try PushManagerImpl.call_subscribe(instance, options);
    }

    pub fn call_getSubscription(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PushManagerImpl.call_getSubscription(instance);
    }

    pub fn call_permissionState(instance: *runtime.Instance, options: webidl.Opt(PushSubscriptionOptionsInit)) anyerror!runtime.JSValue {
        
        return try PushManagerImpl.call_permissionState(instance, options);
    }

};
