//! Generated from: push-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PushSubscriptionImpl = @import("impls").PushSubscription;
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const PushSubscriptionJSON = @import("dictionaries").PushSubscriptionJSON;
const PushSubscriptionOptions = @import("interfaces").PushSubscriptionOptions;
const PushEncryptionKeyName = @import("enums").PushEncryptionKeyName;

pub const PushSubscription = struct {
    pub const Meta = struct {
        pub const name = "PushSubscription";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            endpoint: runtime.USVString = undefined,
            expirationTime: ?EpochTimeStamp = null,
            options: PushSubscriptionOptions = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PushSubscription, .{
        .deinit_fn = &deinit_wrapper,

        .get_endpoint = &get_endpoint,
        .get_expirationTime = &get_expirationTime,
        .get_options = &get_options,

        .call_getKey = &call_getKey,
        .call_toJSON = &call_toJSON,
        .call_unsubscribe = &call_unsubscribe,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PushSubscriptionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PushSubscriptionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_endpoint(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PushSubscriptionImpl.get_endpoint(instance);
    }

    pub fn get_expirationTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try PushSubscriptionImpl.get_expirationTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_options(instance: *runtime.Instance) anyerror!PushSubscriptionOptions {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_options) |cached| {
            return cached;
        }
        const value = try PushSubscriptionImpl.get_options(instance);
        state.cached_options = value;
        return value;
    }

    pub fn call_unsubscribe(instance: *runtime.Instance) anyerror!anyopaque {
        return try PushSubscriptionImpl.call_unsubscribe(instance);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!PushSubscriptionJSON {
        return try PushSubscriptionImpl.call_toJSON(instance);
    }

    pub fn call_getKey(instance: *runtime.Instance, name: PushEncryptionKeyName) anyerror!anyopaque {
        
        return try PushSubscriptionImpl.call_getKey(instance, name);
    }

};
