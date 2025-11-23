//! Generated from: turtledove.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupScriptRunnerGlobalScope;
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const InterestGroupScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupScriptRunnerGlobalScope = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "privateAggregation", "get_privateAggregation", null },
            .{ "protectedAudience", "get_protectedAudience", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "privateAggregation", "get_privateAggregation", null },
            .{ "protectedAudience", "get_protectedAudience", null },
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
            privateAggregation: ?PrivateAggregation = null,
            protectedAudience: ProtectedAudienceUtilities = undefined,
        },
    );

    const delegates = .{

        .get_privateAggregation = &get_privateAggregation,
        .get_protectedAudience = &get_protectedAudience,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!PrivateAggregation {
        return try InterestGroupScriptRunnerGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!ProtectedAudienceUtilities {
        return try InterestGroupScriptRunnerGlobalScopeImpl.get_protectedAudience(instance);
    }

};
