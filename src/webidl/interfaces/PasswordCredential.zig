//! Generated from: credential-management.idl
//! Generated at: 2025-11-29T02:15:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PasswordCredentialImpl = @import("impls").PasswordCredential;
const mixins = @import("mixins");
const Credential = @import("interfaces").Credential;
const CredentialUserData = @import("interfaces").CredentialUserData;
const HTMLFormElement = @import("interfaces").HTMLFormElement;
const PasswordCredentialData = @import("dictionaries").PasswordCredentialData;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const PasswordCredential = struct {
    pub const Meta = struct {
        pub const name = "PasswordCredential";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Credential;
        pub const MixinTypes = &.{
            CredentialUserData,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "password", "get_password", null },
            .{ "name", "get_name", null },
            .{ "iconURL", "get_iconURL", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "password", "get_password", null },
            .{ "name", "get_name", null },
            .{ "iconURL", "get_iconURL", null },
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
            password: runtime.USVString = undefined,
            name: runtime.USVString = undefined,
            iconURL: runtime.USVString = undefined,
            _internal: ?*PasswordCredentialImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_iconURL = &get_iconURL,
        .get_name = &get_name,
        .get_password = &get_password,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PasswordCredentialImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PasswordCredentialImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, form: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try PasswordCredentialImpl.call_constructor(allocator, ctx, form);
    }

    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_password(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_name(instance);
    }

    pub fn get_iconURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PasswordCredentialImpl.get_iconURL(instance);
    }

};
