//! Generated from: fedcm.idl
//! Generated at: 2025-11-25T19:42:23Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IdentityCredentialErrorImpl = @import("impls").IdentityCredentialError;
const DOMException = @import("interfaces").DOMException;
const IdentityCredentialErrorInit = @import("dictionaries").IdentityCredentialErrorInit;
const DOMString = @import("typedefs").DOMString;
const USVString = @import("interfaces").USVString;

pub const IdentityCredentialError = struct {
    pub const Meta = struct {
        pub const name = "IdentityCredentialError";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMException;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "error", "get_error", null },
            .{ "url", "get_url", null },
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
            .{ "error", "get_error", null },
            .{ "url", "get_url", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"error": runtime.DOMString = undefined,
            url: runtime.USVString = undefined,
            _internal: ?*IdentityCredentialErrorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_error = &get_error,
        .get_url = &get_url,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IdentityCredentialErrorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdentityCredentialErrorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, message: DOMString, options: IdentityCredentialErrorInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IdentityCredentialErrorImpl.call_constructor(allocator, ctx, message, options);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!DOMString {
        return try IdentityCredentialErrorImpl.get_error(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try IdentityCredentialErrorImpl.get_url(instance);
    }

};
