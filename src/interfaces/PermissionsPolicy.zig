//! Generated from: permissions-policy.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsPolicyImpl = @import("../impls/PermissionsPolicy.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        PermissionsPolicyImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PermissionsPolicyImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_allowsFeature(instance: *runtime.Instance, feature: runtime.DOMString, origin: runtime.DOMString) bool {
        const state = instance.getState(State);
        
        return PermissionsPolicyImpl.call_allowsFeature(state, feature, origin);
    }

    pub fn call_allowedFeatures(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyImpl.call_allowedFeatures(state);
    }

    pub fn call_features(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PermissionsPolicyImpl.call_features(state);
    }

    pub fn call_getAllowlistForFeature(instance: *runtime.Instance, feature: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return PermissionsPolicyImpl.call_getAllowlistForFeature(state, feature);
    }

};
