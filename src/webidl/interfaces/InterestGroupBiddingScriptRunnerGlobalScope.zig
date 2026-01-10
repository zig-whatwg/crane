//! Generated from: turtledove.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const InterestGroupBiddingScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupBiddingScriptRunnerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const InterestGroupBiddingAndScoringScriptRunnerGlobalScope = @import("InterestGroupBiddingAndScoringScriptRunnerGlobalScope.zig").InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
const ProtectedAudienceUtilities = @import("ProtectedAudienceUtilities.zig").ProtectedAudienceUtilities;
const RealTimeReporting = @import("RealTimeReporting.zig").RealTimeReporting;
const GenerateBidOutput = @import("dictionaries").GenerateBidOutput;
const ForDebuggingOnly = @import("ForDebuggingOnly.zig").ForDebuggingOnly;
const DOMString = @import("typedefs").DOMString;
const PrivateAggregation = @import("PrivateAggregation.zig").PrivateAggregation;

pub const InterestGroupBiddingScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupBiddingScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = InterestGroupBiddingAndScoringScriptRunnerGlobalScope.State;
        pub const ParentInterface = InterestGroupBiddingAndScoringScriptRunnerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "InterestGroupBiddingScriptRunnerGlobalScope" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingScriptRunnerGlobalScope = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setBid", "call_setBid", 0 },
            .{ "setPriority", "call_setPriority", 1 },
            .{ "setPrioritySignalsOverride", "call_setPrioritySignalsOverride", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setBid",
            "setPriority",
            "setPrioritySignalsOverride",
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
            _internal: ?*InterestGroupBiddingScriptRunnerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_setBid = &call_setBid,
        .call_setPriority = &call_setPriority,
        .call_setPrioritySignalsOverride = &call_setPrioritySignalsOverride,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return InterestGroupBiddingScriptRunnerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupBiddingScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn call_setBid(instance: *runtime.Instance, oneOrManyBids: webidl.Opt(runtime.JSValue)) anyerror!bool {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setBid(instance, oneOrManyBids);
    }

    pub fn call_setPriority(instance: *runtime.Instance, priority: f64) anyerror!void {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPriority(instance, priority);
    }

    pub fn call_setPrioritySignalsOverride(instance: *runtime.Instance, key: DOMString, priority: webidl.Opt(?f64)) anyerror!void {
        
        return try InterestGroupBiddingScriptRunnerGlobalScopeImpl.call_setPrioritySignalsOverride(instance, key, priority);
    }

};
