//! Generated from: turtledove.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ForDebuggingOnlyImpl = @import("impls").ForDebuggingOnly;
const USVString = @import("interfaces").USVString;

pub const ForDebuggingOnly = struct {
    pub const Meta = struct {
        pub const name = "ForDebuggingOnly";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupBiddingAndScoringScriptRunnerGlobalScope" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupBiddingAndScoringScriptRunnerGlobalScope = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "reportAdAuctionWin", "call_reportAdAuctionWin", 1 },
            .{ "reportAdAuctionLoss", "call_reportAdAuctionLoss", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "reportAdAuctionWin",
            "reportAdAuctionLoss",
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
            _internal: ?*ForDebuggingOnlyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_reportAdAuctionLoss = &call_reportAdAuctionLoss,
        .call_reportAdAuctionWin = &call_reportAdAuctionWin,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ForDebuggingOnlyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ForDebuggingOnlyImpl.deinit(instance);
    }

    pub fn call_reportAdAuctionLoss(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        
        return try ForDebuggingOnlyImpl.call_reportAdAuctionLoss(instance, url);
    }

    pub fn call_reportAdAuctionWin(instance: *runtime.Instance, url: runtime.USVString) anyerror!void {
        
        return try ForDebuggingOnlyImpl.call_reportAdAuctionWin(instance, url);
    }

};
