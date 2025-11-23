//! Generated from: credential-management.idl
//! Generated at: 2025-11-23T19:47:42Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CredentialImpl = @import("impls").Credential;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const Credential = struct {
    pub const Meta = struct {
        pub const name = "Credential";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "isConditionalMediationAvailable", "call_isConditionalMediationAvailable", 0 },
            .{ "willRequestConditionalCreation", "call_willRequestConditionalCreation", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "isConditionalMediationAvailable",
            "willRequestConditionalCreation",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", null },
            .{ "type", "get_type", null },
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
            id: runtime.USVString = undefined,
            @"type": runtime.DOMString = undefined,
            _internal: ?*CredentialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_id = &get_id,
        .get_type = &get_type,

        .call_isConditionalMediationAvailable = &call_isConditionalMediationAvailable,
        .call_willRequestConditionalCreation = &call_willRequestConditionalCreation,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CredentialImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CredentialImpl.get_id(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try CredentialImpl.get_type(instance);
    }

    pub fn call_willRequestConditionalCreation(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CredentialImpl.call_willRequestConditionalCreation(instance);
    }

    pub fn call_isConditionalMediationAvailable(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CredentialImpl.call_isConditionalMediationAvailable(instance);
    }

};
