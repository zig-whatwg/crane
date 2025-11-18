//! Generated from: cookiestore.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CookieStoreManagerImpl = @import("impls").CookieStoreManager;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<sequence<CookieStoreGetOptions>> = @import("interfaces").Promise<sequence<CookieStoreGetOptions>>;

pub const CookieStoreManager = struct {
    pub const Meta = struct {
        pub const name = "CookieStoreManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "ServiceWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .ServiceWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CookieStoreManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_getSubscriptions = &call_getSubscriptions,
        .call_subscribe = &call_subscribe,
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
        CookieStoreManagerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CookieStoreManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_unsubscribe(instance: *runtime.Instance, subscriptions: anyopaque) anyerror!anyopaque {
        
        return try CookieStoreManagerImpl.call_unsubscribe(instance, subscriptions);
    }

    pub fn call_subscribe(instance: *runtime.Instance, subscriptions: anyopaque) anyerror!anyopaque {
        
        return try CookieStoreManagerImpl.call_subscribe(instance, subscriptions);
    }

    pub fn call_getSubscriptions(instance: *runtime.Instance) anyerror!anyopaque {
        return try CookieStoreManagerImpl.call_getSubscriptions(instance);
    }

};
