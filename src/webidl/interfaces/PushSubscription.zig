//! Generated from: push-api.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushSubscriptionImpl = @import("impls").PushSubscription;
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const PushSubscriptionOptions = @import("interfaces").PushSubscriptionOptions;
const PushSubscriptionJSON = @import("dictionaries").PushSubscriptionJSON;
const USVString = @import("interfaces").USVString;
const PushEncryptionKeyName = @import("enums").PushEncryptionKeyName;

pub const PushSubscription = struct {
    pub const Meta = struct {
        pub const name = "PushSubscription";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            .{ "endpoint", "get_endpoint", null },
            .{ "expirationTime", "get_expirationTime", null },
            .{ "options", "get_options", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getKey", "call_getKey", 1 },
            .{ "unsubscribe", "call_unsubscribe", 0 },
            .{ "toJSON", "call_toJSON", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getKey",
            "unsubscribe",
            "toJSON",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "endpoint", "get_endpoint", null },
            .{ "expirationTime", "get_expirationTime", null },
            .{ "options", "get_options", null },
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
            endpoint: runtime.USVString = undefined,
            expirationTime: ?EpochTimeStamp = null,
            options: *runtime.Instance = undefined,
            cached_options: ?*runtime.Instance = null,
            _internal: ?*PushSubscriptionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_endpoint = &get_endpoint,
        .get_expirationTime = &get_expirationTime,
        .get_options = &get_options,

        .call_getKey = &call_getKey,
        .call_toJSON = &call_toJSON,
        .call_unsubscribe = &call_unsubscribe,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PushSubscriptionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushSubscriptionImpl.deinit(instance);
    }

    pub fn get_endpoint(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PushSubscriptionImpl.get_endpoint(instance);
    }

    pub fn get_expirationTime(instance: *runtime.Instance) anyerror!EpochTimeStamp {
        return try PushSubscriptionImpl.get_expirationTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_options(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_options) |cached| {
            return cached;
        }
        const value = try PushSubscriptionImpl.get_options(instance);
        state.own.cached_options = value;
        return value;
    }

    pub fn call_unsubscribe(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PushSubscriptionImpl.call_unsubscribe(instance);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PushSubscriptionJSON {
        return try PushSubscriptionImpl.call_toJSON(instance);
    }

    pub fn call_getKey(instance: *runtime.Instance, name: PushEncryptionKeyName) anyerror!*const anyopaque {
        
        return try PushSubscriptionImpl.call_getKey(instance, name);
    }

};
