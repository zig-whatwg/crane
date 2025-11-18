//! Generated from: permissions-policy.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsPolicyImpl = @import("impls").PermissionsPolicy;

pub const PermissionsPolicy = struct {
    pub const Meta = struct {
        pub const name = "PermissionsPolicy";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PermissionsPolicy, .{
        .deinit_fn = &deinit_wrapper,

        .call_allowedFeatures = &call_allowedFeatures,
        .call_allowsFeature = &call_allowsFeature,
        .call_features = &call_features,
        .call_getAllowlistForFeature = &call_getAllowlistForFeature,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PermissionsPolicyImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PermissionsPolicyImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_allowsFeature(instance: *runtime.Instance, feature: DOMString, origin: DOMString) anyerror!bool {
        
        return try PermissionsPolicyImpl.call_allowsFeature(instance, feature, origin);
    }

    pub fn call_allowedFeatures(instance: *runtime.Instance) anyerror!anyopaque {
        return try PermissionsPolicyImpl.call_allowedFeatures(instance);
    }

    pub fn call_features(instance: *runtime.Instance) anyerror!anyopaque {
        return try PermissionsPolicyImpl.call_features(instance);
    }

    pub fn call_getAllowlistForFeature(instance: *runtime.Instance, feature: DOMString) anyerror!anyopaque {
        
        return try PermissionsPolicyImpl.call_getAllowlistForFeature(instance, feature);
    }

};
