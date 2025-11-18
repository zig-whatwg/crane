//! Generated from: fedcm.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdentityProviderImpl = @import("impls").IdentityProvider;
const IdentityResolveOptions = @import("dictionaries").IdentityResolveOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<sequence<IdentityUserInfo>> = @import("interfaces").Promise<sequence<IdentityUserInfo>>;
const IdentityProviderConfig = @import("dictionaries").IdentityProviderConfig;

pub const IdentityProvider = struct {
    pub const Meta = struct {
        pub const name = "IdentityProvider";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IdentityProvider, .{
        .deinit_fn = &deinit_wrapper,

        .call_close = &call_close,
        .call_getUserInfo = &call_getUserInfo,
        .call_resolve = &call_resolve,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        IdentityProviderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdentityProviderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_resolve(instance: *runtime.Instance, token: anyopaque, options: IdentityResolveOptions) anyerror!anyopaque {
        
        return try IdentityProviderImpl.call_resolve(instance, token, options);
    }

    pub fn call_getUserInfo(instance: *runtime.Instance, config: IdentityProviderConfig) anyerror!anyopaque {
        
        return try IdentityProviderImpl.call_getUserInfo(instance, config);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try IdentityProviderImpl.call_close(instance);
    }

};
