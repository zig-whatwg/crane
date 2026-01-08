//! Generated from: turtledove.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const InterestGroupScriptRunnerGlobalScope = @import("interfaces").InterestGroupScriptRunnerGlobalScope;
const RealTimeReporting = @import("interfaces").RealTimeReporting;
const PrivateAggregation = @import("interfaces").PrivateAggregation;
const ForDebuggingOnly = @import("interfaces").ForDebuggingOnly;
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;

pub const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = InterestGroupScriptRunnerGlobalScope.State;
        pub const ParentInterface = InterestGroupScriptRunnerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingAndScoringScriptRunnerGlobalScope = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "forDebuggingOnly", "get_forDebuggingOnly", null },
            .{ "realTimeReporting", "get_realTimeReporting", null },
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
            .{ "forDebuggingOnly", "get_forDebuggingOnly", null },
            .{ "realTimeReporting", "get_realTimeReporting", null },
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
            forDebuggingOnly: *runtime.Instance = undefined,
            realTimeReporting: *runtime.Instance = undefined,
            _internal: ?*InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_forDebuggingOnly = &get_forDebuggingOnly,
        .get_realTimeReporting = &get_realTimeReporting,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn get_forDebuggingOnly(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_forDebuggingOnly(instance);
    }

    pub fn get_realTimeReporting(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try InterestGroupBiddingAndScoringScriptRunnerGlobalScopeImpl.get_realTimeReporting(instance);
    }

};
