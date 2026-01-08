//! Generated from: turtledove.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const InterestGroupScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupScriptRunnerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const InterestGroupScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            privateAggregation: ?*runtime.Instance = null,
            protectedAudience: *runtime.Instance = undefined,
            _internal: ?*InterestGroupScriptRunnerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_privateAggregation = &get_privateAggregation,
        .get_protectedAudience = &get_protectedAudience,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return InterestGroupScriptRunnerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try InterestGroupScriptRunnerGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_protectedAudience(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try InterestGroupScriptRunnerGlobalScopeImpl.get_protectedAudience(instance);
    }

};
