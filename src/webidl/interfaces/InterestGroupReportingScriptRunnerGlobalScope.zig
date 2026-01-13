//! Generated from: turtledove.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const InterestGroupReportingScriptRunnerGlobalScopeImpl = @import("impls").InterestGroupReportingScriptRunnerGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const InterestGroupScriptRunnerGlobalScope = @import("InterestGroupScriptRunnerGlobalScope.zig").InterestGroupScriptRunnerGlobalScope;
const ProtectedAudienceUtilities = @import("ProtectedAudienceUtilities.zig").ProtectedAudienceUtilities;
const USVString = @import("typedefs").USVString;
const PrivateAggregation = @import("PrivateAggregation.zig").PrivateAggregation;
const DOMString = @import("typedefs").DOMString;

pub const InterestGroupReportingScriptRunnerGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "InterestGroupReportingScriptRunnerGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = InterestGroupScriptRunnerGlobalScope.State;
        pub const ParentInterface = InterestGroupScriptRunnerGlobalScope;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*InterestGroupReportingScriptRunnerGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_registerAdBeacon = &call_registerAdBeacon,
        .call_registerAdMacro = &call_registerAdMacro,
        .call_sendReportTo = &call_sendReportTo,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return InterestGroupReportingScriptRunnerGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        InterestGroupReportingScriptRunnerGlobalScopeImpl.deinit(instance);
    }

    pub fn call_sendReportTo(instance: *runtime.Instance, url: DOMString) anyerror!void {
        
        return try InterestGroupReportingScriptRunnerGlobalScopeImpl.call_sendReportTo(instance, url);
    }

    pub fn call_registerAdBeacon(instance: *runtime.Instance, map: runtime.JSValue) anyerror!void {
        
        return try InterestGroupReportingScriptRunnerGlobalScopeImpl.call_registerAdBeacon(instance, map);
    }

    pub fn call_registerAdMacro(instance: *runtime.Instance, name: DOMString, value: runtime.USVString) anyerror!void {
        
        return try InterestGroupReportingScriptRunnerGlobalScopeImpl.call_registerAdMacro(instance, name, value);
    }

};
