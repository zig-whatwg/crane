//! Generated from: turtledove.idl
//! Generated at: 2025-11-23T19:17:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const InterestGroupReportingScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupReportingScriptRunnerGlobalScope;
const InterestGroupScriptRunnerGlobalScope = @import("interfaces").InterestGroupScriptRunnerGlobalScope;
const ProtectedAudienceUtilities = @import("interfaces").ProtectedAudienceUtilities;
const PrivateAggregation = @import("interfaces").PrivateAggregation;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const InterestGroupReportingScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupReportingScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *InterestGroupScriptRunnerGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "InterestGroupReportingScriptRunnerGlobalScope" } },
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "InterestGroupScriptRunnerGlobalScope", "InterestGroupReportingScriptRunnerGlobalScope" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .InterestGroupReportingScriptRunnerGlobalScope = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "sendReportTo", "call_sendReportTo", 1 },
            .{ "registerAdBeacon", "call_registerAdBeacon", 1 },
            .{ "registerAdMacro", "call_registerAdMacro", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "sendReportTo",
            "registerAdBeacon",
            "registerAdMacro",
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

        .call_registerAdBeacon = &call_registerAdBeacon,
        .call_registerAdMacro = &call_registerAdMacro,
        .call_sendReportTo = &call_sendReportTo,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupReportingScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn call_registerAdMacro(instance: *runtime.Instance, name: DOMString, value: runtime.USVString) anyerror!void {
        
        return try InterestGroupReportingScriptRunnerGlobalScopeImpl.call_registerAdMacro(instance, name, value);
    }

    pub fn call_registerAdBeacon(instance: *runtime.Instance, map: *const anyopaque) anyerror!void {
        
        return try InterestGroupReportingScriptRunnerGlobalScopeImpl.call_registerAdBeacon(instance, map);
    }

    pub fn call_sendReportTo(instance: *runtime.Instance, url: DOMString) anyerror!void {
        
        return try InterestGroupReportingScriptRunnerGlobalScopeImpl.call_sendReportTo(instance, url);
    }

};
