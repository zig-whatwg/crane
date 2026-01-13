//! Generated from: permissions-policy.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PermissionsPolicyImpl = @import("impls").PermissionsPolicy;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const PermissionsPolicy = struct {
    pub const Meta = struct {
        pub const name = "PermissionsPolicy";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        struct {
            _internal: ?*PermissionsPolicyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_allowedFeatures = &call_allowedFeatures,
        .call_allowsFeature = &call_allowsFeature,
        .call_features = &call_features,
        .call_getAllowlistForFeature = &call_getAllowlistForFeature,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PermissionsPolicyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return PermissionsPolicyImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PermissionsPolicyImpl.deinit(instance);
    }

    pub fn call_features(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PermissionsPolicyImpl.call_features(instance);
    }

    pub fn call_getAllowlistForFeature(instance: *runtime.Instance, feature: DOMString) anyerror!runtime.JSValue {
        
        return try PermissionsPolicyImpl.call_getAllowlistForFeature(instance, feature);
    }

    pub fn call_allowedFeatures(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try PermissionsPolicyImpl.call_allowedFeatures(instance);
    }

    pub fn call_allowsFeature(instance: *runtime.Instance, feature: DOMString, origin: webidl.Opt(DOMString)) anyerror!bool {
        
        return try PermissionsPolicyImpl.call_allowsFeature(instance, feature, origin);
    }

};
