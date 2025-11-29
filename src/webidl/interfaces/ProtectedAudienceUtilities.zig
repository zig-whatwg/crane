//! Generated from: turtledove.idl
//! Generated at: 2025-11-29T11:15:57Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ProtectedAudienceUtilitiesImpl = @import("impls").ProtectedAudienceUtilities;
const mixins = @import("mixins");
const USVString = @import("interfaces").USVString;

pub const ProtectedAudienceUtilities = struct {
    pub const Meta = struct {
        pub const name = "ProtectedAudienceUtilities";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "encodeUtf8", "call_encodeUtf8", 1 },
            .{ "decodeUtf8", "call_decodeUtf8", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "encodeUtf8",
            "decodeUtf8",
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
            _internal: ?*ProtectedAudienceUtilitiesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_decodeUtf8 = &call_decodeUtf8,
        .call_encodeUtf8 = &call_encodeUtf8,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ProtectedAudienceUtilitiesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ProtectedAudienceUtilitiesImpl.deinit(instance);
    }

    pub fn call_decodeUtf8(instance: *runtime.Instance, bytes: *const anyopaque) anyerror!runtime.USVString {
        
        return try ProtectedAudienceUtilitiesImpl.call_decodeUtf8(instance, bytes);
    }

    pub fn call_encodeUtf8(instance: *runtime.Instance, input: runtime.USVString) anyerror!*const anyopaque {
        
        return try ProtectedAudienceUtilitiesImpl.call_encodeUtf8(instance, input);
    }

};
