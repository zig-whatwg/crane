//! Generated from: permissions-policy.idl
//! Generated at: 2025-11-23T01:18:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PermissionsPolicyImpl = @import("impls").PermissionsPolicy;
const DOMString = @import("typedefs").DOMString;

pub const PermissionsPolicy = struct {
    pub const Meta = struct {
        pub const name = "PermissionsPolicy";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "allowsFeature", "call_allowsFeature", 1 },
            .{ "features", "call_features", 0 },
            .{ "allowedFeatures", "call_allowedFeatures", 0 },
            .{ "getAllowlistForFeature", "call_getAllowlistForFeature", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "allowsFeature",
            "features",
            "allowedFeatures",
            "getAllowlistForFeature",
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
        struct {},
    );

    const delegates = .{

        .call_allowedFeatures = &call_allowedFeatures,
        .call_allowsFeature = &call_allowsFeature,
        .call_features = &call_features,
        .call_getAllowlistForFeature = &call_getAllowlistForFeature,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PermissionsPolicyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PermissionsPolicyImpl.deinit(instance);
    }

    pub fn call_allowsFeature(instance: *runtime.Instance, feature: DOMString, origin: DOMString) anyerror!bool {
        
        return try PermissionsPolicyImpl.call_allowsFeature(instance, feature, origin);
    }

    pub fn call_allowedFeatures(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PermissionsPolicyImpl.call_allowedFeatures(instance);
    }

    pub fn call_features(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try PermissionsPolicyImpl.call_features(instance);
    }

    pub fn call_getAllowlistForFeature(instance: *runtime.Instance, feature: DOMString) anyerror!*const anyopaque {
        
        return try PermissionsPolicyImpl.call_getAllowlistForFeature(instance, feature);
    }

};
