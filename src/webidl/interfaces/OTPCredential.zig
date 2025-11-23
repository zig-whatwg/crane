//! Generated from: web-otp.idl
//! Generated at: 2025-11-23T19:17:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const OTPCredentialImpl = @import("impls").OTPCredential;
const Credential = @import("interfaces").Credential;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const OTPCredential = struct {
    pub const Meta = struct {
        pub const name = "OTPCredential";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Credential;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "code", "get_code", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "isConditionalMediationAvailable",
            "willRequestConditionalCreation",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "code", "get_code", null },
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
            code: runtime.DOMString = undefined,
            _internal: ?*OTPCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_code = &get_code,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return OTPCredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        OTPCredentialImpl.deinit(instance);
    }

    pub fn get_code(instance: *runtime.Instance) anyerror!DOMString {
        return try OTPCredentialImpl.get_code(instance);
    }

};
